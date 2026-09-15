import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/services/download_engine.dart';
import '../../core/services/sharing_service.dart';
import '../../core/services/storage_service.dart';
import '../widgets/download_form.dart';
import '../widgets/download_options_sheet.dart';
import '../widgets/history_list.dart';
import 'player_screen.dart';

/// Tela inicial principal do Savee.
/// Gerencia a integração de todos os serviços (Storage, Sharing e Engine) e UI.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final TextEditingController _urlController = TextEditingController();
  final DownloadEngine _downloadEngine = DownloadEngine();
  final SharingService _sharingService = SharingService();
  final StorageService _storageService = StorageService();

  bool _isDownloading = false;
  bool _isPaused = false;
  double _downloadProgress = 0.0;
  List<String> _history = [];
  StreamSubscription<double>? _downloadSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeServices();
  }

  /// Inicializa os serviços assíncronos e escuta por intents de compartilhamento.
  Future<void> _initializeServices() async {
    await _storageService.init();
    await _loadHistory();

    // Carrega as regras dinâmicas do servidor
    await _downloadEngine.fetchRemoteRules();

    // Inicializa a escuta de links compartilhados por outros apps
    _sharingService.initSharingListener(
      onLinkReceived: (url) {
        setState(() {
          _urlController.text = url;
        });
        _showSnackBar("Link compartilhado carregado!");
      },
    );

    // Verifica a área de transferência na inicialização
    _checkClipboard();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _urlController.dispose();
    _sharingService.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkClipboard();
    }
  }

  /// Verifica se há um link de vídeo válido na área de transferência.
  Future<void> _checkClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (data != null && data.text != null) {
        final text = data.text!.trim();
        final isValid = await _downloadEngine.validateUrl(text);

        // Apenas sugere se for um link válido e diferente do que já está na tela
        if (isValid && text != _urlController.text) {
          _showClipboardSuggestion(text);
        }
      }
    } catch (e) {
      print("Erro ao verificar área de transferência: $e");
    }
  }

  /// Exibe um diálogo sugerindo colar o link detectado na área de transferência.
  void _showClipboardSuggestion(String url) {
    final platform = _downloadEngine.detectPlatform(url);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.content_paste, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            const Text("Link Detectado"),
          ],
        ),
        content: Text(
          "Encontramos um link do $platform na sua área de transferência. Deseja colá-lo?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar"),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _urlController.text = url;
              });
            },
            child: const Text("Colar Link"),
          ),
        ],
      ),
    );
  }

  /// Atualiza a lista do histórico local.
  Future<void> _loadHistory() async {
    final files = await _storageService.listDownloadedFiles();
    setState(() {
      _history = files;
    });
  }

  /// Exibe mensagens amigáveis na tela.
  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  /// Abre a seleção de opções antes de iniciar o download.
  Future<void> _handleDownloadPressed() async {
    final url = _urlController.text.trim();
    print("URL recebida para download: '$url'");
    if (url.isEmpty) {
      _showSnackBar("Insira ou cole um link de vídeo primeiro.");
      return;
    }

    final isValid = await _downloadEngine.validateUrl(url);
    if (!isValid) {
      _showSnackBar("Link inválido ou não suportado pelas regras.");
      return;
    }

    final platform = _downloadEngine.detectPlatform(url);

    // Exibe o painel de opções (Qualidade e Formato)
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DownloadOptionsSheet(
        url: url,
        platform: platform,
        onConfirm: (format, quality) {
          _startDownload(url, platform, format, quality);
        },
      ),
    );
  }

  /// Dispara o download com as configurações escolhidas pelo usuário.
  Future<void> _startDownload(
    String url,
    String platform,
    String format,
    String quality,
  ) async {
    setState(() {
      _isDownloading = true;
      _isPaused = false;
      _downloadProgress = 0.0;
    });

    final typeFolder = format == 'Video' ? 'Video' : 'Audio';
    final saveDir = await _storageService.getMediaPath(platform: platform, type: typeFolder);

    // Inicia o download
    _downloadSubscription?.cancel();
    _downloadSubscription = _downloadEngine.downloadVideo(
      url: url,
      saveDir: saveDir,
      format: format,
      quality: quality,
    ).listen(
      (progress) {
        setState(() {
          _downloadProgress = progress;
        });
      },
      onDone: () async {
        try {
          _showSnackBar("Download concluído!");
          _urlController.clear();
        } catch (e) {
          _showSnackBar("Erro: $e");
        } finally {
          setState(() {
            _isDownloading = false;
            _downloadProgress = 0.0;
          });
          _loadHistory();
        }
      },
      onError: (err) {
        _showSnackBar("Erro no download: $err");
        setState(() {
          _isDownloading = false;
        });
      },
    );
  }

  void _cancelDownload() {
    _downloadSubscription?.cancel();
    _downloadSubscription = null;
    setState(() {
      _isDownloading = false;
      _isPaused = false;
      _downloadProgress = 0.0;
    });
    _showSnackBar("Download cancelado.");
  }

  void _togglePause() {
    if (_downloadSubscription == null) return;
    if (_isPaused) {
      _downloadSubscription!.resume();
      _showSnackBar("Download retomado.");
    } else {
      _downloadSubscription!.pause();
      _showSnackBar("Download pausado.");
    }
    setState(() {
      _isPaused = !_isPaused;
    });
  }

  Future<void> _deleteFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        _showSnackBar("Arquivo excluído.");
        _loadHistory();
      }
    } catch (e) {
      _showSnackBar("Erro ao excluir arquivo: $e");
    }
  }

  /// Exibe o painel de diálogo "Sobre" com os créditos do desenvolvedor.
  void _showAboutDialog() {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: theme.colorScheme.surface,
        title: Row(
          children: [
            Icon(Icons.info_outline, color: theme.colorScheme.primary, size: 28),
            const SizedBox(width: 12),
            Text(
              "Sobre o Savee",
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.download_done_rounded,
                  size: 48,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                "Savee v1.1.0",
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            Text(
              "Desenvolvido por:",
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "Neumar Porto Permonian",
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "Descrição:",
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "O Savee é um gerenciador de downloads autônomo, rápido e seguro para baixar vídeos e áudios do YouTube e TikTok diretamente para o seu armazenamento local de forma organizada.",
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Fechar"),
          ),
        ],
      ),
    );
  }

  /// Exibe diálogo para configurar a URL do servidor yt-dlp privado (Tailscale).
  void _showServerSettingsDialog() {
    final controller = TextEditingController(text: _downloadEngine.serverUrl ?? '');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.dns_rounded),
            SizedBox(width: 8),
            Text("Servidor yt-dlp"),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Insira o IP/MagicDNS do seu servidor Tailscale (Umbrel) para extrações em alta velocidade:",
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: "http://100.x.y.z:8000",
                labelText: "URL do Servidor Backend",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.link),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar"),
          ),
          FilledButton(
            onPressed: () {
              setState(() {
                _downloadEngine.serverUrl = controller.text.trim();
              });
              Navigator.pop(context);
              _showSnackBar("URL do Servidor Backend atualizada!");
            },
            child: const Text("Salvar"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Savee',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.dns_outlined),
            tooltip: 'Servidor Tailscale (yt-dlp)',
            onPressed: _showServerSettingsDialog,
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'Sobre',
            onPressed: _showAboutDialog,
          ),
        ],
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Baixe vídeos com simplicidade',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Insira o link abaixo para iniciar o download de qualquer rede social.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),

                // Formulário de Download
                DownloadForm(
                  urlController: _urlController,
                  isDownloading: _isDownloading,
                  downloadProgress: _downloadProgress,
                  onDownloadPressed: _handleDownloadPressed,
                  onCancelPressed: _cancelDownload,
                  onPausePressed: _togglePause,
                  isPaused: _isPaused,
                ),

                const SizedBox(height: 32),
                const Divider(),
                const SizedBox(height: 16),

                Text(
                  'Histórico de Downloads',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),

                // Lista de histórico com player interno integrado
                HistoryList(
                  downloadedFiles: _history,
                  onDeleteItem: _deleteFile,
                  onItemPressed: (filePath) {
                    final fileName = p.basename(filePath);
                    showModalBottomSheet(
                      context: context,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                      ),
                      builder: (context) {
                        return SafeArea(
                          child: Wrap(
                            children: [
                              ListTile(
                                leading: const Icon(Icons.play_circle_outline),
                                title: const Text('Assistir no App (Savee)'),
                                onTap: () {
                                  Navigator.pop(context);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => PlayerScreen(
                                        filePath: filePath,
                                        title: fileName,
                                      ),
                                    ),
                                  );
                                },
                              ),
                              ListTile(
                                leading: const Icon(Icons.photo_library_outlined),
                                title: const Text('Abrir na Galeria do Celular'),
                                subtitle: const Text('Ideal para editar, recortar ou compartilhar'),
                                onTap: () {
                                  Navigator.pop(context);
                                  StorageService.openInGallery(filePath);
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

