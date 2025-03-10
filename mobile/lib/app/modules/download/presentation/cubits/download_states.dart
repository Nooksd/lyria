import 'package:equatable/equatable.dart';

class DownloadState extends Equatable {
  final Map<String, DownloadStatus> downloads;

  const DownloadState({required this.downloads});

  @override
  List<Object> get props => [downloads];
}

enum DownloadStatus { notDownloaded, downloading, downloaded, error }
