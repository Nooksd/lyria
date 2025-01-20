import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Music Streamer',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const MusicPlayer(),
    );
  }
}

class MusicPlayer extends StatefulWidget {
  const MusicPlayer({super.key});

  @override
  State<MusicPlayer> createState() => _MusicPlayerState();
}

class _MusicPlayerState extends State<MusicPlayer> {
  final String _musicListUrl = 'http://192.168.1.68:9000/musics';
  final String _streamBaseUrl = 'http://192.168.1.68:9000/stream/';

  late List<Map<String, dynamic>> _musics;
  final Map<String, AudioPlayer> _preloadedPlayers = {};

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchAndPreloadMusics();
  }

  Future<void> _fetchAndPreloadMusics() async {
    try {
      final response = await http.get(Uri.parse(_musicListUrl));
      if (response.statusCode == 200) {
        _musics = List<Map<String, dynamic>>.from(json.decode(response.body));

        for (var music in _musics) {
          final player = AudioPlayer();
          await player.setUrl(_streamBaseUrl + music['audioPath']);
          _preloadedPlayers[music['id']] = player;
        }

        setState(() {
          _isLoading = false;
        });
      } else {
        throw Exception('Erro ao obter músicas.');
      }
    } catch (e) {
      debugPrint('Erro ao buscar músicas: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    for (var player in _preloadedPlayers.values) {
      player.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Music Streamer')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Music Streamer')),
      body: ListView.builder(
        itemCount: _musics.length,
        itemBuilder: (context, index) {
          final music = _musics[index];
          return ListTile(
            title: Text(music['name']),
            subtitle: Text(music['artistName']),
            trailing: const Icon(Icons.arrow_forward),
            onTap: () {
              final player = _preloadedPlayers[music['id']];
              if (player != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MusicDetailsPage(
                      music: music,
                      player: player,
                    ),
                  ),
                );
              }
            },
          );
        },
      ),
    );
  }
}

class MusicDetailsPage extends StatefulWidget {
  final Map<String, dynamic> music;
  final AudioPlayer player;

  const MusicDetailsPage({
    required this.music,
    required this.player,
    super.key,
  });

  @override
  State<MusicDetailsPage> createState() => _MusicDetailsPageState();
}

class _MusicDetailsPageState extends State<MusicDetailsPage> {
  late AudioPlayer _player;
  late Stream<Duration> _positionStream;
  late Stream<Duration?> _durationStream;

  Duration _position = Duration.zero;
  Duration? _duration;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _player = widget.player;

    _positionStream = _player.positionStream;
    _durationStream = _player.durationStream;

    // Listener para posição atual da música
    _positionStream.listen((position) {
      setState(() {
        _position = position;
      });
    });

    // Listener para duração da música
    _durationStream.listen((duration) {
      setState(() {
        _duration = duration;
      });
    });

    _playMusic();
  }

  Future<void> _playMusic() async {
    await _player.play();
    setState(() {
      _isPlaying = true;
    });
  }

  Future<void> _pauseMusic() async {
    await _player.pause();
    setState(() {
      _isPlaying = false;
    });
  }

  void _seekTo(double value) {
    final newPosition = Duration(seconds: value.toInt());
    _player.seek(newPosition);
  }

  @override
  void dispose() {
    _player.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String positionText = _formatDuration(_position);
    final String durationText =
        _duration != null ? _formatDuration(_duration!) : "0:00";

    return Scaffold(
      appBar: AppBar(title: Text(widget.music['name'])),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.music['name'],
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            Text(widget.music['artistName'], style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 20),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(positionText, style: const TextStyle(fontSize: 16)),
                if (_duration != null)
                  Slider(
                    value: _position.inSeconds.toDouble(),
                    min: 0.0,
                    max: _duration!.inSeconds.toDouble(),
                    onChanged: (value) => _seekTo(value),
                  ),
                Text(durationText, style: const TextStyle(fontSize: 16)),
              ],
            ),
            IconButton(
              onPressed: _isPlaying ? _pauseMusic : _playMusic,
              icon: Icon(
                _isPlaying ? Icons.pause : Icons.play_arrow,
                size: 50,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
