import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:lyria/app/core/services/http/my_http_client.dart';
import 'package:lyria/app/core/services/storege/my_local_storage.dart';

class DioClient implements MyHttpClient {
  final Dio dio = Dio();
  MyLocalStorage storage;

  DioClient({required this.storage}) {
    dio.options.baseUrl = 'http://192.168.1.55:9000';

    dio.options.validateStatus = (status) {
      return status != null && status >= 200 && status < 300;
    };

    dio.options.receiveDataWhenStatusError = true;
    dio.options.followRedirects = true;
    dio.options.headers['Content-Type'] = 'application/json';
    dio.options.connectTimeout = Durations.extralong4 * 10;
    dio.options.receiveTimeout = Durations.extralong4 * 10;

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          String? accessToken = await storage.get('accessToken');

          if (accessToken != null) {
            options.headers['Authorization'] = accessToken;
          }
          return handler.next(options);
        },
        onResponse: (response, handler) async {
          if (response.statusCode == 401) {
            return handler.reject(
              DioException(
                requestOptions: response.requestOptions,
                response: response,
                type: DioExceptionType.badResponse,
              ),
            );
          }
          return handler.next(response);
        },
        onError: (DioException error, handler) async {
          if (error.response?.statusCode == 401) {
            String? refreshToken = await storage.get('refreshToken');

            if (refreshToken != null) {
              try {
                final response = await dio.get(
                  '/auth/refresh-token',
                  options: Options(
                    headers: {
                      'Token': refreshToken,
                    },
                  ),
                );

                if (response.statusCode == 200) {
                  final newAccessToken = response.data['accessToken'];

                  await storage.set('accessToken', newAccessToken);

                  final options = error.requestOptions;
                  options.headers['Authorization'] = newAccessToken;
                  final retryResponse = await dio.fetch(options);

                  return handler.resolve(retryResponse);
                } else {
                  await storage.remove('accessToken');
                  await storage.remove('refreshToken');
                  await storage.remove('user');
                  return handler.next(error);
                }
              } catch (e) {
                return handler.next(error);
              }
            }
          }

          return handler.next(error);
        },
      ),
    );
  }

  @override
  Future<dynamic> get(String url) async {
    try {
      final response = await dio.get(url);
      return {
        "data": response.data,
        "status": response.statusCode,
      };
    } catch (e) {
      return {
        "error": e.toString(),
      };
    }
  }

  @override
  Future<dynamic> delete(String url) async {
    try {
      final response = await dio.delete(url);
      return {
        "data": response.data,
        "status": response.statusCode,
      };
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<dynamic> post(String url, {dynamic data}) async {
    try {
      final response = await dio.post(url, data: data);

      return {
        "data": response.data,
        "status": response.statusCode,
      };
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<dynamic> put(String url, {dynamic data}) async {
    try {
      final response = await dio.put(url, data: data);
      return {
        "data": response.data,
        "status": response.statusCode,
      };
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future multiPart(String url, {dynamic body}) async {
    try {
      final formData = FormData();

      await Future.forEach(body.entries,
          (MapEntry<String, dynamic> entry) async {
        if (entry.value is File) {
          formData.files.add(MapEntry(
            entry.key,
            await MultipartFile.fromFile(entry.value.path),
          ));
        } else {
          formData.fields.add(MapEntry(entry.key, entry.value.toString()));
        }
      });

      final response = await dio.post(url, data: formData);

      return {
        "data": response.data,
        "status": response.statusCode,
      };
    } catch (e) {
      rethrow;
    }
  }
}