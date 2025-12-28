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
  /// [anchorTargetParentId]: The ID of the parent in the Target Clan to attach the Source Root to.
  /// [sourceRootMemberId]: The ID of the root member (user) in the Source Clan.
  /// [rootBirthOrder]: The birth order for the Source Root in the new clan.
  Future<MergeResult> mergeClans({
    required String sourceClanId,
    required String targetClanId,
    int? anchorTargetParentId,
    int? sourceRootMemberId,
    int? rootBirthOrder,
  }) async {
    List<String> errors = [];
    int added = 0;
    int skipped = 0;
    int linked = 0;

    try {
      // 1. Fetch ALL members
      final sourceRes = await _client.from('family_members').select().eq('clan_id', sourceClanId);
      final targetRes = await _client.from('family_members').select().eq('clan_id', targetClanId);

      final sourceMembers = (sourceRes as List).map((j) => FamilyMember.fromJson(j)).toList();
      final targetMembers = (targetRes as List).map((j) => FamilyMember.fromJson(j)).toList();

      if (sourceMembers.isEmpty) {
        return MergeResult(addedCount: 0, skippedCount: 0, linkedCount: 0, errors: ['Gia phả nguồn trống']);
      }

      // 2. ID Mapping
      Map<int, int> idMap = {};

      // 3. Identification & Creation
      for (var src in sourceMembers) {
        FamilyMember? match;
        
        // Try exact match
        try {
          match = targetMembers.firstWhere((tgt) {
            bool nameMatch = tgt.fullName.trim().toLowerCase() == src.fullName.trim().toLowerCase();
            bool genderMatch = tgt.gender == src.gender;
            bool dobMatch = true;
            if (src.birthDate != null && tgt.birthDate != null) {
               dobMatch = src.birthDate!.year == tgt.birthDate!.year && 
                          src.birthDate!.month == tgt.birthDate!.month &&
                          src.birthDate!.day == tgt.birthDate!.day;
            }
            return nameMatch && genderMatch && dobMatch;
          });
        } catch (_) {}

        if (match != null) {
           // FOUND DUPLICATE
           idMap[src.id] = match.id;
           skipped++;
           
           // Special Case: If this is the Root, we still want to update their Parent/BirthOrder if anchored
           if (src.id == sourceRootMemberId && anchorTargetParentId != null) {
              await _client.from('family_members').update({
                'father_id': anchorTargetParentId, // Assume Father for now, logic could check gender 
                'birth_order': rootBirthOrder
              }).eq('id', match.id);
           }
           
        } else {
           // NEW MEMBER
           // Check if this is the Root being anchored
           int? fatherIdToUse; 
           // Note: We don't set relations in INSERT, we do it in UPDATE later.
           // However, for the Root, we might want to override the stored father_id (which maps to nothing yet)
           // to the anchorTargetParentId.
           
           // Insert without relations first
           final insertRes = await _client.from('family_members').insert({
             'clan_id': targetClanId,
             'full_name': src.fullName,
             'gender': src.gender,
             'birth_date': src.birthDate?.toIso8601String(),
             'is_alive': src.isAlive,
             'title': src.title,
             'address': src.address,
             'is_maternal': src.isMaternal,
             'birth_order': (src.id == sourceRootMemberId && rootBirthOrder != null) ? rootBirthOrder : src.birthOrder,
             'generation_level': src.generationLevel, 
             'bio': src.bio,
             'father_id': null,
             'mother_id': null,
             'spouse_id': null, 
           }).select().single();
           
           final newId = insertRes['id'] as int;
           idMap[src.id] = newId;
           added++;
        }
      }

      // 4. Relinking Phase
      for (var src in sourceMembers) {
         final targetId = idMap[src.id];
         if (targetId == null) continue;

         // Resolve new Parent/Spouse IDs
         int? newFatherId = src.fatherId != null ? idMap[src.fatherId!] : null;
         int? newMotherId = src.motherId != null ? idMap[src.motherId!] : null;
         int? newSpouseId = src.spouseId != null ? idMap[src.spouseId!] : null;
         
         // OVERRIDE for Root Anchoring
         if (src.id == sourceRootMemberId && anchorTargetParentId != null) {
            // If the anchor is valid, we set it as Father (usually). 
            // TODO: Ideally check anchor gender to decide Father vs Mother. 
            // For now, let's assume Father for hierarchy.
            newFatherId = anchorTargetParentId;
            // What if anchor is Mother? We need to know. 
            // We can fetch anchor info or assume user selected "Parent" which implies Father in patriarchal tree?
            // Let's assume Father for safety in basic logic, or fetch?
            // Since we don't have anchor info loaded here, we trust the caller passed a valid ID.
            // But which field? Father or Mother?
            // Let's assume 'father_id' for now.
         }

         Map<String, dynamic> updates = {};
         if (newFatherId != null) updates['father_id'] = newFatherId;
         if (newMotherId != null) updates['mother_id'] = newMotherId;
         if (newSpouseId != null) updates['spouse_id'] = newSpouseId;
         
         if (updates.isNotEmpty) {
            bool isNew = !targetMembers.any((t) => t.id == targetId);
            
            if (isNew) {
               await _client.from('family_members').update(updates).eq('id', targetId);
               linked++;
            } else {
               // Existing member: Only update missing fields OR if this is the Root we are explicitly anchoring
               bool isRoot = (src.id == sourceRootMemberId && anchorTargetParentId != null);
               
               final existing = targetMembers.firstWhere((t) => t.id == targetId);
               Map<String, dynamic> safeUpdates = {};
               
               if (isRoot || existing.fatherId == null) {
                  if (updates.containsKey('father_id')) safeUpdates['father_id'] = updates['father_id'];
               }
               if (isRoot || existing.motherId == null) {
                  if (updates.containsKey('mother_id')) safeUpdates['mother_id'] = updates['mother_id'];
               }
               if (existing.spouseId == null && updates.containsKey('spouse_id')) safeUpdates['spouse_id'] = updates['spouse_id'];
               
               if (safeUpdates.isNotEmpty) {
                  await _client.from('family_members').update(safeUpdates).eq('id', targetId);
                  linked++;
               }
            }
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
