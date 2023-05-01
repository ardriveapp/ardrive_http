import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

List<int> retryStatusCodes = [
  408,
  429,
  440,
  460,
  499,
  500,
  502,
  503,
  504,
  520,
  521,
  522,
  523,
  524,
  525,
  527,
  598,
  599
];

const Map<String, Object> headers = {
  'access-control-allow-origin': '*',
  'access-control-allow-methods': 'GET, POST, OPTIONS',
  'access-control-allow-headers': 'content-type, test',
  'allow': '*',
};

Future<void> main() async {
  Router router = Router();

  final server = await shelf_io.serve(
    router,
    InternetAddress.anyIPv4,
    8080,
  );

  router.all(
    '/getJson',
    (Request request) => Response.ok(
      const JsonEncoder.withIndent(' ').convert({'message': 'ok'}),
      headers: {
        ...headers,
        'Content-Type': 'application/json',
      },
    ),
  );

  router.all(
    '/ok',
    (Request request) => Response.ok(
      'ok',
      headers: headers,
    ),
  );

  router.options(
    '/headerCheck',
    (Request request) => Response.ok(
      null,
      headers: headers,
    ),
  );

  router.get(
    '/headerCheck',
    (Request request) {
      if (request.headers['test'] == 'ok') {
        return Response.ok(
          'ok',
          headers: headers,
        );
      } else {
        return Response(
          400,
          headers: headers,
        );
      }
    },
  );

  router.post(
    '/headerCheck',
    (Request request) {
      if (request.headers['test'] == 'ok') {
        return Response.ok(
          'ok',
          headers: headers,
        );
      } else {
        return Response(
          400,
          headers: headers,
        );
      }
    },
  );

  for (int statusCode in retryStatusCodes) {
    router.options(
      '/$statusCode',
      (Request request) => Response.ok(
        null,
        headers: headers,
      ),
    );

    router.get(
      '/$statusCode',
      (Request request) => Response(
        statusCode,
        headers: headers,
      ),
    );

    router.post(
      '/$statusCode',
      (Request request) => Response(
        statusCode,
        headers: headers,
      ),
    );
  }

  router.all(
    '/404',
    (Request request) => Response(
      404,
      headers: headers,
    ),
  );

  router.get(
    '/exit',
    (Request request) {
      server.close();
      return Response.ok(
        null,
        headers: headers,
      );
    },
  );

  // ignore: avoid_print
  print('Serving at http://${server.address.host}:${server.port}');
}
