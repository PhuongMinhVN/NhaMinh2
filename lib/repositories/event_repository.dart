import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/clan_event.dart';

class EventRepository {
  final SupabaseClient _client = Supabase.instance.client;

  Future<List<ClanEvent>> fetchUpcomingEvents() async {
    try {
      // 1. Fetch all events (we filter in memory because annual events logic is complex)
      final response = await _client.from('clan_events').select().order('event_date', ascending: true);
      
      final List<ClanEvent> allEvents = (response as List)
          .map((e) => ClanEvent.fromJson(e))
          .toList();

      // 2. Calculate upcoming dates
      final now = DateTime.now();
      for (var event in allEvents) {
        event.calculateUpcoming(now);
      }

      // 3. Filter past one-time events & Sort
      final validEvents = allEvents.where((e) {
        // Giữ lại sự kiện nếu nó còn hạn (daysUntil >= 0)
        // Hoặc có thể giữ lại cả sự kiện đã qua trong năm nay nếu muốn hiển thị lịch sử
        // Ở đây ta chỉ lấy "Sắp tới" -> daysUntil >= 0
        return e.daysUntil != null && e.daysUntil! >= 0;
      }).toList();

      validEvents.sort((a, b) => a.daysUntil!.compareTo(b.daysUntil!));

      return validEvents;
    } catch (e) {
      throw 'Lỗi tải sự kiện: $e';
    }
  }

  Future<void> addEvent(String title, DateTime date, bool isLunar, String type, String desc, String location) async {
    await _client.from('clan_events').insert({
      'title': title,
      'event_date': date.toIso8601String(),
      'is_lunar': isLunar,
      'type': type,
      'description': desc,
      'location': location,
      'created_by': _client.auth.currentUser?.id
    });
  }
}
