// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class AppLocalizationsIt extends AppLocalizations {
  AppLocalizationsIt([String locale = 'it']) : super(locale);

  @override
  String get appTitle => 'quark: dove inizia il suono';

  @override
  String get selectFolderHint =>
      'Seleziona la cartella con le tracce.\nPuoi anche collegare il tuo account di streaming.';

  @override
  String get pickFolder => 'Scegli cartella';

  @override
  String get restorePlaylist => 'Ripristina playlist';

  @override
  String get yandexMusic => 'Yandex Music';

  @override
  String get youtubeMusic => 'YouTube Music';

  @override
  String get vkMusic => 'VK Music';

  @override
  String get soundCloud => 'SoundCloud';

  @override
  String get search => 'Cerca';

  @override
  String get settings => 'Impostazioni';

  @override
  String get login => 'Accedi';

  @override
  String get logout => 'Esci';

  @override
  String get deleteAllPlaylists => 'Eliminare tutte le playlist?';

  @override
  String get deleteAllPlaylistsDesc =>
      'Tutte le playlist locali e le relative tracce verranno eliminate definitivamente.';

  @override
  String get cancel => 'Annulla';

  @override
  String get delete => 'Elimina';

  @override
  String playlistError(Object error) {
    return 'Errore nel caricamento della playlist: $error';
  }

  @override
  String get preferences => 'Preferenze';

  @override
  String get debug => 'Debug';

  @override
  String get main => 'Principale';

  @override
  String get warning => 'ATTENZIONE';

  @override
  String get databaseWarning =>
      'Il database non è disponibile o contiene errori. Le modifiche potrebbero non essere salvate. Controlla i log.';

  @override
  String get audioEngine => 'Motore audio';

  @override
  String audioEngineHint(Object platform) {
    return 'Consigliato per la tua piattaforma: $platform';
  }

  @override
  String get audioEngineJustAudioMK => 'Just Audio MK';

  @override
  String get audioEngineJustAudio => 'Just Audio';

  @override
  String get audioEngineStandart => 'Standard';

  @override
  String get recursiveFiles => 'Aggiunta ricorsiva di file';

  @override
  String get recursiveFilesHint =>
      'Il player verificherà non solo la cartella principale, ma anche tutte le sottocartelle per aggiungere tracce locali.';

  @override
  String get playlistArea => 'Area di apertura playlist';

  @override
  String get playlistAreaHint =>
      'Passando il cursore sul lato sinistro dello schermo, la playlist si aprirà automaticamente.';

  @override
  String get stateIndicator => 'Indicatore di stato';

  @override
  String get stateIndicatorHint =>
      'Attiva/disattiva l\'indicatore di stato che notifica quando vengono eseguite operazioni di rete.';

  @override
  String get transitionSpeed => 'Velocità di transizione';

  @override
  String get transitionSpeedHint =>
      'Modifica la velocità della maggior parte delle animazioni nell\'applicazione.';

  @override
  String get dynamicWindowColor => 'Colore finestra dinamico';

  @override
  String get dynamicWindowColorHint =>
      'Il colore della finestra cambierà dinamicamente in base al contenuto sullo schermo.';

  @override
  String get restoreDefaults => 'Ripristina predefiniti';

  @override
  String get restoreDefaultsHint =>
      'Reimposta le impostazioni del player ai valori di fabbrica. Si consiglia di riavviare dopo.';

  @override
  String get restore => 'Ripristina';

  @override
  String get again => 'Di nuovo';

  @override
  String get searchInYandex => 'Cerca';

  @override
  String get searchInYandexHint =>
      'Aggiungere le tracce trovate in Yandex Music alla ricerca tracce nella playlist';

  @override
  String get yandexPreload => 'Precaricamento Yandex Music';

  @override
  String get yandexPreloadHint =>
      'All\'avvio, Yandex Music si inizializzerà durante il caricamento per velocizzare l\'interazione.';

  @override
  String get originalCoverSize => 'Dimensione copertina originale';

  @override
  String get originalCoverSizeHint =>
      'Visualizzando una copertina ingrandita, sarà mostrata alla dimensione massima invece del 1000x1000 standard.';

  @override
  String get quality => 'Qualità';

  @override
  String get qualityHint => 'Qualità delle tracce scaricate.';

  @override
  String get qualityLossless => 'Senza perdita (Max.)';

  @override
  String get qualityNormal => 'Normale (256 kbps)';

  @override
  String get qualityLow => 'Bassa (64 kbps)';

  @override
  String get token => 'Token';

  @override
  String get tokenHint => 'Il tuo token account Yandex.';

  @override
  String get tokenPlaceholder => 'Inserisci il token';

  @override
  String get database => 'Database';

  @override
  String databaseInfo(Object inited, Object error) {
    return 'Inizializzato: $inited || Ultimo errore: $error';
  }

  @override
  String get nativeControl => 'NativeControl';

  @override
  String nativeControlInfo(Object inited, Object tries, Object error) {
    return 'Inizializzato: $inited || Tentativi: $tries || Ultimo errore: $error';
  }
}
