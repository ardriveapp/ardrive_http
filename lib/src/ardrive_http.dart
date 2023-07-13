import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:ardrive_http/src/responses.dart';
import 'package:dio/dio.dart';
import 'package:dio_smart_retry/dio_smart_retry.dart';
import 'package:flutter/foundation.dart';
import 'package:isolated_worker/js_isolated_worker.dart';

const List<String> jsScriptsToImport = <String>['ardrive-http.js'];

String normalizeResponseTypeToJS(ResponseType responseType) {
  switch (responseType) {
    case ResponseType.bytes:
      return 'bytes';
    case ResponseType.plain:
      return 'text';
    case ResponseType.json:
      return 'json';

    default:
      return responseType.toString().split('.')[1];
  }
}

/// `ArDriveHTTP` is a HTTP client for ArDrive application. It encapsulates the logic for sending HTTP requests and handling responses.
/// It provides support for GET and POST requests, retrying failed requests, and optional logging.
/// The class is designed to work across different platforms (Web and Dart IO) and supports different types of data (JSON, bytes, etc.).
/// For the Web platform, it attempts to use web workers for requests when possible, falling back to the Dart IO implementation otherwise.
class ArDriveHTTP {
  int retries;
  int retryDelayMs;
  bool noLogs;
  int retryAttempts = 0;

  ArDriveHTTP({
    this.retries = 8,
    this.retryDelayMs = 200,
    this.noLogs = false,
  });

