import 'dart:math';

import 'package:quark/services/database/library_engine.dart';


class TrackStats {
  final KnownTrack track;
  final int totalPlays;
  final int completePlays;
  final int skips;
  final int totalPlayedSeconds;
  final double avgProgressPercent;
  final double completionRate;
  final double skipRate;
  final DateTime? firstListened;
  final DateTime? lastListened;
  final int uniqueDaysListened;
  final int longestStreakDays;

  const TrackStats({
    required this.track,
    required this.totalPlays,
    required this.completePlays,
    required this.skips,
    required this.totalPlayedSeconds,
    required this.avgProgressPercent,
    required this.completionRate,
    required this.skipRate,
    required this.firstListened,
    required this.lastListened,
    required this.uniqueDaysListened,
    required this.longestStreakDays,
  });

  @override
  String toString() => '''
  Track: "${track.title}" by ${track.artists}
    Plays: $totalPlays (complete: $completePlays, skipped: $skips)
    Total time: ${_fmtDuration(totalPlayedSeconds)}
    Avg progress: ${avgProgressPercent.toStringAsFixed(1)}%
    Completion rate: ${(completionRate * 100).toStringAsFixed(1)}%
    Skip rate: ${(skipRate * 100).toStringAsFixed(1)}%
    First: ${firstListened?.toLocal()}
    Last:  ${lastListened?.toLocal()}
    Unique days: $uniqueDaysListened | Streak: $longestStreakDays days''';
}

class ArtistStats {
  final String artist;
  final int totalPlays;
  final int uniqueTracks;
  final int totalPlayedSeconds;
  final double avgCompletionRate;
  final double skipRate;
  final List<String> topTracks;
  final Map<String, int> albumPlayCounts;

  const ArtistStats({
    required this.artist,
    required this.totalPlays,
    required this.uniqueTracks,
    required this.totalPlayedSeconds,
    required this.avgCompletionRate,
    required this.skipRate,
    required this.topTracks,
    required this.albumPlayCounts,
  });

  @override
  String toString() => '''
  Artist: "$artist"
    Plays: $totalPlays across $uniqueTracks unique tracks
    Total time: ${_fmtDuration(totalPlayedSeconds)}
    Avg completion: ${(avgCompletionRate * 100).toStringAsFixed(1)}%
    Skip rate: ${(skipRate * 100).toStringAsFixed(1)}%
    Top tracks: ${topTracks.take(3).join(', ')}
    Albums: ${albumPlayCounts.entries.map((e) => '${e.key}(${e.value})').join(', ')}''';
}

class AlbumStats {
  final String album;
  final String artists;
  final int totalPlays;
  final int uniqueTracks;
  final int totalPlayedSeconds;
  final double avgCompletionRate;
  final int sequentialSessions;
  final double albumCompletionSessions;

  const AlbumStats({
    required this.album,
    required this.artists,
    required this.totalPlays,
    required this.uniqueTracks,
    required this.totalPlayedSeconds,
    required this.avgCompletionRate,
    required this.sequentialSessions,
    required this.albumCompletionSessions,
  });

  @override
  String toString() => '''
  Album: "$album" by $artists
    Plays: $totalPlays across $uniqueTracks tracks
    Total time: ${_fmtDuration(totalPlayedSeconds)}
    Avg completion: ${(avgCompletionRate * 100).toStringAsFixed(1)}%
    Sequential sessions: $sequentialSessions
    Full album listens: ${albumCompletionSessions.toStringAsFixed(1)}''';
}

class HourlyActivity {
  final int hour;
  final int plays;
  final int totalSeconds;

  const HourlyActivity({required this.hour, required this.plays, required this.totalSeconds});

  @override
  String toString() =>
      '  ${hour.toString().padLeft(2, '0')}:00 — $plays plays, ${_fmtDuration(totalSeconds)}';
}

class DailyActivity {
  final DateTime date;
  final int plays;
  final int totalSeconds;
  final int uniqueTracks;

  const DailyActivity({
    required this.date,
    required this.plays,
    required this.totalSeconds,
    required this.uniqueTracks,
  });

  @override
  String toString() =>
      '  ${date.toIso8601String().substring(0, 10)} — $plays plays, ${_fmtDuration(totalSeconds)}, $uniqueTracks unique tracks';
}

class ListeningSession {
  final DateTime start;
  final DateTime end;
  final List<ListenStat> stats;
  final int durationSeconds;
  final int uniqueTracks;

  const ListeningSession({
    required this.start,
    required this.end,
    required this.stats,
    required this.durationSeconds,
    required this.uniqueTracks,
  });

  @override
  String toString() =>
      '  Session ${start.toLocal()} → ${end.toLocal()} | ${stats.length} plays, $uniqueTracks unique tracks, ${_fmtDuration(durationSeconds)}';
}

class DiscoveryEvent {
  final KnownTrack track;
  final DateTime firstHeard;
  final int playsInFirstWeek;

  const DiscoveryEvent({
    required this.track,
    required this.firstHeard,
    required this.playsInFirstWeek,
  });

