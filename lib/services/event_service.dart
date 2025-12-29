import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lunar/lunar.dart';
import '../models/event_model.dart';
import '../models/event_participant_model.dart';
import 'notification_service.dart';

class EventService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final _notificationService = NotificationService();

  /// Fetch events for the current user (Family & Clan)
  Future<List<Event>> getEvents() async {
    try {
      final response = await _supabase
          .from('events')
          .select()
          .order('next_occurrence_solar', ascending: true);
      
      final events = (response as List).map((e) => Event.fromJson(e)).toList();
      return events;
    } catch (e) {
      print('Error fetching events: $e');
      rethrow;
    }
  }

  /// Create a new event
  Future<Event> createEvent(Event event) async {
    final eventData = event.toJson();
    
    // Calculate next occurrence before saving
    final nextSolar = calculateNextOccurrence(
      event.day, 
      event.month, 
      event.isLunar, 
      event.recurrenceType
    );
    eventData['next_occurrence_solar'] = nextSolar.toIso8601String();
    
    // Remove nulls to avoid Supabase errors if any
    eventData.removeWhere((key, value) => value == null);

    final response = await _supabase
        .from('events')
        .insert(eventData)
        .select()
        .single();
    
    final createdEvent = Event.fromJson(response);

    // Trigger Notification is handled by SQL Trigger (handle_new_event_notification)
    // Removed manual call to avoid double notifications.

    return createdEvent;
  }

  /// Notify all members of the Clan/Family about the new event
  Future<void> _notifyMembers(Event event) async {
    if (event.clanId == null) return;

    try {
      // 1. Get all members of the clan/family
      final res = await _supabase
          .from('family_members')
          .select('profile_id')
          .eq('clan_id', event.clanId!);
      
      final memberIds = (res as List)
          .map((row) => row['profile_id'])
          .where((uid) => uid != null && uid != event.createdBy) // Safe filter
          .cast<String>()
          .toList();

      if (memberIds.isEmpty) return;

      // 2. Prepare Message
      final String title = 'Sự kiện mới: ${event.title}';
      final String dateStr = event.isLunar 
          ? '${event.day}/${event.month} (Âm lịch)'
          : '${event.day}/${event.month}/${event.year ?? DateTime.now().year}';
      
      final String message = '${event.scope == EventScope.CLAN ? "Dòng họ" : "Gia đình"} vừa có sự kiện mới vào ngày $dateStr. Hãy kiểm tra ngay!';

      // 3. Send Notification
      await _notificationService.sendBatchNotifications(
        userIds: memberIds,
        title: title,
        message: message,
        type: 'event_new',
        relatedId: event.id,
      );
      
    } catch (e) {
      print('Error in _notifyMembers: $e');
    }
  }
  
  /// Add participant to an event
  Future<void> addParticipant(String eventId, String userId, ParticipantRole role) async {
    await _supabase.from('event_participants').insert({
      'event_id': eventId,
      'user_id': userId,
      'role': role.name,
      'status': 'PENDING',
    });
  }

  /// Get participants for an event
  Future<List<EventParticipant>> getParticipants(String eventId) async {
    final response = await _supabase
        .from('event_participants')
        .select('*, profiles(full_name, avatar_url)')
        .eq('event_id', eventId);
        
    return (response as List).map((e) => EventParticipant.fromJson(e)).toList();
  }
  
  /// Update participant status
  Future<void> updateParticipantStatus(String participantId, ParticipantStatus status) async {
    await _supabase
        .from('event_participants')
        .update({'status': status.name})
        .eq('id', participantId);
  }

  // --- Logic Helpers ---

  /// Calculate the next solar date for the event
  DateTime calculateNextOccurrence(int day, int month, bool isLunar, RecurrenceType recurrence) {
    final now = DateTime.now();
    int targetYear = now.year;
    
    DateTime? candidateDate;
    
    // Try current year first
    candidateDate = _getDate(day, month, targetYear, isLunar);
    
    // If date has passed or invalid, try next year (only if recurring)
    if (candidateDate.isBefore(DateTime(now.year, now.month, now.day))) {
       if (recurrence == RecurrenceType.YEARLY) {
         targetYear++;
         candidateDate = _getDate(day, month, targetYear, isLunar);
       } else {
         // Non-recurring event that has passed: keep the original date (or handled elsewhere)
         // For now, return the passed date so it shows up in history or as "Overdue"
         // If passed, we don't change year if not recurring.
         // If it was a one-time event in the past, we rely on the specific 'year' field if it was set?
         // This function assumes "Calculated Dynamic Next Occurrence". 
         // For one-time event, we should probably respect the specific set year.
       }
    }
    
    return candidateDate;
  }

  DateTime _getDate(int day, int month, int year, bool isLunar) {
    if (!isLunar) {
      // Simple Solar Date
      // Handle leap years etc technically
       try {
        return DateTime(year, month, day);
      } catch (e) {
        // e.g. Feb 30, return last valid day of month? 
        return DateTime(year, month + 1, 0); 
      }
    } else {
      // Lunar Date Conversion
      // Lunar.fromLunar(lunarYear, lunarMonth, lunarDay) -> Solar
      // Note: 'lunar' package might allow creating Lunar date then getting solar
      // We assume standard lunar month (not lease month for simplicity MVP, or 1st one)
      try {
        final lunarDate = Lunar.fromYmd(year, month, day);
        final solar = lunarDate.getSolar();
        return DateTime(solar.getYear(), solar.getMonth(), solar.getDay());
      } catch (e) {
        // Fallback or next valid lunar date
         return DateTime(year, month, day); // Fail safe
      }
    }
  }
}
