import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

/// Componente para listar os downloads salvos no dispositivo.
/// Se não houver arquivos, renderiza um aviso centralizado amigável.
class HistoryList extends StatelessWidget {
  final List<String> downloadedFiles;
  final void Function(String filePath) onItemPressed;
  final void Function(String filePath)? onDeleteItem;

  const HistoryList({
    super.key,
    required this.downloadedFiles,
    required this.onItemPressed,
    this.onDeleteItem,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (downloadedFiles.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
            ),
            const SizedBox(height: 12),
            Text(
              'Nenhum download recente',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: downloadedFiles.length,
      itemBuilder: (context, index) {
        final filePath = downloadedFiles[index];
        final fileName = p.basename(filePath);
        final folderName = p.basename(p.dirname(filePath)); // Ex: Video, Audio
        final platformName = p.basename(p.dirname(p.dirname(filePath))); // Ex: YouTube, TikTok

        final isAudio = folderName.toLowerCase() == 'audio';

        return Card(
          elevation: 0.5,
          margin: const EdgeInsets.symmetric(vertical: 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Icon(
                isAudio ? Icons.music_note : Icons.movie,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            title: Text(
              fileName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text('$platformName • $folderName'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (onDeleteItem != null)
                  IconButton(
                    icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
                    onPressed: () => onDeleteItem!(filePath),
                  ),
                Icon(
                  Icons.play_circle_outline,
                  color: theme.colorScheme.primary,
                ),
              ],
            ),
            onTap: () {
              onItemPressed(filePath);
            },
          ),
        );
      },
    );
  }
}
