import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:lyria/app/core/services/http/my_http_client.dart';
import 'package:lyria/app/modules/music/domain/entities/music.dart';
import 'package:lyria/app/modules/music/presentation/cubits/music_cubit.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

enum IdentifyState { idle, recording, identifying, found, notFound, error }

class IdentifyInclude extends StatefulWidget {
  final VoidCallback onClose;

  const IdentifyInclude({super.key, required this.onClose});

  @override
  State<IdentifyInclude> createState() => _IdentifyIncludeState();
}

class _IdentifyIncludeState extends State<IdentifyInclude>
    with SingleTickerProviderStateMixin {
  final AudioRecorder _recorder = AudioRecorder();
  final MyHttpClient _http = GetIt.instance<MyHttpClient>();
  final MusicCubit _musicCubit = GetIt.instance<MusicCubit>();

  IdentifyState _state = IdentifyState.idle;
  String _message = '';
  int _recordSeconds = 0;
  String? _currentFilePath;
  Timer? _timer;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _startIdentification() async {
    // Check microphone permission
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      setState(() {
        _state = IdentifyState.error;
        _message = 'Permissão de microfone negada';
      });
      return;
    }

    // Get temp path
    final dir = await getTemporaryDirectory();
    final filePath =
        '${dir.path}/identify_${DateTime.now().millisecondsSinceEpoch}.wav';

    // Start recording
    try {
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 8000,
          numChannels: 1,
          bitRate: 128000,
        ),
        path: filePath,
      );
    } catch (e) {
      setState(() {
        _state = IdentifyState.error;
        _message = 'Erro ao iniciar gravação';
      });
      return;
    }

    _currentFilePath = filePath;
    setState(() {
      _state = IdentifyState.recording;
      _recordSeconds = 0;
      _message = 'Ouvindo...';
    });
    _pulseController.repeat(reverse: true);

    // Timer to show recording duration
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _recordSeconds++;
      });

      // Auto-stop after 10 seconds
      if (_recordSeconds >= 10) {
        timer.cancel();
        _stopAndIdentify(filePath);
      }
    });
  }

  Future<void> _stopAndIdentify(String filePath) async {
    _timer?.cancel();
    _pulseController.stop();
    _pulseController.reset();

    // Stop recording
    await _recorder.stop();

    setState(() {
      _state = IdentifyState.identifying;
      _message = 'Identificando...';
    });

    // Send to server
    try {
      final audioFile = File(filePath);
      if (!await audioFile.exists()) {
        setState(() {
          _state = IdentifyState.error;
          _message = 'Arquivo de áudio não encontrado';
        });
        return;
      }

      final response = await _http.multiPart(
        '/music/identify',
        body: {'audio': audioFile},
      );

      // Clean up temp file
      audioFile.delete().catchError((_) => audioFile);

      if (response['error'] != null) {
        setState(() {
          _state = IdentifyState.notFound;
          _message = 'Música não identificada. Tente novamente.';
        });
        return;
      }

      final data = response['data'];
      if (data == null || response['status'] != 200) {
        final errorMsg = data?['error'] ?? data?['message'] ?? 'Música não identificada';
        setState(() {
          _state = IdentifyState.notFound;
          _message = errorMsg.toString();
        });
        return;
      }

      final musicData = data['music'];
      if (musicData == null) {
        setState(() {
          _state = IdentifyState.notFound;
          _message = 'Música não identificada. Tente novamente.';
        });
        return;
      }

      final music = Music.fromJson(musicData);

      setState(() {
        _state = IdentifyState.found;
        _message = '${music.name} — ${music.artistName}';
      });

      // Start playing and navigate to music page
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      await _musicCubit.setQueue([music], 0, null);
      if (!mounted) return;
      context.push('/auth/music');
    } catch (e) {
      setState(() {
        _state = IdentifyState.error;
        _message = 'Erro na identificação. Tente novamente.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final bgColor = Theme.of(context).colorScheme.surface;

    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Identificador de Música',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _state == IdentifyState.idle
                  ? 'Toque no botão para identificar'
                  : _state == IdentifyState.recording
                      ? 'Ouvindo... ${_recordSeconds}s'
                      : _message,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[400],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),
            // Mic button
            GestureDetector(
              onTap: () {
                if (_state == IdentifyState.idle ||
                    _state == IdentifyState.notFound ||
                    _state == IdentifyState.error) {
                  _startIdentification();
                } else if (_state == IdentifyState.recording &&
                    _currentFilePath != null) {
                  _stopAndIdentify(_currentFilePath!);
                }
              },
              child: AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  final scale = _state == IdentifyState.recording
                      ? _pulseAnimation.value
                      : 1.0;
                  return Transform.scale(
                    scale: scale,
                    child: child,
                  );
                },
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _state == IdentifyState.recording
                        ? primaryColor
                        : _state == IdentifyState.identifying
                            ? primaryColor.withValues(alpha: 0.5)
                            : primaryColor.withValues(alpha: 0.15),
                    border: Border.all(
                      color: primaryColor,
                      width: 3,
                    ),
                    boxShadow: _state == IdentifyState.recording
                        ? [
                            BoxShadow(
                              color: primaryColor.withValues(alpha: 0.4),
                              blurRadius: 30,
                              spreadRadius: 10,
                            )
                          ]
                        : null,
                  ),
                  child: Center(
                    child: _state == IdentifyState.identifying
                        ? SizedBox(
                            width: 40,
                            height: 40,
                            child: CircularProgressIndicator(
                              color: bgColor,
                              strokeWidth: 3,
                            ),
                          )
                        : _state == IdentifyState.found
                            ? Icon(Icons.check, size: 50, color: primaryColor)
                            : Icon(
                                Icons.mic,
                                size: 50,
                                color: _state == IdentifyState.recording
                                    ? bgColor
                                    : primaryColor,
                              ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 48),
            if (_state == IdentifyState.found)
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Text(
                  _message,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: primaryColor,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            if (_state == IdentifyState.notFound ||
                _state == IdentifyState.error)
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: TextButton(
                  onPressed: _startIdentification,
                  child: Text(
                    'Tentar novamente',
                    style: TextStyle(color: primaryColor),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
