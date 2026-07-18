class ApiException implements Exception {
  const ApiException(
    this.message, {
    this.statusCode,
    this.code,
    this.retryAfterSeconds,
  });

  final String message;
  final int? statusCode;
  final String? code;
  final int? retryAfterSeconds;

  @override
  String toString() => message;
}
