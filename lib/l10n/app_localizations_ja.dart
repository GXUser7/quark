// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appTitle => 'quark：サウンドが始まる場所';

  @override
  String get selectFolderHint =>
      'トラックを含むフォルダを選択してください。\nストリーミングアカウントをリンクして使用することもできます。';

  @override
  String get pickFolder => 'フォルダを選択';

  @override
  String get restorePlaylist => 'プレイリストを復元';

  @override
  String get yandexMusic => 'Yandex Music';

  @override
  String get youtubeMusic => 'YouTube Music';

  @override
  String get vkMusic => 'VK Music';

  @override
  String get soundCloud => 'SoundCloud';

  @override
  String get search => '検索';

  @override
  String get settings => '設定';

  @override
  String get login => 'ログイン';

  @override
  String get logout => 'ログアウト';

  @override
  String get deleteAllPlaylists => 'すべてのプレイリストを削除しますか？';

  @override
  String get deleteAllPlaylistsDesc => 'これにより、すべてのローカルプレイリストとそのトラックが永久に削除されます。';

  @override
  String get cancel => 'キャンセル';

  @override
  String get delete => '削除';

  @override
  String playlistError(Object error) {
    return 'プレイリストの読み込みエラー：$error';
  }

  @override
  String get preferences => '設定';

  @override
  String get debug => 'デバッグ';

  @override
  String get main => 'メイン';

  @override
  String get warning => '警告';

  @override
  String get databaseWarning => 'データベースが利用できないかエラーを含んでいます。変更が保存されない場合があります。';

  @override
  String get audioEngine => 'オーディオエンジン';

  @override
  String audioEngineHint(Object platform) {
    return 'お使いのプラットフォームに推奨：$platform';
  }

  @override
  String get audioEngineJustAudioMK => 'Just Audio MK';

  @override
  String get audioEngineJustAudio => 'Just Audio';

  @override
  String get audioEngineStandart => '標準';

  @override
  String get recursiveFiles => '再帰的にファイルを追加';

  @override
  String get recursiveFilesHint =>
      'プレイヤーはトップフォルダだけでなく、すべてのサブフォルダもチェックしてローカルトラックを追加します。';

  @override
  String get playlistArea => 'プレイリスト開くエリア';

  @override
  String get playlistAreaHint => '画面の左側にカーソルを合わせると、プレイリストビューが自動的に開きます。';

  @override
  String get stateIndicator => '状態インジケーター';

  @override
  String get stateIndicatorHint => 'ネットワーク操作実行時の通知インジケーターをオン/オフします。';

  @override
  String get transitionSpeed => '遷移速度';

  @override
  String get transitionSpeedHint => 'アプリケーション内のほとんどのアニメーションの速度を変更します。';

  @override
  String get dynamicWindowColor => '動的ウィンドウカラー';

  @override
  String get dynamicWindowColorHint => 'ウィンドウの色は画面のコンテンツに応じて動的に変化します。';

  @override
  String get restoreDefaults => 'デフォルトに復元';

  @override
  String get restoreDefaultsHint => 'プレイヤー設定を工場出荷時にリセットします。リセット後は再起動を推奨します。';

  @override
  String get restore => '復元';

  @override
  String get again => 'もう一度';

  @override
  String get searchInYandex => 'Yandex で検索';

  @override
  String get searchInYandexHint => 'Yandex Music で見つけたトラックをプレイリスト検索に追加';

  @override
  String get yandexPreload => 'Yandex Music 事前読み込み';

  @override
  String get yandexPreloadHint =>
      'プレイヤー起動時、Yandex Music が読み込み中に初期化され、操作が高速化されます。';

  @override
  String get originalCoverSize => 'オリジナルカバーサイズ';

  @override
  String get originalCoverSizeHint =>
      '拡大表示時、カバーは標準の 1000x1000 ではなく最大サイズで表示されます。';

  @override
  String get quality => '音質';

  @override
  String get qualityHint => 'ダウンロードするトラックの音質。';

  @override
  String get qualityLossless => 'ロスレス（最大）';

  @override
  String get qualityNormal => '標準（256kbps）';

  @override
  String get qualityLow => '低（64kbps）';

  @override
  String get token => 'トークン';

  @override
  String get tokenHint => 'Yandex アカウントのトークン。';

  @override
  String get tokenPlaceholder => 'トークンを入力';

  @override
  String get database => 'データベース';

  @override
  String databaseInfo(Object inited, Object error) {
    return '初期化済み：$inited || 最終エラー：$error';
  }

  @override
  String get nativeControl => 'NativeControl';

  @override
  String nativeControlInfo(Object inited, Object tries, Object error) {
    return '初期化済み：$inited || 試行回数：$tries || エラー：$error';
  }
}
