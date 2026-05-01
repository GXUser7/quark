# quark Local API (v0 - Beta) Documentation

> **Note**s: 
> This API is designed for **desktop platforms only**. 
> Authentication tokens are not yet implemented. 
> WebSocket functionality is currently **read-only** (subscriptions for receiving updates only).
> While no major changes are expected for the final release, we do not recommend assuming that v0 will be identical to v1. 
> Backward compatibility and version-specific endpoints  will only be supported starting from version 1.

---

## Overview

The quark Local API is a lightweight HTTP interface that allows external clients to control and monitor the Quark music player instance running on the same machine. It provides endpoints for playback control, metadata retrieval, and real-time updates via WebSocket.

### Key Characteristics

| Feature        | Status                               |
| -------------- | ------------------------------------ |
| Platform       | Desktop only (Windows, Linux, macOS) |
| Transport      | HTTP/1.1 + WebSocket                 |
| Authentication | Not implemented (reserved)           |
| Data Format    | JSON                                 |
| API Version    | `0`                                  |

---

## Getting Started

### 1. Discover the API Port

When the Local API is initialized, Quark writes the assigned port number to a file:

```
# Linux/macOS
~/.cache/com.quark.quark/api.port

# Windows
%LOCALAPPDATA%\com.quark.quark\api.port
```

Read this file to obtain the port number (e.g., `54321`). 
The server binds to `127.0.0.1` (loopback only), so connections are only possible from the local machine.

### 2. Construct Base URL

```
http://127.0.0.1:{PORT}
```

or

```
ws://127.0.0.1:{PORT}
```

### 3. Make Requests

All endpoints respond with `Content-Type: application/json` unless otherwise noted. 
Most control endpoints return `204 No Content` on success.

---

## API Endpoints

### General

#### `GET /get-api-version`

Returns the current API version.

**Response** (plain text):
```
0
```

---

### Quick Parameters

#### `GET /get-quick-parameters`

Returns a compact snapshot of key player states.

**Response** (JSON):
```json
{
  "repeat": true,
  "shuffle": false,
  "volume": 0.75,
  "paused": false
}
```


---

### Playback Control

| Endpoint         | Method | Description            |
| ---------------- | ------ | ---------------------- |
| `/pause`         | GET    | Pause playback         |
| `/resume`        | GET    | Resume playback        |
| `/play-next`     | GET    | Skip to next track     |
| `/play-previous` | GET    | Skip to previous track |

**Response**: `204 No Content` on success

---

### Volume Control

#### `GET /get-volume`

Returns current volume level.

**Response** (plain text, double):
```
0.75
```

#### `GET /set-volume?value={0.0-1.0}`

Sets the volume level.

| Parameter | Type | Required | Range |
|-----------|------|----------|-------|
| `value` | double | Yes | `0.0` – `1.0` |

**Response**: `204 No Content` on success  
**Error**: `400 Bad Request` if value is missing or out of range

---

### Repeat Mode

#### `GET /get-repeat`

Returns current repeat mode status.

**Response** (plain text, boolean):
```
true
```

#### `GET /set-repeat?value={true|false}`

Enables or disables repeat mode.

| Parameter | Type | Required |
|-----------|------|----------|
| `value` | boolean | Yes |

**Response**: `204 No Content` on success

---

### Shuffle Mode

#### `GET /get-shuffle`

Returns current shuffle mode status.

**Response** (plain text, boolean):
```
false
```

#### `GET /set-shuffle?value={true|false}`

Enables or disables shuffle mode.

| Parameter | Type | Required |
|-----------|------|----------|
| `value` | boolean | Yes |

**Response**: `204 No Content` on success

---

### Track Position & Duration

#### `GET /get-position`

Returns current playback position in seconds.

**Response** (plain text, integer):
```
142
```

#### `GET /get-duration`

Returns total track duration in seconds.

**Response** (plain text, integer):
```
371
```

#### `GET /seek?value={seconds}`

Seeks to an absolute position in the current track.

| Parameter | Type | Required | Range |
|-----------|------|----------|-------|
| `value` | integer | Yes | `0` – `duration` |

**Response**: `204 No Content` on success

#### `GET /seek-delta-seconds?value={seconds}`

Seeks relative to current position (forward only in current implementation).

| Parameter | Type    | Required | Range            |
| --------- | ------- | -------- | ---------------- |
| `value`   | integer | Yes      | `0` - `duration` |

**Response**: `204 No Content` on success

---

### Now Playing Track

#### `GET /get-now-playing-track`

Returns detailed metadata for the currently playing track.

**Response** (JSON):
```json
{
  "title": ""Heroes"",
  "artists": ["David Bowie"],
  "albums": ["Unknown"],
  "filepath": "/mnt/windows/Users/zenar56/Music/1977. David Bowie - Heroes (2017) [24-192]/03. "Heroes".flac",
  "cover": "/mnt/windows/Users/zenar56/Music/1977. David Bowie - Heroes (2017) [24-192]/03. "Heroes".flac",
  "coverType": "builtIn",
  "position": 304,
  "duration": 371,
  "paused": false,
  "local": true,
  "from-queue": false,
  "index": 7,
  "queue-index": -1
}
```

#### `GET /set-now-playing-track?value={index}`

Plays a track from the current playlist by index.

