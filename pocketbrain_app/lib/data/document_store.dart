
import 'package:flutter/foundation.dart';

import '../Services/api_service.dart';
import '../models/library_document.dart';
import 'local_storage.dart';

class DocumentStore extends ChangeNotifier {
  DocumentStore._();

  static final DocumentStore instance = DocumentStore._();

  final List<LibraryDocument> _documents = [];
  final Set<String> _starredIds = {};
  final List<String> _recentIds = [];
  final Set<String> _backendDocumentIds = {};

  bool _initialized = false;
  bool _isSyncing = false;
  String? _syncError;

  bool get isInitialized => _initialized;
  bool get isSyncing => _isSyncing;
  String? get syncError => _syncError;

  List<LibraryDocument> get documents =>
      List.unmodifiable(_documents);

  // Documents confirmed to exist in FastAPI.
  List<LibraryDocument> get searchableDocuments =>
      List.unmodifiable(
        _documents.where(
          (doc) => _backendDocumentIds.contains(doc.id),
        ),
      );

  // Only show starred documents that exist in FastAPI.
  List<LibraryDocument> get starredDocuments =>
      List.unmodifiable(
        _documents.where(
          (doc) =>
              _backendDocumentIds.contains(doc.id) &&
              _starredIds.contains(doc.id),
        ),
      );

  // Only show recent documents that exist in FastAPI.
  List<LibraryDocument> get recentDocuments =>
      List.unmodifiable(
        _recentIds
            .map(_findDocumentById)
            .whereType<LibraryDocument>()
            .where(
              (doc) => _backendDocumentIds.contains(doc.id),
            ),
      );

  bool isStarred(String id) => _starredIds.contains(id);

  bool isBackendDocument(String id) =>
      _backendDocumentIds.contains(id);

  static String serverDocumentId(String filename) =>
      'server:$filename';

  LibraryDocument? _findDocumentById(String id) {
    for (final document in _documents) {
      if (document.id == id) {
        return document;
      }
    }

    return null;
  }

  LibraryDocument? findBackendDocumentByName(
    String filename,
  ) {
    for (final document in _documents) {
      if (_backendDocumentIds.contains(document.id) &&
          document.name == filename) {
        return document;
      }
    }

    return null;
  }

  Future<void> initialize() async {
    if (_initialized) return;

    final savedDocuments =
        await LocalStorage.loadJson(
          LocalStorage.documentsKey,
        );

    final savedStarred =
        await LocalStorage.loadJson(
          LocalStorage.starredKey,
        );

    final savedRecent =
        await LocalStorage.loadJson(
          LocalStorage.recentKey,
        );

    if (savedDocuments is List) {
      _documents.clear();

      for (final item in savedDocuments) {
        if (item is Map) {
          try {
            _documents.add(
              LibraryDocument.fromJson(
                Map<String, dynamic>.from(item),
              ),
            );
          } catch (error) {
            debugPrint(
              'Skipping invalid saved document: $error',
            );
          }
        }
      }
    }

    if (savedStarred is List) {
      _starredIds
        ..clear()
        ..addAll(savedStarred.whereType<String>());
    }

    if (savedRecent is List) {
      _recentIds
        ..clear()
        ..addAll(savedRecent.whereType<String>());
    }

    _initialized = true;
    notifyListeners();

    try {
      await syncWithBackend();
    } catch (error) {
      debugPrint(
        'Initial backend sync failed: $error',
      );
    }
  }

