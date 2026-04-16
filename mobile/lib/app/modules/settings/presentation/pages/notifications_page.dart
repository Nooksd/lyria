import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lyria/app/app_router.dart';
import 'package:lyria/app/core/services/storege/my_local_storage.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final MyLocalStorage storage = getIt<MyLocalStorage>();

  bool _newMusic = true;
  bool _jamInvites = true;
  bool _appUpdates = false;

  static const _keyNewMusic = 'notif_new_music';
  static const _keyJamInvites = 'notif_jam_invites';
  static const _keyAppUpdates = 'notif_app_updates';

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final nm = await storage.get(_keyNewMusic);
    final ji = await storage.get(_keyJamInvites);
    final au = await storage.get(_keyAppUpdates);
    if (mounted) {
      setState(() {
        _newMusic = nm != 'false';
        _jamInvites = ji != 'false';
        _appUpdates = au == 'true';
      });
    }
  }

  Future<void> _toggle(String key, bool value) async {
    await storage.set(key, value.toString());
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text("Notificações"),
      ),
      body: ListView(
        children: [
          const SizedBox(height: 8),
          SwitchListTile(
            title: const Text("Novas músicas"),
            subtitle:
                const Text("Notificar quando artistas favoritos lançarem"),
            value: _newMusic,
            activeTrackColor: primary,
            onChanged: (val) {
              setState(() => _newMusic = val);
              _toggle(_keyNewMusic, val);
            },
          ),
          const Divider(height: 1),
          SwitchListTile(
            title: const Text("Convites de Jam"),
            subtitle: const Text("Notificar convites para sessões de jam"),
            value: _jamInvites,
            activeTrackColor: primary,
            onChanged: (val) {
              setState(() => _jamInvites = val);
              _toggle(_keyJamInvites, val);
            },
          ),
          const Divider(height: 1),
          SwitchListTile(
            title: const Text("Atualizações do app"),
            subtitle: const Text("Receber notificações sobre novas versões"),
            value: _appUpdates,
            activeTrackColor: primary,
            onChanged: (val) {
              setState(() => _appUpdates = val);
              _toggle(_keyAppUpdates, val);
            },
          ),
        ],
      ),
    );
  }
}