| Parameter | Type | Required | Range |
|-----------|------|----------|-------|
| `value` | integer | Yes | `0` – `playlist.length - 1` |

**Response**: `204 No Content` on success

---

### Playlist

#### `GET /get-now-playlist`

Returns the full current playlist + queue with metadata for each track.

**Response** (JSON):
```json
{
  "length": 1499,
  "source": "local",
  "name": "Local",
  "unqueued-track-index": -1,
  "tracks": [
    {
      "title": "Pigs On The Wing (Part One) [2011 Remastered Version]",
      "artists": ["Pink Floyd"],
      "albums": ["Unknown"],
      "filepath": "/mnt/Music/1977(2021) Pink Floyd - Animals (2011 Remastered Version) [24B-192kHz] flac/02. Dogs [2011 Remastered Version].flac",
      "cover": "/mnt/Music/1977(2021) Pink Floyd - Animals (2011 Remastered Version) [24B-192kHz] flac/02. Dogs [2011 Remastered Version].flac",
      "coverType": "builtIn",
      "duration": 371,
      "paused": false,
      "local": true,
      "from-queue": false,
      "index": 0,
      "queue-index": -1
    }
    // ... more tracks
  ]
}
```

**Field Descriptions**:

| Field | Type | Description |
|-------|------|-------------|
| `length` | int | Number of tracks in main playlist |
| `source` | string | Playlist source identifier (`local`, `spotify`, etc.) |
| `name` | string | Playlist display name |
| `unqueued-track-index` | int | Index of last unqueued track, or `-1` |
| `tracks` | array | List of track objects (see below) |

**Track Object Fields**:

| Field | Type | Description |
|-------|------|-------------|
| `title` | string | Track title |
| `artists` | array[string] | List of artist names |
| `albums` | array[string] | List of album names |
| `filepath` | string | Absolute file path (for local tracks) |
| `cover` | string | Path or URL to cover art |
| `coverType` | string | Cover source type (`builtIn`, `embedded`, etc.) |
| `duration` | int | Track duration in seconds |
| `position` | int | *Only in `/get-now-playing-track`* Current playback position in seconds |
| `paused` | bool | Playback state |
| `local` | bool | Whether track is a local file |
| `from-queue` | bool | Whether track originates from queue |
| `index` | int | Position in main playlist (`-1` if not in playlist) |
| `queue-index` | int | Position in queue (`-1` if not in queue) |

---

## WebSocket Subscriptions (Read-Only)

> **WebSocket Control:** Currently unsupported. WebSockets are restricted to **read-only** subscriptions for real-time updates.
> **Position Updates:** Subscriptions for playback position are disabled due to high traffic (5–10 requests/sec).
> **Note:** Full write access and position tracking will be implemented in **API v1.0**.

### Endpoint

```
GET /subscribe?subscriptions={comma-separated-endpoints}
```

### Supported Subscription Topics

```
repeat, shuffle, now-playing-track, playlist, play-pause, duration, volume
```

### Example Request

```
GET /subscribe?subscriptions=now-playing-track,volume,play-pause
```

### Upgrade & Message Format

Upon successful WebSocket upgrade, the server sends JSON messages when subscribed values change:

```json
{
  "event": "now-playing-track-update",
  "new": {
    "title": "...",
    "artists": ["..."],
    ...
  }
}
```

**Event Names**: `{endpoint}-update` (e.g., `volume-update`, `play-pause-update`)

**Note**: 
- Clients must handle reconnection logic.
- Closed/closing sockets are automatically unsubscribed by the server.
- The `position` and `duration` values are returned as integers (seconds), not `Duration` objects.

---

## Client Implementation Guidelines

### Recommended Workflow

1. **On Startup**:
   - Read `api.port` file to get the port.
   - Verify connectivity with `GET /get-api-version`.
   - Optionally subscribe to WebSocket updates for real-time UI sync.

2. **Polling Alternative**:
   - If WebSocket is not used, poll endpoints like `/get-now-playing-track` at reasonable intervals (e.g., 1–2 seconds for position updates).

3. **State Synchronization**:
   - Use `/get-quick-parameters` for initial state bootstrap.
   - Subscribe to `play-pause`, `position`, and `now-playing-track` for responsive UI updates.

4. **Error Recovery**:
   - Monitor for `404`/connection errors — the API server may restart or change ports.
   - Re-read `api.port` if connection fails.

### Sample Client Pseudocode (Dart-like)

```dart
Future<void> connectToQuark() async {
  final portFile = File(getPortFilePath()); // Platform-specific path
  if (!await portFile.exists()) {
    throw Exception('Quark API not initialized');
  }
  final port = int.parse(await portFile.readAsString());
  final baseUrl = 'http://127.0.0.1:$port';
  
  // Verify API
  final version = await http.get(Uri.parse('$baseUrl/get-api-version'));
  if (version.statusCode != 200) {
    throw Exception('API unreachable');
  }
  
  // Optional: Subscribe to updates
  final wsUrl = 'ws://127.0.0.1:$port/subscribe?subscriptions=play-pause,now-playing-track';
  final channel = WebSocketChannel.connect(Uri.parse(wsUrl));
  channel.stream.listen((message) {
    final data = jsonDecode(message);
    handleUpdate(data['event'], data['new']);
  });
}
```
