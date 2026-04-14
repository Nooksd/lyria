import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lyria/app/core/services/connectivity/connectivity_service.dart';
import 'package:lyria/app/modules/download/data/api_download_repo.dart';
import 'package:lyria/app/modules/explorer/domain/entities/search.dart';
import 'package:lyria/app/modules/explorer/domain/repos/search_repo.dart';
import 'package:lyria/app/modules/explorer/presentation/cubits/search_states.dart';

class SearchCubit extends Cubit<SearchState> {
  final SearchRepo searchRepo;
  final ConnectivityService connectivity;
  final ApiDownloadRepo downloadRepo;
  List<Search> _history = [];

  SearchCubit({
    required this.searchRepo,
    required this.connectivity,
    required this.downloadRepo,
  }) : super(SearchInitial());

  Future<List<Search>> search(String query) async {
    emit(SearchLoading());

    if (!connectivity.isOnline) {
      // Offline: search only downloaded music
      final downloaded = await downloadRepo.getDownloadedMusics();
      final lowerQuery = query.toLowerCase();
      final filtered = downloaded.where((m) {
        return m.name.toLowerCase().contains(lowerQuery) ||
            m.artistName.toLowerCase().contains(lowerQuery) ||
            m.albumName.toLowerCase().contains(lowerQuery);
      }).toList();

      final searches = filtered
          .map((m) => Search(
                id: m.id,
                name: m.name,
                type: 'music',
                description: m.artistName,
                imageUrl: m.coverUrl,
                music: m,
              ))
          .toList();
      emit(SearchLoaded(searches));
      return searches;
    }

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

  Future<void> addToHistory(Search search) async {
    if (_history.contains(search)) return;
    
    _history.add(search);
    await searchRepo.updateHistory(_history);
  }

  Future<List<Search>> removeFromHistory(Search search) async {
    _history.remove(search);
    await searchRepo.updateHistory(_history);
    return _history;
  }

  List<Search> get history => _history;
}