  @override
  String toString() =>
      '  "${track.title}" — first heard ${firstHeard.toLocal().toString().substring(0, 10)}, $playsInFirstWeek plays in first week';
}

class MoodPeriod {
  final String label;
  final DateTime start;
  final DateTime end;
  final double avgSkipRate;
  final double avgCompletionRate;
  final int plays;

  const MoodPeriod({
    required this.label,
    required this.start,
    required this.end,
    required this.avgSkipRate,
    required this.avgCompletionRate,
    required this.plays,
  });

  @override
  String toString() =>
      '  [$label] ${start.toLocal().toString().substring(0, 10)} → ${end.toLocal().toString().substring(0, 10)} | skip=${(avgSkipRate * 100).toStringAsFixed(0)}% complete=${(avgCompletionRate * 100).toStringAsFixed(0)}% plays=$plays';
}

class MusicAnalyticsReport {
  final int totalPlays;
  final int totalPlayedSeconds;
  final int totalCompletePlays;
  final int totalSkips;
  final double overallSkipRate;
  final double overallCompletionRate;
  final int uniqueTracksPlayed;
  final int uniqueArtistsPlayed;
  final int uniqueAlbumsPlayed;

  final DateTime? firstListenDate;
  final DateTime? lastListenDate;
  final int activeListeningDays;
  final double avgPlaysPerActiveDay;
  final double avgSecondsPerActiveDay;

  final List<TrackStats> topTracksByPlays;
  final List<TrackStats> topTracksByTime;
  final List<TrackStats> topTracksByCompletion;
  final List<TrackStats> mostSkippedTracks;
  final List<ArtistStats> topArtistsByPlays;
  final List<ArtistStats> topArtistsByTime;
  final List<AlbumStats> topAlbumsByPlays;
  final List<AlbumStats> topAlbumsByTime;
  final List<AlbumStats> mostPlayedSequentially;

  final List<HourlyActivity> hourlyActivity;
  final int peakHour;
  final List<String> peakDaysOfWeek;
  final List<DailyActivity> topDaysByPlays;
  final List<DailyActivity> topDaysByTime;
  final Map<String, int> playsByMonthYear;
  final Map<String, int> playsByDayOfWeek;

  final List<ListeningSession> longestSessions;
  final int totalSessions;
  final double avgSessionDurationSeconds;
  final int avgTracksPerSession;

  final int longestListeningStreakDays;
  final DateTime? longestStreakStart;
  final DateTime? longestStreakEnd;
  final int currentStreakDays;

  final List<DiscoveryEvent> mostReplayed;
  final List<KnownTrack> quicklyAbandoned;
  final Map<String, int> sourceBreakdown;

  final List<MoodPeriod> moodPeriods;
  final double morningListeningShare;
  final double afternoonListeningShare;
  final double eveningListeningShare;
  final double nightListeningShare;

  final double catalogExplorationRate;
  final double repeatListeningRate;
  final int longestRepeatStreak;
  final KnownTrack? mostRepeatedInRow;

  final Map<String, int> monthlyUniqueArtists;
  final Map<String, int> monthlyNewTracks;
  final double recentVsHistoricPlayRatio;

  const MusicAnalyticsReport({
    required this.totalPlays,
    required this.totalPlayedSeconds,
    required this.totalCompletePlays,
    required this.totalSkips,
    required this.overallSkipRate,
    required this.overallCompletionRate,
    required this.uniqueTracksPlayed,
    required this.uniqueArtistsPlayed,
    required this.uniqueAlbumsPlayed,
    required this.firstListenDate,
    required this.lastListenDate,
    required this.activeListeningDays,
    required this.avgPlaysPerActiveDay,
    required this.avgSecondsPerActiveDay,
    required this.topTracksByPlays,
    required this.topTracksByTime,
    required this.topTracksByCompletion,
    required this.mostSkippedTracks,
    required this.topArtistsByPlays,
    required this.topArtistsByTime,
    required this.topAlbumsByPlays,
    required this.topAlbumsByTime,
    required this.mostPlayedSequentially,
    required this.hourlyActivity,
    required this.peakHour,
    required this.peakDaysOfWeek,
    required this.topDaysByPlays,
    required this.topDaysByTime,
    required this.playsByMonthYear,
    required this.playsByDayOfWeek,
    required this.longestSessions,
    required this.totalSessions,
    required this.avgSessionDurationSeconds,
    required this.avgTracksPerSession,
    required this.longestListeningStreakDays,
    required this.longestStreakStart,
    required this.longestStreakEnd,
    required this.currentStreakDays,
    required this.mostReplayed,
    required this.quicklyAbandoned,
    required this.sourceBreakdown,
    required this.moodPeriods,
    required this.morningListeningShare,
    required this.afternoonListeningShare,
    required this.eveningListeningShare,
    required this.nightListeningShare,
    required this.catalogExplorationRate,
    required this.repeatListeningRate,
    required this.longestRepeatStreak,
    required this.mostRepeatedInRow,
    required this.monthlyUniqueArtists,
    required this.monthlyNewTracks,
    required this.recentVsHistoricPlayRatio,
  });

