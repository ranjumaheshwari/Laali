// lib/services/chat_history_service.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/chat_message.dart';

class ChatHistoryService {
  static final ChatHistoryService _instance = ChatHistoryService._internal();
  factory ChatHistoryService() => _instance;
  ChatHistoryService._internal();

  static const String _chatHistoryKey = 'chat_history';

  Future<void> saveChatHistory(List<ChatMessage> messages) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final messagesJson = messages.map((msg) => msg.toJson()).toList();
      await prefs.setString(_chatHistoryKey, jsonEncode(messagesJson));
      debugPrint('✅ Chat history saved locally');
    } catch (e) {
      debugPrint('❌ Error saving chat history: $e');
    }
  }

  Future<List<ChatMessage>> loadChatHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final chatHistoryJson = prefs.getString(_chatHistoryKey);
      if (chatHistoryJson != null) {
        final List<dynamic> messagesData = jsonDecode(chatHistoryJson);
        final List<ChatMessage> loadedMessages = [];

        for (final messageData in messagesData) {
          try {
            loadedMessages.add(ChatMessage.fromJson(messageData));
          } catch (e) {
            debugPrint('❌ Error parsing message: $e');
          }
        }

        debugPrint('✅ Chat history loaded: ${loadedMessages.length} messages');
        return loadedMessages;
      }
    } catch (e) {
      debugPrint('❌ Error loading chat history: $e');
    }

    return [];
  }

  Future<void> clearChatHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_chatHistoryKey);
      debugPrint('✅ Chat history cleared');
    } catch (e) {
      debugPrint('❌ Error clearing chat history: $e');
    }
  }
}