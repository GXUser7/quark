// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'quark：声音的起点';

  @override
  String get selectFolderHint => '选择包含曲目的文件夹。\n您也可以绑定流媒体账号。';

  @override
  String get pickFolder => '选择文件夹';

  @override
  String get restorePlaylist => '恢复播放列表';

  @override
  String get yandexMusic => 'Yandex 音乐';

  @override
  String get youtubeMusic => 'YouTube Music';

  @override
  String get vkMusic => 'VK 音乐';

  @override
  String get soundCloud => 'SoundCloud';

  @override
  String get search => '搜索';

  @override
  String get settings => '设置';

  @override
  String get login => '登录';

  @override
  String get logout => '退出';

  @override
  String get deleteAllPlaylists => '删除所有播放列表？';

  @override
  String get deleteAllPlaylistsDesc => '所有本地播放列表及其曲目将被永久删除。';

  @override
  String get cancel => '取消';

  @override
  String get delete => '删除';

  @override
  String playlistError(Object error) {
    return '加载播放列表失败：$error';
  }

  @override
  String get preferences => '偏好设置';

  @override
  String get debug => '调试';

  @override
  String get main => '主页';

  @override
  String get warning => '警告';

  @override
  String get databaseWarning => '数据库不可用或包含错误。更改可能无法保存。请检查日志。';

  @override
  String get audioEngine => '音频引擎';

  @override
  String audioEngineHint(Object platform) {
    return '适合您平台的推荐引擎：$platform';
  }

  @override
  String get audioEngineJustAudioMK => 'Just Audio MK';

  @override
  String get audioEngineJustAudio => 'Just Audio';

  @override
  String get audioEngineStandart => '标准';

  @override
  String get recursiveFiles => '递归添加文件';

  @override
  String get recursiveFilesHint => '播放器不仅检查顶层文件夹，还检查所有子文件夹以添加本地曲目。';

  @override
  String get playlistArea => '播放列表打开区域';

  @override
  String get playlistAreaHint => '将光标移至屏幕左侧时，播放列表将自动打开。';

  @override
  String get stateIndicator => '状态指示器';

  @override
  String get stateIndicatorHint => '开启/关闭在执行网络操作时通知您的状态指示器。';

  @override
  String get transitionSpeed => '过渡速度';

  @override
  String get transitionSpeedHint => '更改应用程序中大多数动画的速度。';

  @override
  String get dynamicWindowColor => '动态窗口颜色';

  @override
  String get dynamicWindowColorHint => '窗口颜色将根据屏幕上的内容动态变化。';

  @override
  String get restoreDefaults => '恢复默认值';

  @override
  String get restoreDefaultsHint => '将播放器设置重置为出厂默认值。重置后建议重启播放器。';

  @override
  String get restore => '恢复';

  @override
  String get again => '再次';

  @override
  String get searchInYandex => '搜索';

  @override
  String get searchInYandexHint => '将在 Yandex Music 中找到的曲目添加到播放列表中的曲目搜索';

  @override
  String get yandexPreload => 'Yandex Music 预加载';

  @override
  String get yandexPreloadHint => '播放器启动时，Yandex Music 将在加载过程中初始化以加快交互速度。';

  @override
  String get originalCoverSize => '原始封面尺寸';

  @override
  String get originalCoverSizeHint => '查看放大封面时，将以最大尺寸显示而非标准的 1000x1000。';

  @override
  String get quality => '音质';

  @override
  String get qualityHint => '已下载曲目的音质。';

  @override
  String get qualityLossless => '无损（最高）';

  @override
  String get qualityNormal => '普通（256kbps）';

  @override
  String get qualityLow => '低（64kbps）';

  @override
  String get token => '令牌';

  @override
  String get tokenHint => '您的 Yandex 账号令牌。';

  @override
  String get tokenPlaceholder => '在此输入令牌';

  @override
  String get database => '数据库';

  @override
  String databaseInfo(Object inited, Object error) {
    return '已初始化：$inited || 最后错误：$error';
  }

  @override
  String get nativeControl => 'NativeControl';

  @override
  String nativeControlInfo(Object inited, Object tries, Object error) {
    return '已初始化：$inited || 初始化尝试：$tries || 最后错误：$error';
  }
}
