import 'package:flutter/material.dart';

/// Componente que renderiza a caixa de entrada para a URL e o botão de download.
/// Também gerencia e exibe o estado visual de progresso de downloads ativos.
class DownloadForm extends StatelessWidget {
  final TextEditingController urlController;
  final bool isDownloading;
  final double downloadProgress;
  final VoidCallback onDownloadPressed;
  final VoidCallback? onCancelPressed;
  final VoidCallback? onPausePressed;
  final bool isPaused;

  const DownloadForm({
    super.key,
    required this.urlController,
    required this.isDownloading,
    required this.downloadProgress,
    required this.onDownloadPressed,
    this.onCancelPressed,
    this.onPausePressed,
    this.isPaused = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Campo de entrada de Link
        TextField(
          controller: urlController,
          enabled: !isDownloading,
          keyboardType: TextInputType.url,
          decoration: InputDecoration(
            labelText: 'Link do vídeo',
            hintText: 'Cole a URL do vídeo aqui...',
            prefixIcon: const Icon(Icons.link),
            suffixIcon: urlController.text.isNotEmpty && !isDownloading
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      urlController.clear();
                    },
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
          ),
          style: theme.textTheme.bodyLarge,
        ),
        const SizedBox(height: 16),

        // Botão para iniciar o download
        ElevatedButton.icon(
          onPressed: isDownloading ? null : onDownloadPressed,
          icon: isDownloading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Icon(Icons.download),
          label: Text(
            isDownloading
                ? 'Baixando... (${(downloadProgress * 100).toStringAsFixed(0)}%)'
                : 'Baixar Vídeo',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 2,
          ),
        ),

        // Barra de progresso linear abaixo do botão
        if (isDownloading) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: downloadProgress,
                    minHeight: 8,
                    backgroundColor: theme.colorScheme.outlineVariant,
                    valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                  ),
                ),
              ),
              if (onPausePressed != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(isPaused ? Icons.play_arrow : Icons.pause, color: theme.colorScheme.primary),
                  onPressed: onPausePressed,
                  tooltip: isPaused ? 'Retomar Download' : 'Pausar Download',
                ),
              ],
              if (onCancelPressed != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.cancel, color: theme.colorScheme.error),
                  onPressed: onCancelPressed,
                  tooltip: 'Cancelar Download',
                ),
              ]
            ],
          ),
        ],
      ],
    );
  }
}
