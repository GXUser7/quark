/// Universal audio tag reader — MP4/M4A container + MP3 ID3v2
/// Pure Dart, no dependencies.
///
/// Mirrors the encoding conventions of audio_tagger.dart:
///   • MP4 atom type names are latin-1 (© = 0xA9, one byte).
///   • ID3v2.3 and ID3v2.4 are both supported.
///   • Returns null for any field that is absent or empty.
/// BY AI
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

// ─── Public result type ───────────────────────────────────────────────────────

class AudioTagsResult {
  final String? title;
  final String? artist;
  final String? albumArtist;
  final String? album;
  final String? year;
  final String? genre;
  final String? comment;
  final int? trackNumber;
  final int? trackTotal;
  final int? discNumber;
  final int? discTotal;
  final Uint8List? coverData;
  final String? coverMime;

  // Extra info
  final String format;    // 'mp4', 'mp3', 'unknown'
  final int fileSizeBytes;

  const AudioTagsResult({
    this.title,
    this.artist,
    this.albumArtist,
    this.album,
    this.year,
    this.genre,
    this.comment,
    this.trackNumber,
    this.trackTotal,
    this.discNumber,
    this.discTotal,
    this.coverData,
    this.coverMime,
    required this.format,
    required this.fileSizeBytes,
  });

  @override
  String toString() {
    final lines = <String>[
      'Format       : $format',
      'File size    : $fileSizeBytes bytes',
      if (title       != null) 'Title        : $title',
      if (artist      != null) 'Artist       : $artist',
      if (albumArtist != null) 'Album artist : $albumArtist',
      if (album       != null) 'Album        : $album',
      if (year        != null) 'Year         : $year',
      if (genre       != null) 'Genre        : $genre',
      if (comment     != null) 'Comment      : $comment',
      if (trackNumber != null) 'Track        : $trackNumber${trackTotal != null ? "/$trackTotal" : ""}',
      if (discNumber  != null) 'Disc         : $discNumber${discTotal  != null ? "/$discTotal"  : ""}',
      if (coverData   != null) 'Cover        : ${coverData!.length} bytes ($coverMime)',
    ];
    return lines.join('\n');
  }
}

// ─── Reader ───────────────────────────────────────────────────────────────────

class AudioTagReader {
  /// Read tags from [path]. Never throws on missing tags — returns empty result.
  static Future<AudioTagsResult> readFromFile(String path) async {
    final file = File(path);
    if (!await file.exists()) throw FileSystemException('File not found', path);

    final src = await file.readAsBytes();
    final fmt = _detect(src);

    return switch (fmt) {
      _Format.mp4  => Mp4TagReader._read(src),
      _Format.mp3  => Id3TagReader._read(src),
      _Format.unknown => AudioTagsResult(
          format: 'unknown',
          fileSizeBytes: src.length,
        ),
    };
  }
}

// ─── Format detection (mirrors audio_tagger.dart) ────────────────────────────

enum _Format { mp4, mp3, unknown }

_Format _detect(Uint8List src) {
  if (src.length >= 8) {
    final t = String.fromCharCodes(src.sublist(4, 8));
    if (t == 'ftyp' || t == 'moov' || t == 'mdat' || t == 'free' || t == 'wide') {
      return _Format.mp4;
    }
  }
  if (src.length >= 3) {
    if (src[0] == 0x49 && src[1] == 0x44 && src[2] == 0x33) return _Format.mp3;
    if (src[0] == 0xFF && (src[1] & 0xE0) == 0xE0)          return _Format.mp3;
  }
  return _Format.unknown;
}

// ─── Shared byte helpers ─────────────────────────────────────────────────────

/// Read atom type as latin-1 — mirrors _readType in audio_tagger.dart.
String _readAtomType(Uint8List bytes, int pos) =>
    String.fromCharCodes(bytes.sublist(pos + 4, pos + 8));

class _Atom {
  final int offset;
  final int size;
  final String type;

  _Atom(this.offset, this.size, this.type);
  int get end        => offset + size;
  int get dataOffset => offset + 8;
}

List<_Atom> _parseAtoms(Uint8List bytes, int start, int end) {
  final result = <_Atom>[];
  final bd = ByteData.sublistView(bytes);
  int pos = start;
  while (pos + 8 <= end) {
    final size = bd.getUint32(pos);
    if (size < 8 || pos + size > end) break;
    result.add(_Atom(pos, size, _readAtomType(bytes, pos)));
    pos += size;
  }
  return result;
}

