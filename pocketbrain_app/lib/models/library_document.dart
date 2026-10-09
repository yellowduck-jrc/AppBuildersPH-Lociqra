
class LibraryDocument {
  final String id;
  final String name;
  final String type;
  final String? path;

  const LibraryDocument({
    required this.id,
    required this.name,
    required this.type,
    this.path,
  });

  bool get isLocalFile => path != null;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'path': path,
    };
  }

  factory LibraryDocument.fromJson(
    Map<String, dynamic> json,
  ) {
    return LibraryDocument(
      id: json['id'] as String,
      name: json['name'] as String,
      type: json['type'] as String,
      path: json['path'] as String?,
    );
  }
}
