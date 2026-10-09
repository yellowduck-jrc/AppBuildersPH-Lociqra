
class SourceSelection {
  final bool useAllFiles;
  final List<String> documentIds;

  const SourceSelection({
    required this.useAllFiles,
    required this.documentIds,
  });

  bool get hasSources => documentIds.isNotEmpty;

  Map<String, dynamic> toJson() {
    return {
      'use_all_files': useAllFiles,
      'document_ids': documentIds,
    };
  }
}
