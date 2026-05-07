import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../../main.dart';

// ─────────────────────────────────────────────
// Chat Page — real-time conversation
// ─────────────────────────────────────────────

class ChatPage extends StatefulWidget {
  final String conversationId;
  final String otherUserId;
  final String otherName;
  final String otherAvatar;
  final String contextTitle;
  final String contextType;

  const ChatPage({
    super.key,
    required this.conversationId,
    required this.otherUserId,
    required this.otherName,
    required this.otherAvatar,
    required this.contextTitle,
    required this.contextType,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _supabase   = Supabase.instance.client;
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  List<Map<String, dynamic>> _messages = [];
  bool _isLoading  = true;
  bool _isSending  = false;
  RealtimeChannel? _channel;

  String get _myId => _supabase.auth.currentUser?.id ?? '';

  @override
  void initState() {
    super.initState();
    _fetchMessages();
    _subscribeToMessages();
    _markAllRead();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ── Data ──────────────────────────────────────────────────────────────────

  Future<void> _fetchMessages() async {
    try {
      final data = await _supabase
          .from('messages')
          .select()
          .eq('conversation_id', widget.conversationId)
          .order('created_at', ascending: true);
      if (mounted) {
        setState(() {
          _messages = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _subscribeToMessages() {
    _channel = _supabase
        .channel('chat:${widget.conversationId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: widget.conversationId,
          ),
          callback: (payload) {
            final newMsg = payload.newRecord;
            if (mounted) {
              setState(() => _messages.add(newMsg));
              _scrollToBottom();
              // Mark incoming messages as read immediately
              if (newMsg['sender_id'] != _myId) {
                _markMessageRead(newMsg['id']);
              }
            }
          },
        )
        .subscribe();
  }

  Future<void> _markAllRead() async {
    try {
      await _supabase
          .from('messages')
          .update({'is_read': true})
          .eq('conversation_id', widget.conversationId)
          .neq('sender_id', _myId)
          .eq('is_read', false);
    } catch (_) {}
  }

  Future<void> _markMessageRead(String messageId) async {
    try {
      await _supabase
          .from('messages')
          .update({'is_read': true})
          .eq('id', messageId);
    } catch (_) {}
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 100,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Sending ───────────────────────────────────────────────────────────────

  Future<void> _sendText() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    await _sendMessage(text: text);
  }

  Future<void> _sendMessage({
    String? text,
    String? imageUrl,
    String? fileUrl,
    String? fileName,
    int? fileSize,
  }) async {
    if (_isSending) return;
    setState(() => _isSending = true);
    try {
      await _supabase.from('messages').insert({
        'conversation_id': widget.conversationId,
        'sender_id':        _myId,
        if (text != null)      'text':      text,
        if (imageUrl != null)  'image_url': imageUrl,
        if (fileUrl != null)   'file_url':  fileUrl,
        if (fileName != null)  'file_name': fileName,
        if (fileSize != null)  'file_size': fileSize,
        'is_read': false,
      });
      // Update conversation preview
      await _supabase.from('conversations').update({
        'last_message':    text ?? (imageUrl != null ? '📷 Image' : '📎 $fileName'),
        'last_message_at': DateTime.now().toIso8601String(),
      }).eq('id', widget.conversationId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to send: $e'),
          backgroundColor: AppColors.error,
        ));
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
      maxWidth: 1200,
    );
    if (picked == null) return;

    setState(() => _isSending = true);
    try {
      final file     = File(picked.path);
      final bytes    = await file.readAsBytes();
      final ext      = picked.path.split('.').last;
      final fileName = '${widget.conversationId}/${DateTime.now().millisecondsSinceEpoch}.$ext';

      await _supabase.storage.from('chat-files').uploadBinary(
        fileName,
        bytes,
        fileOptions: FileOptions(contentType: 'image/$ext', upsert: false),
      );

      final url = _supabase.storage.from('chat-files').getPublicUrl(fileName);
      await _sendMessage(imageUrl: url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Image upload failed: $e'),
          backgroundColor: AppColors.error,
        ));
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final picked = result.files.first;
    if (picked.bytes == null) return;

    setState(() => _isSending = true);
    try {
      final storageName =
          '${widget.conversationId}/${DateTime.now().millisecondsSinceEpoch}_${picked.name}';

      await _supabase.storage.from('chat-files').uploadBinary(
        storageName,
        picked.bytes!,
        fileOptions: FileOptions(upsert: false),
      );

      final url = _supabase.storage.from('chat-files').getPublicUrl(storageName);
      await _sendMessage(
        fileUrl:  url,
        fileName: picked.name,
        fileSize: picked.size,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('File upload failed: $e'),
          backgroundColor: AppColors.error,
        ));
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Send Attachment',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _AttachOption(
                  icon: Icons.image_rounded,
                  label: 'Image',
                  color: AppColors.primary,
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage();
                  },
                ),
                _AttachOption(
                  icon: Icons.insert_drive_file_rounded,
                  label: 'File',
                  color: const Color(0xFF06B6D4),
                  onTap: () {
                    Navigator.pop(context);
                    _pickFile();
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ── UI ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // Context banner
          if (widget.contextTitle.isNotEmpty) _buildContextBanner(),

          // Messages
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary))
                : _messages.isEmpty
                    ? _buildEmptyChat()
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg    = _messages[index];
                          final isMe   = msg['sender_id'] == _myId;
                          final showDate = index == 0 ||
                              !_sameDay(_messages[index - 1]['created_at'],
                                  msg['created_at']);
                          return Column(
                            children: [
                              if (showDate)
                                _DateDivider(timestamp: msg['created_at']),
                              _MessageBubble(message: msg, isMe: isMe),
                            ],
                          );
                        },
                      ),
          ),

          // Input bar
          _buildInputBar(),
        ],
      ),
    );
  }

  bool _sameDay(String? a, String? b) {
    if (a == null || b == null) return false;
    final da = DateTime.tryParse(a);
    final db = DateTime.tryParse(b);
    if (da == null || db == null) return false;
    return da.year == db.year && da.month == db.month && da.day == db.day;
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.surface,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded,
            size: 18, color: AppColors.textPrimary),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primaryLight,
              border: Border.all(
                  color: AppColors.primary.withOpacity(0.15), width: 1.5),
            ),
            child: widget.otherAvatar.isNotEmpty
                ? ClipOval(
                    child: Image.network(
                      widget.otherAvatar,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                          Icons.person_rounded,
                          color: AppColors.primary,
                          size: 18),
                    ),
                  )
                : const Icon(Icons.person_rounded,
                    color: AppColors.primary, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              widget.otherName,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContextBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppColors.primaryLight,
      child: Row(
        children: [
          Icon(
            widget.contextType == 'job'
                ? Icons.work_outline_rounded
                : Icons.handyman_rounded,
            size: 13,
            color: AppColors.primary,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              widget.contextTitle,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyChat() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72, height: 72,
            decoration: const BoxDecoration(
              color: AppColors.primaryLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.chat_rounded,
                size: 34, color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          Text(
            'Say hello to ${widget.otherName}!',
            style: AppTextStyles.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text(
            'This is the start of your conversation.',
            style: AppTextStyles.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Attachment button
            IconButton(
              icon: const Icon(Icons.attach_file_rounded,
                  color: AppColors.primary, size: 22),
              onPressed: _isSending ? null : _showAttachmentOptions,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
            const SizedBox(width: 4),

            // Text field
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.border),
                ),
                child: TextField(
                  controller: _controller,
                  minLines: 1,
                  maxLines: 5,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Type a message...',
                    hintStyle:
                        TextStyle(color: AppColors.textHint, fontSize: 14),
                    border: InputBorder.none,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  textInputAction: TextInputAction.newline,
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Send button
            GestureDetector(
              onTap: _isSending ? null : _sendText,
              child: Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.gradientStart, AppColors.gradientEnd],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: _isSending
                    ? const Padding(
                        padding: EdgeInsets.all(10),
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.send_rounded,
                        color: Colors.white, size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Message Bubble
// ─────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final Map<String, dynamic> message;
  final bool isMe;

  const _MessageBubble({required this.message, required this.isMe});

  String _formatTime(String? ts) {
    if (ts == null) return '';
    final dt = DateTime.tryParse(ts)?.toLocal();
    if (dt == null) return '';
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _formatFileSize(int? bytes) {
    if (bytes == null) return '';
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  @override
  Widget build(BuildContext context) {
    final text      = message['text'] as String?;
    final imageUrl  = message['image_url'] as String?;
    final fileUrl   = message['file_url'] as String?;
    final fileName  = message['file_name'] as String?;
    final fileSize  = message['file_size'] as int?;
    final isRead    = message['is_read'] == true;
    final time      = _formatTime(message['created_at']);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) const SizedBox(width: 4),

          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.72,
            ),
            child: Container(
              padding: imageUrl != null
                  ? const EdgeInsets.all(4)
                  : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? AppColors.primary : AppColors.surface,
                borderRadius: BorderRadius.only(
                  topLeft:     const Radius.circular(18),
                  topRight:    const Radius.circular(18),
                  bottomLeft:  Radius.circular(isMe ? 18 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment:
                    isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  // Image
                  if (imageUrl != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        loadingBuilder: (_, child, progress) =>
                            progress == null
                                ? child
                                : SizedBox(
                                    height: 120,
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        value: progress.expectedTotalBytes != null
                                            ? progress.cumulativeBytesLoaded /
                                                progress.expectedTotalBytes!
                                            : null,
                                        color: AppColors.primary,
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  ),
                        errorBuilder: (_, __, ___) => Container(
                          height: 80,
                          color: AppColors.background,
                          child: const Icon(Icons.broken_image_rounded,
                              color: AppColors.textHint),
                        ),
                      ),
                    ),

                  // File attachment
                  if (fileUrl != null && imageUrl == null)
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isMe
                            ? Colors.white.withOpacity(0.15)
                            : AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.insert_drive_file_rounded,
                            color: isMe ? Colors.white : AppColors.primary,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  fileName ?? 'File',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: isMe
                                        ? Colors.white
                                        : AppColors.textPrimary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (fileSize != null)
                                  Text(
                                    _formatFileSize(fileSize),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isMe
                                          ? Colors.white70
                                          : AppColors.textHint,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Text
                  if (text != null && text.isNotEmpty)
                    Padding(
                      padding: imageUrl != null
                          ? const EdgeInsets.fromLTRB(10, 6, 10, 2)
                          : EdgeInsets.zero,
                      child: Text(
                        text,
                        style: TextStyle(
                          fontSize: 14,
                          color:
                              isMe ? Colors.white : AppColors.textPrimary,
                          height: 1.4,
                        ),
                      ),
                    ),

                  const SizedBox(height: 4),

                  // Time + read receipt
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        time,
                        style: TextStyle(
                          fontSize: 10,
                          color: isMe ? Colors.white60 : AppColors.textHint,
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        Icon(
                          isRead
                              ? Icons.done_all_rounded
                              : Icons.done_rounded,
                          size: 12,
                          color: isRead
                              ? Colors.lightBlueAccent
                              : Colors.white54,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),

          if (isMe) const SizedBox(width: 4),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Date Divider
// ─────────────────────────────────────────────

class _DateDivider extends StatelessWidget {
  final String? timestamp;
  const _DateDivider({this.timestamp});

  String _label() {
    if (timestamp == null) return '';
    final dt = DateTime.tryParse(timestamp!)?.toLocal();
    if (dt == null) return '';
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDay = DateTime(dt.year, dt.month, dt.day);
    final diff  = today.difference(msgDay).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          const Expanded(child: Divider(color: AppColors.border)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              _label(),
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textHint,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const Expanded(child: Divider(color: AppColors.border)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Attachment option button
// ─────────────────────────────────────────────

class _AttachOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _AttachOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 60, height: 60,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}