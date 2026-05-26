// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get appTitle => 'quark: 소리가 시작되는 곳';

  @override
  String get selectFolderHint => '트랙이 있는 폴더를 택하세요.\n스트리밍 계정을 연결하여 사용할 수도 있습니다.';

  @override
  String get pickFolder => '폴더 선택';

  @override
  String get restorePlaylist => '플레이리스트 복원';

  @override
  String get yandexMusic => 'Yandex Music';

  @override
  String get youtubeMusic => 'YouTube Music';

  @override
  String get vkMusic => 'VK Music';

  @override
  String get soundCloud => 'SoundCloud';

  @override
  String get search => '검색';

  @override
  String get settings => '설정';

  @override
  String get login => '로그인';

  @override
  String get logout => '로그아웃';

  @override
  String get deleteAllPlaylists => '모든 플레이리스트를 삭제하시겠습니까?';

  @override
  String get deleteAllPlaylistsDesc => '이 작업은 모든 로컬 플레이리스트와 트랙을 영구적으로 삭제합니다.';

  @override
  String get cancel => '취소';

  @override
  String get delete => '삭제';

  @override
  String playlistError(Object error) {
    return '플레이리스트 로드 오류: $error';
  }

  @override
  String get preferences => '환경설정';

  @override
  String get debug => '디버그';

  @override
  String get main => '메인';

  @override
  String get warning => '경고';

  @override
  String get databaseWarning =>
      '데이터베이스를 사용할 수 없거나 오류가 포함되어 있습니다. 변경사항이 저장되지 않을 수 있습니다.';

  @override
  String get audioEngine => '오디오 엔진';

  @override
  String audioEngineHint(Object platform) {
    return '플랫폼 권장: $platform';
  }

  @override
  String get audioEngineJustAudioMK => 'Just Audio MK';

  @override
  String get audioEngineJustAudio => 'Just Audio';

  @override
  String get audioEngineStandart => '표준';

  @override
  String get recursiveFiles => '재귀적으로 파일 추가';

  @override
  String get recursiveFilesHint =>
      '플레이어가 최상위 폴더뿐만 아니라 모든 하위 폴더도 확인하여 로컬 트랙을 추가합니다.';

  @override
  String get playlistArea => '플레이리스트 열기 영역';

  @override
  String get playlistAreaHint => '화면 왼쪽으로 마우스를 올리면 플레이리스트 뷰가 자동으로 열립니다.';

  @override
  String get stateIndicator => '상태 표시기';

  @override
  String get stateIndicatorHint => '네트워크 작업 수행 시 알림 상태 표시기를 켜거나 끕니다.';

  @override
  String get transitionSpeed => '전환 속도';

  @override
  String get transitionSpeedHint => '애플리케이션의 대부분의 애니메이션 속도를 변경합니다.';

  @override
  String get dynamicWindowColor => '동적 윈도우 색상';

  @override
  String get dynamicWindowColorHint => '윈도우 색상이 화면의 콘텐츠에 따라 동적으로 변경됩니다.';

  @override
  String get restoreDefaults => '기본값으로 복원';

  @override
  String get restoreDefaultsHint =>
      '플레이어 설정을 공장 출하 상태로 초기화합니다. 초기화 후 재시작을 권장합니다.';

  @override
  String get restore => '복원';

  @override
  String get again => '다시';

  @override
  String get searchInYandex => 'Yandex 검색';

  @override
  String get searchInYandexHint => 'Yandex Music 에서 찾은 트랙을 플레이리스트 검색에 추가';

  @override
  String get yandexPreload => 'Yandex Music 사전 로드';

  @override
  String get yandexPreloadHint =>
      '플레이어 시작 시 로딩 중에 Yandex Music 이 초기화되어 상호작용이 빨라집니다.';

  @override
  String get originalCoverSize => '원본 커버 크기';

  @override
  String get originalCoverSizeHint =>
      '확대된 커버를 볼 때 표준 1000x1000 대신 최대 크기로 표시됩니다.';

  @override
  String get quality => '음질';

  @override
  String get qualityHint => '다운로드된 트랙의 음질.';

  @override
  String get qualityLossless => '무손실 (최대)';

  @override
  String get qualityNormal => '보통 (256kbps)';

  @override
  String get qualityLow => '낮음 (64kbps)';

  @override
  String get token => '토큰';

  @override
  String get tokenHint => 'Yandex 계정 큰입니다.';

  @override
  String get tokenPlaceholder => '토큰 입력';

  @override
  String get database => '데이터베이스';

  @override
  String databaseInfo(Object inited, Object error) {
    return '초기화됨: $inited || 마지막 오류: $error';
  }

  @override
  String get nativeControl => 'NativeControl';

  @override
  String nativeControlInfo(Object inited, Object tries, Object error) {
    return '초기화됨: $inited || 시도: $tries || 오류: $error';
  }
}
