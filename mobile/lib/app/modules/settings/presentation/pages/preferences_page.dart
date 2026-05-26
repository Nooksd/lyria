import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lyria/app/app_router.dart';
import 'package:lyria/app/core/services/storege/my_local_storage.dart';

class PreferencesPage extends StatefulWidget {
  const PreferencesPage({super.key});

  @override
  State<PreferencesPage> createState() => _PreferencesPageState();
}

class _PreferencesPageState extends State<PreferencesPage> {
  final MyLocalStorage storage = getIt<MyLocalStorage>();
  bool infinitePlay = false;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final saved = await storage.get('infinite_play_enabled');
    if (!mounted) return;
    setState(() {
      infinitePlay = saved == true;
      loading = false;
    });
  }

  Future<void> _setInfinitePlay(bool value) async {
    setState(() => infinitePlay = value);
    await storage.set('infinite_play_enabled', value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Preferencias'),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Play infinito'),
                  subtitle: Text(
                    'Quando a fila acabar, o Lyria adiciona uma proxima musica recomendada.',
                    style: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6),
                    ),
                  ),
                  value: infinitePlay,
                  onChanged: _setInfinitePlay,
                ),
              ],
            ),
    );
  }
}
