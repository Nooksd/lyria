import 'dart:io';

abstract class MyHttpClient {
  Future<dynamic> get(String url);
  Future<dynamic> post(String url, {dynamic data});
  Future<dynamic> multiPart(String url, {dynamic body});
  Future<dynamic> put(String url, {dynamic data});
  Future<dynamic> delete(String url);
  Future<File> download(String url, String filePath);
}
