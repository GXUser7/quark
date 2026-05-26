// Ability to interact with the player on a local network (only for desktop with setting enabled)
// Commands: getCurrentPlaylist (tracks), pause, next, previous, getNowPlayingTrack,
//getRepeat, getShuffle,
//setShuffle, setRepeat,
//seek, getPosition,
//getVolume, setVolume,
// closeapp,
//getAvailablePlaylists,
//playPlaylist,
//getSettings, setSetting


/// GET SETTINGS
Map<String, dynamic> settings = {
    "audio_engine": "JustAudioMK",
    "recursievly_adding_files": true,
    "playlist_opening_area": true,
    "state_indicator": true,
    "transition_speed": 1.2,
    "dynamic_window_color": true,
    "yandex_music_search": true,
    "yandex_music_preload": true,
    "yandex_music_original_cover_size": true,
    "yandex_music_original_quality": "Lossless",
    "yandex_music_token": "y0",
};

/// GET PARAMS
Map<String ,dynamic> params = {
    "type": "params",
    "shuffle": true,
    "repeat": true,
    "playback_speed": 1.0,
    "volume": 0.5620501,
};

/// GET NOW PLAYING TRACK
Map<String ,dynamic> npt = {
    "paused": true,
    "from_queue": false,
    "position": 195000, // MS
    "total_duration": 3000000,
    "type": "now_playing_track",
    "items": [
        jsonTrack2
    ]
};


/// GET QUEUE (NOT PLAYLIST)
Map<String, dynamic> queue = {
    "type": "queue",
    "items": [jsonTrack2]
};

/// GET PLAYLIST
Map<String, dynamic> jsonPlaylist = {
    "type": "playlist",
    "source": "combined",
    "id": "",
    "owner": "",
    "items": [
        jsonTrack,
        jsonTrack2,
    ]
};


Map<String, dynamic> track = {
    "type": "track",
    "from_queue": false,
    "item": jsonTrack
};


/// GET TRACK
Map<String, dynamic> jsonTrack = {
    "artists": ["Radiohead"],
    "title": "Creep",
    "album": "Pablo Honey",
    "filepath": "/mnt/Music/Radiohead - Pablo Honey/Creep.flac",
    "cover_path": "/mnt/Music/Radiohead - Pablo Honey/folder.jpg", /// MAYBE /home/user/.cache/com.quark.quark/cached_images/646720e4995ef3375e4b690b40c7fc50
    "cover_type": "external",
    "source": "local",
};

Map<String, dynamic> jsonTrack2 = {
    "type": "track",
    "artists": ["Queen"],
    "title": "Under Pressure",
    "album": "Bohemian Rhapsody (OST)",
    "filepath": "/home/zenar/.cache/com.quark.quark/cisum_xenday_krauq5918512.flac",
    "stream_url": null,
    "cover_path": "/home/user/.cache/com.quark.quark/cached_images/646720e4995ef3375e4b690b40c7fc50",
    "cover_url": "url",
    "cover_type": "external",
    "source": "yandex_music",
    "source_id": "591203",
    "source_album_id": "59195" // OR NULL
};

Map<String, dynamic> jsonTrack3 = {
    "type": "track",
    "artists": ["Queen"],
    "title": "Under Pressure",
    "album": "Bohemian Rhapsody (OST)",
    "filepath": "/home/zenar/.cache/com.quark.quark/cisum_xenday_krauq5918512.flac",
    "stream_url": "https://yandex/stream////////",
    "cover_path": "/home/user/.cache/com.quark.quark/cached_images/646720e4995ef3375e4b690b40c7fc50",
    "cover_url": "url",
    "cover_type": "external",
    "source": "yandex_music",
    "source_id": "591203",
    "source_album_id": "59195" // OR NULL
};
