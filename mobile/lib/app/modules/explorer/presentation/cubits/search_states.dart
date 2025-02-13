import 'package:lyria/app/modules/explorer/domain/entities/search.dart';

abstract class SearchState {}

class SearchInitial extends SearchState {}

class SearchLoading extends SearchState {}

class SearchLoaded extends SearchState {
  final List<Search> searches;
  SearchLoaded(this.searches);
}

class SearchError extends SearchState {
  final String error;
  SearchError(this.error);
}
