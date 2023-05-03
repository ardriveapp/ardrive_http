import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart';

enum RequestMode {
  sameOrigin('same-origin'),
  noCors('no-cors'),
  cors('cors'),
  navigate('navigate'),
  webSocket('websocket');

  const RequestMode(this.mode);

  factory RequestMode.from(String mode) =>
    values.firstWhere((element) => element.mode == mode);

  final String mode;

  @override
  String toString() => mode;
}

class FetchResponse extends StreamedResponse {
  FetchResponse(super.stream, super.statusCode, this.cancel, this.url, this.redirected);

  final void Function() cancel;

  final String url;

  final bool redirected;
}

class FetchClient implements BaseClient {
  FetchClient({
    RequestMode? mode,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<FetchResponse> send(BaseRequest request) {
    throw UnimplementedError();
  }

  @override
  void close() {
    throw UnimplementedError();
  }

  @override
  Future<Response> delete(Uri url, {Map<String, String>? headers, Object? body, Encoding? encoding}) {
    throw UnimplementedError();
  }

  @override
  Future<Response> get(Uri url, {Map<String, String>? headers}) {
    throw UnimplementedError();
  }

  @override
  Future<Response> head(Uri url, {Map<String, String>? headers}) {
    throw UnimplementedError();
  }

  @override
  Future<Response> patch(Uri url, {Map<String, String>? headers, Object? body, Encoding? encoding}) {
    throw UnimplementedError();
  }

  @override
  Future<Response> post(Uri url, {Map<String, String>? headers, Object? body, Encoding? encoding}) {
    throw UnimplementedError();
  }

  @override
  Future<Response> put(Uri url, {Map<String, String>? headers, Object? body, Encoding? encoding}) {
    throw UnimplementedError();
  }

  @override
  Future<String> read(Uri url, {Map<String, String>? headers}) {
    throw UnimplementedError();
  }

  @override
  Future<Uint8List> readBytes(Uri url, {Map<String, String>? headers}) {
    throw UnimplementedError();
  }
}
