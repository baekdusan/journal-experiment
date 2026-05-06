import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;

/// Represents a chunk retrieved from the RAG system.
class RetrievedChunk {
  final String id;
  final String content;
  final int pageNumber;
  final String? sectionHeader;
  final double similarity;

  RetrievedChunk({
    required this.id,
    required this.content,
    required this.pageNumber,
    this.sectionHeader,
    required this.similarity,
  });

  factory RetrievedChunk.fromJson(Map<String, dynamic> json) {
    return RetrievedChunk(
      id: json['id'] as String,
      content: json['content'] as String,
      pageNumber: json['page_number'] as int,
      sectionHeader: json['section_header'] as String?,
      similarity: (json['similarity'] as num).toDouble(),
    );
  }

  @override
  String toString() {
    return 'RetrievedChunk(id: $id, page: $pageNumber, similarity: ${similarity.toStringAsFixed(2)})';
  }
}

/// Service for retrieving relevant chunks from the RAG system.
///
/// This service communicates with the Flask HTTP Bridge API to perform
/// vector similarity search on the instructional design PDF content.
class RagService {
  final String baseUrl;

  RagService({this.baseUrl = 'http://localhost:5001'});

  /// Retrieve top-K chunks for a given query.
  ///
  /// Returns an empty list if the retrieval fails (graceful degradation).
  Future<List<RetrievedChunk>> retrieve(String query, {int topK = 3}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/retrieve'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'query': query, 'top_k': topK}),
      );

      if (response.statusCode != 200) {
        throw Exception('RAG API error: ${response.statusCode} - ${response.body}');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final results = data['results'] as List;

      final chunks = results
          .map((item) => RetrievedChunk.fromJson(item as Map<String, dynamic>))
          .toList();

      print('[RagService] Retrieved ${chunks.length} chunks for query: "${query.substring(0, min(50, query.length))}..."');
      return chunks;
    } catch (e) {
      // Log error but don't crash - fallback to no RAG context
      print('[RagService] Retrieval failed: $e');
      return [];
    }
  }

  /// Health check for RAG server.
  ///
  /// Returns true if the server is reachable and operational.
  Future<bool> isHealthy() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/health'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        print('[RagService] Health check OK - ${data['index_size']} vectors loaded');
        return true;
      }
      return false;
    } catch (e) {
      print('[RagService] Health check failed: $e');
      return false;
    }
  }
}
