import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../main.dart';
import 'chat_page.dart';
import '../helpers/conversation_helper.dart';

class ServiceDetailPage extends StatefulWidget {
  final Map<String, dynamic> service;

  const ServiceDetailPage({super.key, required this.service});

  @override
  State<ServiceDetailPage> createState() => _ServiceDetailPageState();
}

class _ServiceDetailPageState extends State<ServiceDetailPage> {
  bool _isBooking  = false;
  bool _hasBooked  = false;
  bool _isChatting = false;

  @override
  void initState() {
    super.initState();
    _checkIfBooked();
  }

  Future<void> _checkIfBooked() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      final result = await Supabase.instance.client
          .from('bookings')
          .select('id')
          .eq('service_id', widget.service['id'])
          .eq('client_id', user.id);
      if (mounted) {
        setState(() => _hasBooked = (result as List).isNotEmpty);
      }
    } catch (_) {}
  }

  Future<void> _book() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    setState(() => _isBooking = true);
    try {
      await Supabase.instance.client.from('bookings').insert({
        'service_id':  widget.service['id'],
        'client_id':   user.id,
        'provider_id': widget.service['provider_id'],
      });

      // Notify provider
      if (widget.service['provider_id'] != null) {
        await Supabase.instance.client.from('notifications').insert({
          'user_id': widget.service['provider_id'],
          'title':   'New Booking!',
          'body':    'Someone booked your service: ${widget.service['title'] ?? ''}',
          'type':    'booking',
        });
      }

      if (mounted) {
        setState(() => _hasBooked = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 Booking confirmed!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'),
              backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isBooking = false);
    }
  }

  Future<void> _openChat() async {
    final providerId = widget.service['provider_id'] as String?;
    if (providerId == null) return;

    setState(() => _isChatting = true);
    try {
      final convoId = await ConversationHelper.getOrCreate(
        contextType:  'service',
        contextId:    widget.service['id'],
        contextTitle: widget.service['title'] ?? 'Service',
        otherUserId:  providerId,
      );
      if (convoId == null || !mounted) return;

      // Fetch provider profile for name + avatar
      String providerName   = widget.service['provider'] ?? 'Provider';
      String providerAvatar = '';
      try {
        final profile = await Supabase.instance.client
            .from('profile')
            .select('full_name, avatar_url')
            .eq('id', providerId)
            .maybeSingle();
        providerName   = profile?['full_name']  ?? providerName;
        providerAvatar = profile?['avatar_url'] ?? '';
      } catch (_) {}

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatPage(
            conversationId: convoId,
            otherUserId:    providerId,
            otherName:      providerName,
            otherAvatar:    providerAvatar,
            contextTitle:   widget.service['title'] ?? 'Service',
            contextType:    'service',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isChatting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = widget.service;
    const color   = AppColors.primary;

    // ✅ Fixed: was service['isAvailable'] (camelCase) → 'is_available'
    final isAvailable = service['is_available'] == true;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // ── App Bar ──────────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: color,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded,
                    size: 16, color: Colors.white),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.gradientStart, AppColors.gradientEnd],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 80, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.person_rounded,
                                color: Colors.white, size: 26),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  service['provider'] ?? 'Provider',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  service['title'] ?? '',
                                  style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.white70,
                                      fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ),
                          // Availability badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: isAvailable
                                  ? Colors.white.withOpacity(0.2)
                                  : Colors.black.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: BoxDecoration(
                                    color: isAvailable
                                        ? AppColors.success
                                        : AppColors.textHint,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  isAvailable ? 'Available' : 'Unavailable',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Content ───────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Price + Rating row
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: AppColors.primary.withOpacity(0.2)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Price',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textHint,
                                      fontWeight: FontWeight.w500)),
                              const SizedBox(height: 4),
                              Text(
                                service['price'] ?? '₦0',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primary,
                                ),
                              ),
                              Text(
                                service['per'] ?? '',
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textHint),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Rating',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textHint,
                                      fontWeight: FontWeight.w500)),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.star_rounded,
                                      color: Colors.amber, size: 20),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${service['rating'] ?? '5.0'}',
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                '${service['reviews'] ?? 0} reviews',
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textHint),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  if ((service['description'] ?? '').toString().isNotEmpty) ...[
                    const Text('About this Service',
                        style: AppTextStyles.titleLarge),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(service['description'].toString(),
                          style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                              height: 1.65)),
                    ),
                    const SizedBox(height: 24),
                  ],

                  if ((service['experience'] ?? '').toString().isNotEmpty) ...[
                    const Text('Experience',
                        style: AppTextStyles.titleLarge),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(service['experience'].toString(),
                          style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                              height: 1.65)),
                    ),
                    const SizedBox(height: 24),
                  ],

                  if ((service['description'] ?? '').toString().isEmpty &&
                      (service['experience'] ?? '').toString().isEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Column(
                        children: [
                          Icon(Icons.info_outline_rounded,
                              size: 40, color: AppColors.textHint),
                          SizedBox(height: 10),
                          Text('No details provided',
                              style: TextStyle(
                                  color: AppColors.textHint,
                                  fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // ── Action buttons ────────────────────────────────────────
                  if (_hasBooked) ...[
                    // Already booked — show confirmed + chat
                    Container(
                      width: double.infinity,
                      height: 52,
                      decoration: BoxDecoration(
                        color: AppColors.success.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: AppColors.success.withOpacity(0.4)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_rounded,
                              color: AppColors.success, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Booking Confirmed',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.success,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton.icon(
                        icon: _isChatting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.primary))
                            : const Icon(Icons.chat_rounded, size: 18),
                        label: const Text('Message Provider'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(
                              color: AppColors.primary, width: 1.5),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          textStyle: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                        onPressed: _isChatting ? null : _openChat,
                      ),
                    ),
                  ] else ...[
                    GradientButton(
                      label: isAvailable
                          ? 'Book this Service'
                          : 'Currently Unavailable',
                      onPressed: isAvailable ? _book : () {},
                      isLoading: _isBooking,
                    ),
                    if (!isAvailable) ...[
                      const SizedBox(height: 8),
                      const Center(
                        child: Text(
                          'This provider is currently unavailable',
                          style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textHint,
                              fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ],

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}