// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class AppLocalizationsTr extends AppLocalizations {
  AppLocalizationsTr([String locale = 'tr']) : super(locale);

  @override
  String get appTitle => 'quark: sesin başladığı yer';

  @override
  String get selectFolderHint =>
      'Parçaların bulunduğu klasörü seçin.\nAyrıca bir akış hesabı da bağlayabilirsiniz.';

  @override
  String get pickFolder => 'Klasör seç';

  @override
  String get restorePlaylist => 'Çalma listesini geri yükle';

  @override
  String get yandexMusic => 'Yandex Müzik';

  @override
  String get youtubeMusic => 'YouTube Music';

  @override
  String get vkMusic => 'VK Müzik';

  @override
  String get soundCloud => 'SoundCloud';

  @override
  String get search => 'Ara';

  @override
  String get settings => 'Ayarlar';

  @override
  String get login => 'Giriş yap';

  @override
  String get logout => 'Çıkış yap';

  @override
  String get deleteAllPlaylists => 'Tüm çalma listeleri silinsin mi?';

  @override
  String get deleteAllPlaylistsDesc =>
      'Tüm yerel çalma listeleri ve parçaları kalıcı olarak silinecek.';

  @override
  String get cancel => 'İptal';

  @override
  String get delete => 'Sil';

  @override
  String playlistError(Object error) {
    return 'Çalma listesi yüklenemedi: $error';
  }

  @override
  String get preferences => 'Tercihler';

  @override
  String get debug => 'Hata ayıklama';

  @override
  String get main => 'Ana sayfa';

  @override
  String get warning => 'UYARI';

  @override
  String get databaseWarning =>
      'Veritabanı kullanılamıyor veya hata içeriyor. Değişiklikler kaydedilmeyebilir. Günlükleri kontrol edin.';

  @override
  String get audioEngine => 'Ses motoru';

  @override
  String audioEngineHint(Object platform) {
    return 'Platformunuz için önerilen: $platform';
  }

  @override
  String get audioEngineJustAudioMK => 'Just Audio MK';

  @override
  String get audioEngineJustAudio => 'Just Audio';

  @override
  String get audioEngineStandart => 'Standart';

  @override
  String get recursiveFiles => 'Dosyaları özyinelemeli ekle';

  @override
  String get recursiveFilesHint =>
      'Oynatıcı yalnızca ana klasörü değil, tüm alt klasörleri de yerel parçalar için tarar.';

  @override
  String get playlistArea => 'Çalma listesi açma alanı';

  @override
  String get playlistAreaHint =>
      'Ekranın sol tarafına gelindiğinde çalma listesi otomatik olarak açılır.';

  @override
  String get stateIndicator => 'Durum göstergesi';

  @override
  String get stateIndicatorHint =>
      'Ağ işlemleri gerçekleştirildiğinde bildiren durum göstergesini aç/kapat.';

  @override
  String get transitionSpeed => 'Geçiş hızı';

  @override
  String get transitionSpeedHint =>
      'Uygulamadaki çoğu animasyonun hızını değiştirir.';

  @override
  String get dynamicWindowColor => 'Dinamik pencere rengi';

  @override
  String get dynamicWindowColorHint =>
      'Pencere rengi ekrandaki içeriğe göre dinamik olarak değişir.';

  @override
  String get restoreDefaults => 'Varsayılana sıfırla';

  @override
  String get restoreDefaultsHint =>
      'Oynatıcı ayarlarını fabrika varsayılanlarına sıfırlar. Sıfırlamadan sonra yeniden başlatma önerilir.';

  @override
  String get restore => 'Sıfırla';

  @override
  String get again => 'Tekrar';

  @override
  String get searchInYandex => 'Ara';

  @override
  String get searchInYandexHint =>
      'Yandex Music\'te bulunan parçaları çalma listesindeki parça aramasına ekle';

  @override
  String get yandexPreload => 'Yandex Music Önbelleği';

  @override
  String get yandexPreloadHint =>
      'Başlangıçta Yandex Music, yükleme sırasında başlatılır, böylece etkileşim hızlanır.';

  @override
  String get originalCoverSize => 'Orijinal kapak boyutu';

  @override
  String get originalCoverSizeHint =>
      'Büyütülmüş kapak görüntülenirken standart 1000x1000 yerine maksimum boyutta gösterilir.';

  @override
  String get quality => 'Kalite';

  @override
  String get qualityHint => 'İndirilen parçaların kalitesi.';

  @override
  String get qualityLossless => 'Kayıpsız (Maks.)';

  @override
  String get qualityNormal => 'Normal (256 kbps)';

  @override
  String get qualityLow => 'Düşük (64 kbps)';

  @override
  String get token => 'Jeton';

  @override
  String get tokenHint => 'Yandex hesap jetonunuz.';

  @override
  String get tokenPlaceholder => 'Jetonu buraya girin';

  @override
  String get database => 'Veritabanı';

  @override
  String databaseInfo(Object inited, Object error) {
    return 'Başlatıldı: $inited || Son hata: $error';
  }

  @override
  String get nativeControl => 'NativeControl';

  @override
  String nativeControlInfo(Object inited, Object tries, Object error) {
    return 'Başlatıldı: $inited || Deneme: $tries || Son hata: $error';
  }
}
