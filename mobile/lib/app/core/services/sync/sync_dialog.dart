import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

enum SyncChoice { local, server }

class SyncConflictInfo {
  final String title;
  final String description;
  final DateTime? localUpdatedAt;
  final DateTime? serverUpdatedAt;

  const SyncConflictInfo({
    required this.title,
    required this.description,
    this.localUpdatedAt,
    this.serverUpdatedAt,
  });
}

class SyncDialog {
  static final DateFormat _fmt = DateFormat('dd/MM/yyyy HH:mm');

  static Future<SyncChoice?> showConflict(
    BuildContext context,
    SyncConflictInfo info,
  ) {
    final localLabel = info.localUpdatedAt != null
        ? _fmt.format(info.localUpdatedAt!)
        : 'Desconhecido';
    final serverLabel = info.serverUpdatedAt != null
        ? _fmt.format(info.serverUpdatedAt!)
        : 'Desconhecido';

    return showDialog<SyncChoice>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).colorScheme.primaryContainer,
        title: Text(info.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              info.description,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 20),
            _ChoiceTile(
              icon: Icons.phone_android,
              label: 'Local',
              date: localLabel,
              onTap: () => Navigator.pop(ctx, SyncChoice.local),
            ),
            const SizedBox(height: 10),
            _ChoiceTile(
              icon: Icons.cloud,
              label: 'Online',
              date: serverLabel,
              onTap: () => Navigator.pop(ctx, SyncChoice.server),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String date;
  final VoidCallback onTap;

  const _ChoiceTile({
    required this.icon,
    required this.label,
    required this.date,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    'Atualizado em: $date',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Theme.of(context).colorScheme.primary,
            ),
          ],
        ),
      ),
    );
  }
}