  Dio _dio() {
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 8),
      ),
    );

    if (!noLogs) {
      dio.interceptors.add(LogInterceptor());
    }

    if (retries > 0) {
      dio.interceptors.add(_getDioRetrySettings(dio));
    }

    return dio;
  }

  /// Sends a GET request to the specified URL with the provided headers.
  /// The method behaves differently depending on the platform (Web or Dart IO).
  ///
  /// If web workers are not available, it falls back to the Dart IO implementation (`_getIO`).
  ///
  /// For the Dart IO platform, it uses the Dart IO implementation
  Future<ArDriveHTTPResponse> get({
    required String url,
    Map<String, dynamic> headers = const <String, dynamic>{},
    ResponseType responseType = ResponseType.plain,
  }) async {
    final Map getIOParams = <String, dynamic>{};
    getIOParams['url'] = url;
    getIOParams['headers'] = headers;
    getIOParams['responseType'] = responseType;

    if (kIsWeb) {
      if (await _loadWebWorkers()) {
        return await _getWeb(
          url: url,
          headers: headers,
          responseType: responseType,
        );
      } else {
        return await _getIO(getIOParams);
      }
    }

    return await compute(_getIO, getIOParams);
  }

  Future<ArDriveHTTPResponse> getJson(String url) async {
    return get(url: url, responseType: ResponseType.json);
  }

  Future<ArDriveHTTPResponse> getAsBytes(String url) async {
    return get(url: url, responseType: ResponseType.bytes);
  }

  Future<ArDriveHTTPResponse> _getIO(Map params) async {
    final String url = params['url'];
    final Map<String, dynamic> headers = params['headers'];
    final ResponseType responseType = params['responseType'];

    try {
      Response response = await _dio().get(
        url,
        options: Options(responseType: responseType, headers: headers),
      );

      return ArDriveHTTPResponse(
        data: response.data,
        statusCode: response.statusCode,
        statusMessage: response.statusMessage,
        retryAttempts: retryAttempts,
      );
    } on DioError catch (error) {
      throw ArDriveHTTPException(
        retryAttempts: retryAttempts,
        exception: error,
        statusCode: error.response?.statusCode,
        statusMessage: error.response?.statusMessage,
      );
    } catch (error) {
      throw ArDriveHTTPException(
        retryAttempts: retryAttempts,
        exception: error,
      );
    }
  }

  Future<ArDriveHTTPResponse> _getWeb({
    required String url,
    required ResponseType responseType,
    Map<String, dynamic> headers = const <String, dynamic>{},
  }) async {
    try {
      final LinkedHashMap<dynamic, dynamic> response =
          await JsIsolatedWorker().run(
        functionName: 'get',
        arguments: [
          url,
          jsonEncode(headers),
          normalizeResponseTypeToJS(responseType),
          retries,
          retryDelayMs,
          noLogs,
        ],
      );

      if (response['error'] != null) {
        retryAttempts = response['retryAttempts'];

        throw WebWorkerNetworkRequestError(
          statusCode: response['statusCode'],
          statusMessage: response['statusMessage'],
          retryAttempts: retryAttempts,
          error: response['error'],
        );
      }

      return ArDriveHTTPResponse(
        data: responseType == ResponseType.bytes
            ? Uint8List.view(response['data'])
            : response['data'],
        statusCode: response['statusCode'],
        statusMessage: response['statusMessage'],
        retryAttempts: response['retryAttempts'],
      );
    } on WebWorkerNetworkRequestError catch (error) {
      throw ArDriveHTTPException(
        retryAttempts: retryAttempts,
        exception: error,
        statusCode: error.statusCode,
        statusMessage: error.statusMessage,
      );
    } catch (error) {
      throw ArDriveHTTPException(
        retryAttempts: retryAttempts,
        exception: error,
      );
    }
  }

  /// Sends a POST request to the specified URL with the provided data and headers.
  /// The method behaves differently depending on the platform (Web or Dart IO) and whether a progress callback is provided.
  ///
  /// For the Web platform, if no progress callback is provided (`onSendProgress` is null),
  /// it attempts to use a web worker for the request (`_postWeb`). If web workers are not available,
  /// it falls back to the Dart IO implementation (`_postIO`).
  ///
  /// For the Dart IO platform, or if a progress callback is provided, it uses the Dart IO implementation (`_postIO`).
  ///
  /// We only use isolates when no progress callback is provided because isolates cannot communicate with the main thread
  ///
  /// `data` as a Stream is only supported on the Dart IO platform and won't work on Isolates.
  ///
  Future<ArDriveHTTPResponse> post({
    required String url,
    required dynamic data,
    required ContentType contentType,
    Map<String, dynamic> headers = const <String, dynamic>{},
    ResponseType responseType = ResponseType.plain,
    Function(double)? onSendProgress,
    Duration sendTimeout = const Duration(seconds: 8),
    Duration receiveTimeout = const Duration(seconds: 8),
  }) async {
    final postIOParams = <String, dynamic>{
      'url': url,
      'headers': headers,
      'data': data,
      'contentType': contentType,
      'responseType': responseType,
      'onSendProgress': onSendProgress,
      'sendTimeout': sendTimeout,
      'receiveTimeout': receiveTimeout,
    };

    final hasProgressIndicator = postIOParams['onSendProgress'] != null;
<<<<<<< Updated upstream

=======
>>>>>>> Stashed changes
    final isStream = data is Stream;

    final isWebWorkerPossible = await _isWebWorkerPossible(
      isStream: isStream,
      hasProgressIndicator: hasProgressIndicator,
    );

    if (isWebWorkerPossible) {
      return await _postWeb(
        url: url,
        headers: headers,
        data: data,
        contentType: contentType.toString(),
        responseType: responseType,
      );
    }

    return !hasProgressIndicator && !isStream
        ? await compute(_postIO, postIOParams)
        : await _postIO(postIOParams);
  }

  Future<bool> _isWebWorkerPossible({
    required bool isStream,
    required bool hasProgressIndicator,
  }) async {
    if (!kIsWeb) {
      return false;
    }

    final loadedWebWorkers = await _loadWebWorkers();

    return !isStream && !hasProgressIndicator && loadedWebWorkers;
  }

  Future<ArDriveHTTPResponse> postJson({
    required String url,
    required String data,
    ResponseType responseType = ResponseType.json,
  }) async {
    return post(
      url: url,
      data: data,
      contentType: ContentType.json,
      responseType: responseType,
    );
  }

  /// Sends a POST request with byte array data to the specified URL.
  /// The `data` parameter specifies the byte array data to include in the request body.
  Future<ArDriveHTTPResponse> postBytes({
    required String url,
    required Uint8List data,
    Map<String, dynamic> headers = const <String, dynamic>{},
    ResponseType responseType = ResponseType.json,
    Function(double)? onSendProgress,
    Duration sendTimeout = const Duration(seconds: 8),
    Duration receiveTimeout = const Duration(seconds: 8),
  }) async {
    return post(
      url: url,
      headers: headers,
      data: data,
      contentType: ContentType.binary,
      responseType: responseType,
      onSendProgress: onSendProgress,
      sendTimeout: sendTimeout,
      receiveTimeout: receiveTimeout,
    );
  }

  /// Sends a POST request with byte array data as a stream to the specified URL.
  /// The `data` parameter specifies the byte array data as a stream to include in the request body.
  Future<ArDriveHTTPResponse> postBytesAsStream({
    required String url,
    required Stream<List<int>> data,
    Map<String, dynamic> headers = const <String, dynamic>{},
    ResponseType responseType = ResponseType.json,
    Function(double)? onSendProgress,
    Duration sendTimeout = const Duration(seconds: 8),
    Duration receiveTimeout = const Duration(seconds: 8),
  }) async {
    return post(
      url: url,
      headers: headers,
      data: data,
      contentType: ContentType.binary,
      responseType: responseType,
      onSendProgress: onSendProgress,
      sendTimeout: sendTimeout,
      receiveTimeout: receiveTimeout,
    );
  }

  Future<ArDriveHTTPResponse> _postIO(
    Map params,
  ) async {
    final String url = params['url'];
    final Map<String, dynamic> headers =
        params['headers'] ?? <String, dynamic>{};
    final dynamic data = params['data'];
    final ContentType contentType = params['contentType'];
    final ResponseType responseType = params['responseType'];
    final Function(double)? onSendProgress = params['onSendProgress'];
    final Duration sendTimeout = params['sendTimeout'];
    final Duration receiveTimeout = params['receiveTimeout'];

    try {
      Response response = await _dio().post(
        url,
        data: data,
        onSendProgress: (int sent, int total) {
          if (onSendProgress != null) {
            onSendProgress.call(sent / total);
          }
        },
        options: Options(
          sendTimeout: sendTimeout,
          receiveTimeout: receiveTimeout,
          requestEncoder: (_, __) => data,
          headers: headers,
          contentType: contentType.toString(),
          responseType: responseType,
        ),
      );

      return ArDriveHTTPResponse(
        data: response.data,
        statusCode: response.statusCode,
        statusMessage: response.statusMessage,
        retryAttempts: retryAttempts,
      );
    } on DioError catch (error) {
      throw ArDriveHTTPException(
        retryAttempts: retryAttempts,
        exception: error,
        statusCode: error.response?.statusCode,
        statusMessage: error.response?.statusMessage,
      );
    } catch (error) {
      throw ArDriveHTTPException(
        retryAttempts: retryAttempts,
        exception: error,
      );
    }
  }

  Future<ArDriveHTTPResponse> _postWeb({
    required String url,
    required dynamic data,
    required String contentType,
    required ResponseType responseType,
    Map<String, dynamic> headers = const <String, dynamic>{},
  }) async {
    try {
      final LinkedHashMap<dynamic, dynamic> response =
          await JsIsolatedWorker().run(
        functionName: 'post',
        arguments: [
          url,
          jsonEncode(headers),
          data,
          contentType,
          normalizeResponseTypeToJS(responseType),
          retries,
          retryDelayMs,
          noLogs,
        ],
      );

      if (response['error'] != null) {
        retryAttempts = response['retryAttempts'];

        throw WebWorkerNetworkRequestError(
          statusCode: response['statusCode'],
          statusMessage: response['statusMessage'],
          retryAttempts: retryAttempts,
          error: response['error'],
        );
      }

      return ArDriveHTTPResponse(
        data: responseType == ResponseType.bytes
            ? Uint8List.view(response['data'])
            : response['data'],
        statusCode: response['statusCode'],
        statusMessage: response['statusMessage'],
        retryAttempts: response['retryAttempts'],
      );
    } on WebWorkerNetworkRequestError catch (error) {
      throw ArDriveHTTPException(
        retryAttempts: retryAttempts,
        exception: error,
        statusCode: error.statusCode,
        statusMessage: error.statusMessage,
      );
    } catch (error) {
      throw ArDriveHTTPException(
        retryAttempts: retryAttempts,
        exception: error,
      );
    }
  }

  Future<bool> _loadWebWorkers() async {
    return await JsIsolatedWorker().importScripts(jsScriptsToImport);
  }

  RetryInterceptor _getDioRetrySettings(Dio dio) {
    Duration retryDelay(int retryCount) =>
        Duration(milliseconds: retryDelayMs) * pow(1.5, retryCount);

    List<Duration> retryDelays =
        List.generate(retries, (index) => retryDelay(index));

    FutureOr<bool> setRetryAttempt(DioError error, int attempt) async {
      bool shouldRetry =
          await RetryInterceptor.defaultRetryEvaluator(error, attempt);

      if (shouldRetry) {
        retryAttempts = attempt;
      }

      return shouldRetry;
    }

    return RetryInterceptor(
      dio: dio,
      logPrint: noLogs ? null : print,
      retries: retries,
      retryDelays: retryDelays,
      retryEvaluator: setRetryAttempt,
    );
  }
}
