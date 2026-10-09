import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../Services/api_service.dart';
import '../core/app_colors.dart';
import '../data/document_store.dart';
import '../data/local_storage.dart';
import '../data/settings_store.dart';
import '../models/source_selection.dart';
import '../widgets/source_selector.dart';

enum _ProcessingStage {
  idle,
  checkingDocuments,
  waitingForAI,
  completed,
  failed,
}

class AskPage extends StatefulWidget {
  const AskPage({super.key});

  @override
  State<AskPage> createState() => _AskPageState();
}

class _AskPageState extends State<AskPage> {
  static const String _historyKey = 'lociqra_ask_history_v1';

  final TextEditingController questionController = TextEditingController();
  final DocumentStore store = DocumentStore.instance;
  final SettingsStore settings = SettingsStore.instance;

  bool useAllFiles = true;
  List<String> selectedIds = [];

  bool isLoading = false;
  bool historyLoading = true;
  bool showHistory = false;

  String? submittedQuestion;
  String? aiAnswer;
  String? requestError;

  List<String> submittedSources = [];
  List<Map<String, dynamic>> retrievedSources = [];
  List<Map<String, dynamic>> history = [];

  int? activeHistoryIndex;

  _ProcessingStage processingStage = _ProcessingStage.idle;

  Timer? _elapsedTimer;
  DateTime? _requestStartedAt;
  Duration elapsed = Duration.zero;

  // These values describe the question currently being displayed.
  // They are kept separate from the SourceSelector's current selection.
  bool? _requestUsedAllFiles;
  List<String>? _requestSelectedNames;
  int? _requestRetrievalCount;

  bool get compact => settings.compactMode;

  String get elapsedText {
    final minutes = elapsed.inMinutes;
    final seconds = elapsed.inSeconds.remainder(60);

    if (minutes == 0) {
      return '${seconds}s';
    }

    return '${minutes}m ${seconds.toString().padLeft(2, '0')}s';
  }

  @override
  void initState() {
    super.initState();
    settings.addListener(_onSettingsChanged);
    _loadHistory();
  }

  @override
  void dispose() {
    _elapsedTimer?.cancel();
    settings.removeListener(_onSettingsChanged);
    questionController.dispose();
    super.dispose();
  }

  void _onSettingsChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _startElapsedTimer() {
    _elapsedTimer?.cancel();

    _requestStartedAt = DateTime.now();

    setState(() {
      elapsed = Duration.zero;
    });

    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _requestStartedAt == null) return;