_Atom? _findAtom(List<_Atom> atoms, String type) {
  for (final a in atoms) {
    if (a.type == type) return a;
  }
  return null;
}

// ─── MP4 Tag Reader ───────────────────────────────────────────────────────────

class Mp4TagReader {
  static AudioTagsResult _read(Uint8List src) {
    String? title, artist, albumArtist, album, year, genre, comment;
    int? trackNumber, trackTotal, discNumber, discTotal;
    Uint8List? coverData;
    String? coverMime;

    // Walk: moov → udta → meta → ilst
    final topAtoms = _parseAtoms(src, 0, src.length);
    final moov = _findAtom(topAtoms, 'moov');
    if (moov == null) {
      return AudioTagsResult(format: 'mp4', fileSizeBytes: src.length);
    }

    final moovChildren = _parseAtoms(src, moov.dataOffset, moov.end);
    final udta = _findAtom(moovChildren, 'udta');
    if (udta == null) {
      return AudioTagsResult(format: 'mp4', fileSizeBytes: src.length);
    }

    // meta has a 4-byte version/flags prefix before its children
    final udtaChildren = _parseAtoms(src, udta.dataOffset, udta.end);
    final meta = _findAtom(udtaChildren, 'meta');
    if (meta == null) {
      return AudioTagsResult(format: 'mp4', fileSizeBytes: src.length);
    }

    // Skip the 4-byte version+flags at the start of meta's payload
    final metaChildren = _parseAtoms(src, meta.dataOffset + 4, meta.end);
    final ilst = _findAtom(metaChildren, 'ilst');
    if (ilst == null) {
      return AudioTagsResult(format: 'mp4', fileSizeBytes: src.length);
    }

    final ilstItems = _parseAtoms(src, ilst.dataOffset, ilst.end);
    for (final item in ilstItems) {
      // Each item contains one or more 'data' child boxes
      final itemChildren = _parseAtoms(src, item.dataOffset, item.end);
      final data = _findAtom(itemChildren, 'data');
      if (data == null || data.size < 16) continue;

      final bd      = ByteData.sublistView(src);
      final flags   = bd.getUint32(data.dataOffset);      // well-known type
      final payload = src.sublist(data.dataOffset + 8, data.end);

      String asUtf8() => utf8.decode(payload, allowMalformed: true);

      switch (item.type) {
        case '\u00a9nam': title       = asUtf8();   // ©nam
        case '\u00a9ART': artist      = asUtf8();   // ©ART
        case 'aART':      albumArtist = asUtf8();
        case '\u00a9alb': album       = asUtf8();   // ©alb
        case '\u00a9day': year        = asUtf8();   // ©day
        case '\u00a9gen': genre       = asUtf8();   // ©gen
        case '\u00a9cmt': comment     = asUtf8();   // ©cmt
        case 'trkn':
          if (payload.length >= 6) {
            trackNumber = (payload[2] << 8) | payload[3];
            trackTotal  = (payload[4] << 8) | payload[5];
            if (trackNumber == 0) trackNumber = null;
            if (trackTotal  == 0) trackTotal  = null;
          }
        case 'disk':
          if (payload.length >= 6) {
            discNumber = (payload[2] << 8) | payload[3];
            discTotal  = (payload[4] << 8) | payload[5];
            if (discNumber == 0) discNumber = null;
            if (discTotal  == 0) discTotal  = null;
          }
        case 'covr':
          coverData = payload;
          coverMime = flags == 14 ? 'image/png' : 'image/jpeg';
        // gnre is the numeric genre variant (integer, not string)
        case 'gnre':
          if (payload.length >= 2 && genre == null) {
            final idx = ((payload[0] << 8) | payload[1]) - 1;
            if (idx >= 0 && idx < _id3Genres.length) {
              genre = _id3Genres[idx];
            }
          }
      }
    }

    return AudioTagsResult(
      title: title,
      artist: artist,
      albumArtist: albumArtist,
      album: album,
      year: year,
      genre: genre,
      comment: comment,
      trackNumber: trackNumber,
      trackTotal: trackTotal,
      discNumber: discNumber,
      discTotal: discTotal,
      coverData: coverData,
      coverMime: coverMime,
      format: 'mp4',
      fileSizeBytes: src.length,
    );
  }
}

