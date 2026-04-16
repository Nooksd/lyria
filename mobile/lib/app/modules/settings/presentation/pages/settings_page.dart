import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lyria/app/app_router.dart';
import 'package:lyria/app/modules/auth/presentation/cubits/auth_cubit.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text("Configurações"),
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
        child: Column(
          children: [
            const SizedBox(height: 20),
            _buildSettingsTile(
              context,
              icon: Icons.person_outline,
              title: "Editar Perfil",
              onTap: () => context.push('/auth/ui/settings/edit-profile'),
            ),
            _buildSettingsTile(
              context,
              icon: Icons.notifications_outlined,
              title: "Notificações",
              onTap: () => context.push('/auth/ui/settings/notifications'),
            ),
            _buildSettingsTile(
              context,
              icon: Icons.storage_outlined,
              title: "Armazenamento e Cache",
              onTap: () => context.push('/auth/ui/settings/storage'),
            ),
            _buildSettingsTile(
              context,
              icon: Icons.person_add_outlined,
              title: "Solicitar Artista",
              onTap: () => context.push('/auth/ui/request-artist'),
            ),
            _buildSettingsTile(
              context,
              icon: Icons.info_outline,
              title: "Sobre",
              onTap: () => context.push('/auth/ui/settings/about'),
            ),
            _buildSettingsTile(
              context,
              icon: Icons.logout,
              title: "Sair da Conta",
              onTap: () => getIt<AuthCubit>().logout(context),
              color: Colors.red,
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? color,
  }) {
    final effectiveColor = color ?? Theme.of(context).colorScheme.primary;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: effectiveColor),
      title: Text(title, style: TextStyle(color: color)),
      trailing: Icon(
        Icons.chevron_right,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
      ),
      onTap: onTap,
    );
  }
}
