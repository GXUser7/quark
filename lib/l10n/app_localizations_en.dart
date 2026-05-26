// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'quark: where sound begins';

  @override
  String get selectFolderHint =>
      'Select the folder with tracks.\nYou can also link your streaming account to use it.';

  @override
  String get pickFolder => 'Pick folder';

  @override
  String get restorePlaylist => 'Restore playlist';

  @override
  String get yandexMusic => 'Yandex Music';

  @override
  String get youtubeMusic => 'YouTube Music';

  @override
  String get vkMusic => 'VK Music';

  @override
  String get soundCloud => 'SoundCloud';

  @override
  String get search => 'Search';

  @override
  String get settings => 'Settings';

  @override
  String get login => 'Log in';

  @override
  String get logout => 'Log out';

  @override
  String get deleteAllPlaylists => 'Delete all playlists?';

  @override
  String get deleteAllPlaylistsDesc =>
      'This will permanently delete all local playlists and their tracks.';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String playlistError(Object error) {
    return 'Playlist loading error: $error';
  }

  @override
  String get preferences => 'Preferences';

  @override
  String get debug => 'Debug';

  @override
  String get main => 'Main';

  @override
  String get warning => 'WARNING';

  @override
  String get databaseWarning =>
      'The database is unavailable or contains errors. Changes may not be saved. Check the logs.';

  @override
  String get audioEngine => 'Audio engine';

  @override
  String audioEngineHint(Object platform) {
    return 'Recommended for your platform: $platform';
  }

  @override
  String get audioEngineJustAudioMK => 'Just Audio MK';

  @override
  String get audioEngineJustAudio => 'Just Audio';

  @override
  String get audioEngineStandart => 'Standart';

  @override
  String get recursiveFiles => 'Recursively adding files';

  @override
  String get recursiveFilesHint =>
      'The player will check not only the top folder, but also all subfolders to add local tracks.';

  @override
  String get playlistArea => 'Playlist opening area';

  @override
  String get playlistAreaHint =>
      'When you hover to the left side of the screen, the playlist view will automatically open.';

  @override
  String get stateIndicator => 'State indicator';

  @override
  String get stateIndicatorHint =>
      'Turn on/off the status indicator that notifies you when network operations are being performed.';

  @override
  String get transitionSpeed => 'Transition speed';

  @override
  String get transitionSpeedHint =>
      'Change the speed of most animations in the application.';

  @override
  String get dynamicWindowColor => 'Dynamic window color';

  @override
  String get dynamicWindowColorHint =>
      'The window color will change dynamically depending on the content on the screen.';

  @override
  String get restoreDefaults => 'Restore defaults';

  @override
  String get restoreDefaultsHint =>
      'Reset player settings to factory defaults. After resetting, it is recommended to restart the player.';

  @override
  String get restore => 'Restore';

  @override
  String get again => 'Again';

  @override
  String get searchInYandex => 'Search';

  @override
  String get searchInYandexHint =>
      'Add tracks found in Yandex Music to the track search in the playlist';

  @override
  String get yandexPreload => 'Yandex Music Preload';

  @override
  String get yandexPreloadHint =>
      'When the player starts, Yandex Music will initialize during the player\'s loading to speed up the process of interacting.';

  @override
  String get originalCoverSize => 'Original cover size';

  @override
  String get originalCoverSizeHint =>
      'When viewing an enlarged cover, it will be at its maximum size instead of the standard 1000x1000.';

  @override
  String get quality => 'Quality';

  @override
  String get qualityHint => 'Quality of downloaded tracks.';

  @override
  String get qualityLossless => 'Lossless (Max)';

  @override
  String get qualityNormal => 'Normal (256kbps)';

  @override
  String get qualityLow => 'Low (64kbps)';

  @override
  String get token => 'Token';

  @override
  String get tokenHint => 'Your Yandex account token.';

  @override
  String get tokenPlaceholder => 'Enter token here';

  @override
  String get database => 'Database';

  @override
  String databaseInfo(Object inited, Object error) {
    return 'Inited: $inited || LastError: $error';
  }

  @override
  String get nativeControl => 'NativeControl';

  @override
  String nativeControlInfo(Object inited, Object tries, Object error) {
    return 'Inited: $inited || Init tries: $tries || LastError: $error';
  }
}
