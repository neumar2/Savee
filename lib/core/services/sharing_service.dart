import 'dart:async';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

/// Serviço para gerenciar e escutar intents de compartilhamento do sistema Android.
/// Captura links compartilhados de apps como YouTube, Instagram e TikTok.
class SharingService {
  StreamSubscription? _intentSub;

  /// Inicializa a escuta de intents de compartilhamento.
  /// Aceita um callback [onLinkReceived] que é invocado quando um link válido é recebido.
  void initSharingListener({
    required void Function(String url) onLinkReceived,
  }) {
    try {
      // 1. Escutar links com o aplicativo já em execução na memória
      _intentSub = ReceiveSharingIntent.instance.getMediaStream().listen(
        (List<SharedMediaFile> value) {
          if (value.isNotEmpty) {
            final path = value.first.path;
            if (_isValidUrl(path)) {
              onLinkReceived(path);
            }
          }
        },
        onError: (err) {
          print("Erro ao capturar compartilhamento em tempo de execução: $err");
        },
      );

      // 2. Escutar links se o aplicativo foi aberto a partir de um compartilhamento (estado fechado)
      ReceiveSharingIntent.instance.getInitialMedia().then((List<SharedMediaFile> value) {
        if (value.isNotEmpty) {
          final path = value.first.path;
          if (_isValidUrl(path)) {
            onLinkReceived(path);
          }
        }
      }).catchError((err) {
        print("Erro ao capturar compartilhamento inicial: $err");
      });
    } catch (e) {
      print("Erro ao configurar o SharingService: $e");
    }
  }

  /// Libera a inscrição do stream para evitar vazamentos de memória (memory leaks).
  void dispose() {
    _intentSub?.cancel();
  }

  /// Valida se o texto recebido é um link HTTP/HTTPS válido.
  bool _isValidUrl(String text) {
    final cleanText = text.trim();
    final uri = Uri.tryParse(cleanText);
    return uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
  }
}
