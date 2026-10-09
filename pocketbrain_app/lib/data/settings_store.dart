
import 'package:flutter/foundation.dart';

import 'local_storage.dart';

class SettingsStore extends ChangeNotifier {
  SettingsStore._();

  static final SettingsStore instance =
      SettingsStore._();

  static const String storageKey = 'lociqra_settings';

  bool _initialized = false;

  bool _compactMode = false;
  bool _showSourceReferences = true;
  bool _confirmBeforeDeleting = true;

  int _retrievalCount = 5;

  // GETTERS

  bool get compactMode => _compactMode;

  bool get showSourceReferences =>
      _showSourceReferences;

  bool get confirmBeforeDeleting =>
      _confirmBeforeDeleting;

  int get retrievalCount => _retrievalCount;

  // LOAD SAVED SETTINGS

  Future<void> initialize() async {
    if (_initialized) return;

    try {
      final data = await LocalStorage.loadJson(
        storageKey,
      );

      if (data is Map) {
        _compactMode = data['compact_mode'] == true;

        _showSourceReferences =
            data['show_source_references'] != false;

        _confirmBeforeDeleting =
            data['confirm_before_deleting'] != false;

        final count = data['retrieval_count'];

        if (count is num) {
          _retrievalCount =
              count.toInt().clamp(1, 10).toInt();
        }
      }
    } catch (error) {
      debugPrint('Failed to load settings: $error');
    }

    _initialized = true;
    notifyListeners();
  }

  // SAVE SETTINGS

  Future<void> _save() async {
    try {
      await LocalStorage.saveJson(
        storageKey,
        {
          'compact_mode': _compactMode,
          'show_source_references':
              _showSourceReferences,
          'confirm_before_deleting':
              _confirmBeforeDeleting,
          'retrieval_count': _retrievalCount,
        },
      );
    } catch (error) {
      debugPrint('Failed to save settings: $error');
    }
  }

  // UPDATE COMPACT MODE

  void setCompactMode(bool value) {
    if (_compactMode == value) return;

    _compactMode = value;
    notifyListeners();
    _save();
  }

  // UPDATE SOURCE REFERENCES

  void setShowSourceReferences(bool value) {
    if (_showSourceReferences == value) return;

    _showSourceReferences = value;
    notifyListeners();
    _save();
  }

  // UPDATE DELETE CONFIRMATION

  void setConfirmBeforeDeleting(bool value) {
    if (_confirmBeforeDeleting == value) return;

    _confirmBeforeDeleting = value;
    notifyListeners();
    _save();
  }

  // UPDATE RETRIEVAL COUNT

  void setRetrievalCount(int value) {
    final safeValue = value.clamp(1, 10).toInt();

    if (_retrievalCount == safeValue) return;

    _retrievalCount = safeValue;
    notifyListeners();
    _save();
  }
}
