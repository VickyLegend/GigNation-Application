import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../main.dart';
import '../home.dart'; // for HomeScope logout
import 'edit_profile_page.dart';
import 'my_posts_page.dart';
import 'notifications_page.dart';
import 'payment_methods_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _supabase = Supabase.instance.client;

  String _name = '';
  String _email = '';
  String _avatarUrl = '';
  int _jobsApplied = 0;
  int _servicesBooked = 0;
  int _reviews = 0;
  bool _isLoading = true;

  // ── Replace with your real URLs before going live ───────
  static const _helpCenterUrl = 'https://wa.me/2347046971369';
  static const _privacyUrl    = 'https://www.termsfeed.com/live/c269c48e-e5d1-4a67-929f-1b7900541d9f';
  static const _playStoreUrl  =
      'https://play.google.com/store/apps/details?id=com.yourapp';
  static const _appStoreUrl   =
      'https://apps.apple.com/app/idYOUR_APP_ID';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      _email = user.email ?? '';

      final profile = await _supabase
          .from('profile')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (profile != null) {
        _name      = profile['full_name'] ??
            user.userMetadata?['full_name'] ?? 'User';
        _avatarUrl = profile['avatar_url'] ?? '';
      } else {
        _name = user.userMetadata?['full_name'] ?? 'User';
      }

      final results = await Future.wait([
        _supabase.from('applications').select('id').eq('user_id', user.id),
        _supabase.from('bookings').select('id').eq('client_id', user.id),
        _supabase
            .from('bookings')
            .select('id')
            .eq('provider_id', user.id)
            .eq('status', 'completed'),
      ]);

      _jobsApplied    = (results[0] as List).length;
      _servicesBooked = (results[1] as List).length;
      _reviews        = (results[2] as List).length;
    } catch (_) {
      final user = _supabase.auth.currentUser;
      _name  = user?.userMetadata?['full_name'] ?? 'User';
      _email = user?.email ?? '';
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── URL helpers ──────────────────────────────────────────

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (!await canLaunchUrl(uri)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open link'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openHelpCenter()    => _launch(_helpCenterUrl);
  Future<void> _openPrivacyPolicy() => _launch(_privacyUrl);
  Future<void> _openRateApp() {
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;
    return _launch(isIOS ? _appStoreUrl : _playStoreUrl);
  }

  // ── Build ────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primary));
    }

    // Pull logout from the parent HomePage scope
    final onLogout = HomeScope.of(context)?.onLogout;

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        // ── Gradient Header with SafeArea top padding ──
        Container(
          padding: EdgeInsets.fromLTRB(
            20,
            MediaQuery.of(context).padding.top + 20, // status bar + gap
            20,
            28,
          ),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.gradientStart, AppColors.gradientEnd],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white54, width: 2),
                ),
                child: _avatarUrl.isNotEmpty
                    ? ClipOval(
                  child: Image.network(
                    _avatarUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(
                        Icons.person_rounded,
                        color: Colors.white,
                        size: 38),
                  ),
                )
                    : const Icon(Icons.person_rounded,
                    color: Colors.white, size: 38),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _name.isNotEmpty ? _name : 'User',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _email,
                      style: const TextStyle(
                          fontSize: 13, color: Colors.white70),
                    ),
                    const SizedBox(height: 6),
                    const _RatingBadge(),
                  ],
                ),
              ),
            ],
          ),
        ),

        // ── Stats Row ──
        Container(
          margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              _StatItem(label: 'Jobs Applied',    value: '$_jobsApplied'),
              _divider(),
              _StatItem(label: 'Services Booked', value: '$_servicesBooked'),
              _divider(),
              _StatItem(label: 'Reviews',         value: '$_reviews'),
            ],
          ),
        ),

        const SizedBox(height: 24),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Account ──
              const Text('Account', style: AppTextStyles.label),
              const SizedBox(height: 10),
              _ProfileGroup(items: [
                _ProfileTile(
                  icon: Icons.person_outline_rounded,
                  label: 'Edit Profile',
                  onTap: () async {
                    final updated = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const EditProfilePage()),
                    );
                    if (updated == true) {
                      setState(() => _isLoading = true);
                      _loadProfile();
                    }
                  },
                ),
                _ProfileTile(
                  icon: Icons.post_add_rounded,
                  label: 'My Posts',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const MyPostsPage()),
                  ),
                ),
                _ProfileTile(
                  icon: Icons.notifications_outlined,
                  label: 'Notifications',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const NotificationsPage()),
                  ),
                ),
                _ProfileTile(
                  icon: Icons.credit_card_rounded,
                  label: 'Payment Methods',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const PaymentMethodsPage()),
                  ),
                ),
              ]),

              const SizedBox(height: 24),

              // ── Support ──
              const Text('Support', style: AppTextStyles.label),
              const SizedBox(height: 10),
              _ProfileGroup(items: [
                _ProfileTile(
                  icon: Icons.help_outline_rounded,
                  label: 'Help Center',
                  onTap: _openHelpCenter,
                ),
                _ProfileTile(
                  icon: Icons.privacy_tip_outlined,
                  label: 'Privacy Policy',
                  onTap: _openPrivacyPolicy,
                ),
                _ProfileTile(
                  icon: Icons.star_outline_rounded,
                  label: 'Rate the App',
                  onTap: _openRateApp,
                ),
              ]),

              const SizedBox(height: 24),

              // ── Sign Out ──
              GestureDetector(
                onTap: onLogout,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: AppColors.error.withOpacity(0.25)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.logout_rounded,
                          color: AppColors.error, size: 20),
                      SizedBox(width: 10),
                      Text(
                        'Sign Out',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.error,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 36),
            ],
          ),
        ),
      ],
    );
  }

  Widget _divider() =>
      Container(width: 1, height: 36, color: AppColors.border);
}

// ─────────────────────────────────────────────
// Supporting Widgets
// ─────────────────────────────────────────────

class _StatItem extends StatelessWidget {
  final String label;
  final String value;

  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary)),
          const SizedBox(height: 4),
          Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textHint,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _RatingBadge extends StatelessWidget {
  const _RatingBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded, color: Colors.amber, size: 13),
          SizedBox(width: 4),
          Text('4.7 Rating',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _ProfileGroup extends StatelessWidget {
  final List<_ProfileTile> items;

  const _ProfileGroup({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: List.generate(items.length, (index) {
          final isLast = index == items.length - 1;
          return Column(
            children: [
              items[index],
              if (!isLast)
                const Divider(
                    height: 1, indent: 52, color: AppColors.border),
            ],
          );
        }),
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ProfileTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppColors.primary, size: 18),
      ),
      title: Text(label,
          style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary)),
      trailing: const Icon(Icons.chevron_right_rounded,
          color: AppColors.textHint, size: 20),
    );
  }
}