  @override
  String toString() {
    final buf = StringBuffer();
    buf.writeln('═' * 60);
    buf.writeln('  MUSIC ANALYTICS REPORT');
    buf.writeln('═' * 60);

    buf.writeln('\n▶ OVERVIEW');
    buf.writeln('  Total plays       : $totalPlays');
    buf.writeln('  Total time        : ${_fmtDuration(totalPlayedSeconds)}');
    buf.writeln('  Complete plays    : $totalCompletePlays');
    buf.writeln('  Skips             : $totalSkips (${(overallSkipRate * 100).toStringAsFixed(1)}%)');
    buf.writeln('  Completion rate   : ${(overallCompletionRate * 100).toStringAsFixed(1)}%');
    buf.writeln('  Unique tracks     : $uniqueTracksPlayed');
    buf.writeln('  Unique artists    : $uniqueArtistsPlayed');
    buf.writeln('  Unique albums     : $uniqueAlbumsPlayed');
    buf.writeln('  Active days       : $activeListeningDays');
    buf.writeln('  Avg plays/day     : ${avgPlaysPerActiveDay.toStringAsFixed(1)}');
    buf.writeln('  Avg time/day      : ${_fmtDuration(avgSecondsPerActiveDay.round())}');
    if (firstListenDate != null) {
      buf.writeln('  Period            : ${firstListenDate!.toIso8601String().substring(0, 10)} → ${lastListenDate?.toIso8601String().substring(0, 10)}');
    }

    buf.writeln('\n▶ TOP TRACKS BY PLAYS');
    for (final t in topTracksByPlays.take(10)) {
      buf.writeln('  ${topTracksByPlays.indexOf(t) + 1}. "${t.track.title}" — ${t.track.artists} (${t.totalPlays}x, ${_fmtDuration(t.totalPlayedSeconds)})');
    }

    buf.writeln('\n▶ TOP TRACKS BY TOTAL TIME');
    for (final t in topTracksByTime.take(10)) {
      buf.writeln('  ${topTracksByTime.indexOf(t) + 1}. "${t.track.title}" — ${t.track.artists} (${_fmtDuration(t.totalPlayedSeconds)}, ${t.totalPlays} plays)');
    }

    buf.writeln('\n▶ TOP TRACKS BY COMPLETION RATE (min 5 plays)');
    for (final t in topTracksByCompletion.take(10)) {
      buf.writeln('  ${topTracksByCompletion.indexOf(t) + 1}. "${t.track.title}" — ${(t.completionRate * 100).toStringAsFixed(1)}% complete (${t.totalPlays} plays)');
    }

    buf.writeln('\n▶ MOST SKIPPED TRACKS');
    for (final t in mostSkippedTracks.take(10)) {
      buf.writeln('  ${mostSkippedTracks.indexOf(t) + 1}. "${t.track.title}" — skip rate ${(t.skipRate * 100).toStringAsFixed(1)}% (${t.skips}/${t.totalPlays})');
    }

    buf.writeln('\n▶ TOP ARTISTS BY PLAYS');
    for (final a in topArtistsByPlays.take(10)) {
      buf.writeln('  ${topArtistsByPlays.indexOf(a) + 1}. ${a.artist} — ${a.totalPlays} plays, ${_fmtDuration(a.totalPlayedSeconds)}, ${a.uniqueTracks} tracks');
    }

    buf.writeln('\n▶ TOP ARTISTS BY TIME');
    for (final a in topArtistsByTime.take(10)) {
      buf.writeln('  ${topArtistsByTime.indexOf(a) + 1}. ${a.artist} — ${_fmtDuration(a.totalPlayedSeconds)}, ${a.totalPlays} plays');
    }

    buf.writeln('\n▶ TOP ALBUMS BY PLAYS');
    for (final a in topAlbumsByPlays.take(10)) {
      buf.writeln('  ${topAlbumsByPlays.indexOf(a) + 1}. "${a.album}" by ${a.artists} — ${a.totalPlays} plays, ${_fmtDuration(a.totalPlayedSeconds)}');
    }

    buf.writeln('\n▶ MOST PLAYED SEQUENTIALLY (album sessions)');
    for (final a in mostPlayedSequentially.take(5)) {
      buf.writeln('  "${a.album}" — ${a.sequentialSessions} sequential sessions, ~${a.albumCompletionSessions.toStringAsFixed(1)} full listens');
    }

    buf.writeln('\n▶ HOURLY ACTIVITY');
    for (final h in hourlyActivity) {
      final bar = '█' * (h.plays * 30 ~/ (hourlyActivity.map((x) => x.plays).reduce(max) + 1));
      buf.writeln('  ${h.hour.toString().padLeft(2, '0')}:00 $bar ${h.plays}');
    }
    buf.writeln('  Peak hour: $peakHour:00');

    buf.writeln('\n▶ DAY OF WEEK DISTRIBUTION');
    for (final e in playsByDayOfWeek.entries) {
      buf.writeln('  ${e.key.padRight(9)}: ${e.value} plays');
    }
    buf.writeln('  Peak days: ${peakDaysOfWeek.join(', ')}');

    buf.writeln('\n▶ PEAK DATES (by plays)');
    for (final d in topDaysByPlays.take(10)) buf.writeln(d);

    buf.writeln('\n▶ PEAK DATES (by time)');
    for (final d in topDaysByTime.take(10)) buf.writeln(d);

    buf.writeln('\n▶ MONTHLY PLAYS');
    for (final e in playsByMonthYear.entries) {
      buf.writeln('  ${e.key}: ${e.value} plays');
    }

    buf.writeln('\n▶ LISTENING SESSIONS (longest)');
    buf.writeln('  Total sessions : $totalSessions');
    buf.writeln('  Avg duration   : ${_fmtDuration(avgSessionDurationSeconds.round())}');
    buf.writeln('  Avg tracks     : $avgTracksPerSession');
    for (final s in longestSessions.take(5)) buf.writeln(s);

    buf.writeln('\n▶ STREAKS');
    buf.writeln('  Longest streak : $longestListeningStreakDays days');
    if (longestStreakStart != null) {
      buf.writeln('  Period         : ${longestStreakStart!.toIso8601String().substring(0, 10)} → ${longestStreakEnd?.toIso8601String().substring(0, 10)}');
    }
    buf.writeln('  Current streak : $currentStreakDays days');

    buf.writeln('\n▶ DISCOVERY & LOYALTY');
    buf.writeln('  Hot new picks (replayed fast):');
    for (final d in mostReplayed.take(5)) buf.writeln(d);
    buf.writeln('  Quickly abandoned tracks: ${quicklyAbandoned.length}');
    for (final t in quicklyAbandoned.take(5)) {
      buf.writeln('    "${t.title}" by ${t.artists}');
    }

    buf.writeln('\n▶ TIME-OF-DAY SPLIT');
    buf.writeln('  Morning   (06-12): ${(morningListeningShare * 100).toStringAsFixed(1)}%');
    buf.writeln('  Afternoon (12-18): ${(afternoonListeningShare * 100).toStringAsFixed(1)}%');
    buf.writeln('  Evening   (18-24): ${(eveningListeningShare * 100).toStringAsFixed(1)}%');
    buf.writeln('  Night     (00-06): ${(nightListeningShare * 100).toStringAsFixed(1)}%');

    buf.writeln('\n▶ LISTENING BEHAVIOUR');
    buf.writeln('  Catalog exploration rate : ${(catalogExplorationRate * 100).toStringAsFixed(1)}%');
    buf.writeln('  Repeat listening rate    : ${(repeatListeningRate * 100).toStringAsFixed(1)}%');
    if (mostRepeatedInRow != null) {
      buf.writeln('  Longest repeat streak    : $longestRepeatStreak× "${mostRepeatedInRow!.title}"');
    }

    buf.writeln('\n▶ SOURCES');
    for (final e in sourceBreakdown.entries) {
      buf.writeln('  ${e.key.padRight(15)}: ${e.value} plays');
    }

    buf.writeln('\n▶ MOOD PERIODS');
    for (final m in moodPeriods) buf.writeln(m);

    buf.writeln('\n▶ GROWTH TRENDS');
    buf.writeln('  Recent vs historic play ratio: ${recentVsHistoricPlayRatio.toStringAsFixed(2)}x');
    buf.writeln('  Monthly new tracks discovered:');
    for (final e in monthlyNewTracks.entries) {
      buf.writeln('    ${e.key}: ${e.value} new tracks');
    }
    buf.writeln('  Monthly unique artists heard:');
    for (final e in monthlyUniqueArtists.entries) {
      buf.writeln('    ${e.key}: ${e.value} artists');
    }

    buf.writeln('\n' + '═' * 60);
    return buf.toString();
  }
}

