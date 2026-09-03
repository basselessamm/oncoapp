/// Outcome of a network request, with the freshness of the data it carries.
///
/// The app must be able to state three things apart that a nullable return
/// value cannot express: data fetched now, data served from a valid cache, and
/// data served from an expired cache because the network was unreachable. The
/// third case is still useful but must be labelled, never presented as current.
sealed class ApiResult<T> {
  const ApiResult();

  /// Data if the call succeeded, otherwise `null`.
  T? get dataOrNull => switch (this) {
        ApiSuccess<T>(:final data) => data,
        ApiFailure<T>() => null,
      };

  bool get isSuccess => this is ApiSuccess<T>;
}

/// A successful result, from the network or from cache.
class ApiSuccess<T> extends ApiResult<T> {
  const ApiSuccess({
    required this.data,
    required this.freshness,
    this.retrievedAt,
  });

  final T data;

  final DataFreshness freshness;

  /// When the underlying response was received from the server.
  ///
  /// For [DataFreshness.staleCache] this is how the UI states the age of what
  /// it is showing.
  final DateTime? retrievedAt;

  bool get isStale => freshness == DataFreshness.staleCache;
}

/// A failed result. [message] is written for display to the user.
class ApiFailure<T> extends ApiResult<T> {
  const ApiFailure({
    required this.reason,
    required this.message,
    this.statusCode,
    this.cause,
  });

  final NetworkFailureReason reason;

  final String message;

  /// HTTP status code, when the failure came from a response rather than from
  /// the transport.
  final int? statusCode;

  final Object? cause;

  /// Whether retrying the same request later could plausibly succeed.
  bool get isRetryable => reason.isTransient;

  @override
  String toString() => 'ApiFailure($reason, $statusCode): $message';
}

/// Where a successful payload came from.
enum DataFreshness {
  /// Fetched from the server during this call.
  network('Live'),

  /// Served from cache that is still within its freshness window.
  freshCache('Cached'),

  /// Served from expired cache because the server could not be reached.
  ///
  /// Distinct from [freshCache] because the UI has to say so: showing
  /// month-old target-disease evidence as if it were current would be the same
  /// class of error as the placeholder docking scores this app used to display.
  staleCache('Offline copy');

  const DataFreshness(this.label);

  final String label;
}

/// Why a request failed.
///
/// Split by cause rather than collapsed into one error string, because the UI's
/// response differs: an offline device gets a retry affordance, a consent gate
/// gets a settings link, and a malformed response gets neither.
enum NetworkFailureReason {
  /// The user has not enabled external lookups.
  ///
  /// Not an error condition. External requests are opt-in because a gene list
  /// from an unpublished study reveals what the user is working on.
  consentNotGranted(isTransient: false),

  /// No route to the network: airplane mode, no Wi-Fi, DNS failure.
  offline(isTransient: true),

  /// The request exceeded its time budget.
  timeout(isTransient: true),

  /// TLS negotiation failed. Often a captive portal or a clock skew.
  tlsFailure(isTransient: true),

  /// Server returned 5xx.
  serverError(isTransient: true),

  /// Server returned 429, or a documented rate limit was hit locally.
  rateLimited(isTransient: true),

  /// Server returned 4xx other than 429.
  badRequest(isTransient: false),

  /// Response arrived but could not be parsed, or reported a GraphQL error.
  invalidResponse(isTransient: false),

  /// Response exceeded the size cap.
  responseTooLarge(isTransient: false),

  /// Anything not covered above.
  unknown(isTransient: true);

  const NetworkFailureReason({required this.isTransient});

  /// Whether a later attempt could succeed without the user changing anything.
  ///
  /// Drives both the automatic retry policy and whether the UI offers a retry
  /// button.
  final bool isTransient;
}
