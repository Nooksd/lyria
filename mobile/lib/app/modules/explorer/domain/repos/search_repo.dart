import 'package:lyria/app/modules/explorer/domain/entities/search.dart';

abstract class SearchRepo {
  Future<List<Search>> search(String query);
  Future<void> updateHistory(List<Search> history);
  Future<List<Search>> getHistory();
}