class MusicAnalyticsEngine {
  static const int _sessionGapSeconds = 30 * 60;

  static const int _completionThreshold = 80;

  static MusicAnalyticsReport analyze({
    required List<ListenStat> stats,
    required List<KnownTrack> tracks,
    int topN = 20,
  }) {
    if (stats.isEmpty) {
      throw ArgumentError('No stats to analyze');
    }

    // Index tracks by id
    final trackMap = {for (final t in tracks) t.id: t};

    final sorted = List<ListenStat>.from(stats)..sort((a, b) => a.time.compareTo(b.time));

    KnownTrack? getTrack(int id) => trackMap[id];

    final Map<int, List<ListenStat>> byTrack = {};
    for (final s in sorted) {
      byTrack.putIfAbsent(s.track, () => []).add(s);
    }

    TrackStats buildTrackStats(int trackId, List<ListenStat> tStats) {
      final t = getTrack(trackId);
      final plays = tStats.length;
      final skips = tStats.where((s) => s.isSkipped).length;
      final complete = tStats.where((s) => s.progressPercent >= _completionThreshold).length;
      final totalSec = tStats.fold(0, (acc, s) => acc + s.playedSeconds);
      final avgProgress = tStats.fold(0.0, (acc, s) => acc + s.progressPercent) / plays;

      final dates = tStats.map((s) => _dayKey(s.time)).toSet();
      final sortedDates = dates.toList()..sort();
      int streak = 1, maxStreak = 1;
      for (int i = 1; i < sortedDates.length; i++) {
        final prev = DateTime.parse(sortedDates[i - 1]);
        final curr = DateTime.parse(sortedDates[i]);
        if (curr.difference(prev).inDays == 1) {
          streak++;
          if (streak > maxStreak) maxStreak = streak;
        } else {
          streak = 1;
        }
      }

      return TrackStats(
        track: t ?? _unknownTrack(trackId),
        totalPlays: plays,
        completePlays: complete,
        skips: skips,
        totalPlayedSeconds: totalSec,
        avgProgressPercent: avgProgress,
        completionRate: plays > 0 ? complete / plays : 0,
        skipRate: plays > 0 ? skips / plays : 0,
        firstListened: tStats.first.time,
        lastListened: tStats.last.time,
        uniqueDaysListened: dates.length,
        longestStreakDays: maxStreak,
      );
    }

    final allTrackStats = byTrack.entries.map((e) => buildTrackStats(e.key, e.value)).toList();

    final Map<String, List<ListenStat>> byArtist = {};
    for (final s in sorted) {
      final t = getTrack(s.track);
      if (t == null) continue;
      for (final artist in [t.artists]) {
        byArtist.putIfAbsent(artist, () => []).add(s);
      }
    }

    ArtistStats buildArtistStats(String artist, List<ListenStat> aStats) {
      final plays = aStats.length;
      final skips = aStats.where((s) => s.isSkipped).length;
      final totalSec = aStats.fold(0, (acc, s) => acc + s.playedSeconds);
      final complete = aStats.where((s) => s.progressPercent >= _completionThreshold).length;

      final Map<String, int> trackPlays = {};
      final Map<String, int> albumPlays = {};
      for (final s in aStats) {
        final t = getTrack(s.track);
        if (t == null) continue;
        trackPlays[t.title] = (trackPlays[t.title] ?? 0) + 1;
        albumPlays[t.album] = (albumPlays[t.album] ?? 0) + 1;
      }

      final topTracks = (trackPlays.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
          .take(5).map((e) => e.key).toList();

      return ArtistStats(
        artist: artist,
        totalPlays: plays,
        uniqueTracks: trackPlays.keys.length,
        totalPlayedSeconds: totalSec,
        avgCompletionRate: plays > 0 ? complete / plays : 0,
        skipRate: plays > 0 ? skips / plays : 0,
        topTracks: topTracks,
        albumPlayCounts: albumPlays,
      );
    }

    final allArtistStats = byArtist.entries.map((e) => buildArtistStats(e.key, e.value)).toList();

    final Map<String, List<ListenStat>> byAlbum = {};
    for (final s in sorted) {
      final t = getTrack(s.track);
      if (t == null) continue;
      byAlbum.putIfAbsent(t.album, () => []).add(s);
    }

    Map<String, int> albumSeqSessions = {};
    Map<String, double> albumFullListens = {};
    {
      int run = 1;
      for (int i = 1; i < sorted.length; i++) {
        final prev = getTrack(sorted[i - 1].track);
        final curr = getTrack(sorted[i].track);
        if (prev != null && curr != null && prev.album == curr.album) {
          run++;
        } else {
          if (run >= 2) {
            final album = getTrack(sorted[i - 1].track)?.album ?? '';
            albumSeqSessions[album] = (albumSeqSessions[album] ?? 0) + 1;
          }
          run = 1;
        }
      }
    }

    for (final entry in byAlbum.entries) {
      final album = entry.key;
      final albumTracks = tracks.where((t) => t.album == album).map((t) => t.id).toSet();
      if (albumTracks.isEmpty) continue;
      final albumSorted = List<ListenStat>.from(entry.value)..sort((a, b) => a.time.compareTo(b.time));
      double fullListens = 0;
      Set<int> seen = {};
      for (int i = 0; i < albumSorted.length; i++) {
        seen.add(albumSorted[i].track);
        bool sessionEnd = i == albumSorted.length - 1 ||
            albumSorted[i + 1].time.difference(albumSorted[i].time).inSeconds > _sessionGapSeconds;
        if (sessionEnd) {
          fullListens += seen.length / albumTracks.length;
          seen = {};
        }
      }
      albumFullListens[album] = fullListens;
    }

    AlbumStats buildAlbumStats(String album, List<ListenStat> aStats) {
      final plays = aStats.length;
      final totalSec = aStats.fold(0, (acc, s) => acc + s.playedSeconds);
      final complete = aStats.where((s) => s.progressPercent >= _completionThreshold).length;
      final uniqueTracks = aStats.map((s) => s.track).toSet().length;
      final firstArtist = getTrack(aStats.first.track)?.artists ?? '';
      return AlbumStats(
        album: album,
        artists: firstArtist,
        totalPlays: plays,
        uniqueTracks: uniqueTracks,
        totalPlayedSeconds: totalSec,
        avgCompletionRate: plays > 0 ? complete / plays : 0,
        sequentialSessions: albumSeqSessions[album] ?? 0,
        albumCompletionSessions: albumFullListens[album] ?? 0,
      );
    }

    final allAlbumStats = byAlbum.entries.map((e) => buildAlbumStats(e.key, e.value)).toList();

    final Map<int, List<ListenStat>> byHour = {};
    final Map<String, List<ListenStat>> byDay = {};
    final Map<String, int> byDayOfWeek = {
      'Monday': 0, 'Tuesday': 0, 'Wednesday': 0, 'Thursday': 0,
      'Friday': 0, 'Saturday': 0, 'Sunday': 0,
    };
    final Map<String, int> byMonthYear = {};

    for (final s in sorted) {
      final local = s.time.toLocal();
      byHour.putIfAbsent(local.hour, () => []).add(s);
      byDay.putIfAbsent(_dayKey(local), () => []).add(s);
      final dow = _dowName(local.weekday);
      byDayOfWeek[dow] = (byDayOfWeek[dow] ?? 0) + 1;
      final my = '${local.year}-${local.month.toString().padLeft(2, '0')}';
      byMonthYear[my] = (byMonthYear[my] ?? 0) + 1;
    }

    final hourlyActivity = List.generate(24, (h) {
      final hs = byHour[h] ?? [];
      return HourlyActivity(
        hour: h,
        plays: hs.length,
        totalSeconds: hs.fold(0, (acc, s) => acc + s.playedSeconds),
      );
    });

    final peakHour = hourlyActivity.reduce((a, b) => a.plays >= b.plays ? a : b).hour;

    final maxDow = byDayOfWeek.values.reduce(max);
    final peakDays = byDayOfWeek.entries.where((e) => e.value == maxDow).map((e) => e.key).toList();

    DailyActivity dayActivity(String key, List<ListenStat> ds) => DailyActivity(
          date: DateTime.parse(key),
          plays: ds.length,
          totalSeconds: ds.fold(0, (acc, s) => acc + s.playedSeconds),
          uniqueTracks: ds.map((s) => s.track).toSet().length,
        );

    final allDailyActivity = byDay.entries.map((e) => dayActivity(e.key, e.value)).toList();

    final List<ListeningSession> sessions = [];
    List<ListenStat> currentSession = [sorted.first];

    for (int i = 1; i < sorted.length; i++) {
      final gap = sorted[i].time.difference(sorted[i - 1].time).inSeconds;
      if (gap > _sessionGapSeconds) {
        sessions.add(_buildSession(currentSession));
        currentSession = [];
      }
      currentSession.add(sorted[i]);
    }
    if (currentSession.isNotEmpty) sessions.add(_buildSession(currentSession));

    final activeDaySet = byDay.keys.toSet();
    final activeDaysSorted = activeDaySet.toList()..sort();
    int maxStreak = 0, curStreak = 0;
    DateTime? maxStreakStart, maxStreakEnd, tempStart;

    for (int i = 0; i < activeDaysSorted.length; i++) {
      if (i == 0) {
        curStreak = 1;
        tempStart = DateTime.parse(activeDaysSorted[0]);
      } else {
        final prev = DateTime.parse(activeDaysSorted[i - 1]);
        final curr = DateTime.parse(activeDaysSorted[i]);
        if (curr.difference(prev).inDays == 1) {
          curStreak++;
        } else {
          if (curStreak > maxStreak) {
            maxStreak = curStreak;
            maxStreakStart = tempStart;
            maxStreakEnd = prev;
          }
          curStreak = 1;
          tempStart = curr;
        }
      }
    }
    if (curStreak > maxStreak) {
      maxStreak = curStreak;
      maxStreakStart = tempStart;
      maxStreakEnd = activeDaysSorted.isNotEmpty ? DateTime.parse(activeDaysSorted.last) : null;
    }

    int currentStreak = 0;
    final today = DateTime.now();
    for (int i = activeDaysSorted.length - 1; i >= 0; i--) {
      final d = DateTime.parse(activeDaysSorted[i]);
      final diff = today.difference(d).inDays;
      if (diff == currentStreak) {
        currentStreak++;
      } else {
        break;
      }
    }

    final Map<int, DateTime> firstHeardMap = {};
    for (final s in sorted) {
      firstHeardMap.putIfAbsent(s.track, () => s.time);
    }

    final List<DiscoveryEvent> discoveryEvents = [];
    for (final entry in firstHeardMap.entries) {
      final weekLater = entry.value.add(const Duration(days: 7));
      final playsInWeek = byTrack[entry.key]!.where((s) => s.time.isBefore(weekLater)).length;
      if (playsInWeek >= 3) {
        final t = getTrack(entry.key);
        if (t != null) {
          discoveryEvents.add(DiscoveryEvent(track: t, firstHeard: entry.value, playsInFirstWeek: playsInWeek));
        }
      }
    }
    discoveryEvents.sort((a, b) => b.playsInFirstWeek.compareTo(a.playsInFirstWeek));

    final List<KnownTrack> abandoned = [];
    for (final entry in byTrack.entries) {
      if (entry.value.length == 1) {
        final t = getTrack(entry.key);
        if (t != null) abandoned.add(t);
      }
    }

    final Map<String, int> sourceCounts = {};
    for (final s in sorted) {
      final t = getTrack(s.track);
      if (t == null) continue;
      sourceCounts[t.source] = (sourceCounts[t.source] ?? 0) + 1;
    }

    int morningPlays = 0, afternoonPlays = 0, eveningPlays = 0, nightPlays = 0;
    for (final s in sorted) {
      final h = s.time.toLocal().hour;
      if (h >= 6 && h < 12) morningPlays++;
      else if (h >= 12 && h < 18) afternoonPlays++;
      else if (h >= 18) eveningPlays++;
      else nightPlays++;
    }
    final totalP = sorted.length;

    int longestRepeat = 1, tempRepeat = 1;
    int? longestRepeatTrackId;
    for (int i = 1; i < sorted.length; i++) {
      if (sorted[i].track == sorted[i - 1].track) {
        tempRepeat++;
        if (tempRepeat > longestRepeat) {
          longestRepeat = tempRepeat;
          longestRepeatTrackId = sorted[i].track;
        }
      } else {
        tempRepeat = 1;
      }
    }

    final List<MoodPeriod> moodPeriods = [];
    final Map<String, List<ListenStat>> byWeek = {};
    for (final s in sorted) {
      final d = s.time.toLocal();
      final weekStart = d.subtract(Duration(days: d.weekday - 1));
      final key = _dayKey(weekStart);
      byWeek.putIfAbsent(key, () => []).add(s);
    }
    for (final entry in byWeek.entries) {
      final ws = entry.value;
      final skipRate = ws.where((s) => s.isSkipped).length / ws.length;
      final compRate = ws.where((s) => s.progressPercent >= _completionThreshold).length / ws.length;
      String label;
      if (skipRate > 0.4) label = 'Restless / high skip';
      else if (compRate > 0.8) label = 'Deep listening';
      else if (compRate > 0.6) label = 'Engaged';
      else label = 'Casual';

      final weekStart = DateTime.parse(entry.key);
      moodPeriods.add(MoodPeriod(
        label: label,
        start: weekStart,
        end: weekStart.add(const Duration(days: 6)),
        avgSkipRate: skipRate,
        avgCompletionRate: compRate,
        plays: ws.length,
      ));
    }

    final Map<String, Set<int>> monthlyNewSet = {};
    final Map<String, Set<String>> monthlyArtistSet = {};
    final Set<int> seenTracks = {};

    for (final s in sorted) {
      final d = s.time.toLocal();
      final my = '${d.year}-${d.month.toString().padLeft(2, '0')}';
      monthlyArtistSet.putIfAbsent(my, () => {});
      final t = getTrack(s.track);
      if (t != null) {
        for (final a in [t.artists]) monthlyArtistSet[my]!.add(a);
      }
      if (!seenTracks.contains(s.track)) {
        seenTracks.add(s.track);
        monthlyNewSet.putIfAbsent(my, () => {}).add(s.track);
      }
    }

    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));
    final recentPlays = sorted.where((s) => s.time.isAfter(thirtyDaysAgo)).length;
    final historyDays = sorted.last.time.difference(sorted.first.time).inDays.clamp(1, 9999);
    final historicAvgPer30 = (sorted.length - recentPlays) / (historyDays / 30.0).clamp(1, 9999);
    final recentRatio = historicAvgPer30 > 0 ? recentPlays / historicAvgPer30 : 1.0;

