
import 'package:flutter/material.dart';

import '../core/app_colors.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  Widget featureCard(
    IconData icon,
    String title,
    String description,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: AppColors.accent,
            size: 24,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'About',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 27,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Get to know Lociqra.',
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView(
              children: [
                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius:
                        BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.border,
                    ),
                  ),
                  child: const Column(
                    children: [
                      Icon(
                        Icons.auto_awesome,
                        color: AppColors.accent,
                        size: 52,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'LOCIQRA',
                        style: TextStyle(
                          color: AppColors.text,
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 3,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Intelligence rooted in your own space.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.accent,
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(height: 18),
                      Text(
                        'A privacy-focused, offline-first '
                        'AI document assistant designed '
                        'to help you find answers in your '
                        'own files.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.muted,
                          fontSize: 13,
                          height: 1.6,
                        ),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'UI Development Version',
                        style: TextStyle(
                          color: AppColors.muted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                featureCard(
                  Icons.folder_open_outlined,
                  'Your Documents',
                  'Organize PDF, TXT, and Markdown '
                  'documents in one workspace.',
                ),
                const SizedBox(height: 12),
                featureCard(
                  Icons.psychology_outlined,
                  'Retrieval-Augmented Generation',
                  'The planned Python backend will '
                  'retrieve relevant document passages '
                  'before generating answers.',
                ),
                const SizedBox(height: 12),
                featureCard(
                  Icons.shield_outlined,
                  'Privacy-Focused',
                  'Designed to support local document '
                  'processing and offline AI models.',
                ),
                const SizedBox(height: 12),
                featureCard(
                  Icons.desktop_windows_outlined,
                  'Desktop First',
                  'Built with Flutter for a focused '
                  'Windows desktop experience.',
                ),
                const SizedBox(height: 24),
                const Center(
                  child: Text(
                    'Built with Flutter • Python RAG integration planned',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