  Future<void> syncWithBackend() async {
    if (_isSyncing) return;

    _isSyncing = true;
    _syncError = null;
    notifyListeners();

    try {
      final serverDocuments =
          await ApiService.getDocuments();

      final serverNames = serverDocuments
          .map(
            (item) =>
                item['filename']?.toString() ?? '',
          )
          .where((name) => name.isNotEmpty)
          .toSet();

      // Remove obsolete backend-generated entries.
      final removedIds = _documents
          .where(
            (doc) =>
                doc.id.startsWith('server:') &&
                !serverNames.contains(doc.name),
          )
          .map((doc) => doc.id)
          .toSet();

      _documents.removeWhere(
        (doc) => removedIds.contains(doc.id),
      );

      for (final id in removedIds) {
        _starredIds.remove(id);
        _recentIds.remove(id);
      }

      _backendDocumentIds.clear();

      for (final filename in serverNames) {
        LibraryDocument? existing;

        // Preserve IDs for existing valid PDF records.
        for (final document in _documents) {
          if (document.name == filename &&
              document.type.toUpperCase() == 'PDF') {
            existing = document;
            break;
          }
        }

        if (existing != null) {
          _backendDocumentIds.add(existing.id);
          continue;
        }

        final document = LibraryDocument(
          id: serverDocumentId(filename),
          name: filename,
          type: 'PDF',
        );

        _documents.add(document);
        _backendDocumentIds.add(document.id);
      }

      // Remove history references that no longer
      // correspond to an indexed backend document.
      _recentIds.removeWhere(
        (id) => !_backendDocumentIds.contains(id),
      );

      _starredIds.removeWhere(
        (id) => !_backendDocumentIds.contains(id),
      );

      // Remove duplicate recent IDs while preserving
      // their order.
      final seenRecentIds = <String>{};

      _recentIds.removeWhere(
        (id) => !seenRecentIds.add(id),
      );

      _save();
    } catch (error) {
      _syncError = error.toString();

      debugPrint(
        'Document synchronization failed: $error',
      );

      rethrow;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  void _save() {
    LocalStorage.saveJson(
      LocalStorage.documentsKey,
      _documents
          .map((doc) => doc.toJson())
          .toList(),
    );

    LocalStorage.saveJson(
      LocalStorage.starredKey,
      _starredIds.toList(),
    );

    LocalStorage.saveJson(
      LocalStorage.recentKey,
      _recentIds,
    );
  }

  void toggleStar(String id) {
    if (!_backendDocumentIds.contains(id)) {
      return;
    }

    if (_starredIds.contains(id)) {
      _starredIds.remove(id);
    } else {
      _starredIds.add(id);
    }

    notifyListeners();
    _save();
  }

  void markRecent(String id) {
    // Never record deleted or local-only documents.
    if (!_backendDocumentIds.contains(id)) {
      return;
    }

    _recentIds.remove(id);
    _recentIds.insert(0, id);

    if (_recentIds.length > 20) {
      _recentIds.removeRange(
        20,
        _recentIds.length,
      );
    }

    notifyListeners();
    _save();
  }

  // Useful when the Ask page knows the PDF filename
  // but not its internal document ID.
  void markRecentByFilename(String filename) {
    final document = findBackendDocumentByName(
      filename,
    );

    if (document == null) {
      debugPrint(
        'Cannot mark unknown PDF as recent: $filename',
      );
      return;
    }

    markRecent(document.id);
  }

  void addDocument(LibraryDocument document) {
    if (_documents.any(
      (doc) => doc.id == document.id,
    )) {
      return;
    }

    _documents.add(document);

    // Do not automatically mark unverified local
    // documents as recently used.
    if (_backendDocumentIds.contains(document.id)) {
      markRecent(document.id);
    } else {
      notifyListeners();
      _save();
    }
  }

  void removeDocument(String id) {
    final document = _findDocumentById(id);

    // Also remove duplicate records that refer
    // to the same backend PDF filename.
    final removedIds = _documents
        .where(
          (doc) =>
              doc.id == id ||
              (document != null &&
                  doc.name == document.name &&
                  doc.type.toUpperCase() == 'PDF'),
        )
        .map((doc) => doc.id)
        .toSet();

    _documents.removeWhere(
      (doc) => removedIds.contains(doc.id),
    );

    _starredIds.removeAll(removedIds);
    _recentIds.removeWhere(removedIds.contains);
    _backendDocumentIds.removeAll(removedIds);

    notifyListeners();
    _save();
  }
}
