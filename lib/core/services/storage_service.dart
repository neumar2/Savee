import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Service folder management & Android MediaScanner integration
class StorageService {
  Directory? _baseDir;
  static const _channel = MethodChannel('com.example.savee/media_scanner');

  /// Inicializa o diretório base visível publicamente na Galeria e Downloads.
  Future<void> init() async {
    try {
      Directory? rootDir;
      if (Platform.isAndroid) {
        // Usar diretório público de Filmes/Vídeos ou Downloads no Android
        rootDir = Directory('/storage/emulated/0/Movies/Savee');
      }
      
      // Fallback para documentos se não for Android ou se o diretório falhar
      rootDir ??= await getApplicationDocumentsDirectory();

      _baseDir = rootDir;

      if (!await _baseDir!.exists()) {
        await _baseDir!.create(recursive: true);
      }
    } catch (e) {
      print("Erro ao inicializar diretório de mídia: $e");
    }
  }

  /// Notifica o sistema operacional Android para indexar o arquivo na Galeria de Fotos/Vídeos.
  static Future<void> scanFileForGallery(String filePath) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('scanFile', {'path': filePath});
      print("MediaScanner acionado com sucesso para: $filePath");
    } catch (e) {
      print("Erro ao acionar MediaScanner: $e");
    }
  }

  /// Abre um arquivo diretamente no player / galeria nativa do dispositivo.
  static Future<void> openInGallery(String filePath, {String? mimeType}) async {
    if (!Platform.isAndroid) return;
    try {
      final ext = p.extension(filePath).toLowerCase();
      final determinedMime = mimeType ?? (ext == '.mp3' || ext == '.m4a' ? 'audio/*' : 'video/*');
      await _channel.invokeMethod('openFile', {
        'path': filePath,
        'mimeType': determinedMime,
      });
    } catch (e) {
      print("Erro ao abrir arquivo nativamente: $e");
    }
  }

  /// Retorna o caminho de salvamento baseado na plataforma e no tipo (Vídeo ou MP3).
  Future<String> getMediaPath({
    required String platform,
    required String type,
    String? subFolder,
  }) async {
    if (_baseDir == null) {
      await init();
    }

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
    return input.replaceAll(RegExp(r'[^\w\-_]'), '').trim();
  }
}

