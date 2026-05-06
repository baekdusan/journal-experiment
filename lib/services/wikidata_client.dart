import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_ai/firebase_ai.dart';

class WikidataEntity {
  final String id;
  final String label;
  final String description;
  final List<String> relatedEntityIds;

  WikidataEntity({
    required this.id,
    required this.label,
    required this.description,
    required this.relatedEntityIds,
  });

  factory WikidataEntity.fromJson(Map<String, dynamic> json) {
    // Parse Wikidata JSON format
    final entity = json['entities']?.values.first;
    return WikidataEntity(
      id: entity['id'] as String,
      label: entity['labels']?['en']?['value'] ?? '',
      description: entity['descriptions']?['en']?['value'] ?? '',
      relatedEntityIds: _extractRelatedEntities(entity['claims']),
    );
  }

  static List<String> _extractRelatedEntities(Map<String, dynamic>? claims) {
    // Extract P279 (subclass of), P31 (instance of), P366 (use)
    final related = <String>[];
    for (final property in ['P279', 'P31', 'P366']) {
      final propClaims = claims?[property] as List?;
      if (propClaims != null) {
        for (final claim in propClaims) {
          final entityId = claim['mainsnak']?['datavalue']?['value']?['id'];
          if (entityId != null) related.add(entityId);
        }
      }
    }
    return related;
  }
}

class WikidataClient {
  final http.Client _client;
  final String proxyUrl;

  WikidataClient({
    http.Client? client,
    this.proxyUrl = 'http://localhost:5001',
  }) : _client = client ?? http.Client();

  /// Search for entity by topic name (via proxy)
  Future<String?> searchEntity(String topic) async {
    // Try original search first
    var qId = await _searchWithTopic(topic);
    if (qId != null) return qId;

    // If failed and topic contains Korean characters, try English translation
    if (_containsKorean(topic)) {
      final englishTopic = await _tryTranslateToEnglish(topic);
      if (englishTopic != null && englishTopic != topic) {
        qId = await _searchWithTopic(englishTopic);
      }
    }

    return qId;
  }

  /// Internal method to perform actual search
  Future<String?> _searchWithTopic(String topic) async {
    final url = Uri.parse('$proxyUrl/proxy/wikidata/search');

    final response = await _client.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'topic': topic}),
    );

    if (response.statusCode != 200) return null;

    final data = jsonDecode(response.body);
    final searchResults = data['search'] as List?;

    // Check if search results exist and are not empty
    if (searchResults == null || searchResults.isEmpty) {
      return null;
    }

    return searchResults[0]['id'] as String?;
  }

  /// Check if string contains Korean characters
  bool _containsKorean(String text) {
    return RegExp(r'[가-힣]').hasMatch(text);
  }

  /// Translate Korean to English using Gemini
  Future<String?> _tryTranslateToEnglish(String korean) async {
    try {
      final model = FirebaseAI.vertexAI().generativeModel(
        model: 'gemini-2.0-flash-exp',
        generationConfig: GenerationConfig(
          temperature: 0.0,
          maxOutputTokens: 50,
        ),
      );

      final prompt = '''Translate this Korean academic/technical term to English for Wikidata search.
Only return the English translation, nothing else.

Korean: $korean
English:''';

      final response = await model.generateContent([Content.text(prompt)]);
      final translation = response.text?.trim();

      if (translation != null && translation.isNotEmpty) {
        print('[WikidataClient] Translated "$korean" → "$translation"');
        return translation;
      }

      return null;
    } catch (e) {
      print('[WikidataClient] Translation failed: $e');
      return null;
    }
  }

  /// Get entity details by Q-ID (via proxy)
  Future<WikidataEntity?> getEntity(String qId) async {
    final url = Uri.parse('$proxyUrl/proxy/wikidata/entity');

    final response = await _client.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'qid': qId}),
    );

    if (response.statusCode != 200) return null;

    return WikidataEntity.fromJson(jsonDecode(response.body));
  }

  /// Convenience: Search + Get in one call
  Future<WikidataEntity?> fetchByTopic(String topic) async {
    final qId = await searchEntity(topic);
    if (qId == null) return null;
    return getEntity(qId);
  }
}
