import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Tela para reprodução interna de vídeos offline salvos na pasta Mídia.
class PlayerScreen extends StatefulWidget {
  final String filePath;
  final String title;

  const PlayerScreen({
    super.key,
    required this.filePath,
    required this.title,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  String _errorMessage = "";

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  /// Inicializa o controlador do player a partir do arquivo local.
  Future<void> _initializePlayer() async {
    try {
      final file = File(widget.filePath);
      if (!await file.exists()) {
        setState(() {
          _errorMessage = "O arquivo de vídeo não foi encontrado localmente.";
        });
        return;
      }

      _controller = VideoPlayerController.file(file);
      await _controller.initialize();
      setState(() {
        _isInitialized = true;
      });
      _controller.play();
      _controller.addListener(() {
        if (mounted) setState(() {});
      });
    } catch (e) {
      setState(() {
        _errorMessage = "Erro ao carregar e iniciar o vídeo: $e";
      });
    }
  }

  @override
  void dispose() {
    if (_isInitialized) {
      _controller.dispose();
    }
    super.dispose();
  }

  bool get _isAudio =>
      widget.filePath.toLowerCase().endsWith('.mp3') ||
      widget.filePath.toLowerCase().endsWith('.m4a');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          widget.title,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: _errorMessage.isNotEmpty
            ? Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage,
                      style: const TextStyle(color: Colors.white70, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            : !_isInitialized
                ? const CircularProgressIndicator()
                : _isAudio
                    ? Stack(
                        alignment: Alignment.bottomCenter,
                        children: [
                          Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 140,
                                  height: 140,
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.primaryContainer,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.music_note_rounded,
                                    size: 70,
                                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 24),
                                  child: Text(
                                    widget.title,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  "Reproduzindo Áudio (Offline)",
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _buildControls(),
                        ],
                      )
                    : AspectRatio(
                        aspectRatio: _controller.value.aspectRatio,
                        child: Stack(
                          alignment: Alignment.bottomCenter,
                          children: [
                            VideoPlayer(_controller),
                            _buildControls(),
                          ],
                        ),
                      ),
      ),
    );
  }

  /// Constrói os controles básicos do player (Play/Pause e barra de progresso).
  Widget _buildControls() {
    final duration = _controller.value.duration;
    final position = _controller.value.position;

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // Indicador de progresso interativo (permite arrastar)
        VideoProgressIndicator(
          _controller,
          allowScrubbing: true,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          colors: VideoProgressColors(
            playedColor: Theme.of(context).colorScheme.primary,
            bufferedColor: Colors.white30,
            backgroundColor: Colors.white12,
          ),
        ),
        Container(
          color: Colors.black54,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Botão Play/Pause
              IconButton(
                icon: Icon(
                  _controller.value.isPlaying ? Icons.pause_circle : Icons.play_circle,
                  color: Colors.white,
                  size: 36,
                ),
                onPressed: () {
                  setState(() {
                    _controller.value.isPlaying ? _controller.pause() : _controller.play();
                  });
                },
              ),
              // Tempo decorrido / Tempo total
              Text(
                "${_formatDuration(position)} / ${_formatDuration(duration)}",
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Formata a duração em formato MM:SS
  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }
}
