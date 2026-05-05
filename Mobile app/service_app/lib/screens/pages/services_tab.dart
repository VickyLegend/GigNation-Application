import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../main.dart';
import 'service_detail_page.dart';

class ServicesTab extends StatefulWidget {
  const ServicesTab({super.key});

  @override
  State<ServicesTab> createState() => _ServicesTabState();
}

class _ServicesTabState extends State<ServicesTab> {
  final _supabase = Supabase.instance.client;
  final _searchController = TextEditingController();

  List<Map<String, dynamic>> _providers = [];
  List<Map<String, dynamic>> _filteredProviders = [];
  bool _isLoading = true;

  static final List<Map<String, dynamic>> _allServices = [
    {
      'icon': Icons.cleaning_services_rounded,
      'name': 'Cleaning',
      'desc': 'Home & office',
      'color': const Color(0xFF6366F1),
      'providers': '34 providers',
    },
    {
      'icon': Icons.build_rounded,
      'name': 'Repairs',
      'desc': 'Fix anything',
      'color': const Color(0xFFF59E0B),
      'providers': '22 providers',
    },
    {
      'icon': Icons.local_taxi_rounded,
      'name': 'Transport',
      'desc': 'Fast & safe',
      'color': const Color(0xFF10B981),
      'providers': '48 providers',
    },
    {
      'icon': Icons.design_services_rounded,
      'name': 'Design',
      'desc': 'Creative work',
      'color': const Color(0xFFEC4899),
      'providers': '19 providers',
    },
    {
      'icon': Icons.security_rounded,
      'name': 'Security',
      'desc': 'Stay protected',
      'color': const Color(0xFF3B82F6),
      'providers': '11 providers',
    },
    {
      'icon': Icons.plumbing_rounded,
      'name': 'Plumbing',
      'desc': 'Pipe & water',
      'color': const Color(0xFF06B6D4),
      'providers': '27 providers',
    },
    {
      'icon': Icons.restaurant_rounded,
      'name': 'Catering',
      'desc': 'Food & events',
      'color': const Color(0xFF10B981),
      'providers': '15 providers',
    },
    {
      'icon': Icons.chair_rounded,
      'name': 'Interior',
      'desc': 'Space styling',
      'color': const Color(0xFFEC4899),
      'providers': '9 providers',
    },
  ];

  @override
  void initState() {
    super.initState();
    _fetchProviders();
    _searchController.addListener(_filterProviders);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchProviders() async {
    setState(() => _isLoading = true);
    try {
      final data = await _supabase
          .from('services')
          .select()
          .order('created_at', ascending: false);
      setState(() {
        _providers = List<Map<String, dynamic>>.from(data);
        _filteredProviders = _providers;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _filterProviders() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      if (query.isEmpty) {
        _filteredProviders = _providers;
      } else {
        _filteredProviders = _providers.where((p) {
          final provider = (p['provider'] ?? '').toString().toLowerCase();
          final title = (p['title'] ?? '').toString().toLowerCase();
          final category = (p['category'] ?? '').toString().toLowerCase();
          return provider.contains(query) ||
              title.contains(query) ||
              category.contains(query);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _fetchProviders,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          // Search bar
          TextField(
            controller: _searchController,
            style: const TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              hintText: 'Search services, providers...',
              prefixIcon: const Icon(Icons.search_rounded,
                  color: AppColors.textHint, size: 20),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                icon: const Icon(Icons.close_rounded,
                    size: 18, color: AppColors.textHint),
                onPressed: () {
                  _searchController.clear();
                  _filterProviders();
                },
              )
                  : null,
            ),
          ),

          const SizedBox(height: 16),

          // Featured providers section
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.only(bottom: 16, top: 8),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            )
          else if (_searchController.text.isEmpty && _providers.isNotEmpty) ...[
            const Text('Featured Providers', style: AppTextStyles.titleLarge),
            const SizedBox(height: 12),
            ..._providers.map((provider) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: FeaturedProviderCard(
                provider: provider,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        ServiceDetailPage(service: provider),
                  ),
                ),
              ),
            )),
            const SizedBox(height: 8),
          ] else if (_searchController.text.isNotEmpty) ...[
            // Show filtered providers
            Text(
              '${_filteredProviders.length} result${_filteredProviders.length == 1 ? '' : 's'}',
              style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textHint,
                  fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            if (_filteredProviders.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                child: const Column(
                  children: [
                    Icon(Icons.search_off_rounded,
                        size: 48, color: AppColors.textHint),
                    SizedBox(height: 12),
                    Text('No services match your search',
                        style: AppTextStyles.titleLarge,
                        textAlign: TextAlign.center),
                    SizedBox(height: 8),
                    Text('Try different keywords',
                        style: AppTextStyles.bodyMedium),
                  ],
                ),
              )
            else
              ..._filteredProviders.map((provider) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: FeaturedProviderCard(
                  provider: provider,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          ServiceDetailPage(service: provider),
                    ),
                  ),
                ),
              )),
          ],

