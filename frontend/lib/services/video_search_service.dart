// lib/services/video_search_service.dart
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
//import 'package:http/http.dart' as http;
import '../data/video_record.dart';
//import '../config/api_config.dart';

class VideoSearchService {
  static final VideoSearchService _instance = VideoSearchService._internal();
  factory VideoSearchService() => _instance;
  VideoSearchService._internal();

  List<VideoRecord> _index = [];
  bool _isInitialized = false;

  Future<void> initialize({String assetPath = 'assets/video_index.json'}) async {
    try {
      final raw = await rootBundle.loadString(assetPath);
      final list = json.decode(raw) as List<dynamic>;
      _index = list.map((e) => VideoRecord.fromJson(e as Map<String, dynamic>)).toList();
      _isInitialized = true;
      debugPrint('✅ VideoSearchService initialized with ${_index.length} records');
    } catch (e) {
      throw Exception('❌ Failed to initialize VideoSearchService: $e');
    }
  }

  Future<List<VideoRecord>> searchSimilarVideos({
    required String query,
    int topN = 5,
    double threshold = 0.68,
  }) async {
    if (!_isInitialized) {
      throw Exception('VideoSearchService not initialized. Call initialize() first.');
    }

    if (query.trim().isEmpty) return [];

    try {
      final queryEmbedding = await _getQueryEmbedding(query);
      final matches = _findTopMatches(queryEmbedding, topN: topN, threshold: threshold);
      return matches.map((match) => match['record'] as VideoRecord).toList();
    } catch (e) {
      debugPrint('Search error: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> searchWithScores({
    required String query,
    int topN = 5,
    double threshold = 0.68,
  }) async {
    if (!_isInitialized) {
      throw Exception('VideoSearchService not initialized. Call initialize() first.');
    }

    if (query.trim().isEmpty) return [];

    try {
      final queryEmbedding = await _getQueryEmbedding(query);
      return _findTopMatches(queryEmbedding, topN: topN, threshold: threshold);
    } catch (e) {
      debugPrint('Search with scores error: $e');
      rethrow;
    }
  }

  Future<List<double>> _getQueryEmbedding(String query) async {
    // Use your existing Gemini API or add embedding service
    // For now, using a mock - you'll want to replace this
    return await _getEmbeddingFromGemini(query);
  }

  Future<List<double>> _getEmbeddingFromGemini(String query) async {
    // TODO: Integrate with your Gemini API for embeddings
    // This is a placeholder - you'll need to implement based on your API
    try {
      // Mock implementation - replace with actual API call
      await Future.delayed(Duration(milliseconds: 100));

      // For now, return a mock embedding of same dimension as your index
      if (_index.isNotEmpty) {
        final dimension = _index.first.embedding.length;
        final random = Random(query.hashCode);
        return List.generate(dimension, (i) => random.nextDouble() * 2 - 1);
      }
      return List.generate(384, (i) => 0.0); // Default dimension
    } catch (e) {
      throw Exception('Failed to get embedding: $e');
    }
  }

  List<Map<String, dynamic>> _findTopMatches(
      List<double> queryEmbedding, {
        int topN = 5,
        double threshold = 0.68,
      }) {
    if (_index.isEmpty) return [];

    final scores = <Map<String, dynamic>>[];

    for (final record in _index) {
      final score = _cosineSimilarity(record.embedding, queryEmbedding);
      if (score >= threshold) {
        scores.add({
          'record': record,
          'score': score,
        });
      }
    }

    scores.sort((a, b) => (b['score'] as double).compareTo(a['score'] as double));

    return scores.take(topN).toList();
  }

  double _cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length) {
      throw ArgumentError('Vectors must be same length: ${a.length} != ${b.length}');
    }

    double dot = 0.0;
    double normA = 0.0;
    double normB = 0.0;

    for (int i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }

    final denominator = sqrt(normA) * sqrt(normB);
    return denominator == 0.0 ? 0.0 : dot / denominator;
  }

  // Getters
  bool get isInitialized => _isInitialized;
  int get recordCount => _index.length;
  List<VideoRecord> get allRecords => List.unmodifiable(_index);
}