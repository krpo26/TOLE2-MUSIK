import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

class LyricLine {
  final Duration at;
  final String text;
  const LyricLine(this.at, this.text);
}

class ParsedLyrics {
  final List<LyricLine> lines;
  final bool timed;
  const ParsedLyrics(this.lines, this.timed);
}

/// Letras por canción: se cargan desde un archivo .lrc (sincronizado) o .txt.
class LyricsService {
  static Future<File> _file(String id) async {
    final dir = await getApplicationDocumentsDirectory();
    final safe = id.replaceAll(RegExp(r'[^A-Za-z0-9_]'), '_');
    return File('${dir.path}/lyrics_$safe.txt');
  }

  static Future<String?> load(String id) async {
    final f = await _file(id);
    return await f.exists() ? f.readAsString() : null;
  }

  static Future<bool> pickAndSave(String id) async {
    final res = await FilePicker.platform.pickFiles(type: FileType.any);
    final path = res?.files.single.path;
    if (path == null) return false;
    final bytes = await File(path).readAsBytes();
    final text = utf8.decode(bytes, allowMalformed: true);
    final f = await _file(id);
    await f.writeAsString(text);
    return true;
  }

  static Future<void> delete(String id) async {
    final f = await _file(id);
    if (await f.exists()) await f.delete();
  }

  static ParsedLyrics parse(String raw) {
    final stamp = RegExp(r'\[(\d{1,3}):(\d{1,2})(?:[.:](\d{1,3}))?\]');
    final timed = <LyricLine>[];
    final plain = <String>[];
    for (final line in raw.split(RegExp(r'\r?\n'))) {
      final ms = stamp.allMatches(line).toList();
      final text = line.replaceAll(stamp, '').trim();
      if (ms.isEmpty) {
        if (!RegExp(r'^\[[a-zA-Z]+:.*\]$').hasMatch(line.trim())) {
          plain.add(line.trim());
        }
        continue;
      }
      for (final m in ms) {
        final mm = int.parse(m.group(1)!);
        final ss = int.parse(m.group(2)!);
        final frac = m.group(3);
        var msv = 0;
        if (frac != null) {
          msv = int.parse(frac.padRight(3, '0').substring(0, 3));
        }
        timed.add(LyricLine(
            Duration(minutes: mm, seconds: ss, milliseconds: msv), text));
      }
    }
    if (timed.isNotEmpty) {
      timed.sort((a, b) => a.at.compareTo(b.at));
      return ParsedLyrics(timed, true);
    }
    return ParsedLyrics(
        plain.map((t) => LyricLine(Duration.zero, t)).toList(), false);
  }
}