      setState(() {
        elapsed = DateTime.now().difference(_requestStartedAt!);
      });
    });
  }

  void _stopElapsedTimer() {
    _elapsedTimer?.cancel();
    _elapsedTimer = null;

    if (_requestStartedAt != null) {
      elapsed = DateTime.now().difference(_requestStartedAt!);
    }

    _requestStartedAt = null;
  }

  Future<void> _loadHistory() async {
    try {
      final stored = await LocalStorage.loadJson(_historyKey);

      if (!mounted) return;

      final entries = stored is List
          ? stored
                .whereType<Map>()
                .map((entry) => Map<String, dynamic>.from(entry))
                .toList()
          : <Map<String, dynamic>>[];

      setState(() {
        history = entries;
        historyLoading = false;

        if (entries.isNotEmpty) {
          _displayEntry(entries.first, index: 0);
        }
      });
    } catch (error) {
      debugPrint('Could not load Ask history: $error');

      if (mounted) {
        setState(() {
          historyLoading = false;
        });
      }
    }
  }

  Future<void> _saveHistory() async {
    try {
      await LocalStorage.saveJson(_historyKey, history);
    } catch (error) {
      debugPrint('Could not save Ask history: $error');

      if (mounted) {
        _showMessage('Unable to save conversation history.');
      }
    }
  }

  void _displayEntry(Map<String, dynamic> entry, {required int index}) {
    submittedQuestion = entry['question']?.toString();
    aiAnswer = entry['answer']?.toString();
    requestError = entry['error']?.toString();

    submittedSources =
        (entry['included_documents'] as List?)
            ?.map((item) => item.toString())
            .toList() ??
        <String>[];

    retrievedSources =
        (entry['sources'] as List?)
            ?.whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList() ??
        <Map<String, dynamic>>[];

    activeHistoryIndex = index;

    final savedSeconds = entry['elapsed_seconds'];

    elapsed = savedSeconds is num
        ? Duration(milliseconds: (savedSeconds * 1000).round())
        : Duration.zero;

    // Older history entries may not have retry metadata.
    // For those entries, exact source selection cannot be guaranteed.
    _requestUsedAllFiles = entry['use_all_files'] is bool
        ? entry['use_all_files'] as bool
        : null;

    _requestSelectedNames = entry['selected_filenames'] is List
        ? (entry['selected_filenames'] as List)
              .map((item) => item.toString())
              .toList()
        : null;

    final savedCount = entry['retrieval_count'];

    _requestRetrievalCount =
        savedCount is int && savedCount >= 1 && savedCount <= 10
        ? savedCount
        : null;

    processingStage = requestError != null
        ? _ProcessingStage.failed
        : aiAnswer != null
        ? _ProcessingStage.completed
        : _ProcessingStage.idle;
  }

  void _openHistory(int index) {
    if (isLoading || index < 0 || index >= history.length) return;

    setState(() {
      _displayEntry(history[index], index: index);
      showHistory = false;
    });
  }

  Future<void> _clearHistory() async {
    if (isLoading || history.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Clear conversation history?'),
          content: const Text(
            'All saved questions and answers will be removed '
            'from this computer.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Clear'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      history.clear();
      activeHistoryIndex = null;
      submittedQuestion = null;
      aiAnswer = null;
      requestError = null;
      submittedSources = [];
      retrievedSources = [];
      elapsed = Duration.zero;
      processingStage = _ProcessingStage.idle;
      _requestUsedAllFiles = null;
      _requestSelectedNames = null;
      _requestRetrievalCount = null;
      showHistory = false;
    });

    await _saveHistory();
  }

  void updateSelection(SourceSelection selection) {
    if (!mounted) return;

    setState(() {
      useAllFiles = selection.useAllFiles;
      selectedIds = selection.documentIds;
    });
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  void _recordRecentDocuments({
    required bool allFiles,
    required List<String> selectedNames,
    required List<Map<String, dynamic>> sources,
  }) {
    final filenames = <String>{};

    if (allFiles) {
      for (final source in sources) {
        final filename = source['filename']?.toString() ?? '';

        if (filename.isNotEmpty) {
          filenames.add(filename);
        }
      }
    } else {
      filenames.addAll(selectedNames);
    }

    for (final filename in filenames.toList().reversed) {
      store.markRecentByFilename(filename);
    }
  }

  List<String> _currentSelectedNames() {
    return store.searchableDocuments
        .where((document) => selectedIds.contains(document.id))
        .map((document) => document.name)
        .toSet()
        .toList()
      ..sort();
  }

  Future<void> submitQuestion() async {
    final question = questionController.text.trim();

    if (question.isEmpty || isLoading || historyLoading) return;

    final allFiles = useAllFiles;
    final selectedNames = _currentSelectedNames();
    final retrievalCount = settings.retrievalCount;

    if (!allFiles && selectedNames.isEmpty) {
      _showMessage('Please select at least one document.');
      return;
    }

    questionController.clear();

    await _executeQuestion(
      question: question,
      allFiles: allFiles,
      selectedNames: selectedNames,
      retrievalCount: retrievalCount,
    );
  }

  Future<void> _retryQuestion() async {
    if (isLoading || historyLoading) return;

    final question = submittedQuestion?.trim() ?? '';

    if (question.isEmpty) return;

    if (_requestUsedAllFiles == null ||
        _requestSelectedNames == null ||
        _requestRetrievalCount == null) {
      _showMessage(
        'This older conversation does not contain its original '
        'source selection. Use Edit Question to submit it again.',
      );
      return;
    }

    await _executeQuestion(
      question: question,
      allFiles: _requestUsedAllFiles!,
      selectedNames: List<String>.from(_requestSelectedNames!),
      retrievalCount: _requestRetrievalCount!,
      retryHistoryIndex: activeHistoryIndex,
    );
  }

  void _editQuestion() {
    if (isLoading) return;

    final question = submittedQuestion;

    if (question == null || question.trim().isEmpty) return;

    setState(() {
      showHistory = false;
      questionController.text = question;
      questionController.selection = TextSelection.collapsed(
        offset: questionController.text.length,
      );
    });

    _showMessage(
      'Question restored. Review the selected documents before sending.',
    );
  }

  Future<void> _executeQuestion({
    required String question,
    required bool allFiles,
    required List<String> selectedNames,
    required int retrievalCount,
    int? retryHistoryIndex,
  }) async {
    if (isLoading || historyLoading) return;

    final names = List<String>.from(selectedNames);

    setState(() {
      submittedQuestion = question;
      submittedSources = [];
      retrievedSources = [];
      aiAnswer = null;
      requestError = null;
      showHistory = false;
      isLoading = true;
      processingStage = _ProcessingStage.checkingDocuments;

      _requestUsedAllFiles = allFiles;
      _requestSelectedNames = names;
      _requestRetrievalCount = retrievalCount;

      if (retryHistoryIndex == null) {
        activeHistoryIndex = null;
      }
    });

    _startElapsedTimer();

    try {
      // Stage 1: Check the documents available in FastAPI.
      final serverDocuments = await ApiService.getDocuments();

      if (!mounted) return;

      final availableNames = serverDocuments
          .map((document) => document['filename']?.toString() ?? '')
          .where((name) => name.isNotEmpty)
          .toSet();

      if (availableNames.isEmpty) {
        throw Exception(
          'No PDFs are indexed by Lociqra. '
          'Upload a PDF in Library first.',
        );
      }

      List<String>? filenames;

      if (!allFiles) {
        final missing = names
            .where((name) => !availableNames.contains(name))
            .toList();

        if (missing.isNotEmpty) {
          throw Exception(
            'The following selected documents are unavailable: '
            '${missing.join(', ')}. '
            'Check your Library before retrying.',
          );
        }

        filenames = names;
      }

      // Stage 2: The backend performs retrieval and AI generation.
      setState(() {
        processingStage = _ProcessingStage.waitingForAI;
      });

      final response = await ApiService.askQuestion(
        question: question,
        filenames: filenames,
        retrievalCount: retrievalCount,
      );

      if (!mounted) return;

      final sources = (response['sources'] as List<dynamic>? ?? [])
          .whereType<Map>()
          .map((source) => Map<String, dynamic>.from(source))
          .toList();

      final answer =
          response['answer']?.toString() ?? 'The AI returned an empty answer.';

      _recordRecentDocuments(
        allFiles: allFiles,
        selectedNames: names,
        sources: sources,
      );

      final included = allFiles ? (availableNames.toList()..sort()) : names;

      setState(() {
        aiAnswer = answer;
        retrievedSources = sources;
        submittedSources = included;
        processingStage = _ProcessingStage.completed;
      });
    } catch (error) {
      if (!mounted) return;

      final message = error.toString().replaceFirst('Exception: ', '');

      setState(() {
        requestError = message;
        processingStage = _ProcessingStage.failed;
      });
    } finally {
      _stopElapsedTimer();

      if (mounted) {
        setState(() {
          isLoading = false;

          final entry = <String, dynamic>{
            'question': question,
            'answer': aiAnswer,
            'error': requestError,
            'included_documents': List<String>.from(submittedSources),
            'sources': retrievedSources
                .map((source) => Map<String, dynamic>.from(source))
                .toList(),
            'use_all_files': allFiles,
            'selected_filenames': List<String>.from(names),
            'retrieval_count': retrievalCount,
            'elapsed_seconds': elapsed.inMilliseconds / 1000,
            'created_at': DateTime.now().toIso8601String(),
          };

          final canUpdateExisting =
              retryHistoryIndex != null &&
              retryHistoryIndex >= 0 &&
              retryHistoryIndex < history.length;

          if (canUpdateExisting) {
            // Replace the failed attempt in its original history slot.
            // This prevents duplicate entries after a retry.
            history[retryHistoryIndex] = entry;
            activeHistoryIndex = retryHistoryIndex;
          } else {
            history.insert(0, entry);

            if (history.length > 100) {
              history.removeRange(100, history.length);
            }

            activeHistoryIndex = 0;
          }
        });

        await _saveHistory();
      }
    }
  }

  Future<void> _openSource(String filename, int page) async {
    try {
      final url = ApiService.pdfSourceUrl(filename, page);

      final opened = await launchUrl(url, mode: LaunchMode.externalApplication);

      if (!opened) {
        _showMessage('Could not open $filename.');
      }
    } catch (error) {
      _showMessage('Could not open PDF: $error');
    }
  }

  Widget _welcome() {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.auto_awesome,
              color: AppColors.accent,
              size: compact ? 40 : 52,
            ),
            SizedBox(height: compact ? 12 : 18),
            Text(
              'Ask Lociqra',
              style: TextStyle(
                color: AppColors.text,
                fontSize: compact ? 21 : 25,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: compact ? 6 : 10),
            Text(
              'Explore your documents with local AI.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.muted,
                fontSize: compact ? 12 : 13,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Choose your sources and ask a question below.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.muted,
                fontSize: compact ? 11 : 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stageRow({
    required String title,
    required String subtitle,
    required bool completed,
    required bool active,
  }) {
    final iconColor = completed || active ? AppColors.accent : AppColors.muted;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: compact ? 6 : 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 23,
            height: 23,
            child: Center(
              child: active
                  ? const SizedBox(
                      width: 17,
                      height: 17,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.accent,
                      ),
                    )
                  : Icon(
                      completed
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      color: iconColor,
                      size: 19,
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: completed || active
                        ? AppColors.text
                        : AppColors.muted,
                    fontSize: compact ? 12 : 13,
                    fontWeight: active ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: compact ? 10 : 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _processingPanel() {
    final checking = processingStage == _ProcessingStage.checkingDocuments;
    final waiting = processingStage == _ProcessingStage.waitingForAI;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 12 : 18),
      decoration: BoxDecoration(
        color: AppColors.sidebar,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.psychology_outlined,
                color: AppColors.accent,
                size: 22,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Lociqra is processing',
                  style: TextStyle(
                    color: AppColors.text,
                    fontWeight: FontWeight.bold,
                    fontSize: compact ? 13 : 15,
                  ),
                ),
              ),
              Text(
                elapsedText,
                style: TextStyle(
                  color: AppColors.accent,
                  fontWeight: FontWeight.bold,
                  fontSize: compact ? 12 : 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const LinearProgressIndicator(
            color: AppColors.accent,
            backgroundColor: AppColors.border,
          ),
          const SizedBox(height: 12),
          _stageRow(
            title: 'Checking available documents',
            subtitle: 'Verifying PDFs indexed by FastAPI',
            completed: waiting,
            active: checking,
          ),
          _stageRow(
            title: 'Waiting for local AI',
            subtitle:
                'FastAPI is processing your question and preparing an answer',
            completed: false,
            active: waiting,
          ),
          const SizedBox(height: 9),
          Text(
            'Processing time depends on the documents, '
            'AI model, and computer performance.',
            style: TextStyle(
              color: AppColors.muted,
              fontSize: compact ? 10 : 11,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorPanel() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 12 : 16),
      decoration: BoxDecoration(
        color: AppColors.sidebar,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.error_outline, color: Colors.redAccent, size: 22),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Unable to generate an answer',
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            requestError ?? 'An unexpected error occurred.',
            style: TextStyle(
              color: Colors.redAccent,
              fontSize: compact ? 12 : 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Check that FastAPI and Ollama are running, '
            'then retry your question.',
            style: TextStyle(
              color: AppColors.muted,
              fontSize: compact ? 11 : 12,
              height: 1.5,
            ),
          ),
          SizedBox(height: compact ? 12 : 16),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                onPressed: isLoading ? null : _retryQuestion,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Retry Question'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.background,
                ),
              ),
              OutlinedButton.icon(
                onPressed: isLoading ? null : _editQuestion,
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Edit Question'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.text,
                  side: const BorderSide(color: AppColors.border),
                ),
              ),
            ],
          ),
          if (_requestUsedAllFiles == null ||
              _requestSelectedNames == null ||
              _requestRetrievalCount == null) ...[
            const SizedBox(height: 10),
            Text(
              'This conversation was saved before source-preserving '
              'retries were added. Edit and resubmit the question '
              'using the current source selection.',
              style: TextStyle(
                color: AppColors.muted,
                fontSize: compact ? 10 : 11,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _supportingPassages() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 11 : 16),
      decoration: BoxDecoration(
        color: AppColors.sidebar,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.format_quote,
                color: AppColors.accent,
                size: compact ? 17 : 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Supporting Passages',
                style: TextStyle(
                  color: AppColors.text,
                  fontWeight: FontWeight.bold,
                  fontSize: compact ? 12 : 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (retrievedSources.isEmpty)
            const Text(
              'No source references available.',
              style: TextStyle(color: AppColors.muted),
            )
          else
            ...retrievedSources.map((source) {
              final filename = source['filename']?.toString() ?? '';
              final rawPage = source['page'];

              final page = rawPage is int
                  ? rawPage
                  : int.tryParse(rawPage?.toString() ?? '') ?? 1;

              return Padding(
                padding: EdgeInsets.only(bottom: compact ? 4 : 8),
                child: InkWell(
                  onTap: filename.isEmpty
                      ? null
                      : () => _openSource(filename, page),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        Icon(
                          Icons.picture_as_pdf_outlined,
                          color: AppColors.accent,
                          size: compact ? 15 : 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '$filename — Page $page',
                            style: TextStyle(
                              color: AppColors.text,
                              fontSize: compact ? 11 : 12,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.open_in_new,
                          color: AppColors.muted,
                          size: 15,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _result() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'YOUR QUESTION',
            style: TextStyle(
              color: AppColors.accent,
              fontWeight: FontWeight.bold,
              fontSize: compact ? 10 : 11,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            submittedQuestion ?? '',
            style: TextStyle(
              color: AppColors.text,
              fontSize: compact ? 15 : 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: compact ? 14 : 24),
          const Divider(color: AppColors.border),
          SizedBox(height: compact ? 11 : 20),
          Row(
            children: [
              Icon(
                Icons.auto_awesome,
                color: AppColors.accent,
                size: compact ? 17 : 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Lociqra Response',
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: compact ? 15 : 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (!isLoading && (aiAnswer != null || requestError != null))
                Text(
                  elapsed > Duration.zero
                      ? '${elapsedText} elapsed'
                      : 'Saved response',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: compact ? 10 : 11,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (isLoading)
            _processingPanel()
          else if (requestError != null)
            _errorPanel()
          else if (aiAnswer != null)
            MarkdownBody(
              data: aiAnswer!,
              selectable: true,
              styleSheet: MarkdownStyleSheet(
                p: TextStyle(
                  color: AppColors.text,
                  fontSize: compact ? 12 : 14,
                  height: compact ? 1.4 : 1.6,
                ),
                strong: const TextStyle(
                  color: AppColors.text,
                  fontWeight: FontWeight.bold,
                ),
                h1: TextStyle(
                  color: AppColors.text,
                  fontSize: compact ? 18 : 21,
                  fontWeight: FontWeight.bold,
                ),
                h2: TextStyle(
                  color: AppColors.text,
                  fontSize: compact ? 16 : 18,
                  fontWeight: FontWeight.bold,
                ),
                listBullet: const TextStyle(color: AppColors.accent),
              ),
            ),
          if (!isLoading && settings.showSourceReferences) ...[
            SizedBox(height: compact ? 14 : 24),
            _supportingPassages(),
          ],
          if (!isLoading && submittedSources.isNotEmpty) ...[
            SizedBox(height: compact ? 14 : 24),
            Text(
              'DOCUMENTS INCLUDED',
              style: TextStyle(
                color: AppColors.accent,
                fontSize: compact ? 10 : 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 12),
            ...submittedSources.map(
              (name) => Padding(
                padding: EdgeInsets.only(bottom: compact ? 5 : 9),
                child: Row(
                  children: [
                    const Icon(
                      Icons.description_outlined,
                      color: AppColors.muted,
                      size: 17,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        name,
                        style: TextStyle(
                          color: AppColors.text,
                          fontSize: compact ? 11 : 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _historyPanel() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: EdgeInsets.all(compact ? 10 : 14),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.history, color: AppColors.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Conversation History',
                  style: TextStyle(
                    color: AppColors.text,
                    fontWeight: FontWeight.bold,
                    fontSize: compact ? 13 : 15,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Clear all history',
                onPressed: history.isEmpty || isLoading ? null : _clearHistory,
                icon: const Icon(Icons.delete_outline, color: AppColors.muted),
              ),
              IconButton(
                tooltip: 'Close history',
                onPressed: () {
                  setState(() {
                    showHistory = false;
                  });
                },
                icon: const Icon(Icons.close, color: AppColors.muted),
              ),
            ],
          ),
          const Divider(color: AppColors.border),
          Expanded(
            child: history.isEmpty
                ? const Center(
                    child: Text(
                      'No saved conversations yet.',
                      style: TextStyle(color: AppColors.muted),
                    ),
                  )
                : ListView.builder(
                    itemCount: history.length,
                    itemBuilder: (context, index) {
                      final entry = history[index];

                      final rawDate = entry['created_at']?.toString() ?? '';

                      final displayDate = rawDate
                          .replaceFirst('T', ' ')
                          .split('.')
                          .first;

                      return ListTile(
                        dense: compact,
                        selected: activeHistoryIndex == index,
                        leading: Icon(
                          entry['error'] != null
                              ? Icons.error_outline
                              : Icons.chat_bubble_outline,
                          color: entry['error'] != null
                              ? Colors.redAccent
                              : AppColors.accent,
                          size: 18,
                        ),
                        title: Text(
                          entry['question']?.toString() ?? '',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppColors.text),
                        ),
                        subtitle: Text(
                          displayDate,
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 11,
                          ),
                        ),
                        onTap: () => _openHistory(index),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _questionInput() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(compact ? 11 : 14),
        border: Border.all(color: AppColors.border),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 14,
        vertical: compact ? 3 : 6,
      ),
      child: Row(
        children: [
          Icon(
            Icons.chat_bubble_outline,
            color: AppColors.muted,
            size: compact ? 17 : 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: questionController,
              enabled: !isLoading && !historyLoading,
              onSubmitted: (_) => submitQuestion(),
              style: TextStyle(
                color: AppColors.text,
                fontSize: compact ? 13 : 14,
              ),
              decoration: InputDecoration(
                hintText: 'Ask about your documents...',
                hintStyle: const TextStyle(color: AppColors.muted),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: compact,
              ),
            ),
          ),
          IconButton.filled(
            tooltip: 'Send question',
            onPressed: isLoading || historyLoading ? null : submitQuestion,
            style: IconButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: AppColors.background,
              visualDensity: compact
                  ? VisualDensity.compact
                  : VisualDensity.standard,
            ),
            icon: isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.background,
                    ),
                  )
                : Icon(Icons.arrow_upward_rounded, size: compact ? 19 : 24),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(compact ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text.rich(
                  const TextSpan(
                    children: [
                      TextSpan(text: 'Ask '),
                      TextSpan(
                        text: 'Lociqra',
                        style: TextStyle(color: AppColors.accent),
                      ),
                    ],
                  ),
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: compact ? 23 : 27,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: isLoading || historyLoading
                    ? null
                    : () {
                        setState(() {
                          showHistory = !showHistory;
                        });
                      },
                icon: const Icon(Icons.history),
                label: Text('History (${history.length})'),
              ),
            ],
          ),
          SizedBox(height: compact ? 3 : 6),
          Text(
            'Intelligence rooted in your own space.',
            style: TextStyle(
              color: AppColors.muted,
              fontSize: compact ? 12 : 13,
            ),
          ),
          SizedBox(height: compact ? 16 : 24),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    children: [
                      Expanded(
                        child: showHistory
                            ? _historyPanel()
                            : Container(
                                width: double.infinity,
                                padding: EdgeInsets.all(compact ? 14 : 24),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(
                                    compact ? 11 : 14,
                                  ),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: historyLoading
                                    ? const Center(
                                        child: CircularProgressIndicator(
                                          color: AppColors.accent,
                                        ),
                                      )
                                    : submittedQuestion == null
                                    ? _welcome()
                                    : _result(),
                              ),
                      ),
                      SizedBox(height: compact ? 10 : 16),
                      _questionInput(),
                    ],
                  ),
                ),
                SizedBox(width: compact ? 12 : 20),
                Expanded(
                  flex: 2,
                  child: SourceSelector(onSelectionChanged: updateSelection),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
