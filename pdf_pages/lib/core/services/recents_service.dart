import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Represents a recently opened PDF file
class RecentFile {
  final String name;
  final String path;
  final DateTime openedAt;

  RecentFile({
    required this.name,
    required this.path,
    required this.openedAt,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'path': path,
        'openedAt': openedAt.toIso8601String(),
      };

  factory RecentFile.fromJson(Map<String, dynamic> json) => RecentFile(
        name: json['name'] as String,
        path: json['path'] as String,
        openedAt: DateTime.parse(json['openedAt'] as String),
      );

  @override
  String toString() => 'RecentFile(name: $name, path: $path, openedAt: $openedAt)';
}

/// Service for managing recently opened PDF files
/// Stores up to 20 recent files in SharedPreferences
class RecentsService {
  static const String _storageKey = 'pdf_pages_recents';
  static const int _maxRecents = 20;

  SharedPreferences? _prefs;
  List<RecentFile> _recents = [];

  /// Initialize the service and load existing recents
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    _loadRecents();
  }

  /// Load recents from SharedPreferences
  void _loadRecents() {
    final String? jsonString = _prefs?.getString(_storageKey);
    if (jsonString != null) {
      try {
        final List<dynamic> jsonList = jsonDecode(jsonString);
        _recents = jsonList
            .map((json) => RecentFile.fromJson(json as Map<String, dynamic>))
            .toList();
      } catch (e) {
        // If parsing fails, start fresh
        _recents = [];
      }
    }
  }

  /// Save recents to SharedPreferences
  Future<void> _saveRecents() async {
    final jsonString = jsonEncode(_recents.map((r) => r.toJson()).toList());
    await _prefs?.setString(_storageKey, jsonString);
  }

  /// Add a file to recent history
  /// If file already exists, updates its timestamp and moves to top
  Future<void> addRecent(String name, String path) async {
    // Remove existing entry with same path (if any)
    _recents.removeWhere((r) => r.path == path);

    // Add new entry at the beginning
    _recents.insert(
      0,
      RecentFile(
        name: name,
        path: path,
        openedAt: DateTime.now(),
      ),
    );

    // Keep only the most recent _maxRecents entries
    if (_recents.length > _maxRecents) {
      _recents = _recents.sublist(0, _maxRecents);
    }

    await _saveRecents();
  }

  /// Get all recent files
  List<RecentFile> getRecents() => List.unmodifiable(_recents);

  /// Search recents by name using fuzzy matching
  /// Returns files where the search query is a substring of the filename
  /// Results are ordered by match quality (exact match first, then by recency)
  List<RecentFile> searchRecents(String query) {
    if (query.isEmpty) return [];

    final normalizedQuery = query.toLowerCase().trim();

    // Score each recent file based on match quality
    final scoredResults = <MapEntry<RecentFile, int>>[];

    for (final recent in _recents) {
      final normalizedName = recent.name.toLowerCase();
      final nameWithoutExtension = normalizedName.endsWith('.pdf')
          ? normalizedName.substring(0, normalizedName.length - 4)
          : normalizedName;

      int score = 0;

      // Exact match (highest priority)
      if (nameWithoutExtension == normalizedQuery || normalizedName == normalizedQuery) {
        score = 100;
      }
      // Starts with query
      else if (nameWithoutExtension.startsWith(normalizedQuery)) {
        score = 80;
      }
      // Contains query as a word (word boundary match)
      else if (_containsWord(nameWithoutExtension, normalizedQuery)) {
        score = 60;
      }
      // Contains query anywhere
      else if (nameWithoutExtension.contains(normalizedQuery)) {
        score = 40;
      }
      // Fuzzy match - query words appear in name
      else if (_fuzzyMatch(nameWithoutExtension, normalizedQuery)) {
        score = 20;
      }

      if (score > 0) {
        scoredResults.add(MapEntry(recent, score));
      }
    }

    // Sort by score (descending), then by recency
    scoredResults.sort((a, b) {
      final scoreCompare = b.value.compareTo(a.value);
      if (scoreCompare != 0) return scoreCompare;
      return b.key.openedAt.compareTo(a.key.openedAt);
    });

    return scoredResults.map((e) => e.key).toList();
  }

  /// Check if the name contains the query as a whole word
  bool _containsWord(String name, String query) {
    final words = name.split(RegExp(r'[\s_\-.]'));
    return words.any((word) => word == query || word.startsWith(query));
  }

  /// Fuzzy match - all words in query appear somewhere in name
  bool _fuzzyMatch(String name, String query) {
    final queryWords = query.split(RegExp(r'\s+'));
    return queryWords.every((word) => name.contains(word));
  }

  /// Find best match for a search query
  /// Returns the most likely match or null if no good match found
  RecentFile? findBestMatch(String query) {
    final results = searchRecents(query);
    return results.isNotEmpty ? results.first : null;
  }

  /// Clear all recents
  Future<void> clearRecents() async {
    _recents = [];
    await _saveRecents();
  }

  /// Remove a specific file from recents by path
  Future<void> removeRecent(String path) async {
    _recents.removeWhere((r) => r.path == path);
    await _saveRecents();
  }
}
