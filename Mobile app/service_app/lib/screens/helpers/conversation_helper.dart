import 'package:supabase_flutter/supabase_flutter.dart';

class ConversationHelper {
  static Future<String?> getOrCreate({
    required String contextType,
    required String contextId,
    required String contextTitle,
    required String otherUserId,
  }) async {
    final supabase = Supabase.instance.client;
    final myId = supabase.auth.currentUser?.id;
    if (myId == null) return null;

    try {
      // Try to find existing conversation between these two users for this context
      final existing = await supabase
          .from('conversations')
          .select('id')
          .or('and(participant_1.eq.$myId,participant_2.eq.$otherUserId),and(participant_1.eq.$otherUserId,participant_2.eq.$myId)')
          .eq('context_type', contextType)
          .eq('context_id', contextId)
          .maybeSingle();

      if (existing != null) return existing['id'] as String;

      // Create new conversation
      final created = await supabase.from('conversations').insert({
        'participant_1': myId,
        'participant_2': otherUserId,
        'context_type': contextType,
        'context_id': contextId,
        'context_title': contextTitle,
      }).select('id').single();

      return created['id'] as String;
    } catch (_) {
      return null;
    }
  }
}