// ─── MP3 / ID3v2 Tag Reader ───────────────────────────────────────────────────

class Id3TagReader {
  static AudioTagsResult _read(Uint8List src) {
    if (src.length < 10) {
      return AudioTagsResult(format: 'mp3', fileSizeBytes: src.length);
    }

    // Check for ID3 header
    if (src[0] != 0x49 || src[1] != 0x44 || src[2] != 0x33) {
      // Raw MPEG frame, no ID3 tag at all
      return AudioTagsResult(format: 'mp3', fileSizeBytes: src.length);
    }

    final version = src[3]; // 2=ID3v2.2, 3=ID3v2.3, 4=ID3v2.4
    // src[4] = revision, src[5] = flags
    final hasExtHeader = (src[5] & 0x40) != 0;

    // Syncsafe tag size (bytes 6-9)
    final tagSize =
        (src[6] << 21) | (src[7] << 14) | (src[8] << 7) | src[9];
    final tagEnd = 10 + tagSize;
    if (tagEnd > src.length) {
      return AudioTagsResult(format: 'mp3', fileSizeBytes: src.length);
    }

    // Frame start: skip extended header if present
    int pos = 10;
    if (hasExtHeader && pos + 4 <= tagEnd) {
      final extSize = version == 4
          ? _syncsafeInt(src, pos)   // v2.4: syncsafe
          : ByteData.sublistView(src).getUint32(pos); // v2.3: plain
      pos += extSize;
    }

    String? title, artist, albumArtist, album, year, genre, comment;
    int? trackNumber, trackTotal, discNumber, discTotal;
    Uint8List? coverData;
    String? coverMime;

    // ID3v2.2 uses 3-char frame IDs and 3-byte sizes
    final isV22 = version == 2;

    while (pos + (isV22 ? 6 : 10) <= tagEnd) {
      // ID3v2.2: [ID 3B][size 3B]
      // ID3v2.3/4: [ID 4B][size 4B][flags 2B]
      String frameId;
      int frameSize;

      if (isV22) {
        frameId   = String.fromCharCodes(src.sublist(pos, pos + 3));
        frameSize = (src[pos + 3] << 16) | (src[pos + 4] << 8) | src[pos + 5];
        pos += 6;
      } else {
        frameId = String.fromCharCodes(src.sublist(pos, pos + 4));
        if (version == 4) {
          frameSize = _syncsafeInt(src, pos + 4);
        } else {
          frameSize = ByteData.sublistView(src).getUint32(pos + 4);
        }
        pos += 10; // skip flags (2B) too
      }

      if (frameId[0] == '\x00') break; // padding reached
      if (frameSize <= 0 || pos + frameSize > tagEnd) break;

      final frameData = src.sublist(pos, pos + frameSize);
      pos += frameSize;

      // Map ID3v2.2 three-letter IDs to their v2.3 equivalents
      final id = isV22 ? _v22to23(frameId) : frameId;

      switch (id) {
        case 'TIT2': title       = _decodeText(frameData);
        case 'TPE1': artist      = _decodeText(frameData);
        case 'TPE2': albumArtist = _decodeText(frameData);
        case 'TALB': album       = _decodeText(frameData);
        case 'TYER': // v2.3
        case 'TDRC': // v2.4
          year = _decodeText(frameData);
          if (year != null && year.length > 4) year = year.substring(0, 4);
        case 'TCON': genre   = _parseGenre(_decodeText(frameData));
        case 'TRCK':
          final parts = (_decodeText(frameData) ?? '').split('/');
          trackNumber = int.tryParse(parts[0].trim());
          if (parts.length > 1) trackTotal = int.tryParse(parts[1].trim());
        case 'TPOS':
          final parts = (_decodeText(frameData) ?? '').split('/');
          discNumber = int.tryParse(parts[0].trim());
          if (parts.length > 1) discTotal = int.tryParse(parts[1].trim());
        case 'COMM':
          comment = _decodeComm(frameData);
        case 'APIC':
          final r = _decodeApic(frameData);
          if (r != null) { coverData = r.$1; coverMime = r.$2; }
        case 'PIC': // ID3v2.2 cover (3-char mime, no null after mime)
          final r = _decodePic(frameData);
          if (r != null) { coverData = r.$1; coverMime = r.$2; }
      }
    }

    return AudioTagsResult(
      title: title,
      artist: artist,
      albumArtist: albumArtist,
      album: album,
      year: year,
      genre: genre,
      comment: comment,
      trackNumber: trackNumber,
      trackTotal: trackTotal,
      discNumber: discNumber,
      discTotal: discTotal,
      coverData: coverData,
      coverMime: coverMime,
      format: 'mp3',
      fileSizeBytes: src.length,
    );
  }

