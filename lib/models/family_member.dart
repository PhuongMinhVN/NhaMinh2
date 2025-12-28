class FamilyMember {
  final int id;
  final String fullName;
  final String? nickname;
  final String? gender; // 'male', 'female', 'other'
  final DateTime? birthDate;
  final DateTime? deathDate;
  final bool isAlive;
  final int? fatherId;
  final int? motherId;
  final int? spouseId;
  int? generationLevel;
  final int? orderInFamily;
  final String? bio;
  final String? burialPlace;
  final String? profileId;
  final String? avatarUrl;
  final bool isRoot;
  final String? clanId; // NEW
  final String? branchName;
  final bool isMaleLineage;
  final String? title;
  final String? address;

  final bool isMaternal; // NEW: Bên ngoại
  final int? birthOrder; // NEW: Con thứ mấy (1, 2, 3...)

  // Runtime helper
  FamilyMember? spouse;
  List<FamilyMember> children = [];

  FamilyMember({
    required this.id,
    required this.fullName,
    this.nickname,
    this.gender,
    this.birthDate,
    this.deathDate,
    required this.isAlive,
    this.fatherId,
    this.motherId,
    this.spouseId,
    this.generationLevel,
    this.orderInFamily,
    this.bio,
    this.burialPlace,
    this.profileId,
    this.avatarUrl,
    this.isRoot = false,
    this.clanId,
    this.branchName,
    this.isMaleLineage = true,
    this.title,
    this.address,

    this.isMaternal = false,
    this.birthOrder,
  });

  factory FamilyMember.fromJson(Map<String, dynamic> json) {
    return FamilyMember(
      id: json['id'],
      fullName: json['full_name'],
      nickname: json['nickname'],
      gender: json['gender'],
      birthDate: json['birth_date'] != null ? DateTime.parse(json['birth_date']) : null,
      deathDate: json['death_date'] != null ? DateTime.parse(json['death_date']) : null,
      isAlive: json['is_alive'] ?? true,
      fatherId: json['father_id'],
      motherId: json['mother_id'],
      spouseId: json['spouse_id'],
      generationLevel: json['generation_level'],
      orderInFamily: json['order_in_family'],
      bio: json['bio'],
      burialPlace: json['burial_place'],
      profileId: json['profile_id'],
      avatarUrl: json['avatar_url'],
      isRoot: json['is_root'] ?? false,
      clanId: json['clan_id'],
      branchName: json['branch_name'],
      isMaleLineage: json['is_male_lineage'] ?? true,
      title: json['title'],
      address: json['address'],

      isMaternal: json['is_maternal'] ?? false,
      birthOrder: json['birth_order'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'full_name': fullName,
      'nickname': nickname,
      'gender': gender,
      'birth_date': birthDate?.toIso8601String(),
      'death_date': deathDate?.toIso8601String(),
      'is_alive': isAlive,
      'father_id': fatherId,
      'mother_id': motherId,
      'spouse_id': spouseId,
      'generation_level': generationLevel,
      'order_in_family': orderInFamily,
      'bio': bio,
      'burial_place': burialPlace,
      'profile_id': profileId,
      'avatar_url': avatarUrl,
      'is_root': isRoot,
      'clan_id': clanId,
      'branch_name': branchName,
      'is_male_lineage': isMaleLineage,
      'title': title,
      'address': address,
      'is_maternal': isMaternal,
      'birth_order': birthOrder,
    };
  }
}
