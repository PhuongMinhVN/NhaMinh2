import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Send a notification to a specific user
  Future<void> sendNotification({
    required String userId,
    required String title,
    required String message,
    String type = 'general',
    String? relatedId,
  }) async {
    try {
      await _supabase.from('notifications').insert({
        'user_id': userId,
        'title': title,
        'message': message,
        'type': type,
        'related_id': relatedId,
        'is_read': false,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      // Fail silently or log error, don't block main flow
      print('Error sending notification to $userId: $e');
    }
  }

  /// Send notifications to multiple users
  Future<void> sendBatchNotifications({
    required List<String> userIds,
    required String title,
    required String message,
    String type = 'general',
    String? relatedId,
  }) async {
    if (userIds.isEmpty) return;

    final List<Map<String, dynamic>> payload = userIds.map((uid) => {
      'user_id': uid,
      'title': title,
      'message': message,
      'type': type,
      'related_id': relatedId,
      'is_read': false,
      'created_at': DateTime.now().toIso8601String(),
    }).toList();

    try {
      await _supabase.from('notifications').insert(payload);
    } catch (e) {
      print('Error sending batch notifications: $e');
    }
  }
}
