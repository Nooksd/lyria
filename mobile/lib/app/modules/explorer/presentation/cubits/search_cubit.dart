import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lyria/app/modules/explorer/domain/entities/search.dart';
import 'package:lyria/app/modules/explorer/domain/repos/search_repo.dart';
import 'package:lyria/app/modules/explorer/presentation/cubits/search_states.dart';

class SearchCubit extends Cubit<SearchState> {
  final SearchRepo searchRepo;
  List<Search> _history = [];

  SearchCubit({required this.searchRepo}) : super(SearchInitial());

  Future<List<Search>> search(String query) async {
    emit(SearchLoading());
    final searches = await searchRepo.search(query);
    emit(SearchLoaded(searches));
    return searches;
  }

  Future<List<Search>> getHistory() async {
    if (_history.isEmpty) {
      final history = await searchRepo.getHistory();
      _history = history;
    }
    return _history;
  }

  Future<List<Search>> addToHistory(Search search) async {
    _history.add(search);
    await searchRepo.updateHistory(_history);
    return _history;
  }

  Future<List<Search>> removeFromHistory(Search search) async {
    _history.remove(search);
    await searchRepo.updateHistory(_history);
    return _history;
  }

  List<Search> get history => _history;
}