  // ── Text decoding ──────────────────────────────────────────────────────────

  /// ID3 text frame: [encoding 1B][content]
  /// Encoding: 0=ISO-8859-1, 1=UTF-16 (BOM), 2=UTF-16BE, 3=UTF-8
  static String? _decodeText(Uint8List data) {
    if (data.isEmpty) return null;
    final enc = data[0];
    final raw = data.sublist(1);
    final s = _decodeString(raw, enc);
    return s.isEmpty ? null : s;
  }

  static String _decodeString(Uint8List raw, int enc) {
    // Remove trailing null terminators
    Uint8List trim(Uint8List b, int nullWidth) {
      int end = b.length;
      if (nullWidth == 2) {
        while (end >= 2 && b[end - 2] == 0 && b[end - 1] == 0) end -= 2;
      } else {
        while (end > 0 && b[end - 1] == 0) end--;
      }
      return end == b.length ? b : b.sublist(0, end);
    }

    switch (enc) {
      case 0: // ISO-8859-1
        return latin1.decode(trim(raw, 1));
      case 1: // UTF-16 with BOM
        return _utf16Decode(trim(raw, 2));
      case 2: // UTF-16BE without BOM
        return _utf16BeDecode(trim(raw, 2));
      case 3: // UTF-8
        return utf8.decode(trim(raw, 1), allowMalformed: true);
      default:
        return latin1.decode(trim(raw, 1));
    }
  }

  /// UTF-16 with optional BOM (FF FE = LE, FE FF = BE).
  static String _utf16Decode(Uint8List b) {
    if (b.length < 2) return '';
    final be = (b[0] == 0xFE && b[1] == 0xFF);
    final start = (b[0] == 0xFF && b[1] == 0xFE) || be ? 2 : 0;
    return _utf16RawDecode(b, start, be);
  }

  static String _utf16BeDecode(Uint8List b) => _utf16RawDecode(b, 0, true);

  static String _utf16RawDecode(Uint8List b, int start, bool be) {
    final chars = <int>[];
    for (int i = start; i + 1 < b.length; i += 2) {
      final cp = be
          ? (b[i] << 8) | b[i + 1]
          : (b[i + 1] << 8) | b[i];
      // Handle surrogate pairs
      if (cp >= 0xD800 && cp <= 0xDBFF && i + 3 < b.length) {
        final low = be
            ? (b[i + 2] << 8) | b[i + 3]
            : (b[i + 3] << 8) | b[i + 2];
        if (low >= 0xDC00 && low <= 0xDFFF) {
          chars.add(0x10000 + ((cp - 0xD800) << 10) + (low - 0xDC00));
          i += 2;
          continue;
        }
      }
      chars.add(cp);
    }
    return String.fromCharCodes(chars);
  }

  // ── COMM frame ────────────────────────────────────────────────────────────

  /// COMM: [encoding 1B][lang 3B][description + null][text]
  static String? _decodeComm(Uint8List data) {
    if (data.length < 5) return null;
    final enc = data[0];
    // Skip language (3B) and find null terminator of description
    final nullWidth = (enc == 1 || enc == 2) ? 2 : 1;
    int pos = 4;
    while (pos < data.length) {
      if (nullWidth == 1) {
        if (data[pos] == 0) { pos++; break; }
      } else {
        if (pos + 1 < data.length && data[pos] == 0 && data[pos + 1] == 0) {
          pos += 2; break;
        }
      }
      pos++;
    }
    if (pos >= data.length) return null;
    final s = _decodeString(
        Uint8List.fromList([enc, ...data.sublist(pos)]), enc);
    return s.isEmpty ? null : s;
  }

