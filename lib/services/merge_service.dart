import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/family_member.dart';

class MergeResult {
  final int addedCount;
  final int skippedCount;
  final int linkedCount;
  final List<String> errors;

  MergeResult({
    required this.addedCount,
    required this.skippedCount,
    required this.linkedCount,
    this.errors = const [],
  });
}

class MergeService {
  final SupabaseClient _client = Supabase.instance.client;

  /// Merges [sourceClanId] into [targetClanId].
  /// [anchorParent]: The parent (Father/Mother) in the Target Clan to attach the Source Root to.
  /// [sourceRootMemberId]: The ID of the root member (user) in the Source Clan.
  /// [rootBirthOrder]: The birth order for the Source Root in the new clan.
  Future<MergeResult> mergeClans({
    required String sourceClanId,
    required String targetClanId,
    FamilyMember? anchorParent, // ID + Gender info
    int? sourceRootMemberId,
    int? rootBirthOrder,
  }) async {
    List<String> errors = [];
    int added = 0;
    int skipped = 0;
    int linked = 0;

    try {
      // 1. Fetch Source Members to gather info
      final sourceRes = await _client.from('family_members').select().eq('clan_id', sourceClanId);
      final sourceMembers = (sourceRes as List).map((j) => FamilyMember.fromJson(j)).toList();

      if (sourceMembers.isEmpty) {
        return MergeResult(addedCount: 0, skippedCount: 0, linkedCount: 0, errors: ['Gia phả nguồn trống']);
      }

      // 2. Identify Root Source Member
      // If sourceRootMemberId is not provided, we can't do Single Node Merge effectively. 
      // But usually it is passed. If null, maybe fallback to Owner? 
      // For now assume provided or pick first (risky).
      if (sourceRootMemberId == null) {
         return MergeResult(addedCount: 0, skippedCount: 0, linkedCount: 0, errors: ['Không xác định được thành viên gốc để gộp']);
      }
      
      final rootSrc = sourceMembers.firstWhere(
        (m) => m.id == sourceRootMemberId, 
        orElse: () => throw 'Không tìm thấy thành viên gốc trong dữ liệu nguồn'
      );

      // 3. Gather Immediate Family Info from Source Tree
      String familyInfo = '';
      
      // A. Spouse
      List<String> spouses = [];
      // Case 1: root.spouseId points to someone
      if (rootSrc.spouseId != null) {
         try {
           final s = sourceMembers.firstWhere((m) => m.id == rootSrc.spouseId);
           spouses.add(s.fullName);
         } catch (_) {}
      }
      // Case 2: Someone points to root as spouse
      for (var m in sourceMembers) {
         if (m.spouseId == rootSrc.id) spouses.add(m.fullName);
      }
      if (spouses.isNotEmpty) {
         familyInfo += 'Vợ/Chồng: ${spouses.toSet().join(", ")}\n';
      }

      // B. Children
      List<String> children = [];
      for (var m in sourceMembers) {
         if (m.fatherId == rootSrc.id || m.motherId == rootSrc.id) {
            children.add(m.fullName);
         }
      }
      if (children.isNotEmpty) {
         familyInfo += 'Con: ${children.join(", ")}\n';
      }

      // C. Parents (Source) - Optional, mainly for reference since we link to New Parent
      String fatherName = '';
      String motherName = '';
      if (rootSrc.fatherId != null) {
         try { fatherName = sourceMembers.firstWhere((m) => m.id == rootSrc.fatherId).fullName; } catch(_) {}
      }
      if (rootSrc.motherId != null) {
         try { motherName = sourceMembers.firstWhere((m) => m.id == rootSrc.motherId).fullName; } catch(_) {}
      }
      if (fatherName.isNotEmpty) familyInfo += 'Cha (gốc): $fatherName\n';
      if (motherName.isNotEmpty) familyInfo += 'Mẹ (gốc): $motherName\n';

      // 4. Prepare New Bio
      String newBio = rootSrc.bio ?? '';
      if (familyInfo.isNotEmpty) {
         if (newBio.isNotEmpty) newBio += '\n\n';
         newBio += '--- THÔNG TIN GIA ĐÌNH CŨ ---\n$familyInfo';
      }

      // 5. Check Target for Duplicate
      final targetRes = await _client.from('family_members').select().eq('clan_id', targetClanId);
      final targetMembers = (targetRes as List).map((j) => FamilyMember.fromJson(j)).toList();

      FamilyMember? match;
      try {
        match = targetMembers.firstWhere((tgt) {
          bool nameMatch = tgt.fullName.trim().toLowerCase() == rootSrc.fullName.trim().toLowerCase();
          bool genderMatch = tgt.gender == rootSrc.gender;
          bool dobMatch = true;
          if (rootSrc.birthDate != null && tgt.birthDate != null) {
             dobMatch = rootSrc.birthDate!.year == tgt.birthDate!.year && 
                        rootSrc.birthDate!.month == tgt.birthDate!.month && 
                        rootSrc.birthDate!.day == tgt.birthDate!.day;
          }
          return nameMatch && genderMatch && dobMatch;
        });
      } catch (_) {}

      if (match != null) {
         // UPDATE EXISTING
         skipped++;
         Map<String, dynamic> updates = {
           'bio': newBio, // Update Bio with family info
           'birth_order': rootBirthOrder
         };
         
         // Relink Parent
         if (anchorParent != null) {
            if (anchorParent.gender == 'female') {
               updates['mother_id'] = anchorParent.id;
            } else {
               updates['father_id'] = anchorParent.id;
            }
         }
         
         await _client.from('family_members').update(updates).eq('id', match.id);
         linked++;

      } else {
         // INSERT NEW ROOT ONLY
         Map<String, dynamic> insertData = {
             'clan_id': targetClanId,
             'full_name': rootSrc.fullName,
             'gender': rootSrc.gender,
             'birth_date': rootSrc.birthDate?.toIso8601String(),
             'is_alive': rootSrc.isAlive,
             'title': rootSrc.title,
             'address': rootSrc.address,
             'is_maternal': rootSrc.isMaternal,
             'birth_order': rootBirthOrder ?? rootSrc.birthOrder,
             'generation_level': rootSrc.generationLevel, 
             'bio': newBio,
             'father_id': null,
             'mother_id': null,
             'spouse_id': null, 
         };

         if (anchorParent != null) {
            if (anchorParent.gender == 'female') {
               insertData['mother_id'] = anchorParent.id;
            } else {
               insertData['father_id'] = anchorParent.id;
            }
         }

         await _client.from('family_members').insert(insertData);
         added++;
      }

      return MergeResult(
        addedCount: added,
        skippedCount: skipped,
        linkedCount: linked,
        errors: [],
      );

    } catch (e) {
      return MergeResult(addedCount: 0, skippedCount: 0, linkedCount: 0, errors: [e.toString()]);
    }
  }
}