    final totalSec = sorted.fold(0, (acc, s) => acc + s.playedSeconds);
    final totalSkips = sorted.where((s) => s.isSkipped).length;
    final totalComplete = sorted.where((s) => s.progressPercent >= _completionThreshold).length;

    return MusicAnalyticsReport(
      totalPlays: sorted.length,
      totalPlayedSeconds: totalSec,
      totalCompletePlays: totalComplete,
      totalSkips: totalSkips,
      overallSkipRate: sorted.length > 0 ? totalSkips / sorted.length : 0,
      overallCompletionRate: sorted.length > 0 ? totalComplete / sorted.length : 0,
      uniqueTracksPlayed: byTrack.keys.length,
      uniqueArtistsPlayed: byArtist.keys.length,
      uniqueAlbumsPlayed: byAlbum.keys.length,
      firstListenDate: sorted.first.time,
      lastListenDate: sorted.last.time,
      activeListeningDays: activeDaySet.length,
      avgPlaysPerActiveDay: activeDaySet.isEmpty ? 0 : sorted.length / activeDaySet.length,
      avgSecondsPerActiveDay: activeDaySet.isEmpty ? 0 : totalSec / activeDaySet.length,

      topTracksByPlays: (List<TrackStats>.from(allTrackStats)
            ..sort((a, b) => b.totalPlays.compareTo(a.totalPlays)))
          .take(topN).toList(),
      topTracksByTime: (List<TrackStats>.from(allTrackStats)
            ..sort((a, b) => b.totalPlayedSeconds.compareTo(a.totalPlayedSeconds)))
          .take(topN).toList(),
      topTracksByCompletion: (allTrackStats.where((t) => t.totalPlays >= 5).toList()
            ..sort((a, b) => b.completionRate.compareTo(a.completionRate)))
          .take(topN).toList(),
      mostSkippedTracks: (allTrackStats.where((t) => t.totalPlays >= 3).toList()
            ..sort((a, b) => b.skipRate.compareTo(a.skipRate)))
          .take(topN).toList(),

      topArtistsByPlays: (List<ArtistStats>.from(allArtistStats)
            ..sort((a, b) => b.totalPlays.compareTo(a.totalPlays)))
          .take(topN).toList(),
      topArtistsByTime: (List<ArtistStats>.from(allArtistStats)
            ..sort((a, b) => b.totalPlayedSeconds.compareTo(a.totalPlayedSeconds)))
          .take(topN).toList(),

      topAlbumsByPlays: (List<AlbumStats>.from(allAlbumStats)
            ..sort((a, b) => b.totalPlays.compareTo(a.totalPlays)))
          .take(topN).toList(),
      topAlbumsByTime: (List<AlbumStats>.from(allAlbumStats)
            ..sort((a, b) => b.totalPlayedSeconds.compareTo(a.totalPlayedSeconds)))
          .take(topN).toList(),
      mostPlayedSequentially: (List<AlbumStats>.from(allAlbumStats)
            ..sort((a, b) => b.sequentialSessions.compareTo(a.sequentialSessions)))
          .take(topN).toList(),

      hourlyActivity: hourlyActivity,
      peakHour: peakHour,
      peakDaysOfWeek: peakDays,
      topDaysByPlays: (List<DailyActivity>.from(allDailyActivity)
            ..sort((a, b) => b.plays.compareTo(a.plays)))
          .take(topN).toList(),
      topDaysByTime: (List<DailyActivity>.from(allDailyActivity)
            ..sort((a, b) => b.totalSeconds.compareTo(a.totalSeconds)))
          .take(topN).toList(),
      playsByMonthYear: Map.fromEntries(
          (byMonthYear.entries.toList()..sort((a, b) => a.key.compareTo(b.key)))),
      playsByDayOfWeek: byDayOfWeek,

      longestSessions: (List<ListeningSession>.from(sessions)
            ..sort((a, b) => b.durationSeconds.compareTo(a.durationSeconds)))
          .take(10).toList(),
      totalSessions: sessions.length,
      avgSessionDurationSeconds: sessions.isEmpty
          ? 0
          : sessions.fold(0, (acc, s) => acc + s.durationSeconds) / sessions.length,
      avgTracksPerSession: sessions.isEmpty
          ? 0
          : sessions.fold(0, (acc, s) => acc + s.stats.length) ~/ sessions.length,

      longestListeningStreakDays: maxStreak,
      longestStreakStart: maxStreakStart,
      longestStreakEnd: maxStreakEnd,
      currentStreakDays: currentStreak,

      mostReplayed: discoveryEvents.take(topN).toList(),
      quicklyAbandoned: abandoned,
      sourceBreakdown: sourceCounts,

      moodPeriods: moodPeriods,
      morningListeningShare: totalP > 0 ? morningPlays / totalP : 0,
      afternoonListeningShare: totalP > 0 ? afternoonPlays / totalP : 0,
      eveningListeningShare: totalP > 0 ? eveningPlays / totalP : 0,
      nightListeningShare: totalP > 0 ? nightPlays / totalP : 0,

      catalogExplorationRate: sorted.length > 0 ? byTrack.keys.length / sorted.length : 0,
      repeatListeningRate: allTrackStats.isEmpty
          ? 0
          : allTrackStats.where((t) => t.totalPlays > 1).length / allTrackStats.length,
      longestRepeatStreak: longestRepeat,
      mostRepeatedInRow: longestRepeatTrackId != null ? getTrack(longestRepeatTrackId) : null,

      monthlyUniqueArtists: monthlyArtistSet.map((k, v) => MapEntry(k, v.length)),
      monthlyNewTracks: monthlyNewSet.map((k, v) => MapEntry(k, v.length)),
      recentVsHistoricPlayRatio: recentRatio,
    );
  }

  static ListeningSession _buildSession(List<ListenStat> stats) {
    final start = stats.first.time;
    final end = stats.last.time;
    final dur = end.difference(start).inSeconds + (stats.last.playedSeconds);
    return ListeningSession(
      start: start,
      end: end,
      stats: stats,
      durationSeconds: dur,
      uniqueTracks: stats.map((s) => s.track).toSet().length,
    );
  }
}

String _dayKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String _dowName(int weekday) {
  const names = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  return names[weekday - 1];
}

String _fmtDuration(int seconds) {
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = seconds % 60;
  if (h > 0) return '${h}h ${m}m';
  if (m > 0) return '${m}m ${s}s';
  return '${s}s';
}

KnownTrack _unknownTrack(int id) => KnownTrack(
      id: id,
      path: '',
      title: 'Unknown #$id',
      artists: 'Unknown',
      album: 'Unknown',
      source: 'unknown',
      downloaded: false,
    );

void q56() async {
  final tracks = await AppDatabase().getKnownTracks();
  final stats = await AppDatabase().getStats();

  if (stats.isEmpty) {
    return;
  }

  final report = MusicAnalyticsEngine.analyze(
    stats: stats,
    tracks: tracks,
    topN: 20,
  );

  print(report);
}