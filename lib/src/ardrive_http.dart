import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'package:ardrive_http/src/responses.dart';
import 'package:dio/dio.dart';
import 'package:dio_smart_retry/dio_smart_retry.dart';
import 'package:flutter/foundation.dart';
import 'package:isolated_worker/js_isolated_worker.dart';

const List<String> jsScriptsToImport = <String>['ardrive-http.js'];

String normalizeResponseTypeToAxios(ResponseType responseType) {
  if (responseType == ResponseType.bytes) {
    return 'arraybuffer';
  }

  if (responseType == ResponseType.plain) {
    return 'text';
  }

  return responseType.toString().split('.')[1];
}

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
    final dio = Dio();

    if (!noLogs) {
      dio.interceptors.add(LogInterceptor());
    }

    if (retries > 0) {
      dio.interceptors.add(_getDioRetrySettings(dio));
    }

    return dio;
  }

  // get method
  Future<ArDriveHTTPResponse> get({
    required String url,
    ResponseType responseType = ResponseType.plain,
  }) async {
    final Map getIOParams = <String, dynamic>{};
    getIOParams['url'] = url;
    getIOParams['responseType'] = responseType;

    if (kIsWeb) {
      if (await _loadWebWorkers()) {
        return await _getWeb(url: url, responseType: responseType);
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
    final ResponseType responseType = params['responseType'];

    try {
      Response response = await _dio().get(
        url,
        options: Options(responseType: responseType),
      );

      return ArDriveHTTPResponse(
        data: response.data,
        statusCode: response.statusCode,
        statusMessage: response.statusMessage,
        retryAttempts: retryAttempts,
      );
    } catch (error) {
      throw ArDriveHTTPException(
        retryAttempts: retryAttempts,
        dioException: error,
      );
    }
  }

  Future<ArDriveHTTPResponse> _getWeb({
    required String url,
    required ResponseType responseType,
  }) async {
    try {
      String axiosResponseType = normalizeResponseTypeToAxios(responseType);

      final LinkedHashMap<dynamic, dynamic> response =
          await JsIsolatedWorker().run(
        functionName: 'get',
        arguments: [
          url,
          axiosResponseType,
          retries,
          retryDelayMs,
          noLogs,
        ],
      );

      if (response['error'] != null) {
        retryAttempts = response['retryAttempts'];

        throw response['error'];
      }

      return ArDriveHTTPResponse(
        data: responseType == ResponseType.bytes
            ? Uint8List.view(response['data'])
            : response['data'],
        statusCode: response['statusCode'],
        statusMessage: response['statusMessage'],
        retryAttempts: response['retryAttempts'],
      );
    } catch (error) {
      throw ArDriveHTTPException(
        retryAttempts: retryAttempts,
        dioException: error,
      );
    }
  }

  Future<ArDriveHTTPResponse> postBytes({
    required String url,
    required Uint8List dataBytes,
  }) async {
    final Map postIOParams = <String, dynamic>{};
    postIOParams['url'] = url;
    postIOParams['dataBytes'] = dataBytes;
    if (kIsWeb) {
      // if (await _loadWebWorkers()) {
      //   return await _postBytesWeb(url: url, dataBytes: dataBytes);
      // } else {
      return await _postBytesIO(postIOParams);
      // }
    }

    return await compute(_postBytesIO, postIOParams);
  }

  Future<ArDriveHTTPResponse> _postBytesIO(Map params) async {
    final String url = params['url'];
    final Uint8List dataBytes = params['dataBytes'];

    try {
      Response response = await _dio().post(
        url,
        data: Stream.fromIterable([dataBytes]),
        options: Options(contentType: 'application/octet-stream'),
      );

      return ArDriveHTTPResponse(
        data: response.data,
        statusCode: response.statusCode,
        statusMessage: response.statusMessage,
        retryAttempts: retryAttempts,
      );
    } catch (error) {
      throw ArDriveHTTPException(
        retryAttempts: retryAttempts,
        dioException: error,
      );
    }
  }

  Future<ArDriveHTTPResponse> _postBytesWeb({
    required String url,
    required Uint8List dataBytes,
  }) async {
    try {
      final LinkedHashMap<dynamic, dynamic> response =
          await JsIsolatedWorker().run(
        functionName: 'postBytes',
        arguments: [
          url,
          dataBytes,
          retries,
          retryDelayMs,
          noLogs,
        ],
      );

      if (response['error'] != null) {
        retryAttempts = response['retryAttempts'];

        throw response['error'];
      }

      print('--------------');
      print(response['data']);
      print('--------------');

      return ArDriveHTTPResponse(
        data: response['data'],
        statusCode: response['statusCode'],
        statusMessage: response['statusMessage'],
        retryAttempts: response['retryAttempts'],
      );
    } catch (error) {
      throw ArDriveHTTPException(
        retryAttempts: retryAttempts,
        dioException: error,
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
