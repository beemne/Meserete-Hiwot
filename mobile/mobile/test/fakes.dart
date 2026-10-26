import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

typedef Handler = ({int status, Object body}) Function(RequestOptions req);

/// Dio adapter that answers requests from a routing function and records what was sent.
class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.handler);
  final Handler handler;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    final r = handler(options);
    return ResponseBody.fromString(jsonEncode(r.body), r.status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> ok(Object? data) => {'success': true, 'code': 'OK', 'message': 'OK', 'data': data, 'errors': []};
Map<String, dynamic> failBody(String code, [List<Map<String, String>> errors = const []]) =>
    {'success': false, 'code': code, 'message': code, 'data': null, 'errors': errors};

Map<String, dynamic> body(RequestOptions r) => r.data is String ? jsonDecode(r.data as String) as Map<String, dynamic> : (r.data as Map).cast<String, dynamic>();
