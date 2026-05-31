from fastapi import FastAPI, HTTPException, Header, Form, UploadFile, File
import yt_dlp
from typing import cast, Dict, Any, Optional
from scalar_fastapi import get_scalar_api_reference  # type: ignore
from pydantic import BaseModel, Field, HttpUrl
from base_models import *
import tempfile
from os import unlink, path
import re
import json
import time
import hashlib
from collections import OrderedDict
from threading import Lock
import os 

# auth
from auth_router import router as auth_router

# vk
from vk_router import router as vk_router

# ym
from yandex_router import router as ym_router

#db
from database import connect, disconnect, get_db
from services import ensure_indexes

# acc
from account_router import router as account_router
from sync import router as sync_router

# stOYrPNGXFw - videotape

app = FastAPI()

@app.on_event("startup")
async def startup():
    await connect()
    db = await get_db()
    await ensure_indexes(db)

@app.on_event("shutdown")
async def shutdown():
    await disconnect()


CACHE_TTL_SECONDS = 604800
MAX_CACHE_SIZE = 100     # макс. количество записей

app.include_router(auth_router)
app.include_router(vk_router)
app.include_router(ym_router)
app.include_router(account_router)
app.include_router(account_router)
app.include_router(sync_router)

class SimpleCache:
    """LRU-кэш с TTL для FastAPI (in-memory, потокобезопасный)"""
    
    def __init__(self, ttl: int = CACHE_TTL_SECONDS, max_size: int = MAX_CACHE_SIZE):
        self.ttl = ttl
        self.max_size = max_size
        self._cache: OrderedDict[str, dict] = OrderedDict()
        self._timestamps: dict[str, float] = {}
        self._lock = Lock()
    
    def _generate_key(self, endpoint: str, params: dict) -> str:
        """Генерирует уникальный ключ кэша из параметров запроса"""
        sorted_params = json.dumps(params, sort_keys=True, default=str)
        raw_key = f"{endpoint}:{sorted_params}"
        return hashlib.sha256(raw_key.encode()).hexdigest()
    
    def _cleanup_expired(self):
        """Удаляет просроченные записи"""
        now = time.time()
        expired = [k for k, ts in self._timestamps.items() if now - ts > self.ttl]
        for key in expired:
            self._cache.pop(key, None)
            self._timestamps.pop(key, None)
    
    def _enforce_size_limit(self):
        """Удаляет старые записи при превышении лимита (LRU)"""
        while len(self._cache) > self.max_size:
            oldest_key = next(iter(self._cache))
            self._cache.pop(oldest_key, None)
            self._timestamps.pop(oldest_key, None)
    
    def get(self, endpoint: str, params: dict) -> Optional[Any]:
        """Получает данные из кэша"""
        with self._lock:
            self._cleanup_expired()
            key = self._generate_key(endpoint, params)
            
            if key in self._cache:
                self._cache.move_to_end(key)
                print(f"{endpoint} | params={params}")
                return self._cache[key]
            print(f"cache miss: {endpoint} | params={params}")
            return None
    
    def set(self, endpoint: str, params: dict, data: Any):
        """Сохраняет данные в кэш"""
        with self._lock:
            key = self._generate_key(endpoint, params)
            self._cleanup_expired()
            self._enforce_size_limit()
            
            self._cache[key] = data
            self._timestamps[key] = time.time()
            self._cache.move_to_end(key) 


response_cache = SimpleCache()


def is_music_track(entry: dict) -> bool:
    
    if not entry or not isinstance(entry, dict):
        return False
    
    categories = entry.get('categories') or []
    if 'Music' in categories:
        return True    

    music_video_type = entry.get('music_video_type')
    if music_video_type and music_video_type != 'NOT_MUSIC_VIDEO':
        return True
    
    channel_id = entry.get('channel_id') or ''
    uploader_id = entry.get('uploader_id') or ''
    if 'Topic' in channel_id or 'Topic' in uploader_id:
        return True
    
    has_audio_meta = bool(
        entry.get('artist') or 
        entry.get('album') or 
        entry.get('track') or
        entry.get('album_artist')
    )

    is_live = entry.get('is_live') or entry.get('live_status') == 'is_live'
    has_video = entry.get('vcodec') and entry.get('vcodec') != 'none'
    
    requested_format = entry.get('format') or ''
    is_audio_only = 'audio only' in requested_format or requested_format.startswith('ba')
    
    if is_live:
        return False
    
    if has_audio_meta and not has_video:
        return True
    
    if has_audio_meta and is_audio_only:
        return True
    
    # Фолбэк: если есть и артист, и альбом — считаем музыкой
    if entry.get('artist') and entry.get('album'):
        return True
    
    return False


def get_original_thumbnail_url(thumbnail_url: str) -> str:
    if not thumbnail_url or 'googleusercontent.com' not in thumbnail_url:
        return thumbnail_url
    
    base_url = thumbnail_url.split('=')[0]
    return f"{base_url}=s0"


