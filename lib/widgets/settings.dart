import 'dart:io';
import 'dart:math';
import 'dart:ui';
import 'dart:async';
import 'package:quark/services/player/player.dart';

import 'state_indicator.dart';
import 'package:flutter/material.dart';
import 'package:yandex_music/yandex_music.dart';
import '../services/database/settings_engine.dart';
import 'package:quark/services/database/database.dart';
import 'package:quark/services/database/listen_logger.dart';
import 'package:interactive_slider/interactive_slider.dart';
import 'package:quark/services/native_controls/native_control.dart';
import 'package:quark/l10n/app_localizations.dart'; // ✅ Импорт локализации

class Settings extends StatefulWidget {
  final Function() closeView;
  const Settings({required this.closeView});

  @override
  State<StatefulWidget> createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  int taps = 0;
  
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!; 
    final size = MediaQuery.of(context).size;
    
    return Center(
      child: Container(
        width: min(size.width * 0.92, 800),

        decoration: BoxDecoration(
          borderRadius: BorderRadius.all(Radius.circular(15)),
          color: Color.fromARGB(0, 255, 255, 255),
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.all(Radius.circular(15)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 75, sigmaY: 75),
            child: Container(
              width: min(size.width * 0.92, 1040),
              height: min(size.height * 0.92, 1036),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: const BorderRadius.all(Radius.circular(20)),
                gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(0.15),
                    Colors.white.withOpacity(0.05),
                  ],
                ),
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 25),
                    Center(
                      child: GestureDetector(
                        onTap: () => setState(() {
                          taps += 1;
                        }),
                        behavior: HitTestBehavior.opaque,
                        child: Text(
                          l10n.preferences,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),

                    Padding(
                      padding: EdgeInsetsGeometry.only(left: 35, right: 35),
                      child: Row(
                        children: [
                          Text(
                            '🌐 ${l10n.settings}:',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Spacer(),
                          DropdownButton<Locale>(
                            dropdownColor: const Color.fromRGBO(44, 44, 44, 0.9),
                            value: Localizations.localeOf(context),
                            underline: SizedBox.shrink(),
                            style: TextStyle(color: Colors.white, fontSize: 13),
                            items: [
                              DropdownMenuItem(
                                value: Locale('en', ''),
                                child: Text('English'),
                              ),
                              DropdownMenuItem(
                                value: Locale('ru', ''),
                                child: Text('Русский'),
                              ),
                              DropdownMenuItem(
                                value: Locale('es', ''),
                                child: Text('Español'),
                              ),
                              DropdownMenuItem(
                                value: Locale('fr', ''),
                                child: Text('Français'),
                              ),
                              DropdownMenuItem(
                                value: Locale('de', ''),
                                child: Text('Deutsch'),
                              ),
                              DropdownMenuItem(
                                value: Locale('pt', ''),
                                child: Text('Português'),
                              ),
                              DropdownMenuItem(
                                value: Locale('zh', ''),
                                child: Text('中文'),
                              ),
                              DropdownMenuItem(
                                value: Locale('ja', ''),
                                child: Text('日本語'),
                              ),
                              DropdownMenuItem(
                                value: Locale('ko', ''),
                                child: Text('한국어'),
                              ),
                              DropdownMenuItem(
                                value: Locale('tr', ''),
                                child: Text('Türkçe'),
                              ),
                            ],
                            onChanged: (Locale? newLocale) async {
                              if (newLocale != null) {
                                await DatabaseStreamerService()
                                    .setAppLocale(newLocale);
                                if (mounted) {
                                  setState(() {});
                                }
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    if (taps >= 5) ...[
                      const SizedBox(height: 15),

                      Padding(
                        padding: EdgeInsetsGeometry.only(left: 35),
                        child: Text(
                          l10n.debug, 
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _DebugSettings(),
                    ],

                    Padding(
                      padding: EdgeInsetsGeometry.only(left: 35),
                      child: Text(
                        l10n.main, 
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _LocalSettings(),

                    const SizedBox(height: 15),

                    Padding(
                      padding: EdgeInsetsGeometry.only(left: 35),
                      child: Text(
                        l10n.yandexMusic, 
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _YandexMusicSettings(),

                    const SizedBox(height: 15),

                    Padding(
                      padding: EdgeInsetsGeometry.only(left: 35),
                      child: Text(
                        'Spotify',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _SpotifySettings(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LocalSettings extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => __LocalSettingsWidget();
}

class __LocalSettingsWidget extends State<_LocalSettings> {
  bool stateIndicatorState = true;
  bool playlistOpeningArea = true;
  bool recursiveFilesAdding = true;
  bool dynamicWindowColor = true;
  int clicks = 0;
  String? restoreText; 
  String? audioEngine; 
  bool? databaseError;
  InteractiveSliderController transitionSpeedController =
      InteractiveSliderController(1.0);
  List<String> audioEngineList = ['Standart', 'Just Audio', 'Just Audio MK'];
  final Map<String, PlayerBackend> backendMap = {
    'Just Audio MK': PlayerBackend.justAudioMediaKit,
    'Just Audio': PlayerBackend.justAudio,
    'Standart': PlayerBackend.audioPlayers,
  };

  void initDatabase() async {
    try {
      bool indicator = DatabaseStreamerService().stateIndicator.value;
      double transitionSpeed = DatabaseStreamerService().transitionSpeed.value;
      bool playlistArea = DatabaseStreamerService().playlistOpeningArea.value;
      bool recursiveFilesAdding2 =
          DatabaseStreamerService().recursiveFilesAdding.value;
      bool dynamicWindowColor2 =
          DatabaseStreamerService().dynamicWindowColor.value;
      
      if (!mounted) return;
      setState(() {
        stateIndicatorState = indicator;
        playlistOpeningArea = playlistArea;
        recursiveFilesAdding = recursiveFilesAdding2;
        transitionSpeedController.value = transitionSpeed;
        dynamicWindowColor = dynamicWindowColor2;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        databaseError = true;
      });
    }
  }

  Future<void> restoreDefaults() async {
    await DatabaseStreamerService().reset();
  }

  void setIndicator(bool value) async {
    DatabaseStreamerService().stateIndicator.value = value;
  }

  void setPlaylistArea(bool value) async {
    DatabaseStreamerService().playlistOpeningArea.value = value;
  }

  void setRecursive(bool value) async {
    DatabaseStreamerService().recursiveFilesAdding.value = value;
  }

  @override
  void initState() {
    super.initState();
    initDatabase();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!; // ✅ Локализация
    final size = MediaQuery.of(context).size;
    final maxWidth = min(size.width * 0.92 * 0.92, 800 * 0.92);
    final rightPadding = 7.5;
    
    // ✅ Определяем рекомендуемый движок с локализацией
    final recommendedEngine = Platform.isAndroid
        ? l10n.audioEngineJustAudio
        : Platform.isWindows
            ? l10n.audioEngineStandart
            : l10n.audioEngineJustAudioMK;

    return Center(
      child: Column(
        children: [
          if (databaseError == true || Database.lastError != null)
            button(
              l10n.warning, 
              l10n.databaseWarning,
              SizedBox.shrink(),
              maxWidth,
              rightPadding,
              ButtonPosition.start,
              crossAxisAlignment: CrossAxisAlignment.center,
              nameColor: Colors.red,
            ),
          SizedBox(height: 1),
          button(
            l10n.audioEngine, 
            l10n.audioEngineHint(recommendedEngine),
            DropdownButton<String>(
              dropdownColor: const Color.fromRGBO(44, 44, 44, 0.2),
              value: audioEngineList.contains(audioEngine)
                  ? audioEngine
                  : 'Standart',
              borderRadius: BorderRadius.all(Radius.circular(5)),
              elevation: 16,
              focusColor: const Color.fromARGB(113, 255, 255, 255),
              style: const TextStyle(color: Color.fromARGB(255, 255, 255, 255)),
              underline: SizedBox.shrink(),
              onChanged: (String? value) async {
                if (value != null) {
                  DatabaseStreamerService().playerBackend.value = value;
                  await Player.player.stop();
                  await Player.player.dispose();
                  await Player.player.init(backend: backendMap[value]);
                }
              },
              items: audioEngineList.map<DropdownMenuItem<String>>((
                String value,
              ) {
                final localizedValue = value == 'Standart'
                    ? l10n.audioEngineStandart
                    : value == 'Just Audio'
                        ? l10n.audioEngineJustAudio
                        : 'Just Audio MK';
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(localizedValue),
                );
              }).toList(),
            ),
            maxWidth,
            rightPadding,
            databaseError == true
                ? ButtonPosition.center
                : ButtonPosition.start,
          ),

          SizedBox(height: 1),
          button(
            l10n.recursiveFiles, // ✅ 'Recursively adding files'
            l10n.recursiveFilesHint, // ✅ описание
            Switch(
              value: recursiveFilesAdding,
              activeTrackColor: const Color.fromRGBO(77, 77, 77, 0.3),
              inactiveThumbColor: Colors.grey[300],
              inactiveTrackColor: const Color.fromRGBO(77, 77, 77, 0.3),
              onChanged: (a) {
                setState(() {
                  recursiveFilesAdding = a;
                });
                setRecursive(a);
              },
            ),
            maxWidth,
            rightPadding,
            databaseError == true
                ? ButtonPosition.center
                : ButtonPosition.start,
          ),

          SizedBox(height: 1),
          button(
            l10n.playlistArea, // ✅ 'Playlist opening area'
            l10n.playlistAreaHint,
            Switch(
              value: playlistOpeningArea,
              activeTrackColor: const Color.fromRGBO(77, 77, 77, 0.3),
              inactiveThumbColor: Colors.grey[300],
              inactiveTrackColor: const Color.fromRGBO(77, 77, 77, 0.3),
              onChanged: (a) {
                setState(() {
                  playlistOpeningArea = a;
                });
                setPlaylistArea(a);
              },
            ),
            maxWidth,
            rightPadding,
            ButtonPosition.center,
          ),
          SizedBox(height: 1),

          button(
            l10n.stateIndicator,
            l10n.stateIndicatorHint,
            Switch(
              value: stateIndicatorState,
              activeTrackColor: const Color.fromRGBO(77, 77, 77, 0.3),
              inactiveThumbColor: Colors.grey[300],
              inactiveTrackColor: const Color.fromRGBO(77, 77, 77, 0.3),
              onChanged: (a) {
                setState(() {
                  stateIndicatorState = a;
                });
                setIndicator(a);
              },
            ),
            maxWidth,
            rightPadding,
            ButtonPosition.end,
          ),
          SizedBox(height: 1),
          button(
            l10n.transitionSpeed,
            l10n.transitionSpeedHint,
            SizedBox(
              width: 150,
              child: InteractiveSlider(
                padding: EdgeInsets.all(0),
                controller: transitionSpeedController,
                unfocusedHeight: 5,
                focusedHeight: 10,
                min: 0.0,
                max: 2.5,
                onProgressUpdated: (value) async {
                  DatabaseStreamerService().transitionSpeed.value = value;
                },
                onFocused: (value) {},
                brightness: Brightness.light,
                initialProgress: 1.0,
                iconColor: Colors.white,
                gradient: LinearGradient(colors: [Colors.white, Colors.white]),
                shapeBorder: RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                ),
              ),
            ),
            maxWidth,
            rightPadding,
            ButtonPosition.center,
          ),
          SizedBox(height: 1),
          if (Platform.isLinux) ...[
            button(
              l10n.dynamicWindowColor,
              l10n.dynamicWindowColorHint,
              Switch(
                value: dynamicWindowColor,
                activeTrackColor: const Color.fromRGBO(77, 77, 77, 0.3),
                inactiveThumbColor: Colors.grey[300],
                inactiveTrackColor: const Color.fromRGBO(77, 77, 77, 0.3),
                onChanged: (a) {
                  setState(() {
                    dynamicWindowColor = a;
                  });
                  DatabaseStreamerService().dynamicWindowColor.value = a;
                },
              ),
              maxWidth,
              rightPadding,
              ButtonPosition.center,
            ),
            SizedBox(height: 1),
          ],

          button(
            l10n.restoreDefaults,
            l10n.restoreDefaultsHint,
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () async {
                  if (clicks < 2) {
                    setState(() {
                      restoreText = l10n.again; // ✅ 'Again'
                      clicks += 1;
                    });
                  } else {
                    await restoreDefaults();
                    setState(() {
                      restoreText = l10n.restore; // ✅ 'Restore'
                      clicks = 0;
                    });
                  }
                },
                child: Container(
                  height: 30,
                  width: 50,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Center(
                    child: Text(
                      restoreText ?? l10n.restore, // ✅ fallback
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 12,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            maxWidth,
            rightPadding,
            ButtonPosition.end,
          ),
        ],
      ),
    );
  }
}

class _YandexMusicSettings extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => __YandexMusicSettingsWidget();
}

class __YandexMusicSettingsWidget extends State<_YandexMusicSettings> {
  bool search = true;
  bool yandexMusicPreload = true;
  String? quality; // ✅ nullable
  List<String> qualityList = [
    'Lossless (Max)',
    'Normal (256kbps)',
    'Low (64kbps)',
  ];
  Map<String, String> qualityMap = {
    'lossless': 'Lossless (Max)',
    'nq': 'Normal (256kbps)',
    'lq': 'Low (64kbps)',
  };
  Timer? searchDebounceTimer;
  StateIndicatorOperation operation = StateIndicatorOperation.none;
  TextEditingController controller = TextEditingController(text: '');
  final Duration _searchDebounceDuration = const Duration(milliseconds: 500);
  final db = DatabaseStreamerService();

  void yandexMusicChecker(String value) async {
    searchDebounceTimer?.cancel();
    searchDebounceTimer = Timer(_searchDebounceDuration, () async {
      if (value.isEmpty) {
        return;
      }
      try {
        if (!mounted) return;
        setState(() {
          operation = StateIndicatorOperation.loading;
        });
        YandexMusic yandexMusic = YandexMusic(token: value);
        await yandexMusic.init();
        String email = await yandexMusic.account.getEmail();
        String displayName = await yandexMusic.account.getDisplayName();
        String fullName = await yandexMusic.account.getFullName();
        String login = await yandexMusic.account.getLogin();

        db.yandexMusicToken.value = value;
        db.yandexMusicLogin.value = login;
        db.yandexMusicFullName.value = fullName;
        db.yandexMusicDisplayName.value = displayName;
        db.yandexMusicUid.value = yandexMusic.accountID;
        db.yandexMusicEmail.value = email;

        if (!mounted) return;
        setState(() {
          operation = StateIndicatorOperation.success;
        });
      } on YandexMusicException {
        if (!mounted) return;
        setState(() {
          operation = StateIndicatorOperation.error;
        });
      }
    });
  }

  void setQuality(String value) async {
    final Map<String, String> qualityReverse = {
      for (var entry in qualityMap.entries) entry.value: entry.key,
    };
    String? quality2 = qualityReverse[value];
    db.yandexMusicQuality.value = quality2!;
    if (!mounted) return;
    setState(() {
      quality = value;
    });
  }

  void setSearch(bool value) async {
    db.yandexMusicSearch.value = value;
  }

  void setPreload(bool value) async {
    db.yandexMusicPreload.value = value;
  }

  void initDatabase() {
    setState(() {
      controller.text = db.yandexMusicToken.value;
      quality = qualityMap[db.yandexMusicQuality.value] ?? quality;
      search = db.yandexMusicSearch.value;
      yandexMusicPreload = db.yandexMusicPreload.value;
    });
    yandexMusicChecker(db.yandexMusicToken.value);
  }

  @override
  void initState() {
    super.initState();
    initDatabase();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!; // ✅ Локализация
    final size = MediaQuery.of(context).size;
    final maxWidth = min(size.width * 0.92 * 0.92, 800 * 0.92);
    final textFieldWidth = min(size.width * 0.3, 250.0);
    final rightPadding = 7.5;
    
    return Center(
      child: Column(
        children: [
          button(
            l10n.searchInYandex, // ✅ 'Search'
            l10n.searchInYandexHint,
            Switch(
              value: search,
              activeTrackColor: const Color.fromRGBO(77, 77, 77, 0.3),
              inactiveThumbColor: Colors.grey[300],
              inactiveTrackColor: const Color.fromRGBO(77, 77, 77, 0.3),
              onChanged: (a) {
                setState(() {
                  search = a;
                });
                setSearch(a);
              },
            ),
            maxWidth,
            rightPadding,
            ButtonPosition.start,
          ),
          SizedBox(height: 1),

          button(
            l10n.yandexPreload,
            l10n.yandexPreloadHint,
            Switch(
              value: yandexMusicPreload,
              activeTrackColor: const Color.fromRGBO(77, 77, 77, 0.3),
              inactiveThumbColor: Colors.grey[300],
              inactiveTrackColor: const Color.fromRGBO(77, 77, 77, 0.3),
              onChanged: (a) {
                setState(() {
                  yandexMusicPreload = a;
                });
                setPreload(a);
              },
            ),
            maxWidth,
            rightPadding,
            ButtonPosition.center,
          ),
          SizedBox(height: 1),
          ValueListenableBuilder(
            valueListenable:
                DatabaseStreamerService().originalImageSizeForCoverView,
            builder: (context, originalSize, child) {
              return button(
                l10n.originalCoverSize,
                l10n.originalCoverSizeHint,
                Switch(
                  value: originalSize,
                  activeTrackColor: const Color.fromRGBO(77, 77, 77, 0.3),
                  inactiveThumbColor: Colors.grey[300],
                  inactiveTrackColor: const Color.fromRGBO(77, 77, 77, 0.3),
                  onChanged: (a) {
                    DatabaseStreamerService()
                            .originalImageSizeForCoverView
                            .value =
                        a;
                  },
                ),
                maxWidth,
                rightPadding,
                ButtonPosition.start,
              );
            },
          ),

          SizedBox(height: 1),

          button(
            l10n.quality,
            l10n.qualityHint,
            DropdownButton<String>(
              dropdownColor: const Color.fromRGBO(44, 44, 44, 0.2),
              value: qualityList.contains(quality)
                  ? quality
                  : l10n.qualityNormal,
              borderRadius: BorderRadius.all(Radius.circular(5)),
              elevation: 16,
              focusColor: const Color.fromARGB(113, 255, 255, 255),
              style: const TextStyle(color: Color.fromARGB(255, 255, 255, 255)),
              underline: SizedBox.shrink(),
              onChanged: (String? value) {
                if (value != null) {
                  setQuality(value);
                }
              },
              items: qualityList.map<DropdownMenuItem<String>>((String value) {
                // ✅ Локализуем названия качеств
                final localizedValue = value == 'Lossless (Max)'
                    ? l10n.qualityLossless
                    : value == 'Normal (256kbps)'
                        ? l10n.qualityNormal
                        : l10n.qualityLow;
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(localizedValue),
                );
              }).toList(),
            ),
            maxWidth,
            rightPadding,
            ButtonPosition.center,
          ),

          SizedBox(height: 1),
          button(
            l10n.token,
            l10n.tokenHint,
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                StateIndicator(operation: operation),
                const SizedBox(width: 10),
                Padding(
                  padding: EdgeInsets.only(right: rightPadding),
                  child: Row(
                    children: [
                      SizedBox(
                        width: textFieldWidth,
                        height: 40,
                        child: TextField(
                          onChanged: (value) => yandexMusicChecker(value),
                          style: TextStyle(
                            color: Colors.white.withAlpha(220),
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            overflow: TextOverflow.ellipsis,
                          ),
                          controller: controller,
                          decoration: InputDecoration(
                            hintText: l10n.tokenPlaceholder, // ✅ 'Enter token here'
                            hintStyle: TextStyle(
                              color: Colors.white.withAlpha(178),
                              overflow: TextOverflow.ellipsis,
                              fontSize: 14,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: BorderSide(
                                color: Colors.white.withAlpha(155),
                                width: 1,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: BorderSide(
                                color: Colors.white.withAlpha(155),
                                width: 1,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: BorderSide(
                                color: Colors.white.withAlpha(155),
                                width: 1.5,
                              ),
                            ),
                            filled: false,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            maxWidth,
            rightPadding,
            ButtonPosition.end,
          ),
        ],
      ),
    );
  }
}

class _DebugSettings extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => __DebugSettingsWidget();
}

class __DebugSettingsWidget extends State<_DebugSettings> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!; // ✅ Локализация
    final size = MediaQuery.of(context).size;
    final maxWidth = min(size.width * 0.92 * 0.92, 800 * 0.92);
    final rightPadding = 7.5;
    
    return Center(
      child: Column(
        children: [
          InkWell(
            onTap: () async {
              await showDialog(
                context: context,
                builder: (builder) => GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: SingleChildScrollView(
                    child: SizedBox(
                      width: maxWidth,
                      height: maxWidth,
                      child: Center(
                        child: Text(
                          Database.lastError.toString(),
                          style: TextStyle(color: Colors.white),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
            child: button(
              l10n.database, 
              l10n.databaseInfo(
                Database.isInited.toString(),
                Database.lastError?.toString() ?? 'null',
              ),
              SizedBox.shrink(),
              maxWidth,
              rightPadding,
              ButtonPosition.start,
            ),
          ),
          SizedBox(height: 1),
          InkWell(
            onTap: () async {
              await showDialog(
                context: context,
                builder: (builder) => GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: SingleChildScrollView(
                    child: SizedBox(
                      width: maxWidth,
                      height: maxWidth,
                      child: Center(
                        child: Text(
                          NativeControl().lastError.toString(),
                          style: TextStyle(color: Colors.white),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
            child: button(
              l10n.nativeControl,
              l10n.nativeControlInfo(
                NativeControl().inited.toString(),
                NativeControl().initTries.toString(),
                NativeControl().lastError?.toString() ?? 'null',
              ),
              SizedBox.shrink(),
              maxWidth,
              rightPadding,
              ButtonPosition.end,
            ),
          ),
        ],
      ),
    );
  }
}

class _SpotifySettings extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => __SpotifySettingsWidget();
}

class __SpotifySettingsWidget extends State<_SpotifySettings> {
  bool search = true;
  String quality = 'Lossless (CD)';
  final List<String> qualityList = [
    'Hi-Res FLAC',
    'Lossless (CD)',
    'Normal (256kbps)',
    'Low (64kbps)',
    'MP3 (320kbps)',
  ];
  final Map<String, String> qualityMap = {
    'hires': 'Hi-Res FLAC',
    'lossless': 'Lossless (CD)',
    'nq': 'Normal (256kbps)',
    'lq': 'Low (64kbps)',
    'mp3': 'MP3 (320kbps)',
  };
  TextEditingController priorityController = TextEditingController(text: '');
  final db = DatabaseStreamerService();

  void setQuality(String value) async {
    final Map<String, String> qualityReverse = {
      for (var entry in qualityMap.entries) entry.value: entry.key,
    };
    String? qualityCode = qualityReverse[value];
    if (qualityCode != null) {
      db.spotifyQuality.value = qualityCode;
      if (!mounted) return;
      setState(() {
        quality = value;
      });
    }
  }

  void setSearch(bool value) async {
    db.spotifySearch.value = value;
  }

  void initDatabase() {
    setState(() {
      priorityController.text = db.spotifySourcePriority.value;
      quality = qualityMap[db.spotifyQuality.value] ?? quality;
      search = db.spotifySearch.value;
    });
  }

  @override
  void initState() {
    super.initState();
    initDatabase();
  }

  @override
  void dispose() {
    priorityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final maxWidth = min(size.width * 0.92 * 0.92, 800 * 0.92);
    final textFieldWidth = min(size.width * 0.3, 250.0);
    final rightPadding = 7.5;
    return Center(
      child: Column(
        children: [
          button(
            'Search Integration',
            'Add tracks found in Spotify to the track search results',
            Switch(
              value: search,
              activeTrackColor: const Color.fromRGBO(77, 77, 77, 0.3),
              inactiveThumbColor: Colors.grey[300],
              inactiveTrackColor: const Color.fromRGBO(77, 77, 77, 0.3),
              onChanged: (a) {
                setState(() {
                  search = a;
                });
                setSearch(a);
              },
            ),
            maxWidth,
            rightPadding,
            ButtonPosition.start,
          ),
          SizedBox(height: 1),
          button(
            'Streaming Quality',
            "Default quality level resolved from fallbacks.",
            DropdownButton<String>(
              dropdownColor: const Color.fromRGBO(44, 44, 44, 0.2),
              value: qualityList.contains(quality)
                  ? quality
                  : 'Lossless (CD)',
              borderRadius: BorderRadius.all(Radius.circular(5)),
              elevation: 16,
              focusColor: const Color.fromARGB(113, 255, 255, 255),
              style: const TextStyle(color: Color.fromARGB(255, 255, 255, 255)),
              underline: SizedBox.shrink(),
              onChanged: (String? value) {
                if (value != null) {
                  setQuality(value);
                }
              },
              items: qualityList.map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
            ),
            maxWidth,
            rightPadding,
            ButtonPosition.center,
          ),
          SizedBox(height: 1),
          button(
            'Source Priority',
            "Reserved for future use. Streaming now uses GDStudio (Tidal).",
            Padding(
              padding: EdgeInsets.only(right: rightPadding),
              child: Row(
                children: [
                  SizedBox(
                    width: textFieldWidth,
                    height: 40,
                    child: TextField(
                      onChanged: (value) {
                        db.spotifySourcePriority.value = value;
                      },
                      style: TextStyle(
                        color: Colors.white.withAlpha(220),
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        overflow: TextOverflow.ellipsis,
                      ),
                      controller: priorityController,
                      decoration: InputDecoration(
                        hintText: 'gdstudio (tidal)',
                        hintStyle: TextStyle(
                          color: Colors.white.withAlpha(178),
                          overflow: TextOverflow.ellipsis,
                          fontSize: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(
                            color: Colors.white.withAlpha(155),
                            width: 1,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(
                            color: Colors.white.withAlpha(155),
                            width: 1,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(
                            color: Colors.white.withAlpha(155),
                            width: 1.5,
                          ),
                        ),
                        filled: false,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            maxWidth,
            rightPadding,
            ButtonPosition.center,
          ),
          const SizedBox(height: 1),
          ValueListenableBuilder<bool>(
            valueListenable: db.spotifyLoggedIn,
            builder: (context, loggedIn, _) {
              return button(
                'Account Status',
                loggedIn ? 'Logged in to personal Spotify account' : 'Not logged in',
                loggedIn
                    ? TextButton(
                        onPressed: () {
                          db.spotifyOauthToken.value = '';
                          db.spotifyRefreshToken.value = '';
                          db.spotifyLoggedIn.value = false;
                        },
                        child: const Text('Log Out', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                      )
                    : const Text('Unauthorized', style: TextStyle(color: Colors.white54)),
                maxWidth,
                rightPadding,
                ButtonPosition.end,
              );
            },
          ),
        ],
      ),
    );
  }
}

enum ButtonPosition { start, center, end }

Container button(
  String name,
  String description,
  Widget widget,
  double width,
  double rightPadding,
  ButtonPosition buttonPosition, {
  CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.start,
  Color nameColor = Colors.white,
}) {
  return Container(
    width: width,
    height: 50,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(
          buttonPosition == ButtonPosition.start ? 10 : 0,
        ),
        topRight: Radius.circular(
          buttonPosition == ButtonPosition.start ? 10 : 0,
        ),
        bottomLeft: Radius.circular(
          buttonPosition == ButtonPosition.end ? 10 : 0,
        ),
        bottomRight: Radius.circular(
          buttonPosition == ButtonPosition.end ? 10 : 0,
        ),
      ),
      color: Color.fromRGBO(44, 44, 44, 0.2),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(width: 15),

        Expanded(
          child: Column(
            crossAxisAlignment: crossAxisAlignment,
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name,
                style: TextStyle(
                  color: nameColor,
                  fontSize: 12,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                description,
                style: TextStyle(
                  color: const Color.fromARGB(125, 255, 255, 255),
                  fontSize: 12,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),

        Padding(
          padding: EdgeInsets.only(right: rightPadding),
          child: Row(children: [widget, SizedBox(width: 5)]),
        ),
      ],
    ),
  );
}