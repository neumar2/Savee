import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Service folder management
class StorageService {
  Directory? _baseDir;

  /// Inicializa o diretório base 'Mídia'.
  /// Utiliza armazenamento externo no Android (Scoped Storage) e cai de volta para
  /// o diretório de documentos em outras plataformas.
  Future<void> init() async {
    try {
      Directory? rootDir;
      if (Platform.isAndroid) {
        rootDir = Directory('/storage/emulated/0/Download/Savee');
      }
      // Fallback para documentos se não for Android
      rootDir ??= await getApplicationDocumentsDirectory();

      final mediaPath = p.join(rootDir.path, 'Mídia');
      _baseDir = Directory(mediaPath);

      if (!await _baseDir!.exists()) {
        await _baseDir!.create(recursive: true);
      }
    } catch (e) {
      print("Erro ao inicializar db: $e");
    }
  }

  /// Retorna o caminho de salvamento baseado na plataforma e no tipo (Vídeo ou MP3).
  /// Cria as subpastas necessárias caso ainda não existam.
  Future<String> getMediaPath({
    required String platform,
    required String type,
    String? subFolder,
  }) async {
    if (_baseDir == null) {
      await init();
    }

    // Evitando bugs com diretorios
    final safePlatform = _sanitizePathSegment(platform);
    final safeType = _sanitizePathSegment(type);

    var targetPath = p.join(_baseDir!.path, safePlatform, safeType);
    if (subFolder != null && subFolder.isNotEmpty) {
      targetPath = p.join(targetPath, _sanitizePathSegment(subFolder));
    }

    final targetDir = Directory(targetPath);

    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }
    return targetPath;
  }

  /// Retorna a lista de subpastas e arquivos baixados para o histórico.
  Future<List<String>> listDownloadedFiles() async {
    if (_baseDir == null) {
      await init();
    }

    final filesList = <String>[];
    try {
      if (await _baseDir!.exists()) {
        await for (final entity in _baseDir!.list(recursive: true, followLinks: false)) {
          if (entity is File) {
            filesList.add(entity.path);
          }
        }
      }
    } catch (e) {
      print("Erro ao listar arquivos do histórico: $e");
    }
    return filesList;
  }

  String _sanitizePathSegment(String input) {
    // Limpa nome da pasta
    return input.replaceAll(RegExp(r'[^\w\-_]'), '').trim();
  }
}
