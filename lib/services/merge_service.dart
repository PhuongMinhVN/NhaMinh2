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
    int? targetSelfMemberId,
  }) async {
    List<String> errors = [];
    int added = 0;
    int skipped = 0;
    int linked = 0;
    final Map<int, int> idMap = {}; // Old_ID -> New_ID

    try {
      // 1. Fetch Source Members
      final sourceRes = await _client.from('family_members').select().eq('clan_id', sourceClanId);
      final sourceMembers = (sourceRes as List).map((j) => FamilyMember.fromJson(j)).toList();

      if (sourceMembers.isEmpty) {
        return MergeResult(addedCount: 0, skippedCount: 0, linkedCount: 0, errors: ['Gia phả nguồn trống']);
      }

      if (sourceRootMemberId == null) {
         return MergeResult(addedCount: 0, skippedCount: 0, linkedCount: 0, errors: ['Không xác định được thành viên gốc']);
      }
      
      final rootSrc = sourceMembers.firstWhere(
        (m) => m.id == sourceRootMemberId, 
        orElse: () => throw 'Không tìm thấy thành viên gốc'
      );

      // 2. Process Root (Anchor Point)
      // Check for duplicate in Target
      final targetRes = await _client.from('family_members').select().eq('clan_id', targetClanId);
      final targetMembers = (targetRes as List).map((j) => FamilyMember.fromJson(j)).toList();

      if (targetSelfMemberId != null) {
         // --- CASE A: USER IDENTIFIED THEMSELVES IN TARGET ---
         final targetSelf = targetMembers.where((m) => m.id == targetSelfMemberId).firstOrNull;
         if (targetSelf == null) {
            return MergeResult(addedCount: 0, skippedCount: 0, linkedCount: 0, errors: ['Thành viên đích không tồn tại']);
         }
         
         // Map Source Root -> Target Self
         idMap[rootSrc.id] = targetSelf.id;
         linked++;
         
         // If Anchor Parent provided (e.g. updating parents of existing member?)
         // Usually if they exist, they might already have parents. 
         // But allow update if missing.
         Map<String, dynamic> updates = {};
         if (anchorParent != null) {
             if (targetSelf.motherId == null && anchorParent.gender == 'female') {
                updates['mother_id'] = anchorParent.id;
             }
             if (targetSelf.fatherId == null && anchorParent.gender == 'male') {
                updates['father_id'] = anchorParent.id;
             }
         }
         if (updates.isNotEmpty) {
            await _client.from('family_members').update(updates).eq('id', targetSelf.id);
         }
         
      } else {
          // --- CASE B: AUTOMATIC / NEW MEMBER ---
          FamilyMember? match;
          try {
            match = targetMembers.firstWhere((tgt) {
              bool nameMatch = tgt.fullName.trim().toLowerCase() == rootSrc.fullName.trim().toLowerCase();
              bool dobMatch = true;
              if (rootSrc.birthDate != null && tgt.birthDate != null) {
                 dobMatch = rootSrc.birthDate!.year == tgt.birthDate!.year && 
                            rootSrc.birthDate!.month == tgt.birthDate!.month && 
                            rootSrc.birthDate!.day == tgt.birthDate!.day;
              }
              return nameMatch && dobMatch; 
            });
          } catch (_) {}
    
          if (match != null) {
             // LINK EXISTING ROOT (Name Match)
             idMap[rootSrc.id] = match.id;
             linked++;
             
             Map<String, dynamic> updates = {};
             if (anchorParent != null) {
                if (anchorParent.gender == 'female') updates['mother_id'] = anchorParent.id;
                else updates['father_id'] = anchorParent.id;
             }
             if (rootBirthOrder != null) updates['birth_order'] = rootBirthOrder;
             
             if (updates.isNotEmpty) {
               await _client.from('family_members').update(updates).eq('id', match.id);
             }
          } else {
             // INSERT NEW ROOT
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
                 'bio': rootSrc.bio,
                 'father_id': null,
                 'mother_id': null,
                 'spouse_id': null, 
                 'profile_id': rootSrc.profileId, 
             };
    
             if (anchorParent != null) {
                if (anchorParent.gender == 'female') insertData['mother_id'] = anchorParent.id;
                else insertData['father_id'] = anchorParent.id;
             }
    
             final res = await _client.from('family_members').insert(insertData).select().single();
             idMap[rootSrc.id] = res['id'];
             added++;
          }
      }

      // 3. Process Remainder (Full Copy)
      // Filter out Root, we did him.
      final others = sourceMembers.where((m) => m.id != rootSrc.id).toList();

      // Pass 3a: Insert Others (No Relations)
      for (var m in others) {
          Map<String, dynamic> data = {
             'clan_id': targetClanId,
             'full_name': m.fullName,
             'gender': m.gender,
             'birth_date': m.birthDate?.toIso8601String(),
             'is_alive': m.isAlive,
             'title': m.title,
             'address': m.address,
             'is_maternal': m.isMaternal,
             'birth_order': m.birthOrder,
             'generation_level': m.generationLevel, 
             'bio': m.bio,
             // Relations NULL initially
             'father_id': null,
             'mother_id': null,
             'spouse_id': null,
             'profile_id': m.profileId, // Copy Link if any
          };
          
          final res = await _client.from('family_members').insert(data).select().single();
          idMap[m.id] = res['id'];
          added++;
      }

      // Pass 3b: Update Relations (Batch or Loop)
      for (var oldMember in sourceMembers) {
         final newId = idMap[oldMember.id];
         if (newId == null) continue; // Should not happen

         Map<String, dynamic> updates = {};
         
         // Map Father
         if (oldMember.fatherId != null && idMap.containsKey(oldMember.fatherId)) {
            updates['father_id'] = idMap[oldMember.fatherId];
         }
         // Map Mother
         if (oldMember.motherId != null && idMap.containsKey(oldMember.motherId)) {
            updates['mother_id'] = idMap[oldMember.motherId];
         }
         // Map Spouse
         if (oldMember.spouseId != null && idMap.containsKey(oldMember.spouseId)) {
            updates['spouse_id'] = idMap[oldMember.spouseId];
         }

         if (updates.isNotEmpty) {
            await _client.from('family_members').update(updates).eq('id', newId);
         }
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
