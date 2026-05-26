// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'quark : là où le son commence';

  @override
  String get selectFolderHint =>
      'Sélectionnez le dossier contenant vos pistes.\nVous pouvez aussi connecter un compte de streaming.';

  @override
  String get pickFolder => 'Choisir un dossier';

  @override
  String get restorePlaylist => 'Restaurer la playlist';

  @override
  String get yandexMusic => 'Yandex Music';

  @override
  String get youtubeMusic => 'YouTube Music';

  @override
  String get vkMusic => 'VK Music';

  @override
  String get soundCloud => 'SoundCloud';

  @override
  String get search => 'Rechercher';

  @override
  String get settings => 'Paramètres';

  @override
  String get login => 'Connexion';

  @override
  String get logout => 'Déconnexion';

  @override
  String get deleteAllPlaylists => 'Supprimer toutes les playlists ?';

  @override
  String get deleteAllPlaylistsDesc =>
      'Toutes les playlists locales et leurs pistes seront supprimées définitivement.';

  @override
  String get cancel => 'Annuler';

  @override
  String get delete => 'Supprimer';

  @override
  String playlistError(Object error) {
    return 'Erreur de chargement de la playlist : $error';
  }

  @override
  String get preferences => 'Préférences';

  @override
  String get debug => 'Débogage';

  @override
  String get main => 'Principal';

  @override
  String get warning => 'AVERTISSEMENT';

  @override
  String get databaseWarning =>
      'La base de données est indisponible ou contient des erreurs. Les modifications peuvent ne pas être enregistrées. Vérifiez les journaux.';

  @override
  String get audioEngine => 'Moteur audio';

  @override
  String audioEngineHint(Object platform) {
    return 'Recommandé pour votre plateforme : $platform';
  }

  @override
  String get audioEngineJustAudioMK => 'Just Audio MK';

  @override
  String get audioEngineJustAudio => 'Just Audio';

  @override
  String get audioEngineStandart => 'Standard';

  @override
  String get recursiveFiles => 'Ajout récursif de fichiers';

  @override
  String get recursiveFilesHint =>
      'Le lecteur vérifiera non seulement le dossier principal, mais aussi tous les sous-dossiers pour ajouter des pistes locales.';

  @override
  String get playlistArea => 'Zone d\'ouverture de playlist';

  @override
  String get playlistAreaHint =>
      'En survolant le côté gauche de l\'écran, la playlist s\'ouvrira automatiquement.';

  @override
  String get stateIndicator => 'Indicateur d\'état';

  @override
  String get stateIndicatorHint =>
      'Activer/désactiver l\'indicateur de statut qui notifie lors d\'opérations réseau.';

  @override
  String get transitionSpeed => 'Vitesse de transition';

  @override
  String get transitionSpeedHint =>
      'Modifie la vitesse de la plupart des animations de l\'application.';

  @override
  String get dynamicWindowColor => 'Couleur de fenêtre dynamique';

  @override
  String get dynamicWindowColorHint =>
      'La couleur de la fenêtre changera dynamiquement selon le contenu affiché.';

  @override
  String get restoreDefaults => 'Restaurer les paramètres';

  @override
  String get restoreDefaultsHint =>
      'Réinitialise les paramètres du lecteur aux valeurs d\'usine. Un redémarrage est recommandé après.';

  @override
  String get restore => 'Restaurer';

  @override
  String get again => 'À nouveau';

  @override
  String get searchInYandex => 'Rechercher';

  @override
  String get searchInYandexHint =>
      'Ajouter les pistes trouvées dans Yandex Music à la recherche dans la playlist';

  @override
  String get yandexPreload => 'Préchargement Yandex Music';

  @override
  String get yandexPreloadHint =>
      'Au démarrage, Yandex Music s\'initialisera pendant le chargement pour accélérer l\'interaction.';

  @override
  String get originalCoverSize => 'Taille de pochette originale';

  @override
  String get originalCoverSizeHint =>
      'Lors de l\'affichage d\'une pochette agrandie, elle sera à sa taille maximale au lieu du 1000x1000 standard.';

  @override
  String get quality => 'Qualité';

  @override
  String get qualityHint => 'Qualité des pistes téléchargées.';

  @override
  String get qualityLossless => 'Sans perte (Max.)';

  @override
  String get qualityNormal => 'Normale (256 kbps)';

  @override
  String get qualityLow => 'Basse (64 kbps)';

  @override
  String get token => 'Jeton';

  @override
  String get tokenHint => 'Votre jeton de compte Yandex.';

  @override
  String get tokenPlaceholder => 'Entrez le jeton ici';

  @override
  String get database => 'Base de données';

  @override
  String databaseInfo(Object inited, Object error) {
    return 'Initialisée : $inited || Dernière erreur : $error';
  }

  @override
  String get nativeControl => 'NativeControl';

  @override
  String nativeControlInfo(Object inited, Object tries, Object error) {
    return 'Initialisé : $inited || Tentatives : $tries || Dernière erreur : $error';
  }
}
