import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:convert';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Music Jam Tester',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const MusicJamHome(),
    );
  }
}

class MusicJamHome extends StatefulWidget {
  const MusicJamHome({super.key});

  @override
  State<MusicJamHome> createState() => _MusicJamHomeState();
}

class _MusicJamHomeState extends State<MusicJamHome> {
  final String baseUrl = 'http://192.168.1.68:9000';
  final TextEditingController _simpleIdController = TextEditingController();
  WebSocketChannel? _channel;
  String? _simpleId;
  final String _userId = 'example-user-id';
  final String _authToken = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJFbWFpbCI6InRlc3RlQGdtYWlsLmNvbSIsIk5hbWUiOiJKb8OjbyBWaWN0b3IgQWx2ZXMgZGUgT2xpdmVpcmEiLCJBdmF0YXJVcmwiOiJodHRwOi8vMTkyLjE2OC4xLjY4OjkwMDAvYXZhdGFyL2dldC8iLCJVc2VySWQiOiI2NzhlYjAzNzdkNjJiZTJhOTk4NWY4ZGUiLCJVc2VyVHlwZSI6IkFETUlOIiwiZXhwIjoxNzM3NTc5NDk1LCJpYXQiOjE3Mzc0OTMwOTV9.5GLSispzfL0gReEqdJ8sMnJ3s4fRJSXt-AupX6sd92c';
  final List<String> _messages = [];

  @override
  void dispose() {
    _simpleIdController.dispose();
    _channel?.sink.close();
    super.dispose();
  }

  Future<void> _createMusicJam() async {
    final url = Uri.parse('$baseUrl/musicjam/create');
    final response = await http.post(url, headers: {
      'Authorization': _authToken,
    });

    if (response.statusCode == 201) {
      final data = json.decode(response.body);
      setState(() {
        _simpleId = data['simpleId'];
      });
      _joinWebSocket(_simpleId!);
    } else {
      if(!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao criar Music Jam: ${response.body}')),
      );
    }
  }

  Future<void> _joinMusicJam(String simpleId) async {
    final url = Uri.parse('$baseUrl/musicjam/join/$simpleId');
    final response = await http.get(url, headers: {
      'Authorization': 'Bearer $_authToken',
    });

    if (response.statusCode == 200) {
      setState(() {
        _simpleId = simpleId;
      });
      _joinWebSocket(simpleId);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao entrar na Music Jam: ${response.body}')),
      );
    }
  }

  void _joinWebSocket(String simpleId) {
    _channel = WebSocketChannel.connect(
      Uri.parse('ws://192.168.1.68:9000/musicjam/ws/$simpleId?userId=$_userId'),
    );

    _channel!.stream.listen((message) {
      setState(() {
        _messages.add(message);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Mensagem recebida: $message')),
      );
    }, onError: (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro WebSocket: $error')),
      );
    }, onDone: () {
      setState(() {
        _channel = null;
      });
    });
  }

  Future<void> _leaveMusicJam() async {
    final url = Uri.parse('$baseUrl/musicjam/leave/$_simpleId');
    final response = await http.get(url, headers: {
      'Authorization': 'Bearer $_authToken',
    });

    if (response.statusCode == 200) {
      setState(() {
        _simpleId = null;
        _channel?.sink.close();
      });
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao sair da Music Jam: ${response.body}')),
      );
    }
  }

  void _sendControlCommand(String command) {
    if (_channel != null) {
      _channel!.sink.add(json.encode({
        'command': command,
        'userId': _userId,
      }));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Music Jam Tester')),
      body: Center(
        child: _simpleId == null
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton(
                    onPressed: _createMusicJam,
                    child: const Text('Criar Music Jam'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _simpleIdController,
                    decoration: const InputDecoration(labelText: 'Simple ID'),
                  ),
                  ElevatedButton(
                    onPressed: () =>
                        _joinMusicJam(_simpleIdController.text.trim()),
                    child: const Text('Entrar na Music Jam'),
                  ),
                ],
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Conectado à Music Jam: $_simpleId'),
                  ElevatedButton(
                    onPressed: _leaveMusicJam,
                    child: const Text('Sair da Music Jam'),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        return ListTile(
                          title: Text(_messages[index]),
                        );
                      },
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.play_arrow),
                        onPressed: () => _sendControlCommand('play'),
                      ),
                      IconButton(
                        icon: const Icon(Icons.pause),
                        onPressed: () => _sendControlCommand('pause'),
                      ),
                      IconButton(
                        icon: const Icon(Icons.skip_next),
                        onPressed: () => _sendControlCommand('skip'),
                      ),
                      IconButton(
                        icon: const Icon(Icons.replay),
                        onPressed: () => _sendControlCommand('return'),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}
