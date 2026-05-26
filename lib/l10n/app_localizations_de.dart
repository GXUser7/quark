// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'quark: wo der Klang beginnt';

  @override
  String get selectFolderHint =>
      'Wähle den Ordner mit deinen Titeln.\nDu kannst auch ein Streaming-Konto verknüpfen.';

  @override
  String get pickFolder => 'Ordner auswählen';

  @override
  String get restorePlaylist => 'Playlist wiederherstellen';

  @override
  String get yandexMusic => 'Yandex Musik';

  @override
  String get youtubeMusic => 'YouTube Music';

  @override
  String get vkMusic => 'VK Musik';

  @override
  String get soundCloud => 'SoundCloud';

  @override
  String get search => 'Suchen';

  @override
  String get settings => 'Einstellungen';

  @override
  String get login => 'Anmelden';

  @override
  String get logout => 'Abmelden';

  @override
  String get deleteAllPlaylists => 'Alle Playlists löschen?';

  @override
  String get deleteAllPlaylistsDesc =>
      'Alle lokalen Playlists und deren Titel werden dauerhaft gelöscht.';

  @override
  String get cancel => 'Abbrechen';

  @override
  String get delete => 'Löschen';

  @override
  String playlistError(Object error) {
    return 'Fehler beim Laden der Playlist: $error';
  }

  @override
  String get preferences => 'Einstellungen';

  @override
  String get debug => 'Diagnose';

  @override
  String get main => 'Hauptseite';

  @override
  String get warning => 'WARNUNG';

  @override
  String get databaseWarning =>
      'Die Datenbank ist nicht verfügbar oder enthält Fehler. Änderungen werden möglicherweise nicht gespeichert. Protokolle prüfen.';

  @override
  String get audioEngine => 'Audio-Engine';

  @override
  String audioEngineHint(Object platform) {
    return 'Empfohlen für deine Plattform: $platform';
  }

  @override
  String get audioEngineJustAudioMK => 'Just Audio MK';

  @override
  String get audioEngineJustAudio => 'Just Audio';

  @override
  String get audioEngineStandart => 'Standard';

  @override
  String get recursiveFiles => 'Dateien rekursiv hinzufügen';

  @override
  String get recursiveFilesHint =>
      'Der Player durchsucht nicht nur den Hauptordner, sondern auch alle Unterordner nach lokalen Titeln.';

  @override
  String get playlistArea => 'Playlist-Öffnungsbereich';

  @override
  String get playlistAreaHint =>
      'Wenn du zur linken Seite des Bildschirms fährst, öffnet sich die Playlist automatisch.';

  @override
  String get stateIndicator => 'Statusanzeige';

  @override
  String get stateIndicatorHint =>
      'Statusanzeige ein-/ausschalten, die bei Netzwerkoperationen benachrichtigt.';

  @override
  String get transitionSpeed => 'Übergangsgeschwindigkeit';

  @override
  String get transitionSpeedHint =>
      'Ändert die Geschwindigkeit der meisten Animationen in der App.';

  @override
  String get dynamicWindowColor => 'Dynamische Fensterfarbe';

  @override
  String get dynamicWindowColorHint =>
      'Die Fensterfarbe ändert sich dynamisch je nach Inhalt auf dem Bildschirm.';

  @override
  String get restoreDefaults => 'Auf Standard zurücksetzen';

  @override
  String get restoreDefaultsHint =>
      'Setzt die Player-Einstellungen auf die Werkseinstellungen zurück. Danach wird ein Neustart empfohlen.';

  @override
  String get restore => 'Zurücksetzen';

  @override
  String get again => 'Nochmal';

  @override
  String get searchInYandex => 'Suchen';

  @override
  String get searchInYandexHint =>
      'In Yandex Music gefundene Titel zur Titelsuche in der Playlist hinzufügen';

  @override
  String get yandexPreload => 'Yandex Music Vorladen';

  @override
  String get yandexPreloadHint =>
      'Beim Start initialisiert sich Yandex Music während des Ladens, um die Interaktion zu beschleunigen.';

  @override
  String get originalCoverSize => 'Originale Covergröße';

  @override
  String get originalCoverSizeHint =>
      'Beim Anzeigen eines vergrößerten Covers wird es in maximaler Größe statt im Standard-1000x1000 angezeigt.';

  @override
  String get quality => 'Qualität';

  @override
  String get qualityHint => 'Qualität der heruntergeladenen Titel.';

  @override
  String get qualityLossless => 'Verlustfrei (Max.)';

  @override
  String get qualityNormal => 'Normal (256 kbps)';

  @override
  String get qualityLow => 'Niedrig (64 kbps)';

  @override
  String get token => 'Token';

  @override
  String get tokenHint => 'Dein Yandex-Konto-Token.';

  @override
  String get tokenPlaceholder => 'Token eingeben';

  @override
  String get database => 'Datenbank';

  @override
  String databaseInfo(Object inited, Object error) {
    return 'Initialisiert: $inited || Letzter Fehler: $error';
  }

  @override
  String get nativeControl => 'NativeControl';

  @override
  String nativeControlInfo(Object inited, Object tries, Object error) {
    return 'Initialisiert: $inited || Versuche: $tries || Letzter Fehler: $error';
  }
}
