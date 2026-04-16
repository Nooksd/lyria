import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lyria/app/app_router.dart';
import 'package:lyria/app/core/services/http/my_http_client.dart';

class RequestArtistPage extends StatefulWidget {
  const RequestArtistPage({super.key});

  @override
  State<RequestArtistPage> createState() => _RequestArtistPageState();
}

class _RequestArtistPageState extends State<RequestArtistPage> {
  final MyHttpClient http = getIt<MyHttpClient>();
  final _formKey = GlobalKey<FormState>();
  final _urlController = TextEditingController();

  bool _isSubmitting = false;

  static final _spotifyArtistRegex = RegExp(
    r'open\.spotify\.com/artist/[a-zA-Z0-9]+',
  );

  String? _validateUrl(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Insira o link do artista';
    }
    if (!_spotifyArtistRegex.hasMatch(value.trim())) {
      return 'Link inválido. Use o formato: open.spotify.com/artist/...';
    }
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final res = await http.post('/artist-request', data: {
        'spotifyUrl': _urlController.text.trim(),
      });

      if (!mounted) return;

      if (res['status'] == 201 || res['status'] == 200) {
        _urlController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Solicitação enviada com sucesso!'),
          ),
        );
        context.pop();
      } else {
        final error = res['data']?['error'] ?? 'Erro ao enviar solicitação';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    } catch (e) {
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
    _urlController.dispose();
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
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              // Info card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "Envie o link do Spotify de um artista que você gostaria que fosse adicionado ao Lyria.",
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // How to get link
              Text(
                "Como obter o link:",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              _buildStep(context, "1", "Abra o Spotify e vá ao perfil do artista"),
              _buildStep(context, "2", "Toque nos 3 pontos (⋯) ou em Compartilhar"),
              _buildStep(context, "3", "Selecione \"Copiar link\""),
              _buildStep(context, "4", "Cole o link abaixo"),
              const SizedBox(height: 24),
              // URL field
              TextFormField(
                controller: _urlController,
                validator: _validateUrl,
                decoration: InputDecoration(
                  labelText: "Link do Spotify",
                  hintText: "https://open.spotify.com/artist/...",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.link),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => _urlController.clear(),
                  ),
                ),
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 24),
              // Submit button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
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
      ),
    );
  }

  Widget _buildStep(BuildContext context, String number, String text) {
    final primary = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
