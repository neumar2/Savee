# Savee - Contexto & Arquitetura Técnica do Projeto

## Visão Geral
O **Savee** é um aplicativo mobile desenvolvido em Flutter/Dart para gerenciamento e download de vídeos e áudios do YouTube, TikTok, Instagram e diversas outras plataformas.

O projeto possui duas camadas de extração:
1. **Engine Local (Fallback Autônomo)**: Executa diretamente no dispositivo usando `youtube_explode_dart` e APIs públicas (como TikWM) sem depender de infraestrutura.
2. **Servidor Privado Backend (yt-dlp + FastAPI)**: Conecta-se a um microserviço Python via rede privada **Tailscale** para extração em máxima qualidade (1080p+, Shorts, TikTok sem marca d'água, MP3 de alta fidelidade) alimentado por `yt-dlp` e `FFmpeg`.

---

## Estrutura do Repositório

```text
Savee/
├── android/                   # Projeto nativo Android (Kotlin, Gradle 8.7, AGP 8.6)
├── assets/                    # Ícones e recursos gráficos
├── lib/                       # Código-fonte principal em Flutter
│   ├── core/services/
│   │   ├── download_engine.dart  # Motor de download (Servidor Backend + Fallback Local)
│   │   ├── sharing_service.dart  # Listener para links compartilhados de outros apps
│   │   └── storage_service.dart  # Gestão de arquivos públicos e scanner na Galeria
│   ├── ui/
│   │   ├── screens/              # HomeScreen (UI principal), PlayerScreen
│   │   └── widgets/              # HistoryList, DownloadForm, DownloadOptionsSheet
│   └── main.dart              # Ponto de entrada do aplicativo Savee
├── savee-backend/             # Microserviço backend em Python para rodar no servidor doméstico (Umbrel/Docker)
│   ├── main.py                # API FastAPI com rotas de extração yt-dlp
│   ├── Dockerfile             # Imagem Debian-slim + FFmpeg + Python 3.11
│   ├── docker-compose.yml     # Configuração de container na porta 8089
│   └── requirements.txt       # Dependências (fastapi, uvicorn, yt-dlp, pydantic)
└── pubspec.yaml               # Dependências do projeto Flutter
```

---

## Funcionalidades Chave

### 1. Visibilidade Instantânea na Galeria do Android
- Os downloads são direcionados para a pasta pública `/storage/emulated/0/Movies/Savee`.
- Assim que o download é finalizado, o método nativo `StorageService.scanFileForGallery(filePath)` aciona o `MediaScannerConnection` no Kotlin ([`MainActivity.kt`](file:///c:/Users/jose.lemos/.gemini/antigravity-ide/scratch/Savee/android/app/src/main/kotlin/com/example/downtub/MainActivity.kt)).
- Isso garante que os vídeos e áudios apareçam **instantaneamente** no Google Fotos / Samsung Gallery sem necessidade de reiniciar o dispositivo.

### 2. Ações de Mídia
- O usuário pode assistir o vídeo baixado dentro do próprio app Savee ou abrir na **Galeria Nativa do Celular** com 1 clique para editar, cortar ou compartilhar.

### 3. Integração com Tailscale & Backend `yt-dlp`
- No ícone de servidor (DNS) na barra superior, o usuário pode configurar a URL privada do seu servidor Tailscale (ex: `http://100.119.111.100:8089`).
- A API retorna o streaming da mídia em tempo real e o app salva no armazenamento local.

---

## Como Rodar o Backend em um Servidor (Umbrel / Docker)

1. Acesse a pasta `savee-backend`:
   ```bash
   cd savee-backend
   ```
2. Suba o container com o Docker Compose:
   ```bash
   docker compose up -d --build
   ```
3. O servidor ficará ativo na porta `8089` (ex: `http://<IP-TAILSCALE>:8089`).

---

## Diretrizes para IAs e Desenvolvedores Futuros
- **Permissões Android**: Mantenha as permissões `READ_MEDIA_VIDEO`, `READ_MEDIA_AUDIO` e `WRITE_EXTERNAL_STORAGE` ativas no `AndroidManifest.xml`.
- **Compatibilidade Gradle**: O projeto utiliza Gradle `8.7` e AGP `8.6.0` compatível com Java 21+.
- **Padrão de Código**: Mantenha o tratamento de erros em português amigável nas interfaces do usuário.
