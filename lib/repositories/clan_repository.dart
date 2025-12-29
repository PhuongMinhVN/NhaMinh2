import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/clan.dart';
import '../models/family_member.dart';

class ClanRepository {
  final SupabaseClient _client = Supabase.instance.client;

  /// Fetch the Clan owned by current user (if any)
  Future<Clan?> fetchMyClan() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    final response = await _client.from('clans').select().eq('owner_id', user.id).maybeSingle();
    if (response == null) return null;
    return Clan.fromJson(response);
  }

  /// Create a new Clan and adding the Root Member
  Future<void> createClanWithRoot({
    required String clanName,
    required String description,
    required String rootName,
    required String? rootBio,
    required bool isMaleLineage,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw 'User not logged in';

    // 1. Create Clan
    final clanRes = await _client.from('clans').insert({
      'name': clanName,
      'description': description,
      'owner_id': user.id,
    }).select().single();
    
    final newClanId = clanRes['id'];

    // 2. Create Root Member
    await _client.from('family_members').insert({
      'full_name': rootName,
      'bio': rootBio,
      'is_root': true,
      'clan_id': newClanId,
      'is_male_lineage': isMaleLineage,
      'generation_level': 1,
    });
  }

  /// Get Clan by ID (for joining)
  Future<Clan?> getClanById(String id) async {
    final response = await _client.from('clans').select().eq('id', id).maybeSingle();
    if (response == null) return null;
    return Clan.fromJson(response);
  }

  /// Request to join a Clan
  Future<void> requestJoinClan(String targetClanId) async {
    final user = _client.auth.currentUser;
    if (user == null) throw 'User not logged in';

    // Check if request already exists
    final existing = await _client.from('clan_join_requests')
      .select()
      .eq('requester_id', user.id)
      .eq('target_clan_id', targetClanId)
      .eq('status', 'pending')
      .maybeSingle();
      
    if (existing != null) throw 'Bạn đã gửi yêu cầu gia nhập dòng họ này rồi.';

    await _client.from('clan_join_requests').insert({
      'requester_id': user.id,
      'target_clan_id': targetClanId,
      'status': 'pending',
    });
  }

  Future<void> sendDetailedJoinRequest({
    required String targetClanId,
    required String type, // 'claim_existing' | 'create_new'
    required Map<String, dynamic> metadata,
    int? targetParentId,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw 'User not logged in';

    // Check duplicate
    final existing = await _client.from('clan_join_requests')
      .select()
      .eq('requester_id', user.id)
      .eq('target_clan_id', targetClanId)
      .eq('status', 'pending')
      .maybeSingle();

    if (existing != null) throw 'Bạn đang có yêu cầu chờ duyệt.';

    await _client.from('clan_join_requests').insert({
      'requester_id': user.id,
      'target_clan_id': targetClanId,
      'status': 'pending',
      'type': type,
      'metadata': metadata,
      'target_parent_id': targetParentId,
    });
  }

  Future<List<Map<String, dynamic>>> searchClanMembers(String clanId, String query) async {
      final res = await _client.from('family_members')
        .select('id, full_name, birth_date, gender, profile_id, is_alive')
        .eq('clan_id', clanId)
        .ilike('full_name', '%$query%')
        .limit(20);
      return List<Map<String, dynamic>>.from(res);
  }

  Future<Clan?> getClanByQrCode(String code) async {
    final response = await _client.from('clans').select().eq('qr_code', code).maybeSingle();
    if (response == null) return null;
    return Clan.fromJson(response);
  }

  Future<List<Map<String, dynamic>>> fetchPendingRequests(String clanId) async {
    // 1. Fetch requests
    final requests = await _client.from('clan_join_requests')
      .select('*')
      .eq('target_clan_id', clanId)
      .eq('status', 'pending');
    
    final List<Map<String, dynamic>> result = [];
    
    // 2. Manual fetch profile info for each request to avoid RLS/FK issues
    for (var r in requests) {
      final reqMap = Map<String, dynamic>.from(r);
      final requesterId = r['requester_id'];
      if (requesterId != null) {
         try {
           final profile = await _client.from('profiles').select('email, full_name').eq('id', requesterId).maybeSingle();
           if (profile != null) {
              reqMap['requester_profile'] = profile;
           }
         } catch (e) {
           // Ignore if profile not found or error
           print('Error fetching profile for $requesterId $e');
         }
      }
      result.add(reqMap);
    }
    
    return result;
  }

  Future<List<Map<String, dynamic>>> fetchAllMyClanRequests() async {
     final user = _client.auth.currentUser;
     if (user == null) return [];

     // 1. Get all clans I am a member of (to check permissions)
     // Ideally, we only fetch for clans where I have 'Owner' or specific roles.
     // But per new policy, any member can view.
     final myMemberships = await _client.from('family_members').select('clan_id').eq('profile_id', user.id);
     
     if (myMemberships.isEmpty) return [];
     
     final clanIds = myMemberships.map((m) => m['clan_id']).toList();
     
     // 2. Fetch requests for these clans
     final requests = await _client.from('clan_join_requests')
       .select('*, clans(name)')
       .filter('target_clan_id', 'in', clanIds)
       .eq('status', 'pending');
       
     final List<Map<String, dynamic>> result = [];

     for (var r in requests) {
       final reqMap = Map<String, dynamic>.from(r);
       
       // Handle Clan Name manually if join failed (though 'clans(name)' usually works if relations set)
       // If relation not found by Postgrest, we might need manual fetch. 
       // Assume relation 'clans' exists on 'target_clan_id' FK.
       
       // Manual fetch profile
       final requesterId = r['requester_id'];
       if (requesterId != null) {
          try {
            final profile = await _client.from('profiles').select('email, full_name').eq('id', requesterId).maybeSingle();
            if (profile != null) reqMap['requester_profile'] = profile;
          } catch (_) {}
       }
       result.add(reqMap);
     }
     
     return result;
  }

  Future<void> approveRequest(String requestId) async {
    // New Logic: Use RPC to handle claims/creates
    await _client.rpc('approve_clan_join_request', params: {'request_id': requestId});
  }

  Future<void> rejectRequest(String requestId) async {
    await _client.from('clan_join_requests').update({'status': 'rejected'}).eq('id', requestId);
  }

  /// Check if user has permission to join a Clan (Must be Owner/Patriarch/Vice-Patriarch of their own genealogy)
  Future<bool> checkUserJoinPermissions(String userId) async {
    try {
      // 1. Check if Creator (Owner of any Clan/Family)
      final ownedClan = await _client.from('clans').select('id').eq('owner_id', userId).maybeSingle();
      if (ownedClan != null) return true;

      // 2. Check User Roles (Titles) in their Family Members records
      // User might be linked to multiple records, check all
      final memberRoles = await _client.from('family_members')
          .select('title')
          .eq('profile_id', userId);
      
      for (final row in memberRoles) {
        final title = row['title'] as String?;
        if (title != null) {
           final t = title.toLowerCase();
           // Check for Tộc trưởng, Tộc phó (and synonyms)
           if (t.contains('tộc trưởng') || t.contains('tộc phó') || 
               t.contains('trưởng họ') || t.contains('phó họ') ||
               t.contains('người tạo')) {
             return true;
           }
        }
      }
      return false;
    } catch (e) {
      print('Error checking permissions: $e');
      return false;
    }
  }
}
