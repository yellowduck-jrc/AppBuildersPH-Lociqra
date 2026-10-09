import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../Services/api_service.dart';
import '../core/app_colors.dart';
import '../data/collection_store.dart';
import '../data/document_store.dart';
import '../data/settings_store.dart';
import '../models/library_document.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  final DocumentStore store = DocumentStore.instance;
  final SettingsStore settings = SettingsStore.instance;

  final TextEditingController searchController = TextEditingController();

  String searchQuery = '';
  bool isImporting = false;
  bool isRefreshing = false;

  final Set<String> deletingIds = {};

  @override
  void initState() {
    super.initState();
    store.addListener(refresh);
    settings.addListener(refresh);
  }

  @override
  void dispose() {
    store.removeListener(refresh);
    settings.removeListener(refresh);
    searchController.dispose();
    super.dispose();
  }

  void refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  // =====================================================
  // REFRESH DOCUMENTS
  // =====================================================

  Future<void> refreshDocuments() async {
    if (isRefreshing || isImporting) return;

    setState(() {
      isRefreshing = true;
    });

    try {
      await store.syncWithBackend();

      if (!mounted) return;

      showMessage('Library synchronized with PocketBrain.');
    } catch (error) {
      if (!mounted) return;

      showMessage('Unable to refresh Library: $error');
    } finally {
      if (mounted) {
        setState(() {
          isRefreshing = false;
        });
      }
    }
  }

  // =====================================================
  // UPLOAD PDF FILES
  // =====================================================

  Future<void> pickFiles() async {
    if (isImporting || isRefreshing) return;

    setState(() {
      isImporting = true;
    });

    int uploaded = 0;
    int failed = 0;
    final List<String> errors = [];

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: true,
        withData: false,
      );

      if (result == null || result.files.isEmpty) {
        return;
      }

      for (final file in result.files) {
        try {
          final filename = file.name;

          if (!filename.toLowerCase().endsWith('.pdf')) {
            throw Exception('Only PDF files are supported.');
          }

          List<int> bytes;

          if (file.bytes != null) {
            bytes = file.bytes!;
          } else if (file.path != null) {
            bytes = await File(file.path!).readAsBytes();
          } else {
            throw Exception('Unable to read the selected file.');
          }

          if (bytes.isEmpty) {
            throw Exception('The PDF is empty.');
          }

          if (bytes.length > 10 * 1024 * 1024) {
            throw Exception('PDF exceeds the 10 MB limit.');
          }

          await ApiService.uploadPdf(filename: filename, bytes: bytes);

          uploaded++;
        } catch (error) {
          failed++;
          errors.add('${file.name}: $error');
        }
      }

      await store.syncWithBackend();

      if (!mounted) return;

      if (failed == 0) {
        showMessage('$uploaded PDF(s) uploaded and indexed successfully.');
      } else {
        showMessage(
          '$uploaded PDF(s) uploaded. '
          '$failed failed. ${errors.first}',
        );
      }
    } catch (error) {
      if (!mounted) return;

      showMessage('Upload or synchronization error: $error');
    } finally {
      if (mounted) {
        setState(() {
          isImporting = false;
        });
      }
    }
  }

  // =====================================================
  // DOCUMENT DETAILS
  // =====================================================

  String _formatBytes(dynamic rawValue) {
    final int? bytes;

    if (rawValue is num) {
      bytes = rawValue.toInt();
    } else {
      bytes = int.tryParse(rawValue?.toString() ?? '');
    }

    if (bytes == null || bytes < 0) {
      return 'Not provided by backend';
    }

    if (bytes < 1024) {
      return '$bytes B';
    }

    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }

    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  Widget _detailRow(String label, String value, {IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, color: AppColors.accent, size: 19),
            const SizedBox(width: 12),
          ],
          SizedBox(
            width: 105,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> showDocumentDetails(LibraryDocument document) async {
    if (deletingIds.contains(document.id)) return;

    // Request the latest information directly from FastAPI.
    // The dialog also works if the backend is temporarily
    // unavailable, using the document already in Library.
    Map<String, dynamic>? backendDetails;
    String? backendError;

    try {
      final documents = await ApiService.getDocuments();

      for (final entry in documents) {
        final filename = entry['filename']?.toString();

        if (filename == document.name) {
          backendDetails = Map<String, dynamic>.from(entry);
          break;
        }
      }
    } catch (error) {
      backendError = error.toString();
    }

    if (!mounted) return;

    final details = backendDetails;

    final pageCount =
        details?['page_count'] ?? details?['pages'] ?? details?['total_pages'];

    final fileSize =
        details?['size_bytes'] ?? details?['file_size'] ?? details?['size'];

    final isIndexed = details != null;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Row(
            children: [
              Icon(Icons.description_outlined, color: AppColors.accent),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Document Details',
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.sidebar,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.picture_as_pdf_outlined,
                          color: AppColors.accent,
                          size: 34,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            document.name,
                            style: const TextStyle(
                              color: AppColors.text,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  _detailRow(
                    'Filename',
                    document.name,
                    icon: Icons.drive_file_rename_outline,
                  ),
                  _detailRow(
                    'File type',
                    'PDF document',
                    icon: Icons.picture_as_pdf_outlined,
                  ),
                  _detailRow(
                    'AI indexing',
                    isIndexed
                        ? 'Available for AI search'
                        : backendError != null
                        ? 'Unable to verify'
                        : 'Not found on backend',
                    icon: Icons.manage_search,
                  ),
                  _detailRow(
                    'Starred',
                    store.isStarred(document.id) ? 'Yes' : 'No',
                    icon: Icons.star_outline,
                  ),
                  _detailRow(
                    'Page count',
                    pageCount?.toString() ?? 'Not provided by backend',
                    icon: Icons.auto_stories_outlined,
                  ),
                  _detailRow(
                    'File size',
                    _formatBytes(fileSize),
                    icon: Icons.storage_outlined,
                  ),
                  const SizedBox(height: 12),
                  const Divider(color: AppColors.border),
                  const SizedBox(height: 12),
                  Text(
                    backendError != null
                        ? 'Backend details could not be refreshed. '
                              'The information shown is based on your '
                              'local Library where possible.'
                        : 'This document can be used as a source '
                              'when asking Lociqra questions, provided '
                              'it remains indexed by the backend.',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  // =====================================================
  // DELETE CONFIRMATION
  // =====================================================

  Future<bool> showDeleteConfirmation(LibraryDocument document) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text(
            'Delete PDF?',
            style: TextStyle(color: AppColors.text),
          ),
          content: Text(
            'Delete "${document.name}" from PocketBrain?\n\n'
            'This removes the PDF from the backend and '
            'its searchable index. This action cannot be undone.',
            style: const TextStyle(color: AppColors.muted, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    return confirmed == true;
  }

  // =====================================================
  // DELETE DOCUMENT
  // =====================================================

  Future<void> deleteDocument(LibraryDocument document) async {
    if (deletingIds.contains(document.id)) return;

    if (settings.confirmBeforeDeleting) {
      final confirmed = await showDeleteConfirmation(document);

      if (!confirmed || !mounted) return;
    }

    if (!mounted || deletingIds.contains(document.id)) {
      return;
    }

    setState(() {
      deletingIds.add(document.id);
    });

    try {
      await ApiService.deleteDocument(document.name);

      store.removeDocument(document.id);

      CollectionStore.instance.removeDocumentFromAll(document.id);

      await store.syncWithBackend();

      if (!mounted) return;

      showMessage('${document.name} deleted from PocketBrain.');
    } catch (error) {
      if (!mounted) return;

      showMessage('Unable to complete deletion: $error');

      try {
        await store.syncWithBackend();
      } catch (_) {
        // Preserve the original error message.
      }
    } finally {
      if (mounted) {
        setState(() {
          deletingIds.remove(document.id);
        });
      }
    }
  }

  // =====================================================
  // DOCUMENT ROW
  // =====================================================

  Widget buildDocumentRow(LibraryDocument document, bool compact) {
    final starred = store.isStarred(document.id);
    final deleting = deletingIds.contains(document.id);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 18,
        vertical: compact ? 6 : 12,
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(compact ? 7 : 10),
            decoration: BoxDecoration(
              color: AppColors.sidebar,
              borderRadius: BorderRadius.circular(compact ? 7 : 10),
            ),
            child: Icon(
              Icons.picture_as_pdf_outlined,
              color: AppColors.accent,
              size: compact ? 19 : 23,
            ),
          ),
          SizedBox(width: compact ? 9 : 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  document.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: compact ? 12 : 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: compact ? 2 : 5),
                Text(
                  'Indexed in PocketBrain • Available for AI search',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: compact ? 10 : 11,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: compact ? 6 : 12),
          Text(
            'PDF',
            style: TextStyle(
              color: AppColors.muted,
              fontSize: compact ? 10 : 12,
            ),
          ),
          SizedBox(width: compact ? 4 : 12),

          // New: document details button.
          IconButton(
            tooltip: 'View document details',
            visualDensity: compact
                ? VisualDensity.compact
                : VisualDensity.standard,
            constraints: compact
                ? const BoxConstraints(minWidth: 36, minHeight: 36)
                : null,
            onPressed: deleting ? null : () => showDocumentDetails(document),
            icon: Icon(
              Icons.info_outline,
              color: AppColors.muted,
              size: compact ? 19 : 23,
            ),
          ),

          IconButton(
            tooltip: starred ? 'Remove from Starred' : 'Add to Starred',
            visualDensity: compact
                ? VisualDensity.compact
                : VisualDensity.standard,
            constraints: compact
                ? const BoxConstraints(minWidth: 36, minHeight: 36)
                : null,
            onPressed: deleting ? null : () => store.toggleStar(document.id),
            icon: Icon(
              starred ? Icons.star : Icons.star_border,
              size: compact ? 19 : 24,
              color: starred ? AppColors.accent : AppColors.muted,
            ),
          ),

          if (deleting)
            Padding(
              padding: EdgeInsets.all(compact ? 8 : 12),
              child: const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.accent,
                ),
              ),
            )
          else
            IconButton(
              tooltip: settings.confirmBeforeDeleting
                  ? 'Delete PDF (confirmation required)'
                  : 'Delete PDF immediately',
              visualDensity: compact
                  ? VisualDensity.compact
                  : VisualDensity.standard,
              constraints: compact
                  ? const BoxConstraints(minWidth: 36, minHeight: 36)
                  : null,
              onPressed: () => deleteDocument(document),
              icon: Icon(
                Icons.delete_outline,
                size: compact ? 19 : 24,
                color: AppColors.muted,
              ),
            ),
        ],
      ),
    );
  }

  // =====================================================
  // BUILD LIBRARY
  // =====================================================

  @override
  Widget build(BuildContext context) {
    final compact = settings.compactMode;

    final documents = store.searchableDocuments.where((document) {
      return document.name.toLowerCase().contains(searchQuery.toLowerCase());
    }).toList();

    documents.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );

    return Padding(
      padding: EdgeInsets.all(compact ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // HEADER
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Library',
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: compact ? 23 : 27,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: compact ? 3 : 6),
                    Text(
                      'Manage your indexed PDF documents.',
                      style: TextStyle(
                        color: AppColors.muted,
                        fontSize: compact ? 12 : 13,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Refresh from FastAPI',
                onPressed: (isImporting || isRefreshing || store.isSyncing)
                    ? null
                    : refreshDocuments,
                icon: isRefreshing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.accent,
                        ),
                      )
                    : const Icon(Icons.refresh, color: AppColors.accent),
              ),
              SizedBox(width: compact ? 6 : 12),
              FilledButton.icon(
                onPressed: (isImporting || isRefreshing || store.isSyncing)
                    ? null
                    : pickFiles,
                icon: isImporting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add),
                label: Text(isImporting ? 'Uploading...' : 'Add Files'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.background,
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 12 : 16,
                    vertical: compact ? 10 : 12,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 16 : 24),

          // SEARCH BAR
          TextField(
            controller: searchController,
            onChanged: (value) {
              setState(() {
                searchQuery = value;
              });
            },
            style: TextStyle(
              color: AppColors.text,
              fontSize: compact ? 12 : 14,
            ),
            decoration: InputDecoration(
              hintText: 'Search documents...',
              hintStyle: const TextStyle(color: AppColors.muted),
              prefixIcon: const Icon(Icons.search, color: AppColors.muted),
              isDense: compact,
              contentPadding: EdgeInsets.symmetric(
                horizontal: compact ? 12 : 16,
                vertical: compact ? 10 : 14,
              ),
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          SizedBox(height: compact ? 12 : 18),

          // DOCUMENT COUNT
          Row(
            children: [
              Text(
                '${documents.length} indexed document(s)',
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: compact ? 11 : 12,
                ),
              ),
              const Spacer(),
              const Icon(
                Icons.cloud_done_outlined,
                color: AppColors.accent,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                'PocketBrain Backend',
                style: TextStyle(
                  color: AppColors.accent,
                  fontSize: compact ? 11 : 12,
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 8 : 12),

          // DOCUMENT LIST
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: store.isSyncing && documents.isEmpty
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.accent),
                    )
                  : documents.isEmpty
                  ? Center(
                      child: Text(
                        store.syncError != null
                            ? 'Unable to load backend PDFs.\n'
                                  'Check FastAPI and click Refresh.'
                            : searchQuery.isNotEmpty
                            ? 'No documents match your search.'
                            : 'No indexed PDFs found.\n'
                                  'Click Add Files to upload a PDF.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.muted),
                      ),
                    )
                  : ListView.separated(
                      itemCount: documents.length,
                      separatorBuilder: (context, index) =>
                          const Divider(color: AppColors.border, height: 1),
                      itemBuilder: (context, index) {
                        return buildDocumentRow(documents[index], compact);
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
