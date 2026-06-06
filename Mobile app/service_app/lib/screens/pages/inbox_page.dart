import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../main.dart';
import 'chat_page.dart';

// ─────────────────────────────────────────────
// Inbox Page — lists all conversations
// ─────────────────────────────────────────────

class InboxPage extends StatefulWidget {
  const InboxPage({super.key});

  @override
  State<InboxPage> createState() => _InboxPageState();
}

class _InboxPageState extends State<InboxPage> {
  final _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _conversations = [];
  bool _isLoading = true;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _fetchConversations();
    _subscribeToUpdates();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  Future<void> _fetchConversations() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    try {
      // Fetch all conversations this user is part of
      final data = await _supabase
          .from('conversations')
          .select()
          .or('participant_1.eq.${user.id},participant_2.eq.${user.id}')
          .order('last_message_at', ascending: false);

      // For each conversation, fetch the other participant's profile
      final convs = List<Map<String, dynamic>>.from(data);
      final enriched = await Future.wait(convs.map((c) async {
        final otherId = c['participant_1'] == user.id
            ? c['participant_2']
            : c['participant_1'];
        try {
          final profile = await _supabase
              .from('profile')
              .select('full_name, avatar_url')
              .eq('id', otherId)
              .maybeSingle();
          // Count unread messages in this conversation
          final unread = await _supabase
              .from('messages')
              .select('id')
              .eq('conversation_id', c['id'])
              .eq('is_read', false)
              .neq('sender_id', user.id);
          return {
            ...c,
            'other_id': otherId,
            'other_name': profile?['full_name'] ?? 'User',
            'other_avatar': profile?['avatar_url'] ?? '',
            'unread_count': (unread as List).length,
          };
        } catch (_) {
          return {
            ...c,
            'other_id': otherId,
            'other_name': 'User',
            'other_avatar': '',
            'unread_count': 0,
          };
        }
      }));

      if (mounted) {
        setState(() {
          _conversations = enriched;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _subscribeToUpdates() {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    _channel = _supabase
        .channel('inbox:${user.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'conversations',
          callback: (_) => _fetchConversations(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          callback: (_) => _fetchConversations(),
        )
        .subscribe();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // ── Header ────────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(20, 52, 20, 20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.gradientStart, AppColors.gradientEnd],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Messages',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.3,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Your conversations',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white70,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Conversation list ──────────────────────────────────────────────
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary))
                : _conversations.isEmpty
                    ? _buildEmpty()
                    : RefreshIndicator(
                        color: AppColors.primary,
                        onRefresh: _fetchConversations,
                        child: ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: _conversations.length,
                          separatorBuilder: (_, __) => const Divider(
                              height: 1, indent: 80, color: AppColors.border),
                          itemBuilder: (context, index) {
                            final c = _conversations[index];
                            return _ConversationTile(
                              conversation: c,
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ChatPage(
                                      conversationId: c['id'],
                                      otherUserId: c['other_id'],
                                      otherName: c['other_name'],
                                      otherAvatar: c['other_avatar'],
                                      contextTitle: c['context_title'] ?? '',
                                      contextType: c['context_type'] ?? '',
                                    ),
                                  ),
                                );
                                // Refresh unread counts on return
                                _fetchConversations();
                              },
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(
              color: AppColors.primaryLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.chat_bubble_outline_rounded,
                size: 38, color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          const Text('No messages yet', style: AppTextStyles.titleLarge),
          const SizedBox(height: 8),
          const Text(
            'Apply for a job or book a service\nto start a conversation.',
            style: AppTextStyles.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Conversation tile
// ─────────────────────────────────────────────

class _ConversationTile extends StatelessWidget {
  final Map<String, dynamic> conversation;
  final VoidCallback onTap;

  const _ConversationTile({required this.conversation, required this.onTap});

  String _timeAgo(String? ts) {
    if (ts == null) return '';
    final dt = DateTime.tryParse(ts);
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Now';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inDays < 1) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${dt.day}/${dt.month}';
  }

  @override
  Widget build(BuildContext context) {
    final unread = (conversation['unread_count'] ?? 0) as int;
    final avatarUrl = conversation['other_avatar'] ?? '';
    final name = conversation['other_name'] ?? 'User';
    final lastMsg = conversation['last_message'] ?? 'No messages yet';
    final contextType = conversation['context_type'] ?? '';
    final contextTitle = conversation['context_title'] ?? '';

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Avatar
            Stack(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primaryLight,
                    border: Border.all(
                        color: AppColors.primary.withOpacity(0.15), width: 2),
                  ),
                  child: avatarUrl.isNotEmpty
                      ? ClipOval(
                          child: Image.network(
                            avatarUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                                Icons.person_rounded,
                                color: AppColors.primary,
                                size: 26),
                          ),
                        )
                      : const Icon(Icons.person_rounded,
                          color: AppColors.primary, size: 26),
                ),
                if (unread > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: const BoxDecoration(
                        color: AppColors.error,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          unread > 9 ? '9+' : '$unread',
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(width: 12),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: unread > 0
                                ? FontWeight.w700
                                : FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      Text(
                        _timeAgo(conversation['last_message_at']),
                        style: TextStyle(
                          fontSize: 11,
                          color: unread > 0
                              ? AppColors.primary
                              : AppColors.textHint,
                          fontWeight: unread > 0
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  // Context badge
                  if (contextTitle.isNotEmpty) ...[
                    Row(
                      children: [
                        Icon(
                          contextType == 'job'
                              ? Icons.work_outline_rounded
                              : Icons.handyman_rounded,
                          size: 11,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            contextTitle,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                  ],
                  Text(
                    lastMsg,
                    style: TextStyle(
                      fontSize: 13,
                      color: unread > 0
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                      fontWeight: unread > 0
                          ? FontWeight.w500
                          : FontWeight.w400,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}