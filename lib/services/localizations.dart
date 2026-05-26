import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppLocalizations {
  final Locale locale;
  late Map<String, String> _localizedStrings;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  Future<void> load() async {
    final jsonString = await rootBundle.loadString(
      'lib/l10n/app_${locale.languageCode}.arb',
    );
    final Map<String, dynamic> mapped = json.decode(jsonString);
    _localizedStrings = mapped.map((key, value) => MapEntry(key, value.toString()));
  }

  String translate(String key, {Map<String, String>? placeholders}) {
    String result = _localizedStrings[key]!;
    if (result == null) return key;
    
    if (placeholders != null) {
      placeholders.forEach((key, value) {
        result = result!.replaceFirst('{$key}', value);
      });
    }
    return result;
  }

  String get appTitle => translate('appTitle');
  String get selectFolderHint => translate('selectFolderHint');
  String get pickFolder => translate('pickFolder');
  String get restorePlaylist => translate('restorePlaylist');
  String get yandexMusic => translate('yandexMusic');
  String get youtubeMusic => translate('youtubeMusic');
  String get vkMusic => translate('vkMusic');
  String get soundCloud => translate('soundCloud');
  String get search => translate('search');
  String get settings => translate('settings');
  String get login => translate('login');
  String get logout => translate('logout');
  
  String playlistError(String error) => 
      translate('playlistError', placeholders: {'error': error});
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      ['en', 'ru', 'es', 'fr', 'de', 'pt', 'zh', 'ja', 'ko', 'tr', 'ar']
          .contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    final localizations = AppLocalizations(locale);
    await localizations.load();
    return localizations;
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}