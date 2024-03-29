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
  final Object exception;
  final int? statusCode;
  final String? statusMessage;
  final Object? data;

  const ArDriveHTTPException({
    required this.retryAttempts,
    required this.exception,
    this.statusCode,
    this.statusMessage,
    this.data,
  });

  @override
  List<Object?> get props => [retryAttempts];

  @override
  String toString() {
    return 'ArDriveHTTPException: $retryAttempts, $statusCode, $statusMessage, $exception';
  }
}

class WebWorkerNetworkRequestError {
  final int? statusCode;
  final String? statusMessage;
  final int retryAttempts;
  final Object? error;
  final Object? data;

  const WebWorkerNetworkRequestError({
    this.statusCode,
    this.statusMessage,
    required this.retryAttempts,
    this.error,
    this.data,
  });

  @override
  String toString() {
    return 'WebWorkerNetworkRequestError: $error';
  }
}
