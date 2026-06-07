import 'package:flutter/material.dart';

/// Modal bottom sheet para configurar o formato e a qualidade do download.
/// Adapta as opções dependendo da plataforma de origem do vídeo.
class DownloadOptionsSheet extends StatefulWidget {
  final String url;
  final String platform;
  final void Function(String format, String quality) onConfirm;

  const DownloadOptionsSheet({
    super.key,
    required this.url,
    required this.platform,
    required this.onConfirm,
  });

  @override
  State<DownloadOptionsSheet> createState() => _DownloadOptionsSheetState();
}

class _DownloadOptionsSheetState extends State<DownloadOptionsSheet> {
  String _selectedFormat = 'Video'; // 'Video' ou 'Audio'
  String _selectedQuality = '720p';

  final List<String> _videoQualities = ['1080p', '720p', '360p'];
  final List<String> _audioQualities = ['320kbps', '192kbps', '128kbps'];

  @override
  void initState() {
    super.initState();
    _selectedQuality = _videoQualities[1]; // Padrão: 720p
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final qualities = _selectedFormat == 'Video' ? _videoQualities : _audioQualities;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Barra de arrastar no topo do modal
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Opções de Download',
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'Link identificado de: ${widget.platform}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // Seção de Seleção de Formato
          Text(
            'Escolha o formato',
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: const Center(child: Text('Vídeo (MP4)')),
                  selected: _selectedFormat == 'Video',
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _selectedFormat = 'Video';
                        _selectedQuality = _videoQualities[1];
                      });
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ChoiceChip(
                  label: const Center(child: Text('Áudio (MP3)')),
                  selected: _selectedFormat == 'Audio',
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _selectedFormat = 'Audio';
                        _selectedQuality = _audioQualities[0];
                      });
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Seção de Seleção de Qualidade
          Text(
            'Selecione a qualidade',
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: qualities.map((quality) {
              return ChoiceChip(
                label: Text(quality),
                selected: _selectedQuality == quality,
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      _selectedQuality = quality;
                    });
                  }
                },
              );
            }).toList(),
          ),

          // Detalhes extras para TikTok (Remoção de marca d'água)
          if (widget.platform.toLowerCase() == 'tiktok' && _selectedFormat == 'Video') ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.auto_awesome, color: theme.colorScheme.primary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Remoção automática de marca d\'água ativada.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),

          // Botão Confirmar
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onConfirm(_selectedFormat, _selectedQuality);
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Iniciar Download',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}