  // ── APIC frame ────────────────────────────────────────────────────────────

  /// APIC: [enc 1B][mime\0][pic_type 1B][description\0][image data]
  static (Uint8List, String)? _decodeApic(Uint8List data) {
    if (data.length < 4) return null;
    final enc = data[0];

    // Mime type is always ISO-8859-1/ASCII, null-terminated, starts at byte 1
    int mimeEnd = 1;
    while (mimeEnd < data.length && data[mimeEnd] != 0) mimeEnd++;
    final mime = latin1.decode(data.sublist(1, mimeEnd));

    // pic_type byte follows the null
    int pos = mimeEnd + 1 + 1; // skip null + pic_type

    // Skip description (null-terminated, encoding-aware)
    final nullWidth = (enc == 1 || enc == 2) ? 2 : 1;
    while (pos < data.length) {
      if (nullWidth == 1) {
        if (data[pos] == 0) { pos++; break; }
      } else {
        if (pos + 1 < data.length && data[pos] == 0 && data[pos + 1] == 0) {
          pos += 2; break;
        }
      }
      pos++;
    }
    if (pos >= data.length) return null;
    return (data.sublist(pos), mime.isEmpty ? 'image/jpeg' : mime);
  }

  /// ID3v2.2 PIC frame: [enc 1B][format 3B: JPG|PNG][pic_type 1B][desc\0][data]
  static (Uint8List, String)? _decodePic(Uint8List data) {
    if (data.length < 6) return null;
    final enc = data[0];
    final fmt = String.fromCharCodes(data.sublist(1, 4)).toUpperCase();
    final mime = fmt == 'PNG' ? 'image/png' : 'image/jpeg';

    int pos = 5; // skip enc(1) + fmt(3) + pic_type(1)
    final nullWidth = (enc == 1 || enc == 2) ? 2 : 1;
    while (pos < data.length) {
      if (nullWidth == 1) {
        if (data[pos] == 0) { pos++; break; }
      } else {
        if (pos + 1 < data.length && data[pos] == 0 && data[pos + 1] == 0) {
          pos += 2; break;
        }
      }
      pos++;
    }
    if (pos >= data.length) return null;
    return (data.sublist(pos), mime);
  }

  // ── Genre helper ──────────────────────────────────────────────────────────

  /// ID3 genre can be "Rock", "(17)", "(17)Rock", or "(RX)" (remix) etc.
  static String? _parseGenre(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    // Numeric references: (N) or just N
    final match = RegExp(r'^\((\d+)\)(.*)$').firstMatch(raw);
    if (match != null) {
      final idx = int.tryParse(match.group(1)!);
      final extra = match.group(2)!.trim();
      if (idx != null && idx < _id3Genres.length) {
        return extra.isNotEmpty ? extra : _id3Genres[idx];
      }
      return extra.isNotEmpty ? extra : raw;
    }
    final numOnly = int.tryParse(raw.trim());
    if (numOnly != null && numOnly < _id3Genres.length) {
      return _id3Genres[numOnly];
    }
    return raw;
  }

  // ── Misc helpers ──────────────────────────────────────────────────────────

  /// Read a 4-byte syncsafe integer (7 bits per byte, MSB first).
  static int _syncsafeInt(Uint8List src, int pos) =>
      (src[pos] << 21) | (src[pos + 1] << 14) | (src[pos + 2] << 7) | src[pos + 3];

  /// Translate ID3v2.2 three-character IDs to their v2.3 equivalents.
  static String _v22to23(String id) => const {
    'TT2': 'TIT2',
    'TP1': 'TPE1',
    'TP2': 'TPE2',
    'TAL': 'TALB',
    'TYE': 'TYER',
    'TCO': 'TCON',
    'TRK': 'TRCK',
    'TPA': 'TPOS',
    'COM': 'COMM',
    'PIC': 'PIC',   // kept as-is, handled separately
  }[id] ?? id;
}

// ─── ID3 Genre list (standard 192 genres) ────────────────────────────────────

