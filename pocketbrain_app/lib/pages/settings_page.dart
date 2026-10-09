import 'package:flutter/material.dart';

import '../data/settings_store.dart';
import '../Services/api_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final SettingsStore settings = SettingsStore.instance;

  static const Color background = Color(0xFF0D1117);
  static const Color surface = Color(0xFF161B22);
  static const Color border = Color(0xFF30363D);
  static const Color primary = Color(0xFF8B7CF6);
  static const Color textPrimary = Color(0xFFF0F2F5);
  static const Color textSecondary = Color(0xFF9199A8);

  bool loadingBackend = true;
  bool backendConnected = false;

  String modelName = 'Unavailable';
  String embeddingModel = 'Unavailable';
  int loadedChunks = 0;

  @override
  void initState() {
    super.initState();

    settings.addListener(_refreshSettings);
    _loadBackendInformation();
  }

  @override
  void dispose() {
    settings.removeListener(_refreshSettings);
    super.dispose();
  }

  void _refreshSettings() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadBackendInformation() async {
    setState(() {
      loadingBackend = true;
    });

    try {
      final config = await ApiService.getAiConfig();
      final health = await ApiService.getHealth();

      if (!mounted) return;

      setState(() {
        backendConnected = true;

        modelName = config['model']?.toString() ?? 'Unknown';

        embeddingModel = config['embedding_model']?.toString() ?? 'Unknown';

        loadedChunks = (health['chunks_loaded'] as num?)?.toInt() ?? 0;

        loadingBackend = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        backendConnected = false;
        modelName = 'Unavailable';
        embeddingModel = 'Unavailable';
        loadedChunks = 0;
        loadingBackend = false;
      });
    }
  }

  Widget _sectionTitle(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: primary, size: 21),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(color: textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _settingsCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: child,
    );
  }

  Widget _settingSwitch({
    required String title,
    required String description,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                description,
                style: const TextStyle(
                  color: textSecondary,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Switch(value: value, onChanged: onChanged, activeThumbColor: primary),
      ],
    );
  }

  Widget _infoRow({
    required IconData icon,
    required String title,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: textSecondary, size: 18),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(color: textSecondary, fontSize: 13),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: valueColor ?? textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _divider() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 18),
      child: Divider(color: border, height: 1),
    );
  }

  Widget _buildAppearanceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          Icons.palette_outlined,
          'Appearance',
          'Customize your workspace preferences.',
        ),
        _settingsCard(
          child: Column(
            children: [
              _settingSwitch(
                title: 'Compact Mode',
                description: 'Use a denser layout throughout your workspace.',
                value: settings.compactMode,
                onChanged: settings.setCompactMode,
              ),
              _divider(),
              _infoRow(
                icon: Icons.dark_mode_outlined,
                title: 'Current Theme',
                value: 'Lociqra Dark',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAiSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          Icons.auto_awesome_outlined,
          'Local AI',
          'View your AI configuration and adjust retrieval.',
        ),
        _settingsCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    backendConnected
                        ? Icons.check_circle_outline
                        : Icons.cloud_off_outlined,
                    color: loadingBackend
                        ? textSecondary
                        : backendConnected
                        ? const Color(0xFF4ADE80)
                        : const Color(0xFFF87171),
                    size: 19,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      loadingBackend
                          ? 'Checking backend...'
                          : backendConnected
                          ? 'Backend Connected'
                          : 'Backend Disconnected',
                      style: const TextStyle(
                        color: textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Refresh backend status',
                    onPressed: loadingBackend ? null : _loadBackendInformation,
                    icon: const Icon(
                      Icons.refresh,
                      color: textSecondary,
                      size: 20,
                    ),
                  ),
                ],
              ),
              _divider(),
              _infoRow(
                icon: Icons.smart_toy_outlined,
                title: 'AI Model',
                value: modelName,
              ),
              _divider(),
              _infoRow(
                icon: Icons.memory_outlined,
                title: 'Embedding Model',
                value: embeddingModel,
              ),
              _divider(),
              _infoRow(
                icon: Icons.storage_outlined,
                title: 'Indexed Text Chunks',
                value: backendConnected
                    ? loadedChunks.toString()
                    : 'Unavailable',
              ),
              _divider(),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Retrieved Passages',
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${settings.retrievalCount}',
                      style: const TextStyle(
                        color: primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Choose how many relevant document passages '
                'the AI receives when answering normal questions.',
                style: TextStyle(
                  color: textSecondary,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 10),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: primary,
                  inactiveTrackColor: border,
                  thumbColor: primary,
                  overlayColor: primary.withValues(alpha: 0.15),
                ),
                child: Slider(
                  min: 1,
                  max: 10,
                  divisions: 9,
                  value: settings.retrievalCount.toDouble(),
                  label: '${settings.retrievalCount}',
                  onChanged: (value) {
                    settings.setRetrievalCount(value.round());
                  },
                ),
              ),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '1 passage',
                    style: TextStyle(color: textSecondary, fontSize: 11),
                  ),
                  Text(
                    '10 passages',
                    style: TextStyle(color: textSecondary, fontSize: 11),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Your retrieval preference is saved locally '
                'and used by the Ask page. Full-document '
                'summaries use a separate process.',
                style: TextStyle(
                  color: textSecondary,
                  fontSize: 11,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDocumentsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          Icons.description_outlined,
          'Documents',
          'Configure how your document workspace behaves.',
        ),
        _settingsCard(
          child: Column(
            children: [
              _settingSwitch(
                title: 'Show Source References',
                description:
                    'Display supporting PDF references '
                    'alongside AI-generated answers.',
                value: settings.showSourceReferences,
                onChanged: settings.setShowSourceReferences,
              ),
              _divider(),
              _settingSwitch(
                title: 'Confirm Before Deleting',
                description:
                    'Require confirmation before permanently '
                    'deleting a document.',
                value: settings.confirmBeforeDeleting,
                onChanged: settings.setConfirmBeforeDeleting,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPrivacySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          Icons.shield_outlined,
          'Privacy & Offline Access',
          'Information about your local-first setup.',
        ),
        _settingsCard(
          child: Column(
            children: [
              // The actual API URL stays in api_service.dart.
              // Settings only shows a friendly description.
              _infoRow(
                icon: Icons.computer_outlined,
                title: 'Backend Connection',
                value: 'Local Computer',
              ),
              _divider(),
              _infoRow(
                icon: Icons.lock_outline,
                title: 'AI Processing',
                value: 'Local Ollama',
              ),
              _divider(),
              _infoRow(
                icon: Icons.folder_outlined,
                title: 'Document Processing',
                value: 'Local FastAPI',
              ),
              const SizedBox(height: 18),
              const Text(
                'Lociqra uses a local-first architecture. '
                'Documents are processed by your configured '
                'FastAPI backend and answers are generated '
                'using Ollama. Offline use requires the '
                'backend, Ollama, and models to be available '
                'on the computer hosting the backend.',
                style: TextStyle(
                  color: textSecondary,
                  fontSize: 12,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: background,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Settings',
              style: TextStyle(
                color: textPrimary,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Configure your Lociqra workspace.',
              style: TextStyle(color: textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: ListView(
                children: [
                  _buildAppearanceSection(),
                  const SizedBox(height: 24),
                  _buildAiSection(),
                  const SizedBox(height: 24),
                  _buildDocumentsSection(),
                  const SizedBox(height: 24),
                  _buildPrivacySection(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
