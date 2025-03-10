import 'dart:io';
import 'package:lyria/app/core/services/http/my_http_client.dart';
import 'package:path_provider/path_provider.dart';

class DownloadService {
  MyHttpClient http;

  DownloadService({required this.http});

  Future<String> getDownloadDirectory() async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  Future<String> getFilePath(String fileName) async {
    final dir = await getDownloadDirectory();
    return '$dir/$fileName';
  }

  Future<bool> isFileDownloaded(String fileName) async {
    final filePath = await getFilePath(fileName);
    return File(filePath).exists();
  }

  Future<File> downloadFile(String url, String fileName) async {
    final filePath = await getFilePath(fileName);
    print(filePath);
    await http.download(url, filePath);
    return File(filePath);
  }
}
