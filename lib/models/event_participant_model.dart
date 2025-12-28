
enum ParticipantRole { ASSIGNEE, ATTENDEE }
enum ParticipantStatus { PENDING, ACCEPTED, REJECTED }

class EventParticipant {
  final String id;
  final String eventId;
  final String userId;
  final ParticipantRole role;
  final ParticipantStatus status;
  final String? note;
  
  // Optional: User profile details for UI display (joined query)
  final String? userFullName;
  final String? userAvatarUrl;

  EventParticipant({
    required this.id,
    required this.eventId,
    required this.userId,
    this.role = ParticipantRole.ATTENDEE,
    this.status = ParticipantStatus.PENDING,
    this.note,
    this.userFullName,
    this.userAvatarUrl,
  });

  factory EventParticipant.fromJson(Map<String, dynamic> json) {
    return EventParticipant(
      id: json['id'].toString(),
      eventId: json['event_id'].toString(),
      userId: json['user_id'],
      role: _parseRole(json['role']),
      status: _parseStatus(json['status']),
      note: json['note'],
      // Assuming joined query might look like 'profiles': {'full_name': ...}
      userFullName: json['profiles'] != null ? json['profiles']['full_name'] : null,
      userAvatarUrl: json['profiles'] != null ? json['profiles']['avatar_url'] : null,
    );
  }

  static ParticipantRole _parseRole(String? val) {
    return ParticipantRole.values.firstWhere(
      (e) => e.name == val,
      orElse: () => ParticipantRole.ATTENDEE,
    );
  }

  static ParticipantStatus _parseStatus(String? val) {
    return ParticipantStatus.values.firstWhere(
      (e) => e.name == val,
      orElse: () => ParticipantStatus.PENDING,
    );
  }
}
