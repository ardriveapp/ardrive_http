import 'package:equatable/equatable.dart';

class ArDriveHTTPResponse {
  ArDriveHTTPResponse({
    required this.data,
    this.statusCode,
    this.statusMessage,
    required this.retryAttempts,
  }) {
    data = data;
    statusCode = statusCode;
    statusMessage = statusMessage;
    retryAttempts = retryAttempts;
  }

  dynamic data;
  int? statusCode;
  String? statusMessage;
  int retryAttempts;
}

class ArDriveHTTPException extends Equatable implements Exception {
  final int retryAttempts;
  final Object dioException;

  const ArDriveHTTPException(
      {required this.retryAttempts, required this.dioException});
  @override
  List<Object?> get props => [retryAttempts];

  @override
  String toString() {
    return '$dioException\nRetry attempts: $retryAttempts\n';
  }
}
