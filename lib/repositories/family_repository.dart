import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/family_member.dart';

class FamilyRepository {
  final SupabaseClient _client = Supabase.instance.client;

  Future<List<FamilyMember>> fetchAllMembers() async {
    try {
      // 1. Fetch data
      final response = await _client.from('family_members').select();
      final List<FamilyMember> members = (response as List).map((e) => FamilyMember.fromJson(e)).toList();

      // 2. Build relationships (Children mapping)
      // Map ID -> Member
      final Map<int, FamilyMember> memberMap = { for (var m in members) m.id : m };

      for (var m in members) {
        // Link Spouse
        if (m.spouseId != null && memberMap.containsKey(m.spouseId)) {
          m.spouse = memberMap[m.spouseId];
        }

        // Link Children logic (Inverse of Father/Mother ID)
        if (m.fatherId != null && memberMap.containsKey(m.fatherId)) {
           memberMap[m.fatherId]!.children.add(m);
        } else if (m.motherId != null && memberMap.containsKey(m.motherId)) {
           // Only add to father to avoid double counting if graph logic uses one parent? 
           // Or add to both? GraphView usually needs edges.
           memberMap[m.motherId]!.children.add(m); 
        }
      }
      
      return members;
    } catch (e) {
      throw 'Lỗi tải gia phả: $e';
    }
  }

  Future<void> addMember(Map<String, dynamic> data) async {
    await _client.from('family_members').insert(data);
  }
}
