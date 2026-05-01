import 'dart:io';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';
import '/objects/track.dart';
import 'package:path/path.dart' as path;
import 'package:audio_metadata_reader/audio_metadata_reader.dart';

class ApplicationCacheDirectory {
  ApplicationCacheDirectory._();

  static final ApplicationCacheDirectory _instance =
      ApplicationCacheDirectory._();

  static ApplicationCacheDirectory get instance => _instance;

  Directory? _directory;

  Future<void> init() async {
    if (_directory != null) return;
    _directory = await getApplicationCacheDirectory();
  }

  Directory get directory {
    return _directory!;
  }
}

class Files {
  static Future<LocalTrack> _getTrackInfo(
    String paths, {
    String? customCover,
  }) async {
    try {
      final tagsFromFile = readMetadata(File(paths), getImage: true);

      String trackName = tagsFromFile.title ??= 'Unknown';
      Uint8List? cover = tagsFromFile.pictures.isNotEmpty
          ? tagsFromFile.pictures.first.bytes
          : null;
          
      CoverType coverType = CoverType.noCover;
      
      String coverPath = "none";
      if (cover == null) {
        if (customCover != null) {
          cover ??= await File(customCover).readAsBytes();
          coverPath = customCover;
          coverType = CoverType.externalFile;
        } else {
          coverType = CoverType.noCover;
        }
      } else {
        coverType = CoverType.builtIn;
        coverPath = paths;
      }

      LocalTrack track = LocalTrack(
        title: trackName,
        artists: tagsFromFile.artist != null
            ? tagsFromFile.artist!.split(",")
            : ["Unknown"],
        filepath: paths,
        albums: ['Unknown'],
        coverType: coverType,
        cover: coverPath
      );
      if (cover != null) {
        track.coverByted = cover;
      }

      return track;
    } catch (e) {
      String trackName = path.basename(path.normalize(paths));
      LocalTrack track = LocalTrack(
        title: trackName,
        artists: ['Unknown'],
        filepath: paths,
        albums: ['Unknown'],
        coverType: CoverType.noCover,
      );
      return track;
    }
  }

  static Future<LocalTrack> getTrackInfo((String, String?) args) async {
    return _getTrackInfo(args.$1, customCover: args.$2);
  }

  static Future<AudioMetadata?> getFileTags(
    String path, {
    bool getImage = false,
  }) async {
    try {
      return await Isolate.run(() {
        return readMetadata(File(path), getImage: getImage);
      });
    } catch (e) {
      return null;
    }
  }

  // static Future<void> _scanDirectory({
  //   required String path,
  //   required List<PlayerTrack> fileNames,
  //   required bool recursiveEnable,
  // }) async {
  //   final dir = Directory(path);
  //   Uint8List? customCover;

  //   await for (final entity in dir.list()) {
  //     if (entity is File) {
  //       if (entity.path.toLowerCase().endsWith("folder.jpg") ||
  //           entity.path.toLowerCase().endsWith("cover.jpg")) {
  //         customCover = await entity.readAsBytes();
  //       }
  //     }
  //   }

  //   await for (final entity in dir.list()) {
  //     if (entity is File) {
  //       if (entity.path.toLowerCase().endsWith('.mp3') ||
  //           entity.path.toLowerCase().endsWith('.wav') ||
  //           entity.path.toLowerCase().endsWith('.flac') ||
  //           entity.path.toLowerCase().endsWith('.dsf') ||
  //           entity.path.toLowerCase().endsWith('.aac') ||
  //           entity.path.toLowerCase().endsWith('.alac') ||
  //           entity.path.toLowerCase().endsWith('.pcm') ||
  //           entity.path.toLowerCase().endsWith('.m4a')) {
  //         final LocalTrack track = await compute(getTrackInfo, (
  //           entity.path,
  //           customCover,
  //         ));
  //         fileNames.add(track);
  //       }
  //     }
  //     if (entity is Directory) {
  //       if (recursiveEnable) {
  //         await _scanDirectory(
  //           path: entity.path,
  //           fileNames: fileNames,
  //           recursiveEnable: recursiveEnable,
  //         );
  //       }
  //     }
  //   }
  // }

