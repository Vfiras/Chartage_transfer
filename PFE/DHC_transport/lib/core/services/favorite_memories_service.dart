import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Photos a client attaches to a saved place ("Memories").
///
/// Deliberately **device-local**: there is no backend endpoint for favourite
/// photos, and adding one would mean an upload pipeline, storage quota and
/// moderation. Paths live in `SharedPreferences` keyed by favourite id.
///
/// Picked images are **copied** out of the picker's cache into
/// `<app documents>/favorite_memories/` before being recorded — the cache
/// directory is evictable by the OS, so storing the raw pick path would make
/// albums silently empty themselves. Deleting a photo removes the file too.
class FavoriteMemoriesService {
  const FavoriteMemoriesService();

  static const _key = 'favorite_memories';
  static const _folder = 'favorite_memories';

  Future<Map<String, List<String>>> _readAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = json.decode(raw) as Map<String, dynamic>;
      return decoded.map(
        (k, v) => MapEntry(k, (v as List).map((e) => e.toString()).toList()),
      );
    } catch (_) {
      return {};
    }
  }

  Future<void> _writeAll(Map<String, List<String>> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, json.encode(data));
  }

  /// Recorded photos for a favourite, with vanished files filtered out.
  Future<List<String>> photosFor(String favoriteId) async {
    final all = await _readAll();
    final recorded = all[favoriteId] ?? const <String>[];
    final existing = [
      for (final path in recorded)
        if (File(path).existsSync()) path,
    ];
    // Self-heal the index if anything disappeared despite the copy.
    if (existing.length != recorded.length) {
      all[favoriteId] = existing;
      await _writeAll(all);
    }
    return existing;
  }

  Future<int> countFor(String favoriteId) async =>
      (await photosFor(favoriteId)).length;

  /// Copies [sourcePath] into app storage and records it. Returns the new list.
  Future<List<String>> addPhoto(String favoriteId, String sourcePath) async {
    final dir = Directory(
      '${(await getApplicationDocumentsDirectory()).path}/$_folder',
    );
    if (!dir.existsSync()) dir.createSync(recursive: true);

    final ext = sourcePath.contains('.') ? sourcePath.split('.').last : 'jpg';
    final dest =
        '${dir.path}/${favoriteId}_${DateTime.now().millisecondsSinceEpoch}.$ext';
    await File(sourcePath).copy(dest);

    final all = await _readAll();
    all[favoriteId] = [...(all[favoriteId] ?? const <String>[]), dest];
    await _writeAll(all);
    return all[favoriteId]!;
  }

  /// Removes the record and deletes the copied file.
  Future<List<String>> removePhoto(String favoriteId, String path) async {
    final all = await _readAll();
    final list = [...(all[favoriteId] ?? const <String>[])]..remove(path);
    all[favoriteId] = list;
    await _writeAll(all);
    try {
      final file = File(path);
      if (file.existsSync()) await file.delete();
    } catch (_) {
      // Index is already updated; a stranded file is harmless.
    }
    return list;
  }

  /// Drops a favourite's whole album (used when the favourite is deleted).
  Future<void> clearFor(String favoriteId) async {
    final all = await _readAll();
    for (final path in all[favoriteId] ?? const <String>[]) {
      try {
        final file = File(path);
        if (file.existsSync()) await file.delete();
      } catch (_) {}
    }
    all.remove(favoriteId);
    await _writeAll(all);
  }
}
