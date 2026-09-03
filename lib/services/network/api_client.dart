import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'api_result.dart';
import 'response_cache.dart';

/// Signals that external network access has not been enabled.
///
/// External lookups are opt-in: a gene list from an unpublished study reveals
/// what the user is researching, so nothing leaves the device until they say so.
typedef ConsentCheck = bool Function();

/// HTTP client for external APIs, with caching, timeouts, bounded retries, and
/// an explicit offline path.
///
/// Every call returns an [ApiResult] rather than throwing, and every successful
/// result states whether it came from the network, from fresh cache, or from an
/// expired cache used because the server was unreachable.
class ApiClient {
  ApiClient({
    required ConsentCheck hasConsent,
    ResponseCache? cache,
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 12),
    this.maxAttempts = 3,
    this.maxResponseBytes = 4 * 1024 * 1024,
    this.retryBackoff = const Duration(milliseconds: 400),
    this.minRequestSpacing = const Duration(milliseconds: 120),
  })  : _hasConsent = hasConsent,
        _cache = cache ?? ResponseCache(),
        _http = httpClient ?? http.Client(),
        _ownsClient = httpClient == null;

  final ConsentCheck _hasConsent;
  final ResponseCache _cache;
  final http.Client _http;
  final bool _ownsClient;

  /// Per-attempt time budget.
  ///
  /// Applied to each attempt, not to the call as a whole, so a request that
  /// stalls cannot hang the UI. Screens navigate before the request resolves and
  /// render a loading state, so this bounds how long that state can persist.
  final Duration timeout;

  /// Total attempts, including the first. Only transient failures are retried.
  final int maxAttempts;

  /// Hard cap on a response body.
  ///
  /// A GraphQL query with an unbounded page size can return tens of megabytes;
  /// decoding that on the UI isolate would freeze the app.
  final int maxResponseBytes;

  /// Base delay between attempts, doubled each time.
  final Duration retryBackoff;

  /// Minimum gap between outgoing requests.
  ///
  /// A 30-gene signature would otherwise fire 30 requests at once, which reads
  /// as abuse to a public API and risks a 429 for everyone on the same address.
  final Duration minRequestSpacing;

  DateTime? _lastRequestAt;

  /// Serialises the spacing check so concurrent callers cannot both pass it.
  Future<void> _spacingGate = Future.value();

  ResponseCache get cache => _cache;

  /// Issues a POST with a JSON body, typically a GraphQL query.
  ///
  /// [cacheKey] must capture everything that affects the response; for GraphQL
  /// that means the query text and its variables. Pass `null` to bypass the
  /// cache entirely.
  Future<ApiResult<Map<String, dynamic>>> postJson({
    required Uri url,
    required Map<String, dynamic> body,
    String? cacheKey,
    Map<String, String> headers = const {},
  }) async {
    final encodedBody = jsonEncode(body);
    final key = cacheKey ?? '${url.toString()}|$encodedBody';

    // Fresh cache short-circuits before the consent check: data already on this
    // device can be re-read regardless, and this keeps a consent toggle from
    // blanking results the user is looking at.
    final cached = await _cache.read(key);
    if (cached != null && cached.isFresh) {
      final decoded = _decode(cached.body);
      if (decoded != null) {
        return ApiSuccess(
          data: decoded,
          freshness: DataFreshness.freshCache,
          retrievedAt: cached.retrievedAt,
        );
      }
    }

    if (!_hasConsent()) {
      // An expired copy is still better than nothing, and serving it sends no
      // data anywhere.
      if (cached != null) {
        final decoded = _decode(cached.body);
        if (decoded != null) {
          return ApiSuccess(
            data: decoded,
            freshness: DataFreshness.staleCache,
            retrievedAt: cached.retrievedAt,
          );
        }
      }
      return const ApiFailure(
        reason: NetworkFailureReason.consentNotGranted,
        message: 'External lookups are turned off. Enable them in Settings to '
            'fetch target-disease evidence. Your gene symbols are sent to the '
            'external service when this is on.',
      );
    }

    ApiFailure<Map<String, dynamic>>? lastFailure;

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      final outcome = await _attempt(
        url: url,
        encodedBody: encodedBody,
        headers: headers,
      );

      switch (outcome) {
        case _AttemptSuccess(:final body):
          await _cache.write(key, body);
          final decoded = _decode(body);
          if (decoded == null) {
            return const ApiFailure(
              reason: NetworkFailureReason.invalidResponse,
              message: 'The service returned a response this app could not '
                  'read.',
            );
          }
          return ApiSuccess(
            data: decoded,
            freshness: DataFreshness.network,
            retrievedAt: DateTime.now(),
          );

        case _AttemptFailure(:final failure):
          lastFailure = failure;
          final isLastAttempt = attempt == maxAttempts;
          if (!failure.isRetryable || isLastAttempt) {
            return _withStaleFallback(cached, failure);
          }
          // Exponential backoff. Bounded by maxAttempts, so worst case here is
          // 0.4s + 0.8s of delay on top of the per-attempt timeouts.
          await Future<void>.delayed(retryBackoff * (1 << (attempt - 1)));
      }
    }

    return _withStaleFallback(
      cached,
      lastFailure ??
          const ApiFailure(
            reason: NetworkFailureReason.unknown,
            message: 'The request failed.',
          ),
    );
  }

  /// Serves an expired cache entry when the network could not be reached.
  ///
  /// Only for transient failures: a 400 means the request itself was wrong, so
  /// showing old data would hide a real bug.
  ApiResult<Map<String, dynamic>> _withStaleFallback(
    CachedResponse? cached,
    ApiFailure<Map<String, dynamic>> failure,
  ) {
    if (cached != null && failure.isRetryable) {
      final decoded = _decode(cached.body);
      if (decoded != null) {
        return ApiSuccess(
          data: decoded,
          freshness: DataFreshness.staleCache,
          retrievedAt: cached.retrievedAt,
        );
      }
    }
    return failure;
  }

  Future<_AttemptOutcome> _attempt({
    required Uri url,
    required String encodedBody,
    required Map<String, String> headers,
  }) async {
    try {
      await _waitForSpacing();

      final response = await _http
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              ...headers,
            },
            body: encodedBody,
          )
          .timeout(timeout);

      if (response.bodyBytes.length > maxResponseBytes) {
        return _AttemptFailure(ApiFailure(
          reason: NetworkFailureReason.responseTooLarge,
          message: 'The service returned more data than this app will load '
              '(${(response.bodyBytes.length / 1024 / 1024).toStringAsFixed(1)} '
              'MB). Try a smaller gene set.',
          statusCode: response.statusCode,
        ));
      }

      final status = response.statusCode;
      if (status >= 200 && status < 300) {
        return _AttemptSuccess(response.body);
      }

      return _AttemptFailure(_failureForStatus(status));
    } on TimeoutException catch (error) {
      return _AttemptFailure(ApiFailure(
        reason: NetworkFailureReason.timeout,
        message: 'The service did not respond within '
            '${timeout.inSeconds} seconds.',
        cause: error,
      ));
    } on SocketException catch (error) {
      return _AttemptFailure(ApiFailure(
        reason: NetworkFailureReason.offline,
        message: 'No network connection. Cached results are still available.',
        cause: error,
      ));
    } on HandshakeException catch (error) {
      return _AttemptFailure(ApiFailure(
        reason: NetworkFailureReason.tlsFailure,
        message: 'The secure connection could not be established. A captive '
            'Wi-Fi portal or an incorrect device clock can cause this.',
        cause: error,
      ));
    } on http.ClientException catch (error) {
      // http wraps most transport problems in ClientException, including
      // connection resets that never surface as SocketException on some
      // platforms.
      return _AttemptFailure(ApiFailure(
        reason: NetworkFailureReason.offline,
        message: 'The connection was interrupted. Cached results are still '
            'available.',
        cause: error,
      ));
    } catch (error) {
      return _AttemptFailure(ApiFailure(
        reason: NetworkFailureReason.unknown,
        message: 'Unexpected network error.',
        cause: error,
      ));
    }
  }

  static ApiFailure<Map<String, dynamic>> _failureForStatus(int status) {
    if (status == 429) {
      return ApiFailure(
        reason: NetworkFailureReason.rateLimited,
        message: 'The service is rate limiting requests. Try again shortly.',
        statusCode: status,
      );
    }
    if (status >= 500) {
      return ApiFailure(
        reason: NetworkFailureReason.serverError,
        message: 'The service reported an error (HTTP $status).',
        statusCode: status,
      );
    }
    return ApiFailure(
      reason: NetworkFailureReason.badRequest,
      message: 'The service rejected the request (HTTP $status).',
      statusCode: status,
    );
  }

  /// Enforces [minRequestSpacing] across concurrent callers.
  Future<void> _waitForSpacing() {
    // Chaining onto a single future serialises the read-modify-write of
    // _lastRequestAt, so parallel callers queue instead of all seeing the same
    // timestamp and firing together.
    final gate = _spacingGate.then((_) async {
      final last = _lastRequestAt;
      if (last != null) {
        final elapsed = DateTime.now().difference(last);
        final remaining = minRequestSpacing - elapsed;
        if (remaining > Duration.zero) {
          await Future<void>.delayed(remaining);
        }
      }
      _lastRequestAt = DateTime.now();
    });
    _spacingGate = gate.catchError((_) {});
    return gate;
  }

  static Map<String, dynamic>? _decode(String body) {
    try {
      final decoded = jsonDecode(body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (error) {
      debugPrint('Response decode failed: $error');
      return null;
    }
  }

  void dispose() {
    if (_ownsClient) _http.close();
  }
}

sealed class _AttemptOutcome {
  const _AttemptOutcome();
}

class _AttemptSuccess extends _AttemptOutcome {
  const _AttemptSuccess(this.body);

  final String body;
}

class _AttemptFailure extends _AttemptOutcome {
  const _AttemptFailure(this.failure);

  final ApiFailure<Map<String, dynamic>> failure;
}
