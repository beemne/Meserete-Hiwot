import 'package:dio/dio.dart';

void main() {
  final dio = Dio(BaseOptions(baseUrl: 'https://app.hersolan.pro/api/v1'));
  final uri1 = dio.options.baseUrl;
  print('Base URL: $uri1');
  final resolvedUri = Uri.parse(uri1).resolve('/edu/materials/3/file');
  print('Resolved Uri with leading slash: $resolvedUri');
  
  // How Dio resolves path:
  // In Dio, if path starts with '/', it does not replace baseUrl's path ONLY if baseUrl doesn't have path or if dio handles it specially.
  // Let's see:
  final dioUri = dio.options.uri;
  print('Dio options.uri: $dioUri');
  print('dio Uri resolve /edu: ${dioUri.resolve('/edu/materials/3/file')}');
  print('dio Uri resolve without slash: ${Uri.parse('https://app.hersolan.pro/api/v1/').resolve('edu/materials/3/file')}');
}
