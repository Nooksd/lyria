import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lyria/app/app_router.dart';
import 'package:lyria/app/core/services/http/my_http_client.dart';

class SpotifyArtistOption {
  final String spotifyArtistId;
  final String spotifyUrl;
  final String name;
  final String avatarUrl;
  final List<String> genres;

  const SpotifyArtistOption({
    required this.spotifyArtistId,
    required this.spotifyUrl,
    required this.name,
    required this.avatarUrl,
    required this.genres,
  });

  factory SpotifyArtistOption.fromJson(Map<String, dynamic> json) {
    return SpotifyArtistOption(
      spotifyArtistId: json['spotifyArtistId'] as String? ?? '',
      spotifyUrl: json['spotifyUrl'] as String? ?? '',
      name: json['name'] as String? ?? '',
      avatarUrl: json['avatarUrl'] as String? ?? '',
      genres: (json['genres'] as List? ?? []).map((e) => e.toString()).toList(),
    );
  }
}

class RequestArtistPage extends StatefulWidget {
  const RequestArtistPage({super.key});

  @override
  State<RequestArtistPage> createState() => _RequestArtistPageState();
}

class _RequestArtistPageState extends State<RequestArtistPage> {
  final MyHttpClient http = getIt<MyHttpClient>();
  final _searchController = TextEditingController();

  Timer? _debounce;
  List<SpotifyArtistOption> _artists = [];
  SpotifyArtistOption? _selectedArtist;
  String _activeSearchQuery = '';
  bool _isSearching = false;
  bool _isSubmitting = false;

  Future<void> _searchArtists(String query) async {
    final value = query.trim();
    if (value.length < 2) {
      if (mounted) {
        setState(() {
          _activeSearchQuery = '';
          _artists = [];
          _isSearching = false;
        });
      }
      return;
    }

    if (!mounted) return;
    _activeSearchQuery = value;
    setState(() => _isSearching = true);

    try {
      final encoded = Uri.encodeQueryComponent(value);
      final res = await http.get('/artist-request/search?query=$encoded');

      if (!mounted || _activeSearchQuery != value) return;

      if (res['status'] == 200) {
        final data = res['data']?['artists'] as List? ?? [];
        setState(() {
          _artists = data
              .map((item) => SpotifyArtistOption.fromJson(
                    Map<String, dynamic>.from(item),
                  ))
              .where((artist) => artist.spotifyArtistId.isNotEmpty)
              .toList();
        });
      } else {
        setState(() => _artists = []);
      }
    } finally {
      if (mounted && _activeSearchQuery == value) {
        setState(() => _isSearching = false);
      }
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    setState(() {
      _activeSearchQuery = value.trim();
      _selectedArtist = null;
    });

    _debounce = Timer(const Duration(milliseconds: 350), () {
      _searchArtists(value);
    });
  }

  void _selectArtist(SpotifyArtistOption artist) {
    _debounce?.cancel();
    setState(() {
      _activeSearchQuery = '';
      _selectedArtist = artist;
      _artists = [];
      _isSearching = false;
      _searchController.text = artist.name;
    });
  }

  Future<void> _submit() async {
    final artist = _selectedArtist;
    if (artist == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione um artista')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final res = await http.post('/artist-request', data: {
        'spotifyArtistId': artist.spotifyArtistId,
        'spotifyUrl': artist.spotifyUrl,
      });

      if (!mounted) return;

      if (res['status'] == 201 || res['status'] == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Solicitação enviada com sucesso!')),
        );
        context.pop();
      } else {
        final error = res['data']?['error'] ?? 'Erro ao enviar solicitação';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao enviar solicitação')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
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
        title: const Text("Solicitar Artista"),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                labelText: "Artista",
                hintText: "Buscar no Spotify",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _isSearching
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : _searchController.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _activeSearchQuery = '';
                                _selectedArtist = null;
                                _artists = [];
                                _isSearching = false;
                              });
                            },
                          ),
              ),
            ),
            if (_artists.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                constraints: const BoxConstraints(maxHeight: 360),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.12),
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _artists.length,
                  separatorBuilder: (_, __) => Divider(
                    height: 1,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.08),
                  ),
                  itemBuilder: (context, index) {
                    final artist = _artists[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: primary,
                        backgroundImage: artist.avatarUrl.isNotEmpty
                            ? NetworkImage(artist.avatarUrl)
                            : null,
                        child: artist.avatarUrl.isEmpty
                            ? const Icon(Icons.person, color: Colors.white70)
                            : null,
                      ),
                      title: Text(
                        artist.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        artist.genres.take(2).join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => _selectArtist(artist),
                    );
                  },
                ),
              ),
            ],
            if (_selectedArtist != null) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.check_circle, color: primary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _selectedArtist!.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSubmitting
                    ? SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      )
                    : const Text(
                        "Enviar Solicitação",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
