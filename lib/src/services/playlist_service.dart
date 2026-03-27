import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// Lightweight local playlist storage using SharedPreferences.
///
/// Each playlist is stored as a Map with keys:
/// id, title, description, type, tags (List<String>), posts (List<Map>),
/// cover (String?), createdAt (ISO string).
class PlaylistService {
  static const _storageKey = 'coonch_playlists_v1';

  /// Load all playlists from local storage. Returns an empty list if none.
  static Future<List<Map<String, dynamic>>> loadPlaylists() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((e) => e.cast<String, dynamic>())
            .toList();
      }
    } catch (_) {}
    return [];
  }

  /// Persist the provided list of playlists to disk.
  static Future<void> _savePlaylists(
      List<Map<String, dynamic>> playlists) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(playlists));
  }

  /// Add a playlist and persist. Returns the stored playlist map.
  static Future<Map<String, dynamic>> addPlaylist(
      Map<String, dynamic> playlist) async {
    final all = await loadPlaylists();
    final withId = {
      ...playlist,
      // Keep caller-provided IDs, but ensure a generated ID is not overwritten by null.
      'id': playlist['id'] ?? _generateId(),
    };
    all.insert(0, withId);
    await _savePlaylists(all);
    return withId;
  }

  /// Get a playlist by id, or null if not found.
  static Future<Map<String, dynamic>?> getById(String id) async {
    final all = await loadPlaylists();
    try {
      return all.firstWhere((p) => p['id'] == id);
    } catch (_) {
      return null;
    }
  }

  /// Replace all playlists (e.g., after deletion).
  static Future<void> replaceAll(List<Map<String, dynamic>> playlists) async {
    await _savePlaylists(playlists);
  }

  /// Remove a playlist by id.
  static Future<void> deleteById(String id) async {
    final all = await loadPlaylists();
    all.removeWhere((p) => p['id'] == id);
    await _savePlaylists(all);
  }

  static String _generateId() {
    final rnd = Random().nextInt(999999).toString().padLeft(6, '0');
    return 'pl_${DateTime.now().millisecondsSinceEpoch}_$rnd';
  }
}
