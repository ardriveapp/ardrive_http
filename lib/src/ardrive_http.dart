import 'dart:async';
import 'dart:collection';
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
        return await _getWeb(
          url: url,
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
    final ResponseType responseType = params['responseType'];

    try {
      Response response = await _dio()
          .get(
            url,
            options: Options(responseType: responseType),
          )
          .timeout(
            const Duration(seconds: 8), // 8s timeout
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
      final LinkedHashMap<dynamic, dynamic> response =
          await JsIsolatedWorker().run(
        functionName: 'get',
        arguments: [
          url,
          normalizeResponseTypeToJS(responseType),
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

  Future<ArDriveHTTPResponse> post({
    required String url,
    required dynamic data,
    required ContentType contentType,
    ResponseType responseType = ResponseType.plain,
  }) async {
    final Map postIOParams = <String, dynamic>{};
    postIOParams['url'] = url;
    postIOParams['data'] = data;
    postIOParams['contentType'] = contentType;
    postIOParams['responseType'] = responseType;
    if (kIsWeb) {
      if (await _loadWebWorkers()) {
        return await _postWeb(
          url: url,
          data: data,
          contentType: contentType.toString(),
          responseType: responseType,
        );
      } else {
        return await _postIO(postIOParams);
      }
    }

    return await compute(_postIO, postIOParams);
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

  Future<ArDriveHTTPResponse> postBytes({
    required String url,
    required Uint8List data,
    ResponseType responseType = ResponseType.json,
  }) async {
    return post(
      url: url,
      data: data,
      contentType: ContentType.binary,
      responseType: responseType,
    );
  }

  Future<ArDriveHTTPResponse> _postIO(Map params) async {
    final String url = params['url'];
    final dynamic data = params['data'];
    final ContentType contentType = params['contentType'];
    final ResponseType responseType = params['responseType'];

    try {
      Response response = await _dio()
          .post(
            url,
            data: data,
            options: Options(
              contentType: contentType.toString(),
              responseType: responseType,
            ),
          )
          .timeout(
            const Duration(seconds: 8), // 8s timeout
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

  Future<ArDriveHTTPResponse> _postWeb({
    required String url,
    required dynamic data,
    required String contentType,
    required ResponseType responseType,
  }) async {
    try {
      final LinkedHashMap<dynamic, dynamic> response =
          await JsIsolatedWorker().run(
        functionName: 'post',
        arguments: [
          url,
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
