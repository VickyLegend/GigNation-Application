import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../main.dart';
import 'job_detail_page.dart';
import 'service_detail_page.dart';

// ─────────────────────────────────────────────
// Explore / Search Page — fully functional search
// ─────────────────────────────────────────────

class ExplorePage extends StatefulWidget {
  const ExplorePage({super.key});

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  final _supabase = Supabase.instance.client;
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();

  List<Map<String, dynamic>> _jobResults = [];
  List<Map<String, dynamic>> _serviceResults = [];
  bool _isSearching = false;
  bool _hasSearched = false;
  String _lastQuery = '';

  static const _trending = [
    'Website Developer',
    'Graphic Designer',
    'Logo Design',
    'Ethical Hacker',
    'Content Writing',
    'Photography',
    'Virtual Assistant',
    'Video Editing',
    'Security Guard',
    'UI/UX Designer',
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final q = _searchController.text.trim();
    if (q.isEmpty) {
      setState(() {
        _jobResults = [];
        _serviceResults = [];
        _hasSearched = false;
        _lastQuery = '';
      });
    }
  }

  Future<void> _search(String query) async {
    query = query.trim();
    if (query.isEmpty) return;
    _lastQuery = query;
    setState(() => _isSearching = true);

    try {
      // Search jobs: title, company, or location contain the query
      final jobData = await _supabase
          .from('jobs')
          .select()
          .or('title.ilike.%$query%,company.ilike.%$query%,location.ilike.%$query%')
          .order('created_at', ascending: false)
          .limit(20);

      // Search services: title, provider, category, or location contain the query
      final serviceData = await _supabase
          .from('services')
          .select()
          .or('title.ilike.%$query%,provider.ilike.%$query%,category.ilike.%$query%,location.ilike.%$query%')
          .order('created_at', ascending: false)
          .limit(20);

      if (mounted) {
        setState(() {
          _jobResults = List<Map<String, dynamic>>.from(jobData);
          _serviceResults = List<Map<String, dynamic>>.from(serviceData);
          _hasSearched = true;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSearching = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Search failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _searchFromChip(String term) {
    _searchController.text = term;
    _focusNode.unfocus();
    _search(term);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Search bar ──
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: TextField(
            controller: _searchController,
            focusNode: _focusNode,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: 'Search jobs, services, talent...',
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: AppColors.primary,
                size: 22,
              ),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded,
                          size: 18, color: AppColors.textHint),
                      onPressed: () {
                        _searchController.clear();
                        _focusNode.unfocus();
                      },
                    )
                  : null,
            ),
            textInputAction: TextInputAction.search,
            onSubmitted: _search,
          ),
        ),

        // ── Results or trending ──
        Expanded(
          child: _isSearching
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                )
              : _hasSearched
                  ? _buildResults()
                  : _buildTrending(),
        ),
      ],
    );
  }

  Widget _buildTrending() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 8),
        const Text('Trending Searches', style: AppTextStyles.titleLarge),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _trending
              .map(
                (term) => GestureDetector(
                  onTap: () => _searchFromChip(term),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.trending_up_rounded,
                            size: 14, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Text(
                          term,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _buildResults() {
    final totalResults = _jobResults.length + _serviceResults.length;

    if (totalResults == 0) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off_rounded,
                size: 56, color: AppColors.textHint),
            const SizedBox(height: 16),
            const Text('No results found', style: AppTextStyles.titleLarge),
            const SizedBox(height: 8),
            const Text(
              'Try searching for something else',
              style: AppTextStyles.bodyMedium,
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          '$totalResults result${totalResults == 1 ? '' : 's'} for "$_lastQuery"',
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textHint,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 16),

        // Jobs section
        if (_jobResults.isNotEmpty) ...[
          Row(
            children: [
              const Icon(Icons.work_outline_rounded,
                  size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                'Jobs (${_jobResults.length})',
                style: AppTextStyles.titleLarge,
              ),
            ],
          ),
          const SizedBox(height: 10),
          ..._jobResults.map(
            (job) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _SearchResultCard(
                title: job['title'] ?? 'Untitled',
                subtitle: job['company'] ?? '',
                meta: job['location'] ?? 'Remote',
                badge: job['budget'] ?? '',
                icon: Icons.business_center_rounded,
                iconColor: const Color(0xFF6366F1),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => JobDetailPage(job: job),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],

        // Services section
        if (_serviceResults.isNotEmpty) ...[
          Row(
            children: [
              const Icon(Icons.handyman_rounded,
                  size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                'Services (${_serviceResults.length})',
                style: AppTextStyles.titleLarge,
              ),
            ],
          ),
          const SizedBox(height: 10),
          ..._serviceResults.map(
            (service) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _SearchResultCard(
                title: service['provider'] ?? 'Unknown',
                subtitle: service['title'] ?? '',
                meta: service['category'] ?? '',
                badge: service['price'] ?? '',
                icon: Icons.person_rounded,
                iconColor: AppColors.primary,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ServiceDetailPage(service: service),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────
// Compact result card used in search results
// ─────────────────────────────────────────────

class _SearchResultCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String meta;
  final String badge;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;

  const _SearchResultCard({
    required this.title,
    required this.subtitle,
    required this.meta,
    required this.badge,
    required this.icon,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  if (meta.isNotEmpty)
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined,
                            size: 11, color: AppColors.textHint),
                        const SizedBox(width: 3),
                        Text(
                          meta,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textHint,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            if (badge.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  badge,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.textHint, size: 18),
          ],
        ),
      ),
    );
  }
}