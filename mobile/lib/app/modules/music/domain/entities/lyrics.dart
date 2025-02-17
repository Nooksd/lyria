import 'package:equatable/equatable.dart';

class LyricLine extends Equatable {
  final String time;
  final String content;

  const LyricLine({required this.time, required this.content});

  Duration get timeAsDuration {
    final parts = time.split(':');
    final minutes = int.parse(parts[0]);
    final seconds = double.parse(parts[1]);
    return Duration(minutes: minutes, milliseconds: (seconds * 1000).round());
  }

  factory LyricLine.fromJson(Map<String, dynamic> json) {
    return LyricLine(
      time: json['time'],
      content: json['content'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'time': time,
      'content': content,
    };
  }

  @override
  List<Object?> get props => [time, content];
}
