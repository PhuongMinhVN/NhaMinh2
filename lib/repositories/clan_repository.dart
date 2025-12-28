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

  Future<Clan?> getClanByQrCode(String code) async {
    final response = await _client.from('clans').select().eq('qr_code', code).maybeSingle();
    if (response == null) return null;
    return Clan.fromJson(response);
  }

  Future<List<Map<String, dynamic>>> fetchPendingRequests(String clanId) async {
    final response = await _client.from('clan_join_requests')
      .select('*, requester:requester_id (email, raw_user_meta_data)')
      .eq('target_clan_id', clanId)
      .eq('status', 'pending');
    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> approveRequest(String requestId) async {
    await _client.from('clan_join_requests').update({'status': 'approved'}).eq('id', requestId);
  }

  Future<void> rejectRequest(String requestId) async {
    await _client.from('clan_join_requests').update({'status': 'rejected'}).eq('id', requestId);
  }
}
