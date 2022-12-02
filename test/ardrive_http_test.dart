import 'package:ardrive_http/ardrive_http.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import './webserver.dart';

const String baseUrl = 'http://localhost:8080';

void main() {
  final http = ArDriveHTTP(
    retryDelayMs: 0,
    noLogs: true,
  );

  tearDownAll(() => http.get(url: '$baseUrl/exit'));
  group('ArDriveHTTP', () {
    test('can be instantiated', () {
      expect(http, isNotNull);
    });

    group('get method', () {
      test('throws when isJson and asBytes are used together', () async {
        final response = http.get(
          url: baseUrl,
          isJson: true,
          asBytes: true,
        );

        expect(() => response, throwsA(const TypeMatcher<ArgumentError>()));
      });

      test('returns plain response data', () async {
        const String url = '$baseUrl/getText';
        final response = await http.get(url: url);

        expect(response.data, 'ok');
        expect(response.retryAttempts, 0);
      });

      test('returns decoded json response', () async {
        const String url = '$baseUrl/getJson';

        final getResponse = await http.get(url: url, isJson: true);

        expect(getResponse.data['message'], 'ok');
        expect(getResponse.retryAttempts, 0);

        final getJsonResponse = await http.getJson(url);

        expect(getJsonResponse.data['message'], 'ok');
        expect(getJsonResponse.retryAttempts, 0);
      });

      test('returns byte response', () async {
        const String url = '$baseUrl/getText';

        final getResponse = await http.get(url: url, asBytes: true);

        expect(getResponse.data, Uint8List.fromList([111, 107]));
        expect(getResponse.retryAttempts, 0);

        final getAsBytesResponse = await http.getAsBytes(url);

        expect(getAsBytesResponse.data, Uint8List.fromList([111, 107]));
        expect(getAsBytesResponse.retryAttempts, 0);
      });

      test('fail without retry', () async {
        const String url = '$baseUrl/404';

        await expectLater(
            () => http.get(url: url),
            throwsA(const ArDriveHTTPException(
              retryAttempts: 0,
              dioException: {},
            )));
      });

      for (int statusCode in retryStatusCodes) {
        test('retry 8 times by default when response is $statusCode', () async {
          final url = '$baseUrl/$statusCode';

          await expectLater(
              () => http.get(url: url),
              throwsA(const ArDriveHTTPException(
                retryAttempts: 8,
                dioException: {},
              )));
        });
      }

      test('retry 4 times', () async {
        final http = ArDriveHTTP(
          retries: 4,
          retryDelayMs: 0,
          noLogs: true,
        );
        const String url = '$baseUrl/429';

        await expectLater(
            () => http.get(url: url),
            throwsA(const ArDriveHTTPException(
              retryAttempts: 4,
              dioException: {},
            )));
      });
    });
  });
}
