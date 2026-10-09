
import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../data/collection_store.dart';
import '../data/document_store.dart';

class CollectionsPage extends StatefulWidget {
  const CollectionsPage({super.key});

  @override
  State<CollectionsPage> createState() =>
      _CollectionsPageState();
}

class _CollectionsPageState extends State<CollectionsPage> {
  final CollectionStore collections =
      CollectionStore.instance;

  final DocumentStore documents =
      DocumentStore.instance;

  bool _dialogOpen = false;

  @override
  void initState() {
    super.initState();

    collections.addListener(_refresh);
    documents.addListener(_refresh);
  }

  @override
  void dispose() {
    collections.removeListener(_refresh);
    documents.removeListener(_refresh);

    super.dispose();
  }

  void _refresh() {
    if (!mounted) return;

    setState(() {});
  }

  // CREATE COLLECTION

  Future<void> createCollection() async {
    if (!mounted || _dialogOpen) return;

    _dialogOpen = true;

    try {
      final name = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return const _CreateCollectionDialog();
        },
      );

      if (!mounted ||
          name == null ||
          name.trim().isEmpty) {
        return;
      }

      // Update the collection store after the
      // current widget frame has finished.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        collections.addCollection(name.trim());
      });
    } finally {
      _dialogOpen = false;
    }
  }

  // MANAGE COLLECTION

  Future<void> manageCollection(
    DocumentCollection collection,
  ) async {
    if (!mounted || _dialogOpen) return;

    _dialogOpen = true;

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return _ManageCollectionDialog(
            collection: collection,
          );
        },
      );
    } finally {
      _dialogOpen = false;
    }
  }

  // DELETE COLLECTION

  Future<void> deleteCollection(
    DocumentCollection collection,
  ) async {
    if (!mounted || _dialogOpen) return;

    _dialogOpen = true;

    bool? confirmed;

    try {
      confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            backgroundColor: AppColors.surface,
            title: const Text(
              'Delete Collection',
              style: TextStyle(
                color: AppColors.text,
              ),
            ),
            content: Text(
              'Are you sure you want to delete '
              '"${collection.name}"?\n\n'
              'Your documents will not be deleted.',
              style: const TextStyle(
                color: AppColors.muted,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop(false);
                },
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop(true);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                ),
                child: const Text('Delete'),
              ),
            ],
          );
        },
      );
    } finally {
      _dialogOpen = false;
    }

    if (!mounted || confirmed != true) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      collections.removeCollection(collection.id);
    });
  }

  // COLLECTION CARD

  Widget buildCollectionCard(
    DocumentCollection collection,
  ) {
    final count = documents.documents.where((document) {
      return collection.documentIds.contains(
        document.id,
      );
    }).length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.folder_outlined,
            color: AppColors.accent,
            size: 28,
          ),

          const SizedBox(height: 10),

          Text(
            collection.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.text,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),

          const SizedBox(height: 5),

          Text(
            '$count document${count == 1 ? '' : 's'}',
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 12,
            ),
          ),

          const Spacer(),

          Row(
            children: [
              TextButton.icon(
                onPressed: () {
                  manageCollection(collection);
                },
                icon: const Icon(
                  Icons.edit_outlined,
                  size: 16,
                ),
                label: const Text('Manage'),
              ),

              const Spacer(),

              IconButton(
                tooltip: 'Delete collection',
                onPressed: () {
                  deleteCollection(collection);
                },
                icon: const Icon(
                  Icons.delete_outline,
                  color: AppColors.muted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // MAIN PAGE

  @override
  Widget build(BuildContext context) {
    final items = collections.collections;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Collections',
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: 27,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    SizedBox(height: 6),

                    Text(
                      'Organize your documents into groups.',
                      style: TextStyle(
                        color: AppColors.muted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),

              FilledButton.icon(
                onPressed: createCollection,
                icon: const Icon(Icons.add),
                label: const Text('New Collection'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.background,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 16,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          Expanded(
            child: items.isEmpty
                ? buildEmptyState()
                : GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 300,
                      mainAxisExtent: 175,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      return buildCollectionCard(
                        items[index],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.folder_copy_outlined,
            color: AppColors.accent,
            size: 54,
          ),

          const SizedBox(height: 18),

          const Text(
            'No Collections Yet',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 19,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 8),

          const Text(
            'Create a collection to organize your files.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 13,
            ),
          ),

          const SizedBox(height: 18),

          OutlinedButton.icon(
            onPressed: createCollection,
            icon: const Icon(Icons.add),
            label: const Text('Create Collection'),
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------
// CREATE COLLECTION DIALOG
// -------------------------------------------

class _CreateCollectionDialog extends StatefulWidget {
  const _CreateCollectionDialog();

  @override
  State<_CreateCollectionDialog> createState() =>
      _CreateCollectionDialogState();
}

class _CreateCollectionDialogState
    extends State<_CreateCollectionDialog> {
  final TextEditingController _controller =
      TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();

    if (name.isEmpty) return;

    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text(
        'New Collection',
        style: TextStyle(
          color: AppColors.text,
        ),
      ),

      content: SizedBox(
        width: 380,
        child: TextField(
          controller: _controller,
          autofocus: true,
          style: const TextStyle(
            color: AppColors.text,
          ),
          decoration: InputDecoration(
            labelText: 'Collection Name',
            hintText: 'Example: Research Documents',
            prefixIcon: const Icon(
              Icons.folder_outlined,
              color: AppColors.accent,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: AppColors.border,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: AppColors.accent,
              ),
            ),
          ),
          onSubmitted: (_) => _submit(),
        ),
      ),

      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),

        FilledButton(
          onPressed: _submit,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: AppColors.background,
          ),
          child: const Text('Create'),
        ),
      ],
    );
  }
}

// -------------------------------------------
// MANAGE COLLECTION DIALOG
// -------------------------------------------

class _ManageCollectionDialog extends StatefulWidget {
  final DocumentCollection collection;

  const _ManageCollectionDialog({
    required this.collection,
  });

  @override
  State<_ManageCollectionDialog> createState() =>
      _ManageCollectionDialogState();
}

class _ManageCollectionDialogState
    extends State<_ManageCollectionDialog> {
  final DocumentStore documents =
      DocumentStore.instance;

  final CollectionStore collections =
      CollectionStore.instance;

  @override
  void initState() {
    super.initState();
    documents.addListener(_refresh);
  }

  @override
  void dispose() {
    documents.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  void toggleDocument(String documentId) {
    collections.toggleDocument(
      widget.collection.id,
      documentId,
    );

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final availableDocuments = documents.documents;

    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(
        widget.collection.name,
        style: const TextStyle(
          color: AppColors.text,
        ),
      ),

      content: SizedBox(
        width: 420,
        height: 320,
        child: availableDocuments.isEmpty
            ? const Center(
                child: Text(
                  'No documents available.',
                  style: TextStyle(
                    color: AppColors.muted,
                  ),
                ),
              )
            : ListView.builder(
                itemCount: availableDocuments.length,
                itemBuilder: (context, index) {
                  final document =
                      availableDocuments[index];

                  final selected = widget
                      .collection.documentIds
                      .contains(document.id);

                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 5,
                    ),
                    child: Row(
                      children: [
                        Checkbox(
                          value: selected,
                          activeColor: AppColors.accent,
                          checkColor: AppColors.background,
                          onChanged: (_) {
                            toggleDocument(document.id);
                          },
                        ),

                        const SizedBox(width: 10),

                        const Icon(
                          Icons.description_outlined,
                          color: AppColors.muted,
                          size: 18,
                        ),

                        const SizedBox(width: 10),

                        Expanded(
                          child: Text(
                            document.name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.text,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),

      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Done'),
        ),
      ],
    );
  }
}
