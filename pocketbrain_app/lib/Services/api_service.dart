import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class ApiService {
  ApiService._();

  // =====================================================
  // BACKEND CONFIGURATION
  // =====================================================

  // Currently points to FastAPI on this computer.
  //
  // In Step 7B, we will make this configurable so
  // Lociqra can connect to your groupmate's computer.

  static const String baseUrl = 'http://127.0.0.1:8000';

  // Short requests should fail quickly.
  static const Duration connectionTimeout = Duration(seconds: 5);

  static const Duration documentTimeout = Duration(seconds: 30);

  // Indexing a PDF can take longer.
  static const Duration uploadTimeout = Duration(minutes: 3);

  // Local AI generation can be slower on some PCs.
  static const Duration aiTimeout = Duration(minutes: 3);

  // =====================================================
  // INTERNAL HELPERS
  // =====================================================

  static Uri _uri(String path) {
    return Uri.parse('$baseUrl$path');
  }

  static String _readBackendError(http.Response response) {
    final body = response.body.trim();

    if (body.isEmpty) {
      return 'The backend returned HTTP '
          '${response.statusCode}.';
    }

    try {
      final decoded = jsonDecode(body);

      if (decoded is Map) {
        final detail = decoded['detail'];

        if (detail is String && detail.isNotEmpty) {
          return detail;
        }

        if (detail is List && detail.isNotEmpty) {
          return detail
              .map((item) {
                if (item is Map) {
                  return item['msg']?.toString() ?? item.toString();
                }

                return item.toString();
              })
              .join('; ');
        }

        final message = decoded['message'];

        if (message != null) {
          return message.toString();
        }

        final error = decoded['error'];

        if (error != null) {
          return error.toString();
        }
      }
    } catch (_) {
      // The backend may have returned plain text.
    }

    // Avoid dumping a large HTML traceback into the UI.
    if (body.toLowerCase().startsWith('<!doctype') ||
        body.toLowerCase().startsWith('<html')) {
      return 'The server returned an unexpected '
          'HTML error page.';
    }

    if (body.length > 350) {
      return '${body.substring(0, 350)}...';
    }

    return body;
  }

  static void _ensureSuccess(
    http.Response response, {
    required String operation,
  }) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }

    final detail = _readBackendError(response);

    throw Exception(
      '$operation failed '
      '(HTTP ${response.statusCode}): $detail',
    );
  }

  static Map<String, dynamic> _decodeObject(
    http.Response response, {
    required String operation,
  }) {
    try {
      final decoded = jsonDecode(response.body);

      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }

      throw const FormatException('Expected a JSON object.');
    } on FormatException {
      throw Exception(
        '$operation failed: the backend returned '
        'an invalid JSON response.',
      );
    } on TypeError {
      throw Exception(
        '$operation failed: the backend returned '
        'an unexpected response format.',
      );
    }
  }

  static Exception _friendlyError(Object error, {required String operation}) {
    if (error is TimeoutException) {
      return Exception(
        '$operation timed out. The backend may be '
        'busy processing a PDF or generating an AI '
        'response. Please try again.',
      );
    }

    if (error is SocketException || error is http.ClientException) {
      return Exception(
        'Cannot connect to the PocketBrain backend '
        'at $baseUrl. Make sure FastAPI is running '
        'and the backend address is correct.',
      );
    }

    if (error is HandshakeException) {
      return Exception(
        '$operation failed because the secure '
        'connection could not be established.',
      );
    }

    if (error is FormatException) {
      return Exception(
        '$operation failed because the backend '
        'returned an unexpected response.',
      );
    }

    if (error is Exception) {
      return error;
    }

    return Exception('$operation failed: $error');
  }

  static Future<http.Response> _get(
    String path, {
    required String operation,
    Duration timeout = documentTimeout,
  }) async {
    try {
      final response = await http.get(_uri(path)).timeout(timeout);

      _ensureSuccess(response, operation: operation);

      return response;
    } catch (error) {
      throw _friendlyError(error, operation: operation);
    }
  }

  // =====================================================
  // CONNECTION
  // =====================================================

  static Future<bool> checkConnection() async {
    try {
      final response = await http
          .get(_uri('/health'))
          .timeout(connectionTimeout);

      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // =====================================================
  // BACKEND HEALTH INFORMATION
  // =====================================================

  static Future<Map<String, dynamic>> getHealth() async {
    final response = await _get(
      '/health',
      operation: 'Backend health check',
      timeout: connectionTimeout,
    );

    return _decodeObject(response, operation: 'Backend health check');
  }

  // =====================================================
  // AI CONFIGURATION
  // =====================================================

  static Future<Map<String, dynamic>> getAiConfig() async {
    final response = await _get(
      '/ai/config',
      operation: 'Loading AI configuration',
      timeout: connectionTimeout,
    );

    return _decodeObject(response, operation: 'Loading AI configuration');
  }

  // =====================================================
  // DOCUMENTS
  // =====================================================

  static Future<List<Map<String, dynamic>>> getDocuments() async {
    final response = await _get(
      '/documents',
      operation: 'Loading documents',
      timeout: documentTimeout,
    );

    final data = _decodeObject(response, operation: 'Loading documents');

    final documents = data['documents'];

    if (documents == null) {
      return [];
    }

    if (documents is! List) {
      throw Exception(
        'Loading documents failed: the backend '
        'returned an invalid document list.',
      );
    }

    try {
      return documents
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    } catch (_) {
      throw Exception(
        'Loading documents failed: the document '
        'list contains invalid entries.',
      );
    }
  }

  // =====================================================
  // ASK AI
  // =====================================================

  static Future<Map<String, dynamic>> askQuestion({
    required String question,
    List<String>? filenames,
    int retrievalCount = 5,
  }) async {
    final trimmedQuestion = question.trim();

    if (trimmedQuestion.isEmpty) {
      throw Exception('Please enter a question before sending.');
    }

    final safeRetrievalCount = retrievalCount.clamp(1, 10).toInt();

    try {
      final response = await http
          .post(
            _uri('/ask'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'question': trimmedQuestion,
              'filenames': filenames,
              'retrieval_count': safeRetrievalCount,
            }),
          )
          .timeout(aiTimeout);

      _ensureSuccess(response, operation: 'AI request');

      return _decodeObject(response, operation: 'AI request');
    } catch (error) {
      throw _friendlyError(error, operation: 'AI request');
    }
  }

  // =====================================================
  // UPLOAD PDF
  // =====================================================

  static Future<Map<String, dynamic>> uploadPdf({
    required String filename,
    required List<int> bytes,
  }) async {
    if (!filename.toLowerCase().endsWith('.pdf')) {
      throw Exception('Only PDF files are supported.');
    }

    if (bytes.isEmpty) {
      throw Exception('The selected PDF is empty.');
    }

    final request = http.MultipartRequest('POST', _uri('/upload'));

    request.files.add(
      http.MultipartFile.fromBytes('file', bytes, filename: filename),
    );

    final client = http.Client();

    try {
      final streamedResponse = await client
          .send(request)
          .timeout(uploadTimeout);

      final response = await http.Response.fromStream(streamedResponse)
          .timeout(uploadTimeout);

      _ensureSuccess(response, operation: 'PDF upload');

      return _decodeObject(response, operation: 'PDF upload');
    } catch (error) {
      throw _friendlyError(error, operation: 'PDF upload');
    } finally {
      client.close();
    }
  }

  // =====================================================
  // DELETE PDF
  // =====================================================

  static Future<void> deleteDocument(String filename) async {
    final encodedFilename = Uri.encodeComponent(filename);

    try {
      final response = await http
          .delete(_uri('/documents/$encodedFilename'))
          .timeout(documentTimeout);

      _ensureSuccess(response, operation: 'Deleting PDF');
    } catch (error) {
      throw _friendlyError(error, operation: 'Deleting PDF');
    }
  }

  // =====================================================
  // OPEN PDF SOURCE
  // =====================================================

  static Uri pdfSourceUrl(String filename, int page) {
    final encodedFilename = Uri.encodeComponent(filename);

    final safePage = page < 1 ? 1 : page;

    return _uri('/documents/$encodedFilename/file')
        .replace(fragment: 'page=$safePage');
  }
}
