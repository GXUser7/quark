// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Polish (`pl`).
class AppLocalizationsPl extends AppLocalizations {
  AppLocalizationsPl([String locale = 'pl']) : super(locale);

  @override
  String get appTitle => 'quark: gdzie zaczyna się dźwięk';

  @override
  String get selectFolderHint =>
      'Wybierz folder z utworami.\nMożesz też połączyć konto streamingowe.';

  @override
  String get pickFolder => 'Wybierz folder';

  @override
  String get restorePlaylist => 'Przywróć playlistę';

  @override
  String get yandexMusic => 'Yandex Music';

  @override
  String get youtubeMusic => 'YouTube Music';

  @override
  String get vkMusic => 'VK Music';

  @override
  String get soundCloud => 'SoundCloud';

  @override
  String get search => 'Szukaj';

  @override
  String get settings => 'Ustawienia';

  @override
  String get login => 'Zaloguj';

  @override
  String get logout => 'Wyloguj';

  @override
  String get deleteAllPlaylists => 'Usunąć wszystkie playlisty?';

  @override
  String get deleteAllPlaylistsDesc =>
      'Wszystkie lokalne playlisty i ich utwory zostaną trwale usunięte.';

  @override
  String get cancel => 'Anuluj';

  @override
  String get delete => 'Usuń';

  @override
  String playlistError(Object error) {
    return 'Błąd ładowania playlisty: $error';
  }

  @override
  String get preferences => 'Preferencje';

  @override
  String get debug => 'Diagnostyka';

  @override
  String get main => 'Główna';

  @override
  String get warning => 'OSTRZEŻENIE';

  @override
  String get databaseWarning =>
      'Baza danych jest niedostępna lub zawiera błędy. Zmiany mogą nie zostać zapisane. Sprawdź logi.';

  @override
  String get audioEngine => 'Silnik audio';

  @override
  String audioEngineHint(Object platform) {
    return 'Zalecany dla twojej platformy: $platform';
  }

  @override
  String get audioEngineJustAudioMK => 'Just Audio MK';

  @override
  String get audioEngineJustAudio => 'Just Audio';

  @override
  String get audioEngineStandart => 'Standardowy';

  @override
  String get recursiveFiles => 'Rekurencyjne dodawanie plików';

  @override
  String get recursiveFilesHint =>
      'Odtwarzacz sprawdzi nie tylko główny folder, ale też wszystkie podfoldery w celu dodania lokalnych utworów.';

  @override
  String get playlistArea => 'Obszar otwierania playlisty';

  @override
  String get playlistAreaHint =>
      'Po najechaniu na lewą stronę ekranu playlista otworzy się automatycznie.';

  @override
  String get stateIndicator => 'Wskaźnik stanu';

  @override
  String get stateIndicatorHint =>
      'Włącz/wyłącz wskaźnik statusu informujący o wykonywanych operacjach sieciowych.';

  @override
  String get transitionSpeed => 'Szybkość przejść';

  @override
  String get transitionSpeedHint =>
      'Zmienia szybkość większości animacji w aplikacji.';

  @override
  String get dynamicWindowColor => 'Dynamiczny kolor okna';

  @override
  String get dynamicWindowColorHint =>
      'Kolor okna będzie zmieniał się dynamicznie w zależności od zawartości na ekranie.';

  @override
  String get restoreDefaults => 'Przywróć ustawienia';

  @override
  String get restoreDefaultsHint =>
      'Resetuje ustawienia odtwarzacza do wartości fabrycznych. Po resecie zalecany restart.';

  @override
  String get restore => 'Przywróć';

  @override
  String get again => 'Ponownie';

  @override
  String get searchInYandex => 'Szukaj';

  @override
  String get searchInYandexHint =>
      'Dodaj utwory znalezione w Yandex Music do wyszukiwania w playliście';

  @override
  String get yandexPreload => 'Wstępne ładowanie Yandex Music';

  @override
  String get yandexPreloadHint =>
      'Przy starcie Yandex Music zainicjuje się podczas ładowania, aby przyspieszyć interakcję.';

  @override
  String get originalCoverSize => 'Oryginalny rozmiar okładki';

  @override
  String get originalCoverSizeHint =>
      'Przy przeglądaniu powiększonej okładki będzie ona wyświetlana w maksymalnym rozmiarze zamiast standardowego 1000x1000.';

  @override
  String get quality => 'Jakość';

  @override
  String get qualityHint => 'Jakość pobieranych utworów.';

  @override
  String get qualityLossless => 'Bezstratna (Maks.)';

  @override
  String get qualityNormal => 'Normalna (256 kbps)';

  @override
  String get qualityLow => 'Niska (64 kbps)';

  @override
  String get token => 'Token';

  @override
  String get tokenHint => 'Twój token konta Yandex.';

  @override
  String get tokenPlaceholder => 'Wpisz token';

  @override
  String get database => 'Baza danych';

  @override
  String databaseInfo(Object inited, Object error) {
    return 'Zainicjowana: $inited || Ostatni błąd: $error';
  }

  @override
  String get nativeControl => 'NativeControl';

  @override
  String nativeControlInfo(Object inited, Object tries, Object error) {
    return 'Zainicjowany: $inited || Próby: $tries || Ostatni błąd: $error';
  }
}