  // static Future<List<PlayerTrack>> _scanDirectoryCompute(
  //   (String, bool?) args,
  // ) async {
  //   final List<PlayerTrack> result = [];
  //   await _scanDirectory(
  //     path: args.$1,
  //     fileNames: result,
  //     recursiveEnable: args.$2 ?? true,
  //   );
  //   return result;
  // }

  // Future<List<PlayerTrack>> getFilesFromDirectory({
  //   required String directoryPath,
  //   bool? recursiveEnable,
  // }) async {
  //   try {
  //     final fileNames = await compute(_scanDirectoryCompute, (
  //       directoryPath,
  //       recursiveEnable,
  //     ));

  //     return fileNames;
  //   } catch (e) {
  //     Logger('Files').severe('Failed to get files from directory.', e);
  //   }
  //   return [];
  // }

  static const Set<String> _audioExtensions = {
    '.mp3',
    '.wav',
    '.flac',
    '.dsf',
    '.aac',
    '.alac',
    '.pcm',
    '.m4a',
    '.opus',
  };

  static final _naturalRegex = RegExp(r'(\d+)|(\D+)');
  static int _naturalCompare(String a, String b) {
    final partsA = _naturalRegex.allMatches(a).map((m) => m.group(0)!).toList();
    final partsB = _naturalRegex.allMatches(b).map((m) => m.group(0)!).toList();

    final len = partsA.length < partsB.length ? partsA.length : partsB.length;
    for (int i = 0; i < len; i++) {
      final aPart = partsA[i];
      final bPart = partsB[i];

      final bool aIsNum = RegExp(r'^\d+$').hasMatch(aPart);
      final bool bIsNum = RegExp(r'^\d+$').hasMatch(bPart);

      if (aIsNum && bIsNum) {
        final numA = int.tryParse(aPart) ?? 0;
        final numB = int.tryParse(bPart) ?? 0;
        if (numA != numB) return numA.compareTo(numB);
      } else {
        final cmp = aPart.compareTo(bPart);
        if (cmp != 0) return cmp;
      }
    }
    return partsA.length.compareTo(partsB.length);
  }

  Future<List<PlayerTrack>> _scanDirectory({
    required String path,
    required bool recursiveEnable,
  }) async {
    final dir = Directory(path);
    if (!await dir.exists()) return [];
    final entities = await dir.list().toList();
    String? customCover;

    for (final entity in entities) {
      if (entity is File) {
        final lower = entity.path.toLowerCase();
        if (lower.endsWith('folder.jpg') || lower.endsWith('cover.jpg')) {
          customCover = entity.path;
          break;
        }
      }
    }

    final List<Directory> subDirs = [];
    final List<File> audioFiles = [];

    for (final entity in entities) {
      if (entity is Directory && recursiveEnable) {
        subDirs.add(entity);
      } else if (entity is File) {
        final lower = entity.path.toLowerCase();
        if (_audioExtensions.any(lower.endsWith)) {
          audioFiles.add(entity);
        }
      }
    }

    subDirs.sort((a, b) => _naturalCompare(a.path, b.path));
    audioFiles.sort((a, b) => _naturalCompare(a.path, b.path));

    final List<PlayerTrack> result = [];

    for (final file in audioFiles) {
      final track = await getTrackInfo((file.path, customCover));
      result.add(track);
    }

    for (final subDir in subDirs) {
      result.addAll(
        await _scanDirectory(
          path: subDir.path,
          recursiveEnable: recursiveEnable,
        ),
      );
    }

    return result;
  }

  Future<List<PlayerTrack>> _scanDirectoryWrapper(
    (String path, bool? recursiveEnable) args,
  ) async {
    return await _scanDirectory(
      path: args.$1,
      recursiveEnable: args.$2 ?? true,
    );
  }

  Future<List<PlayerTrack>> getFilesFromDirectory({
    required String directoryPath,
    bool? recursiveEnable,
  }) async {
    try {
      return await compute(_scanDirectoryWrapper, (
        directoryPath,
        recursiveEnable,
      ));
    } catch (e, st) {
      Logger('Files').severe('Failed to get files from directory.', e, st);
      return [];
    }
  }
}
