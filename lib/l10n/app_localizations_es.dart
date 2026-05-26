// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'quark: donde comienza el sonido';

  @override
  String get selectFolderHint =>
      'Selecciona la carpeta con tus pistas.\nTambién puedes vincular tu cuenta de streaming.';

  @override
  String get pickFolder => 'Seleccionar carpeta';

  @override
  String get restorePlaylist => 'Restaurar lista';

  @override
  String get yandexMusic => 'Yandex Music';

  @override
  String get youtubeMusic => 'YouTube Music';

  @override
  String get vkMusic => 'VK Music';

  @override
  String get soundCloud => 'SoundCloud';

  @override
  String get search => 'Buscar';

  @override
  String get settings => 'Ajustes';

  @override
  String get login => 'Iniciar sesión';

  @override
  String get logout => 'Cerrar sesión';

  @override
  String get deleteAllPlaylists => '¿Eliminar todas las listas?';

  @override
  String get deleteAllPlaylistsDesc =>
      'Esto eliminará permanentemente todas las listas locales y sus pistas.';

  @override
  String get cancel => 'Cancelar';

  @override
  String get delete => 'Eliminar';

  @override
  String playlistError(Object error) {
    return 'Error al cargar la lista: $error';
  }

  @override
  String get preferences => 'Preferencias';

  @override
  String get debug => 'Depuración';

  @override
  String get main => 'Principal';

  @override
  String get warning => 'ADVERTENCIA';

  @override
  String get databaseWarning =>
      'La base de datos no está disponible o contiene errores. Los cambios pueden no guardarse. Revisa los registros.';

  @override
  String get audioEngine => 'Motor de audio';

  @override
  String audioEngineHint(Object platform) {
    return 'Recomendado para tu plataforma: $platform';
  }

  @override
  String get audioEngineJustAudioMK => 'Just Audio MK';

  @override
  String get audioEngineJustAudio => 'Just Audio';

  @override
  String get audioEngineStandart => 'Estándar';

  @override
  String get recursiveFiles => 'Añadir archivos recursivamente';

  @override
  String get recursiveFilesHint =>
      'El reproductor comprobará no solo la carpeta principal, sino también todas las subcarpetas para añadir pistas locales.';

  @override
  String get playlistArea => 'Área de apertura de lista';

  @override
  String get playlistAreaHint =>
      'Al pasar el cursor por el lado izquierdo de la pantalla, la vista de lista se abrirá automáticamente.';

  @override
  String get stateIndicator => 'Indicador de estado';

  @override
  String get stateIndicatorHint =>
      'Activa/desactiva el indicador que notifica cuando se realizan operaciones de red.';

  @override
  String get transitionSpeed => 'Velocidad de transición';

  @override
  String get transitionSpeedHint =>
      'Cambia la velocidad de la mayoría de animaciones en la aplicación.';

  @override
  String get dynamicWindowColor => 'Color dinámico de ventana';

  @override
  String get dynamicWindowColorHint =>
      'El color de la ventana cambiará dinámicamente según el contenido en pantalla.';

  @override
  String get restoreDefaults => 'Restaurar valores';

  @override
  String get restoreDefaultsHint =>
      'Restablece la configuración a los valores de fábrica. Se recomienda reiniciar el reproductor después.';

  @override
  String get restore => 'Restaurar';

  @override
  String get again => 'De nuevo';

  @override
  String get searchInYandex => 'Buscar';

  @override
  String get searchInYandexHint =>
      'Añadir pistas encontradas en Yandex Music a la búsqueda en la lista';

  @override
  String get yandexPreload => 'Precarga de Yandex Music';

  @override
  String get yandexPreloadHint =>
      'Al iniciar, Yandex Music se inicializará durante la carga para acelerar la interacción.';

  @override
  String get originalCoverSize => 'Tamaño original de portada';

  @override
  String get originalCoverSizeHint =>
      'Al ver una portada ampliada, se mostrará en su tamaño máximo en lugar del estándar 1000x1000.';

  @override
  String get quality => 'Calidad';

  @override
  String get qualityHint => 'Calidad de las pistas descargadas.';

  @override
  String get qualityLossless => 'Sin pérdida (Máx.)';

  @override
  String get qualityNormal => 'Normal (256 kbps)';

  @override
  String get qualityLow => 'Baja (64 kbps)';

  @override
  String get token => 'Token';

  @override
  String get tokenHint => 'Tu token de cuenta de Yandex.';

  @override
  String get tokenPlaceholder => 'Introduce el token';

  @override
  String get database => 'Base de datos';

  @override
  String databaseInfo(Object inited, Object error) {
    return 'Iniciada: $inited || Último error: $error';
  }

  @override
  String get nativeControl => 'NativeControl';

  @override
  String nativeControlInfo(Object inited, Object tries, Object error) {
    return 'Iniciado: $inited || Intentos: $tries || Último error: $error';
  }
}
