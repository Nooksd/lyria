import 'dart:convert';

import 'package:lyria/app/modules/explorer/domain/entities/search.dart';
import 'package:lyria/app/modules/explorer/domain/repos/search_repo.dart';
import 'package:lyria/app/core/services/http/my_http_client.dart';
import 'package:lyria/app/core/services/storege/my_local_storage.dart';

class ApiSearchRepo implements SearchRepo {
  MyHttpClient http;
  MyLocalStorage storage;

  ApiSearchRepo({required this.http, required this.storage});

  @override
  Future<List<Search>> search(String query) async {
    final response = await http.get('/search?query=$query');

    if (response['status'] == 200) {
      final List<dynamic>? data = response['data']['results'];

      if (data != null) {
        return data.map<Search>((e) => Search.fromJson(e)).toList();
      }
    }
    return [];
  }
  
  @override
  Future<List<Search>> getHistory() async {
    final history = await storage.get('search_history');
    if (history == null) {
      return [];
    }
    
    final List<dynamic> jsonList = jsonDecode(history as String);
    return jsonList.map((e) => Search.fromJson(e)).toList();
  }

  @override
  Future<void> updateHistory(List<Search> history) async {
    final String jsonString = jsonEncode(history.map((e) => e.toJson()).toList());
    
    await storage.set('search_history', jsonString);
  }
}
