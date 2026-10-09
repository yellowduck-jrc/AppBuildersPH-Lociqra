
import 'package:flutter/foundation.dart';

import 'local_storage.dart';

class DocumentCollection {
  final String id;
  final String name;
  final Set<String> documentIds;

  DocumentCollection({
    required this.id,
    required this.name,
    Set<String>? documentIds,
  }) : documentIds = documentIds ?? {};

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'document_ids': documentIds.toList(),
    };
  }

  factory DocumentCollection.fromJson(
    Map<String, dynamic> json,
  ) {
    return DocumentCollection(
      id: json['id'] as String,
      name: json['name'] as String,
      documentIds: Set<String>.from(
        json['document_ids'] as List? ?? [],
      ),
    );
  }
}

class CollectionStore extends ChangeNotifier {
  CollectionStore._();

  static final CollectionStore instance =
      CollectionStore._();

  final List<DocumentCollection> _collections = [];

  bool _initialized = false;

  List<DocumentCollection> get collections =>
      List.unmodifiable(_collections);

  Future<void> initialize() async {
    if (_initialized) return;

    final saved =
        await LocalStorage.loadJson(LocalStorage.collectionsKey);

    if (saved is List) {
      _collections.clear();

      for (final item in saved) {
        if (item is Map) {
          _collections.add(
            DocumentCollection.fromJson(
              Map<String, dynamic>.from(item),
            ),
          );
        }
      }
    }

    _initialized = true;
    notifyListeners();
  }

  void _save() {
    LocalStorage.saveJson(
      LocalStorage.collectionsKey,
      _collections
          .map((collection) => collection.toJson())
          .toList(),
    );
  }

  void addCollection(String name) {
    final trimmed = name.trim();

    if (trimmed.isEmpty) return;

    _collections.add(
      DocumentCollection(
        id: DateTime.now()
            .microsecondsSinceEpoch
            .toString(),
        name: trimmed,
      ),
    );

    notifyListeners();
    _save();
  }

  void removeCollection(String id) {
    _collections.removeWhere(
      (collection) => collection.id == id,
    );

    notifyListeners();
    _save();
  }

  void toggleDocument(
    String collectionId,
    String documentId,
  ) {
    for (final collection in _collections) {
      if (collection.id != collectionId) continue;

      if (collection.documentIds.contains(documentId)) {
        collection.documentIds.remove(documentId);
      } else {
        collection.documentIds.add(documentId);
      }

      notifyListeners();
      _save();
      return;
    }
  }

  void removeDocumentFromAll(String documentId) {
    for (final collection in _collections) {
      collection.documentIds.remove(documentId);
    }

    notifyListeners();
    _save();
  }
}
