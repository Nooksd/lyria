import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class StorageCachePage extends StatefulWidget {
  const StorageCachePage({super.key});

  @override
  State<StorageCachePage> createState() => _StorageCachePageState();
}

class _StorageCachePageState extends State<StorageCachePage> {
  int _imageCacheBytes = 0;
  int _downloadedBytes = 0;
  bool _isLoading = true;
  bool _isClearing = false;

  @override
  void initState() {
    super.initState();
    _calculateSizes();
  }

  Future<void> _calculateSizes() async {
    try {
      // Image cache size
      final cacheDir = await getTemporaryDirectory();
      final imageCacheSize = await _dirSize(cacheDir);

      // Downloaded music size
      final docsDir = await getApplicationDocumentsDirectory();
      int downloadedSize = 0;
      final files = docsDir.listSync().whereType<File>();
      for (final file in files) {
        if (file.path.endsWith('.mp3')) {
          downloadedSize += await file.length();
        }
      }

      if (mounted) {
        setState(() {
          _imageCacheBytes = imageCacheSize;
          _downloadedBytes = downloadedSize;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<int> _dirSize(Directory dir) async {
    int total = 0;
    try {
      await for (final entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          total += await entity.length();
        }
      }
    } catch (_) {}
    return total;
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  Future<void> _clearImageCache() async {
    setState(() => _isClearing = true);
    try {
      await DefaultCacheManager().emptyCache();
      final cacheDir = await getTemporaryDirectory();
      if (cacheDir.existsSync()) {
        await for (final entity
            in cacheDir.list(recursive: false, followLinks: false)) {
          try {
            if (entity is Directory) {
              await entity.delete(recursive: true);
            } else if (entity is File) {
              await entity.delete();
            }
          } catch (_) {}
        }
      }
      await _calculateSizes();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cache de imagens limpo!')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao limpar cache')),
        );
      }
    } finally {
      if (mounted) setState(() => _isClearing = false);
    }
  }

  Future<void> _clearDownloads() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Apagar downloads?'),
        content:
            const Text('Todas as músicas baixadas serão removidas do dispositivo.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Apagar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isClearing = true);
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final files = docsDir.listSync().whereType<File>();
      for (final file in files) {
        if (file.path.endsWith('.mp3')) {
          await file.delete();
        }
      }
      await _calculateSizes();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Downloads removidos!')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao limpar downloads')),
        );
      }
    } finally {
      if (mounted) setState(() => _isClearing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text("Armazenamento e Cache"),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primary))
          : ListView(
              padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
              children: [
                const SizedBox(height: 16),
                // Image cache card
                _buildStorageCard(
                  icon: Icons.image_outlined,
                  title: "Cache de imagens",
                  size: _formatBytes(_imageCacheBytes),
                  onClear: _isClearing ? null : _clearImageCache,
                  color: primary,
                ),
                const SizedBox(height: 12),
                // Downloaded music card
                _buildStorageCard(
                  icon: Icons.download_outlined,
                  title: "Músicas baixadas",
                  size: _formatBytes(_downloadedBytes),
                  onClear: _isClearing ? null : _clearDownloads,
                  color: primary,
                ),
                const SizedBox(height: 24),
                // Total
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Total utilizado",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _formatBytes(_imageCacheBytes + _downloadedBytes),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildStorageCard({
    required IconData icon,
    required String title,
    required String size,
    required VoidCallback? onClear,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(size,
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6),
                    )),
              ],
            ),
          ),
          TextButton(
            onPressed: onClear,
            child: Text("Limpar",
                style: TextStyle(color: Colors.red.withValues(alpha: 0.8))),
          ),
        ],
      ),
    );
  }
}
