class Clan {
  final String id;
  final String name;
  final String? description;
  final String ownerId;
  final String? qrCode;
  final DateTime createdAt;

  Clan({
    required this.id,
    required this.name,
    this.description,
    required this.ownerId,
    this.qrCode,
    required this.createdAt,
  });

  factory Clan.fromJson(Map<String, dynamic> json) {
    return Clan(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      ownerId: json['owner_id'],
      qrCode: json['qr_code'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
