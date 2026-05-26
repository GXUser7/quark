// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get appTitle => 'quark: onde o som começa';

  @override
  String get selectFolderHint =>
      'Selecione a pasta com as faixas.\nVocê também pode vincular sua conta de streaming.';

  @override
  String get pickFolder => 'Escolher pasta';

  @override
  String get restorePlaylist => 'Restaurar playlist';

  @override
  String get yandexMusic => 'Yandex Music';

  @override
  String get youtubeMusic => 'YouTube Music';

  @override
  String get vkMusic => 'VK Music';

  @override
  String get soundCloud => 'SoundCloud';

  @override
  String get search => 'Pesquisar';

  @override
  String get settings => 'Configurações';

  @override
  String get login => 'Entrar';

  @override
  String get logout => 'Sair';

  @override
  String get deleteAllPlaylists => 'Excluir todas as playlists?';

  @override
  String get deleteAllPlaylistsDesc =>
      'Todas as playlists locais e suas faixas serão excluídas permanentemente.';

  @override
  String get cancel => 'Cancelar';

  @override
  String get delete => 'Excluir';

  @override
  String playlistError(Object error) {
    return 'Erro ao carregar playlist: $error';
  }

  @override
  String get preferences => 'Preferências';

  @override
  String get debug => 'Depuração';

  @override
  String get main => 'Principal';

  @override
  String get warning => 'AVISO';

  @override
  String get databaseWarning =>
      'O banco de dados está indisponível ou contém erros. As alterações podem não ser salvas. Verifique os logs.';

  @override
  String get audioEngine => 'Motor de áudio';

  @override
  String audioEngineHint(Object platform) {
    return 'Recomendado para sua plataforma: $platform';
  }

  @override
  String get audioEngineJustAudioMK => 'Just Audio MK';

  @override
  String get audioEngineJustAudio => 'Just Audio';

  @override
  String get audioEngineStandart => 'Padrão';

  @override
  String get recursiveFiles => 'Adicionar arquivos recursivamente';

  @override
  String get recursiveFilesHint =>
      'O player verificará não apenas a pasta principal, mas também todas as subpastas para adicionar faixas locais.';

  @override
  String get playlistArea => 'Área de abertura de playlist';

  @override
  String get playlistAreaHint =>
      'Ao passar o cursor pelo lado esquerdo da tela, a playlist abrirá automaticamente.';

  @override
  String get stateIndicator => 'Indicador de estado';

  @override
  String get stateIndicatorHint =>
      'Ativar/desativar o indicador de status que notifica quando operações de rede estão sendo realizadas.';

  @override
  String get transitionSpeed => 'Velocidade de transição';

  @override
  String get transitionSpeedHint =>
      'Altera a velocidade da maioria das animações no aplicativo.';

  @override
  String get dynamicWindowColor => 'Cor dinâmica da janela';

  @override
  String get dynamicWindowColorHint =>
      'A cor da janela mudará dinamicamente conforme o conteúdo na tela.';

  @override
  String get restoreDefaults => 'Restaurar padrões';

  @override
  String get restoreDefaultsHint =>
      'Redefine as configurações do player para os padrões de fábrica. Recomenda-se reiniciar após.';

  @override
  String get restore => 'Restaurar';

  @override
  String get again => 'Novamente';

  @override
  String get searchInYandex => 'Pesquisar';

  @override
  String get searchInYandexHint =>
      'Adicionar faixas encontradas no Yandex Music à pesquisa de faixas na playlist';

  @override
  String get yandexPreload => 'Pré-carregamento do Yandex Music';

  @override
  String get yandexPreloadHint =>
      'Ao iniciar, o Yandex Music será inicializado durante o carregamento para acelerar a interação.';

  @override
  String get originalCoverSize => 'Tamanho original da capa';

  @override
  String get originalCoverSizeHint =>
      'Ao visualizar uma capa ampliada, ela será exibida no tamanho máximo em vez do padrão 1000x1000.';

  @override
  String get quality => 'Qualidade';

  @override
  String get qualityHint => 'Qualidade das faixas baixadas.';

  @override
  String get qualityLossless => 'Sem perdas (Máx.)';

  @override
  String get qualityNormal => 'Normal (256 kbps)';

  @override
  String get qualityLow => 'Baixa (64 kbps)';

  @override
  String get token => 'Token';

  @override
  String get tokenHint => 'Seu token de conta Yandex.';

  @override
  String get tokenPlaceholder => 'Digite o token aqui';

  @override
  String get database => 'Banco de dados';

  @override
  String databaseInfo(Object inited, Object error) {
    return 'Iniciado: $inited || Último erro: $error';
  }

  @override
  String get nativeControl => 'NativeControl';

  @override
  String nativeControlInfo(Object inited, Object tries, Object error) {
    return 'Iniciado: $inited || Tentativas: $tries || Último erro: $error';
  }
}
