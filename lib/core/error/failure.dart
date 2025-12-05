class Failure implements Exception {
  final String message;
  final int? statusCode;

  Failure(this.message, {this.statusCode});

  @override
  String toString() => 'Failure(statusCode: $statusCode, message: $message)';
}