const _id3Genres = [
  'Blues', 'Classic Rock', 'Country', 'Dance', 'Disco', 'Funk', 'Grunge',
  'Hip-Hop', 'Jazz', 'Metal', 'New Age', 'Oldies', 'Other', 'Pop', 'R&B',
  'Rap', 'Reggae', 'Rock', 'Techno', 'Industrial', 'Alternative', 'Ska',
  'Death Metal', 'Pranks', 'Soundtrack', 'Euro-Techno', 'Ambient',
  'Trip-Hop', 'Vocal', 'Jazz+Funk', 'Fusion', 'Trance', 'Classical',
  'Instrumental', 'Acid', 'House', 'Game', 'Sound Clip', 'Gospel', 'Noise',
  'AlternRock', 'Bass', 'Soul', 'Punk', 'Space', 'Meditative',
  'Instrumental Pop', 'Instrumental Rock', 'Ethnic', 'Gothic', 'Darkwave',
  'Techno-Industrial', 'Electronic', 'Pop-Folk', 'Eurodance', 'Dream',
  'Southern Rock', 'Comedy', 'Cult', 'Gangsta', 'Top 40', 'Christian Rap',
  'Pop/Funk', 'Jungle', 'Native American', 'Cabaret', 'New Wave',
  'Psychadelic', 'Rave', 'Showtunes', 'Trailer', 'Lo-Fi', 'Tribal',
  'Acid Punk', 'Acid Jazz', 'Polka', 'Retro', 'Musical', 'Rock & Roll',
  'Hard Rock', 'Folk', 'Folk-Rock', 'National Folk', 'Swing', 'Fast Fusion',
  'Bebob', 'Latin', 'Revival', 'Celtic', 'Bluegrass', 'Avantgarde',
  'Gothic Rock', 'Progressive Rock', 'Psychedelic Rock', 'Symphonic Rock',
  'Slow Rock', 'Big Band', 'Chorus', 'Easy Listening', 'Acoustic', 'Humour',
  'Speech', 'Chanson', 'Opera', 'Chamber Music', 'Sonata', 'Symphony',
  'Booty Bass', 'Primus', 'Porn Groove', 'Satire', 'Slow Jam', 'Club',
  'Tango', 'Samba', 'Folklore', 'Ballad', 'Power Ballad', 'Rhythmic Soul',
  'Freestyle', 'Duet', 'Punk Rock', 'Drum Solo', 'A Cappella', 'Euro-House',
  'Dance Hall', 'Goa', 'Drum & Bass', 'Club-House', 'Hardcore', 'Terror',
  'Indie', 'BritPop', 'Afro-Punk', 'Polsk Punk', 'Beat', 'Christian Gangsta',
  'Heavy Metal', 'Black Metal', 'Crossover', 'Contemporary Christian',
  'Christian Rock', 'Merengue', 'Salsa', 'Thrash Metal', 'Anime', 'JPop',
  'Synthpop', 'Abstract', 'Art Rock', 'Baroque', 'Bhangra', 'Big Beat',
  'Breakbeat', 'Chillout', 'Downtempo', 'Dub', 'EBM', 'Eclectic', 'Electro',
  'Electroclash', 'Emo', 'Experimental', 'Garage', 'Global', 'IDM',
  'Illbient', 'Industro-Goth', 'Jam Band', 'Krautrock', 'Leftfield', 'Lounge',
  'Math Rock', 'New Romantic', 'Nu-Breakz', 'Post-Punk', 'Post-Rock', 'Psytrance',
  'Shoegaze', 'Space Rock', 'Trop Rock', 'World Music', 'Neoclassical',
  'Audiobook', 'Audio Theatre', 'Neue Deutsche Welle', 'Podcast', 'Indie-Rock',
  'G-Funk', 'Dubstep', 'Garage Rock', 'Psybient',
];

// ─── CLI ─────────────────────────────────────────────────────────────────────

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    print('Usage: dart audio_reader.dart <file> [--cover out.jpg]');
    return;
  }

  final path = args[0];
  String? coverOut;
  for (var i = 1; i + 1 < args.length; i += 2) {
    if (args[i] == '--cover') coverOut = args[i + 1];
  }

  try {
    final tags = await AudioTagReader.readFromFile(path);
    print(tags);

    if (coverOut != null && tags.coverData != null) {
      await File(coverOut).writeAsBytes(tags.coverData!);
      print('\nCover saved to: $coverOut');
    } else if (coverOut != null) {
      stderr.writeln('No cover art found in file.');
    }
  } catch (e) {
    stderr.writeln('Error: $e');
    exit(1);
  }
}