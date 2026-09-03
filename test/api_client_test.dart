import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:onco_repurpose_ai/services/network/api_client.dart';
import 'package:onco_repurpose_ai/services/network/api_result.dart';
import 'package:onco_repurpose_ai/services/network/response_cache.dart';

/// Programmable stub for `http.Client`.
///
/// Requests are recorded so tests can assert on retry counts, request spacing,
/// and that no request was made at all when consent is withheld.
class _StubClient extends http.BaseClient {
  _StubClient(this.handler);

  /// Called for each request with the 1-based attempt number.
  final Future<http.StreamedResponse> Function(int attempt, http.BaseRequest)
      handler;

  final List<DateTime> requestTimes = [];
  final List<String> requestBodies = [];

  int get callCount => requestTimes.length;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requestTimes.add(DateTime.now());
    if (request is http.Request) requestBodies.add(request.body);
    return handler(requestTimes.length, request);
  }
}

http.StreamedResponse _response(
  String body, {
  int status = 200,
}) {
  final bytes = utf8.encode(body);
  return http.StreamedResponse(
    Stream.value(bytes),
    status,
    contentLength: bytes.length,
  );
}

void main() {
  final url = Uri.parse('https://api.example.org/graphql');
  const body = {'query': '{ target { id } }'};

  late Directory tempDir;
  late ResponseCache cache;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('onco_api_test');
    cache = ResponseCache(directoryOverride: tempDir);
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  ApiClient clientWith(
    _StubClient stub, {
    bool consent = true,
    int maxAttempts = 3,
    Duration timeout = const Duration(seconds: 12),
    Duration backoff = const Duration(milliseconds: 1),
    Duration spacing = Duration.zero,
    int maxResponseBytes = 4 * 1024 * 1024,
    ResponseCache? cacheOverride,
  }) {
    return ApiClient(
      hasConsent: () => consent,
      cache: cacheOverride ?? cache,
      httpClient: stub,
      timeout: timeout,
      maxAttempts: maxAttempts,
      retryBackoff: backoff,
      minRequestSpacing: spacing,
      maxResponseBytes: maxResponseBytes,
    );
  }

  group('consent gate', () {
    test('sends nothing when consent is withheld', () async {
      final stub = _StubClient((_, __) async => _response('{}'));
      final client = clientWith(stub, consent: false);

      final result = await client.postJson(url: url, body: body);

      expect(stub.callCount, 0, reason: 'no data may leave the device');
      expect(result, isA<ApiFailure<Map<String, dynamic>>>());
      final failure = result as ApiFailure<Map<String, dynamic>>;
      expect(failure.reason, NetworkFailureReason.consentNotGranted);
      expect(failure.isRetryable, isFalse);
      expect(failure.message, contains('Settings'));
    });

    test('explains that gene symbols are transmitted', () async {
      final stub = _StubClient((_, __) async => _response('{}'));
      final client = clientWith(stub, consent: false);

      final result =
          await client.postJson(url: url, body: body) as ApiFailure;
      expect(result.message, contains('gene symbols are sent'));
    });

    test('serves fresh cache without consent, since nothing is transmitted',
        () async {
      final stub = _StubClient((_, __) async => _response('{}'));
      await cache.write('key', '{"cached":true}');

      final client = clientWith(stub, consent: false);
      final result = await client.postJson(
        url: url,
        body: body,
        cacheKey: 'key',
      );

      expect(stub.callCount, 0);
      expect(result, isA<ApiSuccess<Map<String, dynamic>>>());
      final success = result as ApiSuccess<Map<String, dynamic>>;
      expect(success.data['cached'], isTrue);
      expect(success.freshness, DataFreshness.freshCache);
    });

    test('serves expired cache without consent, labelled as an offline copy',
        () async {
      final aged = ResponseCache(
        directoryOverride: tempDir,
        freshFor: Duration.zero,
      );
      await aged.write('key', '{"cached":true}');

      final stub = _StubClient((_, __) async => _response('{}'));
      final client =
          clientWith(stub, consent: false, cacheOverride: aged);

      final result = await client.postJson(
        url: url,
        body: body,
        cacheKey: 'key',
      ) as ApiSuccess<Map<String, dynamic>>;

      expect(stub.callCount, 0);
      expect(result.freshness, DataFreshness.staleCache);
      expect(result.isStale, isTrue);
    });
  });

  group('successful requests', () {
    test('returns decoded JSON marked as live', () async {
      final stub = _StubClient((_, __) async => _response('{"data":{"x":1}}'));
      final client = clientWith(stub);

      final result = await client.postJson(url: url, body: body)
          as ApiSuccess<Map<String, dynamic>>;

      expect(stub.callCount, 1);
      expect(result.freshness, DataFreshness.network);
      expect(result.isStale, isFalse);
      expect(result.data['data'], {'x': 1});
    });

    test('sends the JSON body and content type', () async {
      final stub = _StubClient((_, request) async {
        expect(request.headers['Content-Type'], contains('application/json'));
        return _response('{}');
      });
      final client = clientWith(stub);

      await client.postJson(url: url, body: body);
      expect(stub.requestBodies.single, jsonEncode(body));
    });

    test('caches the response for the next call', () async {
      final stub = _StubClient((_, __) async => _response('{"n":1}'));
      final client = clientWith(stub);

      await client.postJson(url: url, body: body, cacheKey: 'k');
      final second = await client.postJson(url: url, body: body, cacheKey: 'k')
          as ApiSuccess<Map<String, dynamic>>;

      expect(stub.callCount, 1, reason: 'second call must hit the cache');
      expect(second.freshness, DataFreshness.freshCache);
    });

    test('treats different bodies as different cache entries', () async {
      var counter = 0;
      final stub = _StubClient((_, __) async => _response('{"n":${++counter}}'));
      final client = clientWith(stub);

      await client.postJson(url: url, body: {'query': 'A'});
      await client.postJson(url: url, body: {'query': 'B'});

      expect(stub.callCount, 2);
    });
  });

  group('offline behaviour', () {
    test('reports offline when the socket cannot be opened', () async {
      final stub = _StubClient(
          (_, __) async => throw const SocketException('No route to host'));
      final client = clientWith(stub, maxAttempts: 1);

      final failure = await client.postJson(url: url, body: body)
          as ApiFailure<Map<String, dynamic>>;

      expect(failure.reason, NetworkFailureReason.offline);
      expect(failure.isRetryable, isTrue);
      expect(failure.message, contains('Cached results are still available'));
    });

    test('falls back to expired cache when offline', () async {
      // The offline case that matters: a user who looked something up before
      // losing connectivity still sees it, clearly labelled.
      final aged = ResponseCache(
        directoryOverride: tempDir,
        freshFor: Duration.zero,
      );
      await aged.write('k', '{"old":true}');

      final stub =
          _StubClient((_, __) async => throw const SocketException('offline'));
      final client =
          clientWith(stub, maxAttempts: 1, cacheOverride: aged);

      final result = await client.postJson(url: url, body: body, cacheKey: 'k')
          as ApiSuccess<Map<String, dynamic>>;

      expect(result.freshness, DataFreshness.staleCache);
      expect(result.data['old'], isTrue);
      expect(result.retrievedAt, isNotNull);
    });

    test('fails when offline with no cached copy', () async {
      final stub =
          _StubClient((_, __) async => throw const SocketException('offline'));
      final client = clientWith(stub, maxAttempts: 1);

      final result = await client.postJson(url: url, body: body);
      expect(result, isA<ApiFailure<Map<String, dynamic>>>());
      expect(result.dataOrNull, isNull);
    });

    test('maps a ClientException to offline', () async {
      // Some platforms surface connection resets this way rather than as
      // SocketException.
      final stub = _StubClient(
          (_, __) async => throw http.ClientException('Connection reset'));
      final client = clientWith(stub, maxAttempts: 1);

      final failure =
          await client.postJson(url: url, body: body) as ApiFailure;
      expect(failure.reason, NetworkFailureReason.offline);
    });

    test('maps a TLS handshake failure to its own reason', () async {
      final stub =
          _StubClient((_, __) async => throw const HandshakeException('bad'));
      final client = clientWith(stub, maxAttempts: 1);

      final failure =
          await client.postJson(url: url, body: body) as ApiFailure;
      expect(failure.reason, NetworkFailureReason.tlsFailure);
      expect(failure.message, contains('captive'));
    });
  });

  group('slow networks', () {
    test('times out an attempt that never responds', () async {
      final stub = _StubClient((_, __) async {
        // Longer than the client's budget; the timeout must fire first.
        await Future<void>.delayed(const Duration(seconds: 5));
        return _response('{}');
      });
      final client = clientWith(
        stub,
        maxAttempts: 1,
        timeout: const Duration(milliseconds: 80),
      );

      final failure = await client.postJson(url: url, body: body)
          as ApiFailure<Map<String, dynamic>>;

      expect(failure.reason, NetworkFailureReason.timeout);
      expect(failure.isRetryable, isTrue);
    });

    test('a slow first attempt does not prevent a later success', () async {
      final stub = _StubClient((attempt, __) async {
        if (attempt == 1) {
          await Future<void>.delayed(const Duration(seconds: 5));
        }
        return _response('{"ok":true}');
      });
      final client = clientWith(
        stub,
        maxAttempts: 2,
        timeout: const Duration(milliseconds: 80),
      );

      final result = await client.postJson(url: url, body: body);

      expect(stub.callCount, 2);
      expect(result, isA<ApiSuccess<Map<String, dynamic>>>());
    });

    test('a slow response still completes within the budget', () async {
      final stub = _StubClient((_, __) async {
        await Future<void>.delayed(const Duration(milliseconds: 60));
        return _response('{"ok":true}');
      });
      final client = clientWith(
        stub,
        timeout: const Duration(seconds: 2),
      );

      final result = await client.postJson(url: url, body: body);
      expect(result, isA<ApiSuccess<Map<String, dynamic>>>());
    });

    test('falls back to cache after exhausting timeouts', () async {
      final aged = ResponseCache(
        directoryOverride: tempDir,
        freshFor: Duration.zero,
      );
      await aged.write('k', '{"old":true}');

      final stub = _StubClient((_, __) async {
        await Future<void>.delayed(const Duration(seconds: 5));
        return _response('{}');
      });
      final client = clientWith(
        stub,
        maxAttempts: 2,
        timeout: const Duration(milliseconds: 50),
        cacheOverride: aged,
      );

      final result = await client.postJson(url: url, body: body, cacheKey: 'k')
          as ApiSuccess<Map<String, dynamic>>;

      expect(result.freshness, DataFreshness.staleCache);
    });
  });

  group('retry policy', () {
    test('retries a 500 up to maxAttempts', () async {
      final stub =
          _StubClient((_, __) async => _response('boom', status: 500));
      final client = clientWith(stub, maxAttempts: 3);

      final failure =
          await client.postJson(url: url, body: body) as ApiFailure;

      expect(stub.callCount, 3);
      expect(failure.reason, NetworkFailureReason.serverError);
      expect(failure.statusCode, 500);
    });

    test('stops retrying once a call succeeds', () async {
      final stub = _StubClient((attempt, __) async => attempt < 3
          ? _response('boom', status: 503)
          : _response('{"ok":true}'));
      final client = clientWith(stub, maxAttempts: 5);

      final result = await client.postJson(url: url, body: body);

      expect(stub.callCount, 3);
      expect(result, isA<ApiSuccess<Map<String, dynamic>>>());
    });

    test('does not retry a 400, since the request itself is wrong', () async {
      final stub =
          _StubClient((_, __) async => _response('nope', status: 400));
      final client = clientWith(stub, maxAttempts: 3);

      final failure =
          await client.postJson(url: url, body: body) as ApiFailure;

      expect(stub.callCount, 1);
      expect(failure.reason, NetworkFailureReason.badRequest);
      expect(failure.isRetryable, isFalse);
    });

    test('retries a 429 and reports rate limiting', () async {
      final stub =
          _StubClient((_, __) async => _response('slow down', status: 429));
      final client = clientWith(stub, maxAttempts: 2);

      final failure =
          await client.postJson(url: url, body: body) as ApiFailure;

      expect(stub.callCount, 2);
      expect(failure.reason, NetworkFailureReason.rateLimited);
    });

    test('does not serve stale cache for a non-retryable failure', () async {
      // A 400 means the query is broken; showing old data would mask the bug.
      final aged = ResponseCache(
        directoryOverride: tempDir,
        freshFor: Duration.zero,
      );
      await aged.write('k', '{"old":true}');

      final stub =
          _StubClient((_, __) async => _response('nope', status: 400));
      final client = clientWith(stub, cacheOverride: aged);

      final result = await client.postJson(url: url, body: body, cacheKey: 'k');
      expect(result, isA<ApiFailure<Map<String, dynamic>>>());
    });

    test('applies exponential backoff between attempts', () async {
      final stub =
          _StubClient((_, __) async => _response('boom', status: 500));
      final client = clientWith(
        stub,
        maxAttempts: 3,
        backoff: const Duration(milliseconds: 40),
      );

      final started = DateTime.now();
      await client.postJson(url: url, body: body);
      final elapsed = DateTime.now().difference(started);

      // 40ms after attempt 1 plus 80ms after attempt 2.
      expect(elapsed.inMilliseconds, greaterThanOrEqualTo(110));
    });

    test('does not cache a failed response', () async {
      final stub =
          _StubClient((_, __) async => _response('boom', status: 500));
      final client = clientWith(stub, maxAttempts: 1);

      await client.postJson(url: url, body: body, cacheKey: 'k');
      expect(await cache.read('k'), isNull);
    });
  });

  group('malformed and oversized responses', () {
    test('reports an unparseable body as an invalid response', () async {
      final stub = _StubClient((_, __) async => _response('<html>oops'));
      final client = clientWith(stub);

      final failure =
          await client.postJson(url: url, body: body) as ApiFailure;
      expect(failure.reason, NetworkFailureReason.invalidResponse);
      expect(failure.isRetryable, isFalse);
    });

    test('reports a JSON array as an invalid response', () async {
      // GraphQL always returns an object; an array means something else replied.
      final stub = _StubClient((_, __) async => _response('[1,2,3]'));
      final client = clientWith(stub);

      final failure =
          await client.postJson(url: url, body: body) as ApiFailure;
      expect(failure.reason, NetworkFailureReason.invalidResponse);
    });

    test('rejects a response over the size cap', () async {
      final big = jsonEncode({'data': 'x' * 5000});
      final stub = _StubClient((_, __) async => _response(big));
      final client = clientWith(stub, maxAttempts: 1, maxResponseBytes: 1000);

      final failure =
          await client.postJson(url: url, body: body) as ApiFailure;

      expect(failure.reason, NetworkFailureReason.responseTooLarge);
      expect(failure.isRetryable, isFalse);
      expect(failure.message, contains('smaller gene set'));
    });

    test('accepts a response at the size cap', () async {
      final payload = jsonEncode({'ok': true});
      final stub = _StubClient((_, __) async => _response(payload));
      final client = clientWith(
        stub,
        maxResponseBytes: utf8.encode(payload).length,
      );

      final result = await client.postJson(url: url, body: body);
      expect(result, isA<ApiSuccess<Map<String, dynamic>>>());
    });
  });

  group('request spacing', () {
    test('spaces out concurrent requests', () async {
      // A 30-gene signature would otherwise fire 30 requests at once.
      final stub = _StubClient((_, __) async => _response('{}'));
      final client = clientWith(
        stub,
        spacing: const Duration(milliseconds: 30),
      );

      final started = DateTime.now();
      await Future.wait([
        client.postJson(url: url, body: {'q': 1}),
        client.postJson(url: url, body: {'q': 2}),
        client.postJson(url: url, body: {'q': 3}),
      ]);
      final elapsed = DateTime.now().difference(started);

      expect(stub.callCount, 3);
      expect(elapsed.inMilliseconds, greaterThanOrEqualTo(60));

      final gaps = <int>[];
      for (var i = 1; i < stub.requestTimes.length; i++) {
        gaps.add(stub.requestTimes[i]
            .difference(stub.requestTimes[i - 1])
            .inMilliseconds);
      }
      // Allow a small scheduling tolerance below the nominal spacing.
      expect(gaps.every((gap) => gap >= 20), isTrue, reason: 'gaps: $gaps');
    });

    test('does not delay a cache hit', () async {
      final stub = _StubClient((_, __) async => _response('{"n":1}'));
      final client = clientWith(
        stub,
        spacing: const Duration(milliseconds: 500),
      );
      await client.postJson(url: url, body: body, cacheKey: 'k');

      final started = DateTime.now();
      await client.postJson(url: url, body: body, cacheKey: 'k');
      final elapsed = DateTime.now().difference(started);

      expect(elapsed.inMilliseconds, lessThan(400));
    });
  });

  group('ApiResult', () {
    test('dataOrNull exposes success data and null on failure', () {
      const success = ApiSuccess<int>(
          data: 7, freshness: DataFreshness.network);
      const failure = ApiFailure<int>(
        reason: NetworkFailureReason.offline,
        message: 'offline',
      );

      expect(success.dataOrNull, 7);
      expect(success.isSuccess, isTrue);
      expect(failure.dataOrNull, isNull);
      expect(failure.isSuccess, isFalse);
    });

    test('classifies which failures are worth retrying', () {
      expect(NetworkFailureReason.offline.isTransient, isTrue);
      expect(NetworkFailureReason.timeout.isTransient, isTrue);
      expect(NetworkFailureReason.serverError.isTransient, isTrue);
      expect(NetworkFailureReason.rateLimited.isTransient, isTrue);
      expect(NetworkFailureReason.badRequest.isTransient, isFalse);
      expect(NetworkFailureReason.invalidResponse.isTransient, isFalse);
      expect(NetworkFailureReason.consentNotGranted.isTransient, isFalse);
      expect(NetworkFailureReason.responseTooLarge.isTransient, isFalse);
    });

    test('labels each freshness state distinctly', () {
      final labels =
          DataFreshness.values.map((value) => value.label).toSet();
      expect(labels, hasLength(DataFreshness.values.length));
      expect(DataFreshness.staleCache.label, 'Offline copy');
    });
  });
}
