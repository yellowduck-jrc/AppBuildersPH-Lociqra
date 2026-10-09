
import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../data/document_store.dart';

class RecentPage extends StatefulWidget {
  const RecentPage({super.key});

  @override
  State<RecentPage> createState() =>
      _RecentPageState();
}

class _RecentPageState extends State<RecentPage> {
  final DocumentStore store = DocumentStore.instance;

  @override
  void initState() {
    super.initState();
    store.addListener(refresh);
  }

  @override
  void dispose() {
    store.removeListener(refresh);
    super.dispose();
  }

  void refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final recent = store.recentDocuments;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recent',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 27,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Documents recently used in AI conversations..',
            style: TextStyle(
              color: AppColors.muted,
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: recent.isEmpty
                ? const Center(
                    child: Text(
                      'No recent activity yet.',
                      style: TextStyle(
                        color: AppColors.muted,
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: recent.length,
                    itemBuilder: (context, index) {
                      final doc = recent[index];

                      return Container(
                        margin: const EdgeInsets.only(
                          bottom: 12,
                        ),
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius:
                              BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.border,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.history,
                              color: AppColors.accent,
                              size: 24,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    doc.name,
                                    overflow:
                                        TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: AppColors.text,
                                      fontWeight:
                                          FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    doc.type,
                                    style: const TextStyle(
                                      color: AppColors.muted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Mark as recently used',
                              onPressed: () =>
                                  store.markRecent(doc.id),
                              icon: const Icon(
                                Icons.access_time,
                                color: AppColors.muted,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
