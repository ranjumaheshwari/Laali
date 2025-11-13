// lib/services/supabase_service.dart
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class AppUser {
  final String id;
  final String age;
  final String height;
  final String weight;
  final String name;
  final String email;

  AppUser({
    required this.id,
    required this.age,
    required this.height,
    required this.weight,
    required this.name,
    required this.email,
  });
}

class HealthData {
  final String systolicBP;
  final String diastolicBP;

  HealthData({
    required this.systolicBP,
    required this.diastolicBP,
  });
}

class SupabaseService {
  late final SupabaseClient _client;

  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;

  SupabaseService._internal() {
    try {
      _client = Supabase.instance.client;
      debugPrint('✅ Supabase client initialized');
    } catch (e) {
      debugPrint('⚠️ Supabase not initialized yet: $e');
      // Supabase will be initialized later in main()
    }
  }

  /// Check if Supabase is properly initialized
  bool get isInitialized {
    try {
      Supabase.instance.client;
      return true;
    } catch (e) {
      return false;
    }
  }

  // ---------- Auth helpers ----------
  User? get currentUser {
    try {
      return _client.auth.currentUser;
    } catch (e) {
      debugPrint('⚠️ Error getting current user: $e');
      return null;
    }
  }

  Future<AuthResponse> signUpTempUser() async {
    // Generate a random email that Supabase will accept
    // Using timestamp + random string for uniqueness
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomPart = Uuid().v4().substring(0, 8); // First 8 chars of UUID
    // use example.com as a safe, widely-accepted domain for generated emails
    final email = 'user$timestamp$randomPart@example.com';
    final password =
        '${Uuid().v4()}${DateTime.now().millisecondsSinceEpoch}'; // Add timestamp to password for extra entropy

    debugPrint('🔐 Creating temp auth user: $email');
    try {
      final res = await _client.auth.signUp(email: email, password: password);
      debugPrint('✅ Temp user created: ${res.user?.id}');
      return res;
    } catch (e) {
      // Log clearer context for the failure so callers can decide fallback behavior
      debugPrint('❌ Temp user signup failed for $email: $e');
      rethrow;
    }
  }

  Future<void> signOut() async => await _client.auth.signOut();

  // ---------- Profile ----------
  Future<void> createProfile(
      {required String username, bool isAnonymous = false}) async {
    final user = currentUser;
    if (user == null) throw Exception('No user authenticated');

    final data = {
      'id': user.id,
      'username': username,
      'is_anonymous': isAnonymous,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    };

    try {
      await _client.from('profiles').insert(data);
    } catch (e) {
      debugPrint('createProfile error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getProfile() async {
    final user = currentUser;
    if (user == null) return null;
    try {
      final result = await _client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();
      if (result == null) return null;
      return Map<String, dynamic>.from(result);
    } catch (e) {
      debugPrint('getProfile error: $e');
      return null;
    }
  }

  // ---------- Pregnancies ----------
  Future<Map<String, dynamic>?> createPregnancy({
    required DateTime lmpDate,
  }) async {
    final user = currentUser;
    if (user == null) throw Exception('No user authenticated');

    final edd = lmpDate.add(const Duration(days: 280));
    final payload = {
      'user_id': user.id,
      'lmp_date': lmpDate.toIso8601String().split('T').first,
      'estimated_due': edd.toIso8601String().split('T').first,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    };

    try {
      final inserted = await _client
          .from('pregnancies')
          .insert(payload)
          .select()
          .maybeSingle();
      if (inserted == null) return null;
      return Map<String, dynamic>.from(inserted);
    } catch (e) {
      debugPrint('createPregnancy error: $e');
      return null;
    }
  }

  // ---------- Visit Notes ----------
  Future<void> saveVisitNote(String transcript) async {
    final user = currentUser;
    if (user == null) return;

    try {
      await _client.from('visit_notes').insert({
        'user_id': user.id,
        'transcript': transcript,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Error saving visit note: $e');
    }
  }

  // ---------- Data Retrieval ----------
  Future<List<Map<String, dynamic>>> getVisitNotes() async {
    final user = currentUser;
    if (user == null) return [];
    try {
      final result = await _client
          .from('visit_notes')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(result);
    } catch (e) {
      debugPrint('Error getting visit notes: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getVitals() async {
    final user = currentUser;
    if (user == null) return [];
    try {
      final result = await _client
          .from('vitals')
          .select()
          .eq('user_id', user.id)
          .order('measured_at', ascending: false);
      return List<Map<String, dynamic>>.from(result);
    } catch (e) {
      debugPrint('Error getting vitals: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> getLatestRiskScore() async {
    final user = currentUser;
    if (user == null) return null;
    try {
      final result = await _client
          .from('risk_scores')
          .select()
          .eq('user_id', user.id)
          .order('computed_at', ascending: false)
          .limit(1)
          .maybeSingle();
      return result == null ? null : Map<String, dynamic>.from(result);
    } catch (e) {
      debugPrint('Error getting risk score: $e');
      return null;
    }
  }

  // Get latest pregnancy
  Future<Map<String, dynamic>?> getLatestPregnancy() async {
    final user = currentUser;
    if (user == null) return null;
    try {
      final result = await _client
          .from('pregnancies')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      return result == null ? null : Map<String, dynamic>.from(result);
    } catch (e) {
      debugPrint('Error getting pregnancy: $e');
      return null;
    }
  }
}
