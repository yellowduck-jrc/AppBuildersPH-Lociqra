
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class LocalStorage {
  LocalStorage._();

  static const String documentsKey = 'lociqra_documents';
  static const String collectionsKey = 'lociqra_collections';
  static const String starredKey = 'lociqra_starred';
  static const String recentKey = 'lociqra_recent';

  static Future<void> saveJson(
    String key,
    Object value,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      key,
      jsonEncode(value),
    );
  }

  static Future<dynamic> loadJson(String key) async {
    final prefs = await SharedPreferences.getInstance();

    final value = prefs.getString(key);

    if (value == null) return null;

    return jsonDecode(value);
  }
}
