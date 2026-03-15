// lib/services/firebase_service.dart
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;

  FirebaseService._internal() {
    debugPrint('✅ Firebase Service initialized');
  }

  // ---------- Auth ----------
  User? get currentUser => _auth.currentUser;

  // Simple anonymous sign-in
  Future<User?> signInAnonymously() async {
    try {
      final userCredential = await _auth.signInAnonymously();
      debugPrint('✅ Anonymous user created: ${userCredential.user?.uid}');
      return userCredential.user;
    } catch (e) {
      debugPrint('❌ Anonymous sign-in failed: $e');
      rethrow;
    }
  }

  // NEW: Sign in with custom token for multiple accounts
  Future<User?> signInWithCustomToken(String token) async {
    try {
      final userCredential = await _auth.signInWithCustomToken(token);
      debugPrint('✅ Signed in with custom token: ${userCredential.user?.uid}');
      return userCredential.user;
    } catch (e) {
      debugPrint('❌ Custom token sign-in failed: $e');
      rethrow;
    }
  }

  Future<void> signOut() async => await _auth.signOut();

  // ---------- Multi-Account User Management ----------
  Future<void> createUserProfile({
    required String username,
    required DateTime lmpDate,
    bool isAnonymous = false,
    String? customUserId, // NEW: For multiple accounts
  }) async {
    final user = currentUser;
    if (user == null) throw Exception('No user authenticated');

    try {
      // Use custom user ID if provided, otherwise use Firebase UID
      final userId = customUserId ?? user.uid;

      await _firestore.collection('users').doc(userId).set({
        'username': username,
        'lmp_date': Timestamp.fromDate(lmpDate),
        'is_anonymous': isAnonymous,
        'firebase_uid': user.uid, // Track which Firebase user owns this account
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint('✅ User profile created/updated: $username (ID: $userId)');
    } catch (e) {
      debugPrint('❌ createUserProfile error: $e');
      rethrow;
    }
  }

  // NEW: Get all accounts for current Firebase user
  Future<List<Map<String, dynamic>>> getUserAccounts() async {
    final user = currentUser;
    if (user == null) return [];

    try {
      final query = await _firestore
          .collection('users')
          .where('firebase_uid', isEqualTo: user.uid)
          .get();

      final accounts = query.docs.map((doc) {
        final data = doc.data();
        return {
          'user_id': doc.id,
          ...data,
        };
      }).toList();

      debugPrint('✅ Found ${accounts.length} user accounts');
      return accounts;
    } catch (e) {
      debugPrint('❌ getUserAccounts error: $e');
      return [];
    }
  }

  // NEW: Switch to specific user account
  Future<void> switchUserAccount(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('current_user_id', userId);
      debugPrint('✅ Switched to user account: $userId');
    } catch (e) {
      debugPrint('❌ switchUserAccount error: $e');
      rethrow;
    }
  }

  // NEW: Get current selected user account
  Future<String?> getCurrentUserAccountId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('current_user_id');
  }

  // ---------- Chat History Storage ----------
  Future<void> saveChatMessage({
    required String messageId,
    required String content,
    required bool isUser,
    required String? audioPath,
    required String? videoUrl,
    required String? videoTitle,
  }) async {
    final user = currentUser;
    final currentAccountId = await getCurrentUserAccountId();

    if (user == null || currentAccountId == null) {
      debugPrint('❌ No user or account selected for saving chat');
      return;
    }

    try {
      await _firestore
          .collection('users')
          .doc(currentAccountId)
          .collection('chats')
          .doc(messageId)
          .set({
        'content': content,
        'is_user': isUser,
        'audio_path': audioPath,
        'video_url': videoUrl,
        'video_title': videoTitle,
        'timestamp': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ Chat message saved: $messageId');
    } catch (e) {
      debugPrint('❌ saveChatMessage error: $e');
    }
  }

  // NEW: Load chat history for current account
  Future<List<Map<String, dynamic>>> getChatHistory() async {
    final user = currentUser;
    final currentAccountId = await getCurrentUserAccountId();

    if (user == null || currentAccountId == null) {
      debugPrint('❌ No user or account selected for loading chat');
      return [];
    }

    try {
      final query = await _firestore
          .collection('users')
          .doc(currentAccountId)
          .collection('chats')
          .orderBy('timestamp', descending: false)
          .get();

      final messages = query.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'content': data['content'] ?? '',
          'is_user': data['is_user'] ?? false,
          'audio_path': data['audio_path'],
          'video_url': data['video_url'],
          'video_title': data['video_title'],
          'timestamp': (data['timestamp'] as Timestamp).toDate(),
        };
      }).toList();

      debugPrint('✅ Loaded ${messages.length} chat messages');
      return messages;
    } catch (e) {
      debugPrint('❌ getChatHistory error: $e');
      return [];
    }
  }

  // NEW: Clear chat history for current account
  Future<void> clearChatHistory() async {
    final user = currentUser;
    final currentAccountId = await getCurrentUserAccountId();

    if (user == null || currentAccountId == null) {
      debugPrint('❌ No user or account selected for clearing chat');
      return;
    }

    try {
      final query = await _firestore
          .collection('users')
          .doc(currentAccountId)
          .collection('chats')
          .get();

      final batch = _firestore.batch();
      for (final doc in query.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      debugPrint('✅ Chat history cleared for account: $currentAccountId');
    } catch (e) {
      debugPrint('❌ clearChatHistory error: $e');
    }
  }

  // ---------- User Profile Management ----------
  Future<Map<String, dynamic>?> getUserProfile([String? specificUserId]) async {
    final user = currentUser;
    if (user == null) return null;

    try {
      final userId = specificUserId ?? await getCurrentUserAccountId();
      if (userId == null) return null;

      final doc = await _firestore.collection('users').doc(userId).get();
      if (!doc.exists) return null;

      final data = doc.data();
      return {
        'user_id': doc.id,
        ...?data,
      };
    } catch (e) {
      debugPrint('❌ getUserProfile error: $e');
      return null;
    }
  }

  // NEW: Update user profile
  Future<void> updateUserProfile({
    String? username,
    DateTime? lmpDate,
  }) async {
    final user = currentUser;
    final currentAccountId = await getCurrentUserAccountId();

    if (user == null || currentAccountId == null) {
      throw Exception('No user or account selected');
    }

    try {
      final updateData = <String, dynamic>{
        'updated_at': FieldValue.serverTimestamp(),
      };

      if (username != null) updateData['username'] = username;
      if (lmpDate != null) updateData['lmp_date'] = Timestamp.fromDate(lmpDate);

      await _firestore
          .collection('users')
          .doc(currentAccountId)
          .update(updateData);

      debugPrint('✅ User profile updated: $currentAccountId');
    } catch (e) {
      debugPrint('❌ updateUserProfile error: $e');
      rethrow;
    }
  }

  // ---------- Simple Data Getters ----------
  Future<String?> getUsername([String? specificUserId]) async {
    final profile = await getUserProfile(specificUserId);
    return profile?['username'] as String?;
  }

  Future<DateTime?> getLmpDate([String? specificUserId]) async {
    final profile = await getUserProfile(specificUserId);
    final timestamp = profile?['lmp_date'] as Timestamp?;
    return timestamp?.toDate();
  }

  // Check if user exists
  Future<bool> userExists([String? specificUserId]) async {
    final profile = await getUserProfile(specificUserId);
    return profile != null;
  }

  // Get user ID for debugging
  String? get userId => currentUser?.uid;

  // Check if user is anonymous
  bool get isAnonymous => currentUser?.isAnonymous ?? true;
}