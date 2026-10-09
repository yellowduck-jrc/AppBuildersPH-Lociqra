import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../data/collection_store.dart';
import '../data/document_store.dart';
import '../data/settings_store.dart';
import '../models/library_document.dart';
import '../models/source_selection.dart';

enum SourceMode { all, collection, individual }

class SourceSelector extends StatefulWidget {
  final ValueChanged<SourceSelection> onSelectionChanged;

  const SourceSelector({super.key, required this.onSelectionChanged});

  @override
  State<SourceSelector> createState() => _SourceSelectorState();
}

class _SourceSelectorState extends State<SourceSelector> {
  final DocumentStore store = DocumentStore.instance;
  final CollectionStore collectionStore = CollectionStore.instance;
  final SettingsStore settings = SettingsStore.instance;

  SourceMode mode = SourceMode.all;

  String? selectedCollectionId;

  final Set<String> selectedIds = {};

  bool get compact => settings.compactMode;

  @override
  void initState() {
    super.initState();

    store.addListener(_onDataChanged);
    collectionStore.addListener(_onDataChanged);
    settings.addListener(_onSettingsChanged);
  }

  @override
  void dispose() {
    store.removeListener(_onDataChanged);
    collectionStore.removeListener(_onDataChanged);
    settings.removeListener(_onSettingsChanged);

    super.dispose();
  }

  void _onSettingsChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  DocumentCollection? get selectedCollection {
    for (final collection in collectionStore.collections) {
      if (collection.id == selectedCollectionId) {
        return collection;
      }
    }

    return null;
  }

  SourceSelection get selection {
    final documents = store.searchableDocuments;

    final List<String> ids;

    switch (mode) {
      case SourceMode.all:
        ids = documents.map((doc) => doc.id).toList();
        break;

      case SourceMode.collection:
        final collection = selectedCollection;

        ids = collection == null
            ? []
            : documents
                  .where((doc) => collection.documentIds.contains(doc.id))
                  .map((doc) => doc.id)
                  .toList();
        break;

      case SourceMode.individual:
        ids = documents
            .where((doc) => selectedIds.contains(doc.id))
            .map((doc) => doc.id)
            .toList();
        break;
    }

    return SourceSelection(
      useAllFiles: mode == SourceMode.all,
      documentIds: ids,
    );
  }

  void notifySelection() {
    widget.onSelectionChanged(selection);
  }

  void _onDataChanged() {
    final validIds = store.searchableDocuments.map((doc) => doc.id).toSet();

    selectedIds.removeWhere((id) => !validIds.contains(id));

    final collectionExists = collectionStore.collections.any(
      (collection) => collection.id == selectedCollectionId,
    );

    if (!collectionExists) {
      selectedCollectionId = null;
    }

    if (!mounted) return;

    setState(() {});

    notifySelection();
  }

  void changeMode(SourceMode newMode) {
    if (mode == newMode) return;

    setState(() {
      mode = newMode;
    });

    notifySelection();
  }

  void selectCollection(String? id) {
    setState(() {
      selectedCollectionId = id;
    });

    notifySelection();
  }

  void toggleDocument(String id, bool? value) {
    setState(() {
      if (value == true) {
        selectedIds.add(id);
      } else {
        selectedIds.remove(id);
      }
    });

    notifySelection();
  }

  // =====================================================
  // SOURCE MODE OPTION
  // =====================================================

  Widget buildModeOption({
    required SourceMode value,
    required String title,
    required IconData icon,
  }) {
    final selected = mode == value;

    return InkWell(
      onTap: () => changeMode(value),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 7 : 10,
          vertical: compact ? 5 : 10,
        ),
        decoration: BoxDecoration(
          color: selected ? AppColors.sidebar : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.accent : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: compact ? 16 : 19,
              color: selected ? AppColors.accent : AppColors.muted,
            ),

            SizedBox(width: compact ? 7 : 10),

            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: compact ? 11 : 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),