          // Browse Categories (always visible when not searching)
          if (_searchController.text.isEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Browse Categories',
                    style: AppTextStyles.titleLarge),
                TextButton(
                  onPressed: () {},
                  child: const Text(
                    'See all',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.05,
              ),
              itemCount: _allServices.length,
              itemBuilder: (context, index) =>
                  ServiceCategoryCard(service: _allServices[index]),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Featured Provider Card
// ─────────────────────────────────────────────

class FeaturedProviderCard extends StatelessWidget {
  final Map<String, dynamic> provider;
  final VoidCallback? onTap;

  const FeaturedProviderCard({super.key, required this.provider, this.onTap});

  @override
  Widget build(BuildContext context) {
    const color = AppColors.primary;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
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
            Stack(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person_rounded,
                      color: color, size: 26),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      // ✅ Fixed: DB column is 'is_available' (snake_case)
                      color: provider['is_available'] == true
                          ? AppColors.success
                          : AppColors.textHint,
                      shape: BoxShape.circle,
                      border:
                      Border.all(color: AppColors.surface, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    provider['provider'] ?? 'Unknown',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    provider['title'] ?? '',
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.star_rounded,
                          size: 14, color: Colors.amber),
                      const SizedBox(width: 3),
                      Text(
                        '${provider['rating'] ?? '5.0'} (${provider['reviews'] ?? 0} reviews)',
                        style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  provider['price'] ?? '',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
                Text(
                  provider['per'] ?? '',
                  style: const TextStyle(
                      fontSize: 10, color: AppColors.textHint),
                ),
                const SizedBox(height: 8),
                _QuickBookButton(provider: provider),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Service Category Card
// ─────────────────────────────────────────────

class ServiceCategoryCard extends StatelessWidget {
  final Map<String, dynamic> service;

  const ServiceCategoryCard({super.key, required this.service});

  @override
  Widget build(BuildContext context) {
    final color = service['color'] as Color;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(18),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(service['icon'] as IconData,
                      size: 22, color: color),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      service['name'] as String,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      service['desc'] as String,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textHint),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      service['providers'] as String,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Quick Book Button
// Checks for an existing booking before inserting to avoid
// unique-constraint crashes on double-tap or accidental re-tap.
// ─────────────────────────────────────────────

class _QuickBookButton extends StatefulWidget {
  final Map<String, dynamic> provider;
  const _QuickBookButton({required this.provider});

  @override
  State<_QuickBookButton> createState() => _QuickBookButtonState();
}

class _QuickBookButtonState extends State<_QuickBookButton> {
  bool _loading = false;
  bool _booked = false;

  @override
  void initState() {
    super.initState();
    _checkAlreadyBooked();
  }

  Future<void> _checkAlreadyBooked() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      final rows = await Supabase.instance.client
          .from('bookings')
          .select('id')
          .eq('service_id', widget.provider['id'])
          .eq('client_id', user.id);
      if (mounted && (rows as List).isNotEmpty) {
        setState(() => _booked = true);
      }
    } catch (_) {}
  }

  Future<void> _book() async {
    if (_booked || _loading) return;
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    setState(() => _loading = true);
    try {
      // Guard: re-check on the server before inserting.
      final existing = await Supabase.instance.client
          .from('bookings')
          .select('id')
          .eq('service_id', widget.provider['id'])
          .eq('client_id', user.id);
      if ((existing as List).isNotEmpty) {
        if (mounted) setState(() => _booked = true);
        return;
      }

      await Supabase.instance.client.from('bookings').insert({
        'service_id': widget.provider['id'],
        'client_id': user.id,
        'provider_id': widget.provider['provider_id'],
      });

      await Supabase.instance.client.from('notifications').insert({
        'user_id': user.id,
        'title': 'Booking Confirmed',
        'body':
            'Your booking for "${widget.provider['title'] ?? 'service'}" has been placed.',
        'type': 'booking',
        'is_read': false,
      });

      if (mounted) {
        setState(() => _booked = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Booking confirmed!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_booked) {
      return Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: AppColors.success.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.success.withOpacity(0.4)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_rounded, size: 12, color: AppColors.success),
            SizedBox(width: 4),
            Text(
              'Booked',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.success),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      height: 30,
      child: OutlinedButton(
        onPressed: _loading ? null : _book,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          side: BorderSide(
              color: _loading
                  ? AppColors.primary.withOpacity(0.4)
                  : AppColors.primary),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle:
              const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          foregroundColor: AppColors.primary,
          minimumSize: Size.zero,
        ),
        child: _loading
            ? const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.primary),
              )
            : const Text('Book'),
      ),
    );
  }
}