def filter_thumbnails_to_sizes(thumbnails: list[dict], max_thumbnails: int = 3) -> list[dict]:
    if not thumbnails:
        return []
    
    valid_thumbs = [
        t for t in thumbnails
        if t.get('url') and (t.get('width') or t.get('height'))
    ]
    
    if not valid_thumbs:
        return []
    
    for thumb in valid_thumbs:
        url = thumb.get('url', '')
        if 'googleusercontent.com' in url and '=s0' not in url:
            thumb['original_url'] = thumb['url']
            thumb['url'] = get_original_thumbnail_url(url)
            thumb['width'] = None
            thumb['height'] = None
    
    def thumb_score(t: dict) -> float:
        w, h = t.get('width') or 0, t.get('height') or 0
        is_square = 1 if w == h and w > 0 else 0
        area = w * h
        pref = t.get('preference') or 0
        return (area * 0.8) + (pref * 100) + (is_square * 10000)
    
    sorted_thumbs = sorted(valid_thumbs, key=thumb_score, reverse=True)
    
    if len(sorted_thumbs) <= max_thumbnails:
        return sorted_thumbs[::-1]
    
    small = next((t for t in sorted_thumbs if t.get('width') == t.get('height') and t.get('width', 0) <= 300), sorted_thumbs[-1])
    large = next((t for t in sorted_thumbs if t.get('width') == t.get('height') and t.get('width', 0) >= 1000), sorted_thumbs[0])
    medium = sorted_thumbs[len(sorted_thumbs) // 2]
    
    return [small, medium, large]


def filter_formats_to_qualities(formats: list[dict], max_formats: int = 3) -> list[dict]:

    if not formats:
        return []
    
    valid_formats = [
        f for f in formats
        if f.get('vcodec') != 'none' or f.get('acodec') != 'none'
    ]
    
    if not valid_formats:
        return []
    
    def quality_score(fmt: dict) -> float:
        height = fmt.get('height') or 0
        width = fmt.get('width') or 0
        tbr = fmt.get('tbr') or 0
        fps = fmt.get('fps') or 0
        return (height * width) + (tbr * 100) + (fps * 1000)
    
    sorted_formats = sorted(valid_formats, key=quality_score, reverse=True)
    
    if len(sorted_formats) <= max_formats:
        return sorted_formats
    
    selected = []
    selected.append(sorted_formats[0])
    mid_idx = len(sorted_formats) // 2
    selected.append(sorted_formats[mid_idx])
    selected.append(sorted_formats[-1])

    return [selected[2], selected[1], selected[0]]


def get_ydl_opts_with_cookies(cookie_string: Optional[str]) -> tuple[dict, str]:
    
    cookies_clean = re.sub(r'\s+[A-Z][A-Za-z-]*:.*$', '', cookie_string.strip())  # type: ignore
    
    tmp = tempfile.NamedTemporaryFile(mode='w', suffix='.txt', delete=False, encoding='utf-8')
    
    tmp.write("# Netscape HTTP Cookie File\n")
    tmp.write("# https://curl.haxx.se/docs/http-cookies.html\n\n")
    
    for cookie in cookies_clean.split(';'):
        cookie = cookie.strip()
        if '=' not in cookie:
            continue
        name, value = cookie.split('=', 1)
        name, value = name.strip(), value.strip()
        
        if not name or not value:
            continue
        
        secure = "TRUE" if name.startswith('__Secure-') or name.startswith('__Host-') else "FALSE"
        
        tmp.write(f".youtube.com\tTRUE\t/\t{secure}\t0\t{name}\t{value}\n")
    
    tmp.close()
    
    return {
        'quiet': True,
        'no_warnings': True,
       # 'extract_flat': True,
	'extract_flat': 'in_playlist',
        'ignoreerrors': True,
	'skip_download': True,
    }, tmp.name

@app.get("/api/yt/song")
async def extracting_info(request: StreamRequest):
    
    video_id = request.video_id
    media_format = request.format

    cache_params = {"video_id": video_id, "format": media_format}
    cached = response_cache.get("song", cache_params)
    if cached is not None:
        return cached

    # Try different player clients or formats on failure to bypass cloud/IP blocks
    player_clients_to_try = [
        ['ios', 'android'],
        ['web_music', 'android_music'],
        ['web', 'default']
    ]
    
    info = None
    last_err = None
    
    for clients in player_clients_to_try:
        try:
            ydl_opts: Dict[str, Any] = {
                'format': media_format or 'bestaudio[ext=m4a]/bestaudio[acodec!=opus]/bestaudio/best',
                'quiet': True,
                'no_warnings': True,
                'extract_flat': False,
                'extractor_args': {
                    'youtube': {
                        'player_client': clients,
                    }
                }
            }
            with yt_dlp.YoutubeDL(cast(Any, ydl_opts)) as ydl:
                info = ydl.extract_info(f"https://youtube.com/watch?v={video_id}", download=False)
            if info:
                break
        except Exception as e:
            last_err = e
            continue

    if not info:
        try:
            ydl_opts = {
                'quiet': True,
                'no_warnings': True,
                'extract_flat': False,
            }
            with yt_dlp.YoutubeDL(cast(Any, ydl_opts)) as ydl:
                info = ydl.extract_info(f"https://youtube.com/watch?v={video_id}", download=False)
        except Exception as e:
            last_err = e

    if not info:
        raise HTTPException(
            status_code=500,
            detail=f"Failed to extract track metadata. yt-dlp error: {str(last_err)}"
        )
    
    response = {
        # === ИДЕНТИФИКАТОРЫ И ССЫЛКИ ===
        "id": info.get("id"),
        "title": info.get("title"),
        "alt_title": info.get("alt_title"),
        "description": info.get("description"),
        "webpage_url": info.get("webpage_url"),
        "webpage_url_basename": info.get("webpage_url_basename"),
        "original_url": info.get("original_url"),
        "display_id": info.get("display_id"),
        "extractor": info.get("extractor"),
        "extractor_key": info.get("extractor_key"),
        "ie_key": info.get("ie_key"),
        
        # === АВТОР / КАНАЛ ===
        "uploader": info.get("uploader"),
        "uploader_id": info.get("uploader_id"),
        "uploader_url": info.get("uploader_url"),
        "channel": info.get("channel"),
        "channel_id": info.get("channel_id"),
        "channel_url": info.get("channel_url"),
        "channel_follower_count": info.get("channel_follower_count"),
        "channel_is_verified": info.get("channel_is_verified"),
        
        # === ДАТЫ И ВРЕМЯ ===
        "upload_date": info.get("upload_date"),
        "timestamp": info.get("timestamp"),
        "release_timestamp": info.get("release_timestamp"),
        "modified_timestamp": info.get("modified_timestamp"),
        "created_at": info.get("created_at"),
        "mtime": info.get("mtime"),
        
        # === ДЛИТЕЛЬНОСТЬ И СТАТУС ===
        "duration": info.get("duration"),
        "duration_string": info.get("duration_string"),
        "live_status": info.get("live_status"),
        "was_live": info.get("was_live"),
        "playable_in_embed": info.get("playable_in_embed"),
        "is_live": info.get("is_live"),
        "was_live_flag": info.get("was_live_flag"),
        "consecutive_id": info.get("consecutive_id"),
        
        # === СТАТИСТИКА ===
        "view_count": info.get("view_count"),
        "like_count": info.get("like_count"),
        "dislike_count": info.get("dislike_count"),
        "repost_count": info.get("repost_count"),
        "comment_count": info.get("comment_count"),
        "average_rating": info.get("average_rating"),
        
        # === МИНИАТЮРЫ ===
        "thumbnail": info.get("thumbnail"),
        "thumbnails": filter_thumbnails_to_sizes(info.get("thumbnails") or []),
        "thumbnail_id": info.get("thumbnail_id"),
        
        # === СЕРИИ / ЭПИЗОДЫ / СЕЗОНЫ ===
        "series": info.get("series"),
        "series_id": info.get("series_id"),
        "season": info.get("season"),
        "season_id": info.get("season_id"),
        "season_number": info.get("season_number"),
        "episode": info.get("episode"),
        "episode_id": info.get("episode_id"),
        "episode_number": info.get("episode_number"),
        "season_number_string": info.get("season_number_string"),
        "episode_number_string": info.get("episode_number_string"),
        
        # === МЕДИА-ХАРАКТЕРИСТИКИ ===
        "url": info.get("url"),
        "streamUrl": info.get("url"),
        "ext": info.get("ext"),
        "format": info.get("format"),
        "format_id": info.get("format_id"),
        "format_note": info.get("format_note"),
        "protocol": info.get("protocol"),
        "acodec": info.get("acodec"),
        "vcodec": info.get("vcodec"),
        "abr": info.get("abr"),
        "vbr": info.get("vbr"),
        "tbr": info.get("tbr"),
        "width": info.get("width"),
        "height": info.get("height"),
        "resolution": info.get("resolution"),
        "fps": info.get("fps"),
        "fps_approx": info.get("fps_approx"),
        "asr": info.get("asr"),
        "filesize": info.get("filesize"),
        "filesize_approx": info.get("filesize_approx"),
        "container": info.get("container"),
        "dynamic_range": info.get("dynamic_range"),
        "has_drm": info.get("has_drm"),
        "source_preference": info.get("source_preference"),
        
        # === АУДИО-МЕТАДАННЫЕ ===
        "artist": info.get("artist"),
        "track": info.get("track"),
        "album": info.get("album"),
        "album_artist": info.get("album_artist"),
        "album_type": info.get("album_type"),
        "artists": info.get("artists"),
        "composer": info.get("composer"),
        "genre": info.get("genre"),
        "release_year": info.get("release_year"),
        "track_id": info.get("track_id"),
        "track_number": info.get("track_number"),
        "disc_number": info.get("disc_number"),
        "compilation": info.get("compilation"),
        
        # === ДОСТУПНОСТЬ И ОГРАНИЧЕНИЯ ===
        "availability": info.get("availability"),
        "age_limit": info.get("age_limit"),
        "age_restricted": info.get("age_restricted"),
        "was_restricted": info.get("was_restricted"),
        "license": info.get("license"),
        "creator": info.get("creator"),
        
        # === КАТЕГОРИИ И ТЕГИ ===
        "categories": info.get("categories"),
        "tags": info.get("tags"),
        "language": info.get("language"),
        "languages": info.get("languages"),
        "subtitles": info.get("subtitles"),
        
        # === ГЕО-ОГРАНИЧЕНИЯ ===
        "geo_countries": info.get("geo_countries"),
        "geo_bypass": info.get("geo_bypass"),
        "geo_bypass_country": info.get("geo_bypass_country"),
        "geo_bypass_ip_block": info.get("geo_bypass_ip_block"),
        
        # === ГЛАВЫ И СТРУКТУРА ===
        "chapters": info.get("chapters"),
        "chapter": info.get("chapter"),
        "chapter_number": info.get("chapter_number"),
        "chapter_id": info.get("chapter_id"),
        "heatmap": info.get("heatmap"),
        
        # === ДОПОЛНИТЕЛЬНЫЕ ПОЛЯ ===
        "playlist": info.get("playlist"),
        "playlist_id": info.get("playlist_id"),
        "playlist_index": info.get("playlist_index"),
        "playlist_count": info.get("playlist_count"),
        "playlist_title": info.get("playlist_title"),
        "playlist_uploader": info.get("playlist_uploader"),
        "playlist_uploader_id": info.get("playlist_uploader_id"),
        "n_entries": info.get("n_entries"),
        "requested_subtitles": info.get("requested_subtitles"),
        "_has_drm": info.get("_has_drm"),
        "fulltitle": info.get("fulltitle"),
        "new_title": info.get("new_title"),
        "sort_order": info.get("sort_order"),
        
        # === ФОРМАТЫ ===
        "formats": info.get("formats"),
        "requested_formats": info.get("requested_formats"),
        
        # === КОММЕНТАРИИ ===
        "comments": info.get("comments"),
        
        # === ТЕХНИЧЕСКИЕ ПОЛЯ ===
        "_type": info.get("_type"),
        "_version": info.get("_version"),
        "epoch": info.get("epoch"),
        "http_headers": info.get("http_headers"),
        "ytdl_hooks": info.get("ytdl_hooks"),
        
        # === ПЛЕЙЛИСТ / МНОЖЕСТВЕННОЕ ВИДЕО ===
        "entries": info.get("entries"),
        "multi_video": info.get("multi_video"),
    }
    
    response_cache.set("song", cache_params, response)
    
    return response


@app.post("/api/yt/playlist")
async def extracting_playlists(request: PlaylistRequest):
    
    # проверка кэша
    cache_params = {"playlist_id": request.playlist_id, "format": request.format}
    cached = response_cache.get("playlist", cache_params)
    if cached is not None:
        return cached
            

    if not request:
        raise HTTPException(status_code=400, detail="Cookies required")
    
    try:
        ydl_opts = {
            'quiet': True,
            'no_warnings': True,
            'extract_flat': 'in_playlist', 
 	    'ignoreerrors': True,
    	    'skip_download': True,
            'format': request.format,
        'extractor_args': {
                'youtube': {
                    'player_client': ['web_music', 'android_music'],
                }
            },
        }
        with yt_dlp.YoutubeDL(cast(Any, ydl_opts)) as ydl:
            result = ydl.extract_info(f"https://music.youtube.com/playlist?list={request.playlist_id}", download=False)
            playlist = []
            skipped = 0
            
            for entry in (result.get('entries') or []):
                if not entry or not isinstance(entry, dict):
                    continue
                
                if entry.get('ie_key') == 'YouTube' and entry.get('title') == '[Unavailable]':
                    skipped += 1
                    continue
                
                if entry.get("availability") in ["private", "unlisted", "needs_auth"]:
                    continue
                
                track_data = {
                    # === ИДЕНТИФИКАТОРЫ И ССЫЛКИ ===
                    "id": entry.get("id"),
                    "title": entry.get("title"),
                    "alt_title": entry.get("alt_title"),
                    "description": entry.get("description"),
                    "webpage_url": entry.get("webpage_url"),
                    "webpage_url_basename": entry.get("webpage_url_basename"),
                    "original_url": entry.get("original_url"),
                    "display_id": entry.get("display_id"),
                    "extractor": entry.get("extractor"),
                    "extractor_key": entry.get("extractor_key"),
                    "ie_key": entry.get("ie_key"),
                    
                    # === АВТОР / КАНАЛ ===
                    "uploader": entry.get("uploader"),
                    "uploader_id": entry.get("uploader_id"),
                    "uploader_url": entry.get("uploader_url"),
                    "channel": entry.get("channel"),
                    "channel_id": entry.get("channel_id"),
                    "channel_url": entry.get("channel_url"),
                    "channel_follower_count": entry.get("channel_follower_count"),
                    "channel_is_verified": entry.get("channel_is_verified"),
                    
                    # === ДАТЫ И ВРЕМЯ ===
                    "upload_date": entry.get("upload_date"),
                    "timestamp": entry.get("timestamp"),
                    "release_timestamp": entry.get("release_timestamp"),
                    "modified_timestamp": entry.get("modified_timestamp"),
                    "created_at": entry.get("created_at"),
                    "mtime": entry.get("mtime"),
                    
                    # === ДЛИТЕЛЬНОСТЬ И СТАТУС ===
                    "duration": entry.get("duration"),
                    "duration_string": entry.get("duration_string"),
                    "live_status": entry.get("live_status"),
                    "was_live": entry.get("was_live"),
                    "playable_in_embed": entry.get("playable_in_embed"),
                    "is_live": entry.get("is_live"),
                    "was_live_flag": entry.get("was_live_flag"),
                    "consecutive_id": entry.get("consecutive_id"),
                    
                    # === СТАТИСТИКА ===
                    "view_count": entry.get("view_count"),
                    "like_count": entry.get("like_count"),
                    "dislike_count": entry.get("dislike_count"),
                    "repost_count": entry.get("repost_count"),
                    "comment_count": entry.get("comment_count"),
                    "average_rating": entry.get("average_rating"),
                    
                    # === МИНИАТЮРЫ ===
                    "thumbnail": entry.get("thumbnail"),
                    "thumbnails": filter_thumbnails_to_sizes(entry.get("thumbnails") or []),
                    "thumbnail_id": entry.get("thumbnail_id"),
                    
                    # === СЕРИИ / ЭПИЗОДЫ / СЕЗОНЫ ===
                    "series": entry.get("series"),
                    "series_id": entry.get("series_id"),
                    "season": entry.get("season"),
                    "season_id": entry.get("season_id"),
                    "season_number": entry.get("season_number"),
                    "episode": entry.get("episode"),
                    "episode_id": entry.get("episode_id"),
                    "episode_number": entry.get("episode_number"),
                    "season_number_string": entry.get("season_number_string"),
                    "episode_number_string": entry.get("episode_number_string"),
                    
                    # === МЕДИА-ХАРАКТЕРИСТИКИ ===
                    "url": entry.get("url"),
                    "streamUrl": entry.get("url"),
                    "ext": entry.get("ext"),
                    "format": entry.get("format"),
                    
                    # === АУДИО-МЕТАДАННЫЕ ===
                    "artist": entry.get("artist"),
                    "track": entry.get("track"),
                    "album": entry.get("album"),
                    "album_artist": entry.get("album_artist"),
                    "album_type": entry.get("album_type"),
                    "artists": entry.get("artists"),
                    "composer": entry.get("composer"),
                    "genre": entry.get("genre"),
                    "release_year": entry.get("release_year"),
                    "track_id": entry.get("track_id"),
                    "track_number": entry.get("track_number"),
                    "disc_number": entry.get("disc_number"),
                    "compilation": entry.get("compilation"),
                    
                    # === ДОСТУПНОСТЬ И ОГРАНИЧЕНИЯ ===
                    "availability": entry.get("availability"),
                    "age_limit": entry.get("age_limit"),
                    "age_restricted": entry.get("age_restricted"),
                    "was_restricted": entry.get("was_restricted"),
                    "license": entry.get("license"),
                    "creator": entry.get("creator"),
                    
                    # === КАТЕГОРИИ И ТЕГИ ===
                    "categories": entry.get("categories"),
                    "tags": entry.get("tags"),
                    "language": entry.get("language"),
                    "languages": entry.get("languages"),
                    "subtitles": entry.get("subtitles"),
                    
                    # === ГЕО-ОГРАНИЧЕНИЯ ===
                    "geo_countries": entry.get("geo_countries"),
                    "geo_bypass": entry.get("geo_bypass"),
                    "geo_bypass_country": entry.get("geo_bypass_country"),
                    "geo_bypass_ip_block": entry.get("geo_bypass_ip_block"),
                    
                    # === ДОПОЛНИТЕЛЬНЫЕ ПОЛЯ ===
                    "playlist": entry.get("playlist"),
                    "playlist_id": entry.get("playlist_id"),
                    "playlist_index": entry.get("playlist_index"),
                    "playlist_count": entry.get("playlist_count"),
                    "playlist_title": entry.get("playlist_title"),
                    "playlist_uploader": entry.get("playlist_uploader"),
                    "playlist_uploader_id": entry.get("playlist_uploader_id"),
                    "n_entries": entry.get("n_entries"),
                    "requested_subtitles": entry.get("requested_subtitles"),
                    "_has_drm": entry.get("_has_drm"),
                    "fulltitle": entry.get("fulltitle"),
                    "new_title": entry.get("new_title"),
                    "sort_order": entry.get("sort_order"),
                    
                    # === ФОРМАТЫ ===
                    "formats": filter_formats_to_qualities(entry.get("formats") or []),
                    "requested_formats": entry.get("requested_formats"),
                    
                    # === КОММЕНТАРИИ ===
                    "comments": entry.get("comments"),
                    
                    # === ТЕХНИЧЕСКИЕ ПОЛЯ ===
                    "_type": entry.get("_type"),
                    "_version": entry.get("_version"),
                    "epoch": entry.get("epoch"),
                    "http_headers": entry.get("http_headers"),
                    "ytdl_hooks": entry.get("ytdl_hooks"),
                    
                    # === ПЛЕЙЛИСТ / МНОЖЕСТВЕННОЕ ВИДЕО ===
                    "entries": entry.get("entries"),
                    "multi_video": entry.get("multi_video"),
                }
                playlist.append({"tracks": [track_data]})
            
            response = {
                "success": True,
                "playlist_id": request.playlist_id,
                "title": result.get("title"),
                "video_count": result.get("playlist_count"),
                "videos_returned": len(playlist),
                "videos_skipped": skipped,
                "playlist": playlist,
            }
            
            response_cache.set("playlist", cache_params, response)
    
            
            return response
        
    except Exception as err:
        print(f"playlist extraction err: {err}")
        raise HTTPException(status_code=500, detail=str(err))


@app.post('/api/yt/playlistAuth')
async def playlist_auth(
    playlist_id: str = Form(...),
    format: str = Form(default='ba'),
    cookies: UploadFile = File(...)
):
    cache_params = {
        "playlist_id": playlist_id,
        "format": format,
        "cookies": await cookies.read()  
    }
    await cookies.seek(0) 
    
    cached = response_cache.get("playlist_auth", cache_params)
    if cached is not None:
        return cached
    
    content = await cookies.read()
    cookies_str = content.decode('utf-8')
    
    if not cookies_str.strip() or '# Netscape HTTP Cookie File' not in cookies_str:
        raise HTTPException(
            status_code=400, 
            detail="Invalid cookie file format. Expected Netscape HTTP Cookie File."
        )
    
    tmp_path = None
    try:
        with tempfile.NamedTemporaryFile(
            mode="w",
            suffix=".txt",
            delete=False,
            prefix="yt_cookies_"
        ) as tmp:
            tmp.write(cookies_str)
            tmp_path = tmp.name
        
        ydl_opts = {
            'extract_entries': False,
            'cookiefile': tmp_path,
            'quiet': True,
            'no_warnings': True,
            'ignoreerrors': True,
            'skip_download': True,
            'format': format,
            'extract_flat': 'in_playlist',
            'extractor_args' : {
                'youtube': {
                        'player_client': ['web_music', 'android_music'],            
                    }
            },
        }
        
        playlist_url = f"https://music.youtube.com/playlist?list={playlist_id}"
        
        with yt_dlp.YoutubeDL(cast(Any, ydl_opts)) as ydl:
            result = ydl.extract_info(playlist_url, download=False)
            
            if not result:
                raise HTTPException(
                    status_code=404, 
                    detail=f"Playlist '{playlist_id}' not found or inaccessible"
                )
        
            playlist_items = []
            skipped = 0
            entries = result.get('entries') or []
            
            for entry in entries:
                if not entry or not isinstance(entry, dict):
                    continue
                    
                # if not is_music_track(entry):
                #     skipped += 1
                #     continue
                
                if entry.get('ie_key') == 'YouTube' and entry.get('title') == '[Unavailable]':
                    skipped += 1
                    continue
                
                if entry.get("availability") in ["private", "unlisted", "needs_auth"]:
                    skipped += 1
                    continue
                
                track_data = {
                    # === ИДЕНТИФИКАТОРЫ И ССЫЛКИ ===
                    "id": entry.get("id"),
                    "title": entry.get("title"),
                    "alt_title": entry.get("alt_title"),
                    "description": entry.get("description"),
                    "webpage_url": entry.get("webpage_url"),
                    "webpage_url_basename": entry.get("webpage_url_basename"),
                    "original_url": entry.get("original_url"),
                    "display_id": entry.get("display_id"),
                    "extractor": entry.get("extractor"),
                    "extractor_key": entry.get("extractor_key"),
                    "ie_key": entry.get("ie_key"),
                    
                    # === АВТОР / КАНАЛ ===
                    "uploader": entry.get("uploader"),
                    "uploader_id": entry.get("uploader_id"),
                    "uploader_url": entry.get("uploader_url"),
                    "channel": entry.get("channel"),
                    "channel_id": entry.get("channel_id"),
                    "channel_url": entry.get("channel_url"),
                    "channel_follower_count": entry.get("channel_follower_count"),
                    "channel_is_verified": entry.get("channel_is_verified"),
                    
                    # === ДАТЫ И ВРЕМЯ ===
                    "upload_date": entry.get("upload_date"),
                    "timestamp": entry.get("timestamp"),
                    "release_timestamp": entry.get("release_timestamp"),
                    "modified_timestamp": entry.get("modified_timestamp"),
                    "created_at": entry.get("created_at"),
                    "mtime": entry.get("mtime"),
                    
                    # === ДЛИТЕЛЬНОСТЬ И СТАТУС ===
                    "duration": entry.get("duration"),
                    "duration_string": entry.get("duration_string"),
                    "live_status": entry.get("live_status"),
                    "was_live": entry.get("was_live"),
                    "playable_in_embed": entry.get("playable_in_embed"),
                    "is_live": entry.get("is_live"),
                    "was_live_flag": entry.get("was_live_flag"),
                    "consecutive_id": entry.get("consecutive_id"),
                    
                    # === СТАТИСТИКА ===
                    "view_count": entry.get("view_count"),
                    "like_count": entry.get("like_count"),
                    "dislike_count": entry.get("dislike_count"),
                    "repost_count": entry.get("repost_count"),
                    "comment_count": entry.get("comment_count"),
                    "average_rating": entry.get("average_rating"),
                    
                    # === МИНИАТЮРЫ ===
                    "thumbnail": entry.get("thumbnail"),
                    "thumbnails": filter_thumbnails_to_sizes(entry.get("thumbnails") or []),
                    "thumbnail_id": entry.get("thumbnail_id"),
                    
                    # === СЕРИИ / ЭПИЗОДЫ ===
                    "series": entry.get("series"),
                    "series_id": entry.get("series_id"),
                    "season": entry.get("season"),
                    "season_id": entry.get("season_id"),
                    "season_number": entry.get("season_number"),
                    "episode": entry.get("episode"),
                    "episode_id": entry.get("episode_id"),
                    "episode_number": entry.get("episode_number"),
                    "season_number_string": entry.get("season_number_string"),
                    "episode_number_string": entry.get("episode_number_string"),
                    
                    # === МЕДИА-ХАРАКТЕРИСТИКИ ===
                    "url": entry.get("url"),
                    "streamUrl": entry.get("url"),
                    "ext": entry.get("ext"),
                    "format": entry.get("format"),
                    
                    # === АУДИО-МЕТАДАННЫЕ ===
                    "artist": entry.get("artist"),
                    "track": entry.get("track"),
                    "album": entry.get("album"),
                    "album_artist": entry.get("album_artist"),
                    "album_type": entry.get("album_type"),
                    "artists": entry.get("artists"),
                    "composer": entry.get("composer"),
                    "genre": entry.get("genre"),
                    "release_year": entry.get("release_year"),
                    "track_id": entry.get("track_id"),
                    "track_number": entry.get("track_number"),
                    "disc_number": entry.get("disc_number"),
                    "compilation": entry.get("compilation"),
                    
                    # === ДОСТУПНОСТЬ ===
                    "availability": entry.get("availability"),
                    "age_limit": entry.get("age_limit"),
                    "age_restricted": entry.get("age_restricted"),
                    "was_restricted": entry.get("was_restricted"),
                    "license": entry.get("license"),
                    "creator": entry.get("creator"),
                    
                    # === КАТЕГОРИИ И ТЕГИ ===
                    "categories": entry.get("categories"),
                    "tags": entry.get("tags"),
                    "language": entry.get("language"),
                    "languages": entry.get("languages"),
                    "subtitles": entry.get("subtitles"),
                    
                    # === ГЕО-ОГРАНИЧЕНИЯ ===
                    "geo_countries": entry.get("geo_countries"),
                    "geo_bypass": entry.get("geo_bypass"),
                    "geo_bypass_country": entry.get("geo_bypass_country"),
                    "geo_bypass_ip_block": entry.get("geo_bypass_ip_block"),
                    
                    # === ПЛЕЙЛИСТ-МЕТАДАННЫЕ ===
                    "playlist": entry.get("playlist"),
                    "playlist_id": entry.get("playlist_id"),
                    "playlist_index": entry.get("playlist_index"),
                    "playlist_count": entry.get("playlist_count"),
                    "playlist_title": entry.get("playlist_title"),
                    "playlist_uploader": entry.get("playlist_uploader"),
                    "playlist_uploader_id": entry.get("playlist_uploader_id"),
                    "n_entries": entry.get("n_entries"),
                    
                    # === ТЕХНИЧЕСКИЕ ПОЛЯ ===
                    "requested_subtitles": entry.get("requested_subtitles"),
                    "_has_drm": entry.get("_has_drm"),
                    "fulltitle": entry.get("fulltitle"),
                    "new_title": entry.get("new_title"),
                    "sort_order": entry.get("sort_order"),
                    "formats": filter_formats_to_qualities(entry.get("formats") or []),
                    "requested_formats": entry.get("requested_formats"),
                    "comments": entry.get("comments"),
                    "_type": entry.get("_type"),
                    "_version": entry.get("_version"),
                    "epoch": entry.get("epoch"),
                    "http_headers": entry.get("http_headers"),
                    "ytdl_hooks": entry.get("ytdl_hooks"),
                    "entries": entry.get("entries"),
                    "multi_video": entry.get("multi_video"),
                }
                playlist_items.append({"tracks": [track_data]})
            

            response = {
                "success": True,
                "playlist_id": playlist_id,
                "title": result.get("title", "Unknown playlist"),
                "video_count": result.get("playlist_count", len(playlist_items)),
                "videos_returned": len(playlist_items),
                "videos_skipped": skipped,
                "playlist": playlist_items,
            }
            
            response_cache.set("playlist_auth", cache_params, response)
            
            return response
        
    except Exception as err:
        print(f"playlist extraction err: {err}")
        raise HTTPException(status_code=500, detail=str(err))
    
    finally: 
        if tmp_path and os.path.exists(tmp_path):
            try:
                os.unlink(tmp_path)
            except OSError as e:
                print(f"⚠️ Failed to delete temp cookie file: {e}")

    
@app.post('/api/yt/playlists')
async def playlists(cookies: UploadFile = File(...)):
        
    # проверка кэкэша
    cache_params = {"cookies": cookies}
    cached = response_cache.get("playlist", cache_params)
    if cached is not None:
        return cached
    
    content = await cookies.read()
    cookies_str = content.decode('utf-8')
    
    with tempfile.NamedTemporaryFile(
        mode="w",
        suffix=".txt",
        delete=False,
        prefix="yt_cookies_"
    ) as tmp:
        tmp.write(cookies_str)   # type:ignore
        tmp_path = tmp.name

    if not cookies:
        raise HTTPException(status_code=400, detail="Cookies required")
    
    try:
        ydl_opts = {
            'cookiefile' : tmp_path, # cookie 
            'quiet': False,
            'no_warnings': True,
            'extract_flat': 'in_playlist', 
 	    'ignoreerrors': True,
    	    'skip_download': True,
            'format': "ba",
        'extractor_args': {
            'youtube': {
                'player_client': ['web_music', 'android_music'],
                }
            },
        }
        
        with yt_dlp.YoutubeDL(cast(Any, ydl_opts)) as ydl:
            result = ydl.extract_info(f"https://music.youtube.com/feed/playlists", download=False)
            playlist = []
            skipped = 0
            
            for entry in (result.get('entries') or []):
                if not entry or not isinstance(entry, dict):
                    continue
                
                # if not is_music_track(entry):
                #     skipped += 1
                #     continue

                if entry.get('ie_key') == 'YouTube' and entry.get('title') == '[Unavailable]':
                    skipped += 1
                    continue
                
                if entry.get("availability") in ["private", "unlisted", "needs_auth"]:
                    continue
                
                track_data = {
                    # === ИДЕНТИФИКАТОРЫ И ССЫЛКИ ===
                    "id": entry.get("id"),
                    "title": entry.get("title"),
                    "alt_title": entry.get("alt_title"),
                    "description": entry.get("description"),
                    "webpage_url": entry.get("webpage_url"),
                    "webpage_url_basename": entry.get("webpage_url_basename"),
                    "original_url": entry.get("original_url"),
                    "display_id": entry.get("display_id"),
                    "extractor": entry.get("extractor"),
                    "extractor_key": entry.get("extractor_key"),
                    "ie_key": entry.get("ie_key"),
                    
                    # === АВТОР / КАНАЛ ===
                    "uploader": entry.get("uploader"),
                    "uploader_id": entry.get("uploader_id"),
                    "uploader_url": entry.get("uploader_url"),
                    "channel": entry.get("channel"),
                    "channel_id": entry.get("channel_id"),
                    "channel_url": entry.get("channel_url"),
                    "channel_follower_count": entry.get("channel_follower_count"),
                    "channel_is_verified": entry.get("channel_is_verified"),
                    
                    # === ДАТЫ И ВРЕМЯ ===
                    "upload_date": entry.get("upload_date"),
                    "timestamp": entry.get("timestamp"),
                    "release_timestamp": entry.get("release_timestamp"),
                    "modified_timestamp": entry.get("modified_timestamp"),
                    "created_at": entry.get("created_at"),
                    "mtime": entry.get("mtime"),
                    
                    # === ДЛИТЕЛЬНОСТЬ И СТАТУС ===
                    "duration": entry.get("duration"),
                    "duration_string": entry.get("duration_string"),
                    "live_status": entry.get("live_status"),
                    "was_live": entry.get("was_live"),
                    "playable_in_embed": entry.get("playable_in_embed"),
                    "is_live": entry.get("is_live"),
                    "was_live_flag": entry.get("was_live_flag"),
                    "consecutive_id": entry.get("consecutive_id"),
                    
                    # === СТАТИСТИКА ===
                    "view_count": entry.get("view_count"),
                    "like_count": entry.get("like_count"),
                    "dislike_count": entry.get("dislike_count"),
                    "repost_count": entry.get("repost_count"),
                    "comment_count": entry.get("comment_count"),
                    "average_rating": entry.get("average_rating"),
                    
                    # === МИНИАТЮРЫ ===
                    "thumbnail": entry.get("thumbnail"),
                    "thumbnails": filter_thumbnails_to_sizes(entry.get("thumbnails") or []),
                    "thumbnail_id": entry.get("thumbnail_id"),
                    
                    # === СЕРИИ / ЭПИЗОДЫ / СЕЗОНЫ ===
                    "series": entry.get("series"),
                    "series_id": entry.get("series_id"),
                    "season": entry.get("season"),
                    "season_id": entry.get("season_id"),
                    "season_number": entry.get("season_number"),
                    "episode": entry.get("episode"),
                    "episode_id": entry.get("episode_id"),
                    "episode_number": entry.get("episode_number"),
                    "season_number_string": entry.get("season_number_string"),
                    "episode_number_string": entry.get("episode_number_string"),
                    
                    # === МЕДИА-ХАРАКТЕРИСТИКИ ===
                    "url": entry.get("url"),
                    "streamUrl": entry.get("url"),
                    "ext": entry.get("ext"),
                    "format": entry.get("format"),
                    
                    # === АУДИО-МЕТАДАННЫЕ ===
                    "artist": entry.get("artist"),
                    "track": entry.get("track"),
                    "album": entry.get("album"),
                    "album_artist": entry.get("album_artist"),
                    "album_type": entry.get("album_type"),
                    "artists": entry.get("artists"),
                    "composer": entry.get("composer"),
                    "genre": entry.get("genre"),
                    "release_year": entry.get("release_year"),
                    "track_id": entry.get("track_id"),
                    "track_number": entry.get("track_number"),
                    "disc_number": entry.get("disc_number"),
                    "compilation": entry.get("compilation"),
                    
                    # === ДОСТУПНОСТЬ И ОГРАНИЧЕНИЯ ===
                    "availability": entry.get("availability"),
                    "age_limit": entry.get("age_limit"),
                    "age_restricted": entry.get("age_restricted"),
                    "was_restricted": entry.get("was_restricted"),
                    "license": entry.get("license"),
                    "creator": entry.get("creator"),
                    
                    # === КАТЕГОРИИ И ТЕГИ ===
                    "categories": entry.get("categories"),
                    "tags": entry.get("tags"),
                    "language": entry.get("language"),
                    "languages": entry.get("languages"),
                    "subtitles": entry.get("subtitles"),
                    
                    # === ГЕО-ОГРАНИЧЕНИЯ ===
                    "geo_countries": entry.get("geo_countries"),
                    "geo_bypass": entry.get("geo_bypass"),
                    "geo_bypass_country": entry.get("geo_bypass_country"),
                    "geo_bypass_ip_block": entry.get("geo_bypass_ip_block"),
                    
                    # === ДОПОЛНИТЕЛЬНЫЕ ПОЛЯ ===
                    "playlist": entry.get("playlist"),
                    "playlist_id": entry.get("playlist_id"),
                    "playlist_index": entry.get("playlist_index"),
                    "playlist_count": entry.get("playlist_count"),
                    "playlist_title": entry.get("playlist_title"),
                    "playlist_uploader": entry.get("playlist_uploader"),
                    "playlist_uploader_id": entry.get("playlist_uploader_id"),
                    "n_entries": entry.get("n_entries"),
                    "requested_subtitles": entry.get("requested_subtitles"),
                    "_has_drm": entry.get("_has_drm"),
                    "fulltitle": entry.get("fulltitle"),
                    "new_title": entry.get("new_title"),
                    "sort_order": entry.get("sort_order"),
                    
                    # === ФОРМАТЫ ===
                    "formats": filter_formats_to_qualities(entry.get("formats") or []),
                    "requested_formats": entry.get("requested_formats"),
                    
                    # === КОММЕНТАРИИ ===
                    "comments": entry.get("comments"),
                    
                    # === ТЕХНИЧЕСКИЕ ПОЛЯ ===
                    "_type": entry.get("_type"),
                    "_version": entry.get("_version"),
                    "epoch": entry.get("epoch"),
                    "http_headers": entry.get("http_headers"),
                    "ytdl_hooks": entry.get("ytdl_hooks"),
                    
                    # === ПЛЕЙЛИСТ / МНОЖЕСТВЕННОЕ ВИДЕО ===
                    "entries": entry.get("entries"),
                    "multi_video": entry.get("multi_video"),
                }
                playlist.append({"tracks": [track_data]})
            
            response = {
                "success": True,
                "title": result.get("title"),
                "video_count": result.get("playlist_count"),
                "videos_returned": len(playlist),
                "videos_skipped": skipped,
                "playlist": playlist,
            }
            
            response_cache.set("playlist", cache_params, response)
    
            
            return response
        
    except Exception as err:
        print(f"playlist extraction err: {err}")
        raise HTTPException(status_code=500, detail=str(err))
    
    finally: 
        os.unlink(tmp_path)
    


@app.get('/api/yt/search')
async def search(request: SearchRequest):

    # проверка кэкэша
    cache_params = {"query": request.query, "max_results": request.max_results}
    cached = response_cache.get("search", cache_params)
    if cached is not None:
        return cached


    search_query = f"ytsearch{request.max_results}:{request.query}"
    
    ydl_opts = {
        'quiet': True,
        'no_warnings': True,
        'extract_flat': True,
        'ignoreerrors': True,
        'extractor_args': {
            'youtube': {
                'player_client': ['web_music'],
            }
        },
    }
    
    with yt_dlp.YoutubeDL(cast(Any, ydl_opts)) as ydl:
        result = ydl.extract_info(search_query, download=False)
        
        videos = []
        for entry in (result.get('entries') or []):
            if entry:
                videos.append({
                    "id": entry.get("id"),
                    "title": entry.get("title"),
                    "channel": entry.get("channel"),
                    "duration": entry.get("duration"),
                    "thumbnail": entry.get("thumbnail"),
                    "url": entry.get('url'),
                })
    
    response_cache.set("search", cache_params, videos)
    
    return videos

@app.get("/api/yt/scalar", include_in_schema=False)
async def scalar_html():
    return get_scalar_api_reference(
        openapi_url=app.openapi_url,
        scalar_proxy_url="https://proxy.scalar.com",
    )
