import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../main.dart';

class ServiceDetailPage extends StatefulWidget {
  final Map<String, dynamic> service;

  const ServiceDetailPage({super.key, required this.service});

  @override
  State<ServiceDetailPage> createState() => _ServiceDetailPageState();
}

class _ServiceDetailPageState extends State<ServiceDetailPage> {
  bool _isBooking = false;
  bool _hasBooked = false;

  Map<String, dynamic>? _providerProfile;
  bool _loadingProfile = true;

  @override
  void initState() {
    super.initState();
    _checkIfBooked();
    _loadProviderProfile();
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

  Future<void> _loadProviderProfile() async {
    final providerId = widget.service['provider_id'];
    if (providerId == null) {
      setState(() => _loadingProfile = false);
      return;
    }
    try {
      final data = await Supabase.instance.client
          .from('profile')
          .select()
          .eq('id', providerId)
          .maybeSingle();
      if (mounted) {
        setState(() {
          _providerProfile = data;
          _loadingProfile = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingProfile = false);
    }
  }

  String _friendlyError(Object e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('duplicate') || msg.contains('unique'))
      return 'You have already booked this service.';
    if (msg.contains('network') ||
        msg.contains('socket') ||
        msg.contains('connection'))
      return 'No internet connection. Please check your network.';
    if (msg.contains('permission') ||
        msg.contains('rls') ||
        msg.contains('policy'))
      return 'You don\'t have permission to do this.';
    if (msg.contains('not found') || msg.contains('404'))
      return 'This service no longer exists.';
    if (msg.contains('timeout'))
      return 'Request timed out. Please try again.';
    return 'Something went wrong. Please try again.';
  }

  Future<void> _book() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    setState(() => _isBooking = true);
    try {
      await Supabase.instance.client.from('bookings').insert({
        'service_id': widget.service['id'],
        'client_id': user.id,
        'provider_id': widget.service['provider_id'],
      });
      await Supabase.instance.client.from('notifications').insert({
        'user_id': user.id,
        'title': 'Booking Confirmed',
        'body':
            'Your booking for "${widget.service['title'] ?? 'service'}" with ${widget.service['provider'] ?? 'provider'} has been placed.',
        'type': 'booking',
        'is_read': false,
      });
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
              content: Text(_friendlyError(e)),
              backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isBooking = false);
    }
  }

  void _showProviderProfile() {
    final profile = _providerProfile;
    final service = widget.service;
    final avatarUrl = profile?['avatar_url'] ?? '';
    final name = profile?['full_name'] ?? service['provider'] ?? 'Provider';
    final bio = profile?['bio'] ?? '';
    final skills = profile?['skills'] ?? '';
    final phone = profile?['phone'] ?? '';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),

            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border:
                    Border.all(color: AppColors.primary.withOpacity(0.3), width: 2),
                color: AppColors.primaryLight,
              ),
              child: avatarUrl.isNotEmpty
                  ? ClipOval(
                      child: Image.network(
                        avatarUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                            Icons.person_rounded,
                            color: AppColors.primary,
                            size: 40),
                      ),
                    )
                  : const Icon(Icons.person_rounded,
                      color: AppColors.primary, size: 40),
            ),
            const SizedBox(height: 12),

            Text(
              name,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),

            Text(
              service['title'] ?? '',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                const SizedBox(width: 4),
                Text(
                  '${service['rating'] ?? '5.0'} rating · ${service['reviews'] ?? 0} reviews',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(color: AppColors.border),
            const SizedBox(height: 16),

            if (bio.isNotEmpty) ...[
              _sheetRow(Icons.info_outline_rounded, 'About', bio),
              const SizedBox(height: 14),
            ],

            if (skills.isNotEmpty) ...[
              _sheetRow(Icons.psychology_rounded, 'Skills', skills),
              const SizedBox(height: 14),
            ],

            if (phone.isNotEmpty) ...[
              _sheetRow(Icons.phone_outlined, 'Phone', phone),
              const SizedBox(height: 14),
            ],

            if (bio.isEmpty && skills.isEmpty && phone.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'This provider hasn\'t filled in their full profile yet.',
                  style:
                      TextStyle(color: AppColors.textHint, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ),

            const SizedBox(height: 8),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sheetRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textHint)),
              const SizedBox(height: 2),
              Text(value,
                  style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                      height: 1.4)),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = widget.service;
    const color = AppColors.primary;
    final isAvailable = service['is_available'] == true;

    final avatarUrl = _providerProfile?['avatar_url'] ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 220,
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
                          GestureDetector(
                            onTap: _showProviderProfile,
                            child: Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withOpacity(0.2),
                                border: Border.all(
                                    color: Colors.white54, width: 2),
                              ),
                              child: _loadingProfile
                                  ? const Padding(
                                      padding: EdgeInsets.all(14),
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white),
                                    )
                                  : avatarUrl.isNotEmpty
                                      ? ClipOval(
                                          child: Image.network(
                                            avatarUrl,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) =>
                                                const Icon(
                                                    Icons.person_rounded,
                                                    color: Colors.white,
                                                    size: 28),
                                          ),
                                        )
                                      : const Icon(Icons.person_rounded,
                                          color: Colors.white, size: 28),
                            ),
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
                                const SizedBox(height: 4),
                                GestureDetector(
                                  onTap: _showProviderProfile,
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.person_search_rounded,
                                          size: 13, color: Colors.white70),
                                      SizedBox(width: 4),
                                      Text(
                                        'View Profile',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.white70,
                                          decoration: TextDecoration.underline,
                                          decorationColor: Colors.white70,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
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

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: _showProviderProfile,
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.primaryLight,
                              border: Border.all(
                                  color: AppColors.primary.withOpacity(0.2)),
                            ),
                            child: _loadingProfile
                                ? const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.primary),
                                  )
                                : avatarUrl.isNotEmpty
                                    ? ClipOval(
                                        child: Image.network(
                                          avatarUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              const Icon(Icons.person_rounded,
                                                  color: AppColors.primary,
                                                  size: 24),
                                        ),
                                      )
                                    : const Icon(Icons.person_rounded,
                                        color: AppColors.primary, size: 24),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  service['provider'] ?? 'Provider',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const Text(
                                  'Tap to view full profile',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textHint,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded,
                              color: AppColors.textHint, size: 20),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

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
                                    fontSize: 11, color: AppColors.textHint),
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
                                    fontSize: 11, color: AppColors.textHint),
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
                      child: Text(
                        service['description'].toString(),
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                          height: 1.65,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  if ((service['experience'] ?? '').toString().isNotEmpty) ...[
                    const Text('Experience', style: AppTextStyles.titleLarge),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        service['experience'].toString(),
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                          height: 1.65,
                        ),
                      ),
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

                  _hasBooked
                      ? Container(
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
                        )
                      : GradientButton(
                          label: 'Book this Service',
                          onPressed: isAvailable ? _book : () {},
                          isLoading: _isBooking,
                        ),

                  if (!isAvailable && !_hasBooked) ...[
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