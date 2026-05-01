enum AudioQuality {
  lossless('lossless'),
  normal('nq'),
  low('lq'),
  @Deprecated('use AudioQuality.normal instead')
  mp3('mp3');

  final String value;

  const AudioQuality(this.value);

  static AudioQuality? fromString(String value) {
    AudioQuality? downloadQuality = switch (value) {
      'lossless' => AudioQuality.lossless,
      'nq' => AudioQuality.normal,
      'lq' => AudioQuality.low,
      'mp3' => AudioQuality.normal,
      _ => null,
    };
    return downloadQuality;
  }
}