            Radio<SourceMode>(
              value: value,
              groupValue: mode,
              onChanged: (newValue) {
                if (newValue != null) {
                  changeMode(newValue);
                }
              },
              activeColor: AppColors.accent,
              visualDensity: compact
                  ? VisualDensity.compact
                  : VisualDensity.standard,
              materialTapTargetSize: compact
                  ? MaterialTapTargetSize.shrinkWrap
                  : MaterialTapTargetSize.padded,
            ),
          ],
        ),
      ),
    );
  }

  // =====================================================
  // DOCUMENT ROW
  // =====================================================

  Widget buildDocumentRow(
    LibraryDocument document, {
    required bool checked,
    required bool enabled,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: compact ? 0 : 3),
      child: Row(
        children: [
          Checkbox(
            value: checked,
            onChanged: enabled
                ? (value) => toggleDocument(document.id, value)
                : null,
            activeColor: AppColors.accent,
            checkColor: AppColors.background,
            visualDensity: compact
                ? VisualDensity.compact
                : VisualDensity.standard,
            materialTapTargetSize: compact
                ? MaterialTapTargetSize.shrinkWrap
                : MaterialTapTargetSize.padded,
          ),

          SizedBox(width: compact ? 2 : 5),

          Icon(
            Icons.picture_as_pdf_outlined,
            color: AppColors.muted,
            size: compact ? 15 : 18,
          ),

          SizedBox(width: compact ? 6 : 9),

          Expanded(
            child: Text(
              document.name,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.text,
                fontSize: compact ? 11 : 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =====================================================
  // COLLECTION PICKER
  // =====================================================

  Widget buildCollectionPicker() {
    final collections = collectionStore.collections;

    if (collections.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: compact ? 7 : 12),
        child: Text(
          'No collections yet. Create one on the '
          'Collections page.',
          style: TextStyle(color: AppColors.muted, fontSize: compact ? 11 : 12),
        ),
      );
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 12),
      decoration: BoxDecoration(
        color: AppColors.sidebar,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedCollectionId,
          isExpanded: true,
          isDense: compact,
          dropdownColor: AppColors.surface,
          hint: Text(
            'Choose a collection',
            style: TextStyle(
              color: AppColors.muted,
              fontSize: compact ? 11 : 12,
            ),
          ),
          items: collections.map((collection) {
            final count = store.searchableDocuments
                .where((doc) => collection.documentIds.contains(doc.id))
                .length;

            return DropdownMenuItem<String>(
              value: collection.id,
              child: Row(
                children: [
                  Icon(
                    Icons.folder_outlined,
                    color: AppColors.accent,
                    size: compact ? 15 : 18,
                  ),
                  SizedBox(width: compact ? 6 : 10),
                  Expanded(
                    child: Text(
                      '${collection.name} ($count PDFs)',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: compact ? 11 : 12,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: selectCollection,
        ),
      ),
    );
  }

  // =====================================================
  // BUILD SOURCE SELECTOR
  // =====================================================

  @override
  Widget build(BuildContext context) {
    final documents = store.searchableDocuments;
    final currentSelection = selection;
    final collection = selectedCollection;

    return Container(
      padding: EdgeInsets.all(compact ? 12 : 18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(compact ? 11 : 14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // HEADER

          Row(
            children: [
              Icon(
                Icons.folder_open_outlined,
                color: AppColors.accent,
                size: compact ? 19 : 22,
              ),
              SizedBox(width: compact ? 7 : 10),
              Expanded(
                child: Text(
                  'Select Sources',
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: compact ? 15 : 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: compact ? 5 : 8),

          Text(
            'Choose which indexed PDFs '
            'Lociqra can search.',
            style: TextStyle(
              color: AppColors.muted,
              fontSize: compact ? 11 : 12,
            ),
          ),

          SizedBox(height: compact ? 10 : 18),

          // SOURCE MODES
          buildModeOption(
            value: SourceMode.all,
            title: 'Use All Files',
            icon: Icons.all_inclusive,
          ),

          SizedBox(height: compact ? 5 : 8),

          buildModeOption(
            value: SourceMode.collection,
            title: 'Choose Collection',
            icon: Icons.folder_outlined,
          ),

          SizedBox(height: compact ? 5 : 8),

          buildModeOption(
            value: SourceMode.individual,
            title: 'Select Individual Files',
            icon: Icons.description_outlined,
          ),

          if (mode == SourceMode.collection) ...[
            SizedBox(height: compact ? 8 : 14),
            buildCollectionPicker(),
          ],

          SizedBox(height: compact ? 9 : 16),

          const Divider(color: AppColors.border),

          SizedBox(height: compact ? 6 : 10),

          Text(
            mode == SourceMode.collection
                ? 'COLLECTION DOCUMENTS'
                : 'INDEXED DOCUMENTS',
            style: TextStyle(
              color: AppColors.muted,
              fontSize: compact ? 10 : 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
          ),

          SizedBox(height: compact ? 6 : 10),

          // INDEXED DOCUMENTS
          Expanded(
            child: store.isSyncing && documents.isEmpty
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.accent),
                  )
                : documents.isEmpty
                ? Center(
                    child: Text(
                      store.syncError != null
                          ? 'Could not load backend PDFs.'
                          : 'No indexed PDFs available.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.muted),
                    ),
                  )
                : ListView.builder(
                    itemCount: documents.length,
                    itemBuilder: (context, index) {
                      final document = documents[index];

                      bool checked;

                      switch (mode) {
                        case SourceMode.all:
                          checked = true;
                          break;

                        case SourceMode.collection:
                          checked =
                              collection?.documentIds.contains(document.id) ??
                              false;
                          break;

                        case SourceMode.individual:
                          checked = selectedIds.contains(document.id);
                          break;
                      }

                      return buildDocumentRow(
                        document,
                        checked: checked,
                        enabled: mode == SourceMode.individual,
                      );
                    },
                  ),
          ),

          const Divider(color: AppColors.border),

          SizedBox(height: compact ? 7 : 12),

          // SELECTED FILE COUNT
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Files to search',
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: compact ? 11 : 12,
                ),
              ),
              Text(
                '${currentSelection.documentIds.length} '
                'of ${documents.length}',
                style: TextStyle(
                  color: AppColors.accent,
                  fontSize: compact ? 12 : 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
