import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_it.dart';
import 'app_localizations_pl.dart';
import 'app_localizations_pt.dart';
import 'app_localizations_ru.dart';
import 'app_localizations_tr.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('it'),
    Locale('pl'),
    Locale('pt'),
    Locale('ru'),
    Locale('tr'),
    Locale('zh'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'quark: where sound begins'**
  String get appTitle;

  /// No description provided for @selectFolderHint.
  ///
  /// In en, this message translates to:
  /// **'Select the folder with tracks.\nYou can also link your streaming account to use it.'**
  String get selectFolderHint;

  /// No description provided for @pickFolder.
  ///
  /// In en, this message translates to:
  /// **'Pick folder'**
  String get pickFolder;

  /// No description provided for @restorePlaylist.
  ///
  /// In en, this message translates to:
  /// **'Restore playlist'**
  String get restorePlaylist;

  /// No description provided for @yandexMusic.
  ///
  /// In en, this message translates to:
  /// **'Yandex Music'**
  String get yandexMusic;

  /// No description provided for @youtubeMusic.
  ///
  /// In en, this message translates to:
  /// **'YouTube Music'**
  String get youtubeMusic;

  /// No description provided for @vkMusic.
  ///
  /// In en, this message translates to:
  /// **'VK Music'**
  String get vkMusic;

  /// No description provided for @soundCloud.
  ///
  /// In en, this message translates to:
  /// **'SoundCloud'**
  String get soundCloud;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get login;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get logout;

  /// No description provided for @deleteAllPlaylists.
  ///
  /// In en, this message translates to:
  /// **'Delete all playlists?'**
  String get deleteAllPlaylists;

  /// No description provided for @deleteAllPlaylistsDesc.
  ///
  /// In en, this message translates to:
  /// **'This will permanently delete all local playlists and their tracks.'**
  String get deleteAllPlaylistsDesc;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @playlistError.
  ///
  /// In en, this message translates to:
  /// **'Playlist loading error: {error}'**
  String playlistError(Object error);

  /// No description provided for @preferences.
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get preferences;

  /// No description provided for @debug.
  ///
  /// In en, this message translates to:
  /// **'Debug'**
  String get debug;

  /// No description provided for @main.
  ///
  /// In en, this message translates to:
  /// **'Main'**
  String get main;

  /// No description provided for @warning.
  ///
  /// In en, this message translates to:
  /// **'WARNING'**
  String get warning;

  /// No description provided for @databaseWarning.
  ///
  /// In en, this message translates to:
  /// **'The database is unavailable or contains errors. Changes may not be saved. Check the logs.'**
  String get databaseWarning;

  /// No description provided for @audioEngine.
  ///
  /// In en, this message translates to:
  /// **'Audio engine'**
  String get audioEngine;

  /// No description provided for @audioEngineHint.
  ///
  /// In en, this message translates to:
  /// **'Recommended for your platform: {platform}'**
  String audioEngineHint(Object platform);

  /// No description provided for @audioEngineJustAudioMK.
  ///
  /// In en, this message translates to:
  /// **'Just Audio MK'**
  String get audioEngineJustAudioMK;

  /// No description provided for @audioEngineJustAudio.
  ///
  /// In en, this message translates to:
  /// **'Just Audio'**
  String get audioEngineJustAudio;

  /// No description provided for @audioEngineStandart.
  ///
  /// In en, this message translates to:
  /// **'Standart'**
  String get audioEngineStandart;

  /// No description provided for @recursiveFiles.
  ///
  /// In en, this message translates to:
  /// **'Recursively adding files'**
  String get recursiveFiles;

  /// No description provided for @recursiveFilesHint.
  ///
  /// In en, this message translates to:
  /// **'The player will check not only the top folder, but also all subfolders to add local tracks.'**
  String get recursiveFilesHint;

  /// No description provided for @playlistArea.
  ///
  /// In en, this message translates to:
  /// **'Playlist opening area'**
  String get playlistArea;

  /// No description provided for @playlistAreaHint.
  ///
  /// In en, this message translates to:
  /// **'When you hover to the left side of the screen, the playlist view will automatically open.'**
  String get playlistAreaHint;

  /// No description provided for @stateIndicator.
  ///
  /// In en, this message translates to:
  /// **'State indicator'**
  String get stateIndicator;

  /// No description provided for @stateIndicatorHint.
  ///
  /// In en, this message translates to:
  /// **'Turn on/off the status indicator that notifies you when network operations are being performed.'**
  String get stateIndicatorHint;

  /// No description provided for @transitionSpeed.
  ///
  /// In en, this message translates to:
  /// **'Transition speed'**
  String get transitionSpeed;

  /// No description provided for @transitionSpeedHint.
  ///
  /// In en, this message translates to:
  /// **'Change the speed of most animations in the application.'**
  String get transitionSpeedHint;

  /// No description provided for @dynamicWindowColor.
  ///
  /// In en, this message translates to:
  /// **'Dynamic window color'**
  String get dynamicWindowColor;

  /// No description provided for @dynamicWindowColorHint.
  ///
  /// In en, this message translates to:
  /// **'The window color will change dynamically depending on the content on the screen.'**
  String get dynamicWindowColorHint;

  /// No description provided for @restoreDefaults.
  ///
  /// In en, this message translates to:
  /// **'Restore defaults'**
  String get restoreDefaults;

  /// No description provided for @restoreDefaultsHint.
  ///
  /// In en, this message translates to:
  /// **'Reset player settings to factory defaults. After resetting, it is recommended to restart the player.'**
  String get restoreDefaultsHint;

  /// No description provided for @restore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get restore;

  /// No description provided for @again.
  ///
  /// In en, this message translates to:
  /// **'Again'**
  String get again;

  /// No description provided for @searchInYandex.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get searchInYandex;

  /// No description provided for @searchInYandexHint.
  ///
  /// In en, this message translates to:
  /// **'Add tracks found in Yandex Music to the track search in the playlist'**
  String get searchInYandexHint;

  /// No description provided for @yandexPreload.
  ///
  /// In en, this message translates to:
  /// **'Yandex Music Preload'**
  String get yandexPreload;

  /// No description provided for @yandexPreloadHint.
  ///
  /// In en, this message translates to:
  /// **'When the player starts, Yandex Music will initialize during the player\'s loading to speed up the process of interacting.'**
  String get yandexPreloadHint;

  /// No description provided for @originalCoverSize.
  ///
  /// In en, this message translates to:
  /// **'Original cover size'**
  String get originalCoverSize;

  /// No description provided for @originalCoverSizeHint.
  ///
  /// In en, this message translates to:
  /// **'When viewing an enlarged cover, it will be at its maximum size instead of the standard 1000x1000.'**
  String get originalCoverSizeHint;

  /// No description provided for @quality.
  ///
  /// In en, this message translates to:
  /// **'Quality'**
  String get quality;

  /// No description provided for @qualityHint.
  ///
  /// In en, this message translates to:
  /// **'Quality of downloaded tracks.'**
  String get qualityHint;

  /// No description provided for @qualityLossless.
  ///
  /// In en, this message translates to:
  /// **'Lossless (Max)'**
  String get qualityLossless;

  /// No description provided for @qualityNormal.
  ///
  /// In en, this message translates to:
  /// **'Normal (256kbps)'**
  String get qualityNormal;

  /// No description provided for @qualityLow.
  ///
  /// In en, this message translates to:
  /// **'Low (64kbps)'**
  String get qualityLow;

  /// No description provided for @token.
  ///
  /// In en, this message translates to:
  /// **'Token'**
  String get token;

  /// No description provided for @tokenHint.
  ///
  /// In en, this message translates to:
  /// **'Your Yandex account token.'**
  String get tokenHint;

  /// No description provided for @tokenPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Enter token here'**
  String get tokenPlaceholder;

  /// No description provided for @database.
  ///
  /// In en, this message translates to:
  /// **'Database'**
  String get database;

  /// No description provided for @databaseInfo.
  ///
  /// In en, this message translates to:
  /// **'Inited: {inited} || LastError: {error}'**
  String databaseInfo(Object inited, Object error);

  /// No description provided for @nativeControl.
  ///
  /// In en, this message translates to:
  /// **'NativeControl'**
  String get nativeControl;

  /// No description provided for @nativeControlInfo.
  ///
  /// In en, this message translates to:
  /// **'Inited: {inited} || Init tries: {tries} || LastError: {error}'**
  String nativeControlInfo(Object inited, Object tries, Object error);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
    'de',
    'en',
    'es',
    'fr',
    'it',
    'pl',
    'pt',
    'ru',
    'tr',
    'zh',
  ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
    case 'it':
      return AppLocalizationsIt();
    case 'pl':
      return AppLocalizationsPl();
    case 'pt':
      return AppLocalizationsPt();
    case 'ru':
      return AppLocalizationsRu();
    case 'tr':
      return AppLocalizationsTr();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
