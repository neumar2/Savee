import os
import tempfile
from fastapi import FastAPI, HTTPException, BackgroundTasks
from fastapi.responses import FileResponse
from pydantic import BaseModel
import yt_dlp

app = FastAPI(
    title="Savee Backend API",
    description="API para extração de mídias usando yt-dlp",
    version="1.0.0"
)

class DownloadRequest(BaseModel):
    url: str
    format: str = "Video" # "Video" ou "Audio"
    quality: str = "best" # "best", "1080p", "720p", "360p"

def remove_file(path: str):
    try:
        if os.path.exists(path):
            os.remove(path)
    except Exception as e:
        print(f"Erro ao remover arquivo temporário {path}: {e}")

@app.get("/")
def read_root():
    return {"status": "ok", "service": "Savee yt-dlp Backend"}

@app.post("/api/download")
def download_media(req: DownloadRequest, background_tasks: BackgroundTasks):
    """Faz o download da mídia com yt-dlp e retorna o arquivo baixado."""
    temp_dir = tempfile.mkdtemp(prefix="savee_")
    out_template = os.path.join(temp_dir, "%(title)s.%(ext)s")

    ydl_opts = {
        'outtmpl': out_template,
        'quiet': True,
        'no_warnings': True,
    }

    if "tiktok.com" in req.url.lower():
        # TikTok sem marca d'água via yt-dlp
        ydl_opts['format'] = 'bestvideo+bestaudio/best'
    elif req.format.lower() == 'audio':
        ydl_opts['format'] = 'bestaudio/best'
        ydl_opts['postprocessors'] = [{
            'key': 'FFmpegExtractAudio',
            'preferredcodec': 'mp3',
            'preferredquality': '192',
        }]
    else:
        # Vídeo (YouTube, etc.)
        if "1080" in req.quality:
            ydl_opts['format'] = 'bestvideo[height<=1080]+bestaudio/best[height<=1080]/best'
        elif "720" in req.quality:
            ydl_opts['format'] = 'bestvideo[height<=720]+bestaudio/best[height<=720]/best'
        else:
            ydl_opts['format'] = 'bestvideo+bestaudio/best'

    try:
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            info = ydl.extract_info(req.url, download=True)
            filename = ydl.prepare_filename(info)

            if req.format.lower() == 'audio':
                filename = os.path.splitext(filename)[0] + ".mp3"

            if not os.path.exists(filename):
                files = os.listdir(temp_dir)
                if files:
                    filename = os.path.join(temp_dir, files[0])
                else:
                    raise HTTPException(status_code=500, detail="Arquivo baixado não encontrado no servidor.")

            background_tasks.add_task(remove_file, filename)

            clean_filename = os.path.basename(filename).encode('ascii', 'ignore').decode('ascii')
            if not clean_filename:
                clean_filename = "media_download"

            return FileResponse(
                path=filename,
                filename=clean_filename,
                media_type="application/octet-stream"
            )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erro ao processar mídia com yt-dlp: {str(e)}")
