import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'storage_service.dart';

/// Modelo para representar as regras de extração dinâmica obtidas do servidor.
class DownloadRule {
  final String platform;
  final String regexPattern;
  final String apiEndpoint;

  DownloadRule({
    required this.platform,
    required this.regexPattern,
    required this.apiEndpoint,
  });

  factory DownloadRule.fromJson(Map<String, dynamic> json) {
    return DownloadRule(
      platform: json['platform'] as String? ?? 'Desconhecida',
      regexPattern: json['regexPattern'] as String? ?? '',
      apiEndpoint: json['apiEndpoint'] as String? ?? '',
    );
  }
}

/// Motor de extração e download. Busca regras dinâmicas de servidor remoto
/// ou executa o download diretamente no dispositivo móvel de forma autônoma.
class DownloadEngine {
  final List<DownloadRule> _rules = [];
  bool _rulesLoaded = false;

  /// Busca regras remotas via requisição HTTPS. Em caso de erro, recorre às regras locais.
  Future<void> fetchRemoteRules() async {
    const rulesUrl = 'https://raw.githubusercontent.com/downtub/rules/main/rules.json';

    try {
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(rulesUrl));
      final response = await request.close();

      if (response.statusCode == HttpStatus.ok) {
        final body = await response.transform(utf8.decoder).join();
        final List<dynamic> data = json.decode(body);
        _rules.clear();
        for (var item in data) {
          if (item is Map<String, dynamic>) {
            _rules.add(DownloadRule.fromJson(item));
          }
        }
        _rulesLoaded = true;
        print("Regras dinâmicas de extração atualizadas. Total: ${_rules.length}");
      } else {
        _loadFallbackRules();
      }
    } catch (e) {
      print("Falha ao atualizar regras remotas: $e. Usando fallback local.");
      _loadFallbackRules();
    }
  }

  /// Carrega as regras locais caso o servidor remoto esteja indisponível.
  void _loadFallbackRules() {
    _rules.clear();
    _rules.addAll([
      DownloadRule(
        platform: 'YouTube',
        regexPattern: r'(youtube\.com|youtu\.be)',
        apiEndpoint: 'local_youtube_explode',
      ),
      DownloadRule(
        platform: 'TikTok',
        regexPattern: r'(tiktok\.com)',
        apiEndpoint: 'https://www.tikwm.com/api/',
      ),
      DownloadRule(
        platform: 'Instagram',
        regexPattern: r'(instagram\.com)',
        apiEndpoint: 'local_instagram',
      ),
    ]);
    _rulesLoaded = true;
  }

  /// Valida se o link informado é correspondido por alguma regra ativa.
  Future<bool> validateUrl(String url) async {
    if (!_rulesLoaded) {
      _loadFallbackRules();
    }

    final cleanUrl = url.trim();
    for (var rule in _rules) {
      try {
        if (RegExp(rule.regexPattern, caseSensitive: false).hasMatch(cleanUrl)) {
          return true;
        }
      } catch (e) {
        print("Regex inválido: ${rule.regexPattern}");
      }
    }
    return false;
  }

  /// Identifica a plataforma de origem do link.
  String detectPlatform(String url) {
    if (!_rulesLoaded) {
      _loadFallbackRules();
    }

    final cleanUrl = url.trim();
    for (var rule in _rules) {
      if (RegExp(rule.regexPattern, caseSensitive: false).hasMatch(cleanUrl)) {
        return rule.platform;
      }
    }
    return 'Outros';
  }

  String _sanitizeFileName(String input) {
    // limpa nome do arquivo
    var sanitized = input.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_').trim();
    // Remove múltiplos espaços ou sublinhados seguidos
    sanitized = sanitized.replaceAll(RegExp(r'[_\s]{2,}'), '_');
    // Remove pontos ou sublinhados no início ou fim para evitar arquivos ocultos ou estranhos
    while (sanitized.startsWith('.') || sanitized.startsWith('_')) {
      if (sanitized.length <= 1) {
        sanitized = '';
        break;
      }
      sanitized = sanitized.substring(1);
    }
    while (sanitized.endsWith('.') || sanitized.endsWith('_')) {
      if (sanitized.length <= 1) {
        sanitized = '';
        break;
      }
      sanitized = sanitized.substring(0, sanitized.length - 1);
    }
    // Previne nomes vazios, maliciosos ou reservados do Windows (CON, NUL, etc.)
    final upper = sanitized.toUpperCase();
    final reserved = {
      'CON', 'PRN', 'AUX', 'NUL',
      'COM1', 'COM2', 'COM3', 'COM4', 'COM5', 'COM6', 'COM7', 'COM8', 'COM9',
      'LPT1', 'LPT2', 'LPT3', 'LPT4', 'LPT5', 'LPT6', 'LPT7', 'LPT8', 'LPT9'
    };
    if (sanitized.isEmpty || sanitized == '.' || sanitized == '..' || reserved.contains(upper)) {
      return 'media_${DateTime.now().millisecondsSinceEpoch}';
    }
    return sanitized;
  }

  String? serverUrl = 'http://100.119.111.100:8089';

  /// Executa o download preferencialmente no Servidor yt-dlp (Tailscale) ou cai de volta para extração local.
  Stream<double> downloadVideo({
    required String url,
    required String saveDir,
    required String format,
    required String quality,
  }) async* {
    if (serverUrl != null && serverUrl!.isNotEmpty) {
      try {
        yield* _downloadFromBackend(url, saveDir, format, quality);
        return;
      } catch (e) {
        print("Falha ao usar servidor backend Tailscale: $e. Tentando modo autônomo local.");
      }
    }

    final platform = detectPlatform(url);
    if (platform == 'YouTube') {
      yield* _downloadYouTubeSingle(url, saveDir, format, quality);
    } else if (platform == 'TikTok') {
      yield* _downloadTikTok(url, saveDir, format, quality);
    } else {
      throw Exception("A plataforma $platform não é suportada no modo local offline.");
    }
  }

  /// Baixa a mídia processada pelo servidor backend Python yt-dlp
  Stream<double> _downloadFromBackend(
    String url,
    String saveDir,
    String format,
    String quality,
  ) async* {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 15);

    try {
      var rawUrl = serverUrl!.trim();
      if (!rawUrl.startsWith('http://') && !rawUrl.startsWith('https://')) {
        rawUrl = 'http://$rawUrl';
      }
      final cleanServerUrl = rawUrl.endsWith('/') 
          ? rawUrl.substring(0, rawUrl.length - 1) 
          : rawUrl;
      final uri = Uri.parse('$cleanServerUrl/api/download');

      final request = await client.postUrl(uri);
      request.headers.contentType = ContentType.json;

      final body = json.encode({
        'url': url,
        'format': format,
        'quality': quality,
      });

      request.write(body);
      final response = await request.close();

      if (response.statusCode != HttpStatus.ok) {
        final errText = await response.transform(utf8.decoder).join();
        throw Exception("Servidor yt-dlp retornou erro ${response.statusCode}: $errText");
      }

      // Extrair nome do arquivo do header Content-Disposition se fornecido
      String fileName = 'media_${DateTime.now().millisecondsSinceEpoch}.${format == 'Audio' ? 'mp3' : 'mp4'}';
      final disposition = response.headers.value('content-disposition');
      if (disposition != null && disposition.contains('filename=')) {
        final match = RegExp(r'filename="?([^";]+)"?').firstMatch(disposition);
        if (match != null && match.group(1) != null) {
          fileName = _sanitizeFileName(match.group(1)!);
        }
      }

      final filePath = '$saveDir/$fileName';
      final file = File(filePath);
      await file.parent.create(recursive: true);
      final fileSink = file.openWrite();

      final totalSize = response.contentLength > 0 ? response.contentLength : 1024 * 1024 * 10;
      int downloaded = 0;

      await for (final List<int> chunk in response) {
        fileSink.add(chunk);
        downloaded += chunk.length;
        yield downloaded / totalSize;
      }

      await fileSink.close();
      await StorageService.scanFileForGallery(filePath);
    } catch (e) {
      print("Erro na conexão com o servidor yt-dlp: $e");
      rethrow;
    } finally {
      client.close();
    }
  }

  /// Download de vídeo único do YouTube usando youtube_explode_dart
  Stream<double> _downloadYouTubeSingle(
    String url,
    String saveDir,
    String format,
    String quality,
  ) async* {
    final yt = YoutubeExplode();
    try {
      final video = await yt.videos.get(url);
      final manifest = await yt.videos.streamsClient.getManifest(video.id);

      Stream<List<int>> mediaStream;
      int totalSize = 0;
      final extension = format == 'Video' ? 'mp4' : 'm4a';

      if (format == 'Audio') {
        // Fix: YouTube blocks audioOnly streams, causing them to hang at 0%. 
        // We use the lowest quality muxed stream (video+audio) as a workaround.
        final streamInfo = manifest.muxed.isNotEmpty ? manifest.muxed.first : manifest.muxed.withHighestBitrate();
        mediaStream = yt.videos.streamsClient.get(streamInfo);
        totalSize = streamInfo.size.totalBytes;
      } else {
        MuxedStreamInfo? selectedStream;

        if (quality.contains('1080')) {
          selectedStream = manifest.muxed.sortByVideoQuality().last;
        } else if (quality.contains('720')) {
          try {
            selectedStream = manifest.muxed.firstWhere((s) => s.videoQualityLabel == '720p');
          } catch (_) {
            selectedStream = manifest.muxed.sortByVideoQuality().last;
          }
        } else {
          try {
            selectedStream = manifest.muxed.firstWhere((s) => s.videoQualityLabel == '360p');
          } catch (_) {
            selectedStream = manifest.muxed.first;
          }
        }

        if (selectedStream == null) {
          if (manifest.muxed.isNotEmpty) {
            selectedStream = manifest.muxed.withHighestBitrate();
          } else {
            throw Exception("Nenhum stream de vídeo combinado (muxed) disponível.");
          }
        }

        mediaStream = yt.videos.streamsClient.get(selectedStream);
        totalSize = selectedStream.size.totalBytes;
      }

      final sanitizedTitle = _sanitizeFileName(video.title);
      final filePath = '$saveDir/$sanitizedTitle.$extension';

      final file = File(filePath);
      await file.parent.create(recursive: true);
      final fileSink = file.openWrite();

      int downloaded = 0;
      await for (final List<int> chunk in mediaStream) {
        fileSink.add(chunk);
        downloaded += chunk.length;
        if (totalSize > 0) {
          yield downloaded / totalSize;
        } else {
          yield 0.5;
        }
      }

      await fileSink.close();
      await StorageService.scanFileForGallery(filePath);
    } catch (e) {
      print("Erro no download do YouTube: $e");
      rethrow;
    } finally {
      yt.close();
    }
  }



  /// Download de vídeo do TikTok via API pública TikWM
  Stream<double> _downloadTikTok(
    String url,
    String saveDir,
    String format,
    String quality,
  ) async* {
    final client = HttpClient();
    try {
      final tikwmUri = Uri.parse('https://www.tikwm.com/api/?url=${Uri.encodeComponent(url)}');
      final request = await client.getUrl(tikwmUri);
      final response = await request.close();

      if (response.statusCode != HttpStatus.ok) {
        throw Exception("Erro de conexão com API TikTok (HTTP ${response.statusCode})");
      }

      final responseBody = await response.transform(utf8.decoder).join();
      final Map<String, dynamic> data = json.decode(responseBody);

      if (data['code'] != 0 || data['data'] == null) {
        var msg = data['msg'] ?? 'Falha ao processar link do TikTok';
        if (msg.toString().toLowerCase().contains('url parsing') || 
            msg.toString().toLowerCase().contains('video id') ||
            msg.toString().toLowerCase().contains('failed')) {
          msg = 'Não foi possível extrair o vídeo. O TikTok pode estar bloqueando a API ou o link é inválido/privado.';
        }
        throw Exception(msg);
      }

      final mediaUrl = format == 'Audio' ? data['data']['music'] : data['data']['play'];
      if (mediaUrl == null || mediaUrl.isEmpty) {
        throw Exception("Link de mídia não encontrado na resposta do TikTok.");
      }

      final videoTitle = data['data']['title'] as String? ?? 'TikTok_Video';

      final mediaRequest = await client.getUrl(Uri.parse(mediaUrl));
      final mediaResponse = await mediaRequest.close();

      if (mediaResponse.statusCode != HttpStatus.ok) {
        throw Exception("Erro ao obter stream do TikTok (HTTP ${mediaResponse.statusCode})");
      }

      final extension = format == 'Video' ? 'mp4' : 'mp3';
      final sanitizedTitle = _sanitizeFileName(videoTitle);
      final filePath = '$saveDir/$sanitizedTitle.$extension';

      final file = File(filePath);
      await file.parent.create(recursive: true);
      final fileSink = file.openWrite();

      final totalSize = mediaResponse.contentLength > 0 ? mediaResponse.contentLength : 1024 * 1024 * 5;
      int downloaded = 0;

      await for (final List<int> chunk in mediaResponse) {
        fileSink.add(chunk);
        downloaded += chunk.length;
        yield downloaded / totalSize;
      }

      await fileSink.close();
      await StorageService.scanFileForGallery(filePath);
    } catch (e) {
      print("Erro no download do TikTok: $e");
      rethrow;
    } finally {
      client.close();
    }
  }
}
