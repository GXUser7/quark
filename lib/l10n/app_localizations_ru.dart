// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'quark: где начинается звук';

  @override
  String get selectFolderHint =>
      'Выберите папку с треками.\nВы также можете подключить стриминговый аккаунт.';

  @override
  String get pickFolder => 'Выбрать папку';

  @override
  String get restorePlaylist => 'Восстановить плейлист';

  @override
  String get yandexMusic => 'Яндекс Музыка';

  @override
  String get youtubeMusic => 'YouTube Music';

  @override
  String get vkMusic => 'VK Музыка';

  @override
  String get soundCloud => 'SoundCloud';

  @override
  String get search => 'Поиск';

  @override
  String get settings => 'Настройки';

  @override
  String get login => 'Войти';

  @override
  String get logout => 'Выйти';

  @override
  String get deleteAllPlaylists => 'Удалить все плейлисты?';

  @override
  String get deleteAllPlaylistsDesc =>
      'Это навсегда удалит все локальные плейлисты и их треки.';

  @override
  String get cancel => 'Отмена';

  @override
  String get delete => 'Удалить';

  @override
  String playlistError(Object error) {
    return 'Ошибка загрузки плейлиста: $error';
  }

  @override
  String get preferences => 'Настройки';

  @override
  String get debug => 'Отладка';

  @override
  String get main => 'Главная';

  @override
  String get warning => 'ПРЕДУПРЕЖДЕНИЕ';

  @override
  String get databaseWarning =>
      'База данных недоступна или содержит ошибки. Изменения могут не сохраниться. Проверьте логи.';

  @override
  String get audioEngine => 'Аудио движок';

  @override
  String audioEngineHint(Object platform) {
    return 'Рекомендуется для вашей платформы: $platform';
  }

  @override
  String get audioEngineJustAudioMK => 'Just Audio MK';

  @override
  String get audioEngineJustAudio => 'Just Audio';

  @override
  String get audioEngineStandart => 'Стандартный';

  @override
  String get recursiveFiles => 'Рекурсивное добавление файлов';

  @override
  String get recursiveFilesHint =>
      'Плеер будет проверять не только верхнюю папку, но и все подпапки для добавления локальных треков.';

  @override
  String get playlistArea => 'Область открытия плейлиста';

  @override
  String get playlistAreaHint =>
      'При наведении на левую часть экрана плейлист откроется автоматически.';

  @override
  String get stateIndicator => 'Индикатор состояния';

  @override
  String get stateIndicatorHint =>
      'Включить/выключить индикатор, уведомляющий о выполнении сетевых операций.';

  @override
  String get transitionSpeed => 'Скорость переходов';

  @override
  String get transitionSpeedHint =>
      'Изменяет скорость большинства анимаций в приложении.';

  @override
  String get dynamicWindowColor => 'Динамический цвет окна';

  @override
  String get dynamicWindowColorHint =>
      'Цвет окна будет динамически меняться в зависимости от содержимого на экране.';

  @override
  String get restoreDefaults => 'Сбросить настройки';

  @override
  String get restoreDefaultsHint =>
      'Сбросить настройки плеера до заводских. После сброса рекомендуется перезапустить плеер.';

  @override
  String get restore => 'Сбросить';

  @override
  String get again => 'Снова';

  @override
  String get searchInYandex => 'Поиск';

  @override
  String get searchInYandexHint =>
      'Добавить треки, найденные в Яндекс Музыке, в поиск треков в плейлисте';

  @override
  String get yandexPreload => 'Предзагрузка Яндекс Музыки';

  @override
  String get yandexPreloadHint =>
      'При запуске плеера Яндекс Музыка инициализируется во время загрузки, чтобы ускорить работу.';

  @override
  String get originalCoverSize => 'Оригинальный размер обложки';

  @override
  String get originalCoverSizeHint =>
      'При просмотре увеличенной обложки она будет отображаться в максимальном размере вместо стандартного 1000x1000.';

  @override
  String get quality => 'Качество';

  @override
  String get qualityHint => 'Качество загружаемых треков.';

  @override
  String get qualityLossless => 'Без потерь (Макс.)';

  @override
  String get qualityNormal => 'Нормальное (256 кбит/с)';

  @override
  String get qualityLow => 'Низкое (64 кбит/с)';

  @override
  String get token => 'Токен';

  @override
  String get tokenHint => 'Ваш токен аккаунта Яндекса.';

  @override
  String get tokenPlaceholder => 'Введите токен';

  @override
  String get database => 'База данных';

  @override
  String databaseInfo(Object inited, Object error) {
    return 'Инициализирована: $inited || Последняя ошибка: $error';
  }

  @override
  String get nativeControl => 'NativeControl';

  @override
  String nativeControlInfo(Object inited, Object tries, Object error) {
    return 'Инициализирован: $inited || Попыток: $tries || Последняя ошибка: $error';
  }
}
