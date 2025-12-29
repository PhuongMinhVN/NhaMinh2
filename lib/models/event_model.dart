
enum EventScope { FAMILY, CLAN }
enum EventCategory { ANNIVERSARY, WEDDING, FUNERAL, FESTIVAL, OTHER }
enum RecurrenceType { NONE, YEARLY }

class Event {
  final String id;
  final String title;
  final String? description;
  final EventScope scope;
  final String? clanId; // Nullable if scope is FAMILY
  final EventCategory category;
  final bool isLunar;
  final int day;
  final int month;
  final int? year;
  final RecurrenceType recurrenceType;
  final DateTime? nextOccurrenceSolar;
  final String createdBy;
  final bool requiresAttendance;
  final bool isImportant;
  final DateTime createdAt;

  Event({
    required this.id,
    required this.title,
    this.description,
    this.scope = EventScope.FAMILY,
    this.clanId,
    this.category = EventCategory.OTHER,
    this.isLunar = true,
    required this.day,
    required this.month,
    this.year,
    this.recurrenceType = RecurrenceType.YEARLY,
    this.nextOccurrenceSolar,
    required this.createdBy,
    this.requiresAttendance = false,
    this.isImportant = false,
    required this.createdAt,
  });

  factory Event.fromJson(Map<String, dynamic> json) {
    return Event(
      id: json['id'].toString(),
      title: json['title'] ?? '',
      description: json['description'],
      scope: _parseScope(json['scope']),
      clanId: json['clan_id'],
      category: _parseCategory(json['category']),
      isLunar: json['is_lunar'] ?? true,
      day: json['day'] ?? 1,
      month: json['month'] ?? 1,
      year: json['year'],
      recurrenceType: _parseRecurrence(json['recurrence_type']),
      nextOccurrenceSolar: json['next_occurrence_solar'] != null
          ? DateTime.parse(json['next_occurrence_solar'])
          : null,
      createdBy: json['created_by'] ?? '',
      requiresAttendance: json['requires_attendance'] ?? false,
      isImportant: json['is_important'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'scope': scope.name,
      'clan_id': clanId,
      'category': category.name,
      'is_lunar': isLunar,
      'day': day,
      'month': month,
      'year': year,
      'recurrence_type': recurrenceType.name,
      'requires_attendance': requiresAttendance,
      'is_important': isImportant,
      'created_by': createdBy,
    };
  }

  static EventScope _parseScope(String? val) {
    return EventScope.values.firstWhere(
      (e) => e.name == val,
      orElse: () => EventScope.FAMILY,
    );
  }

  static EventCategory _parseCategory(String? val) {
    return EventCategory.values.firstWhere(
      (e) => e.name == val,
      orElse: () => EventCategory.OTHER,
    );
  }

  static RecurrenceType _parseRecurrence(String? val) {
    return RecurrenceType.values.firstWhere(
      (e) => e.name == val,
      orElse: () => RecurrenceType.YEARLY,
    );
  }
}
