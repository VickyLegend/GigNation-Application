import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../main.dart';
import 'job_detail_page.dart';

class JobsTab extends StatefulWidget {
  const JobsTab({super.key});

  @override
  State<JobsTab> createState() => _JobsTabState();
}

class _JobsTabState extends State<JobsTab> {
  final _supabase = Supabase.instance.client;
  final _searchController = TextEditingController();

  List<Map<String, dynamic>> _jobs = [];
  List<Map<String, dynamic>> _filteredJobs = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchJobs();
    _searchController.addListener(_filterJobs);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchJobs() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await _supabase
          .from('jobs')
          .select()
          .order('created_at', ascending: false);
      setState(() {
        _jobs = List<Map<String, dynamic>>.from(data);
        _filteredJobs = _jobs;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _filterJobs() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      if (query.isEmpty) {
        _filteredJobs = _jobs;
      } else {
        _filteredJobs = _jobs.where((job) {
          final title = (job['title'] ?? '').toString().toLowerCase();
          final company = (job['company'] ?? '').toString().toLowerCase();
          final location = (job['location'] ?? '').toString().toLowerCase();
          final tags = (job['tags'] as List<dynamic>? ?? [])
              .join(' ')
              .toLowerCase();
          return title.contains(query) ||
              company.contains(query) ||
              location.contains(query) ||
              tags.contains(query);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off_rounded,
                size: 48, color: AppColors.textHint),
            const SizedBox(height: 12),
            const Text('Could not load jobs', style: AppTextStyles.titleLarge),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _fetchJobs,
              style: ElevatedButton.styleFrom(minimumSize: const Size(120, 44)),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            controller: _searchController,
            style: const TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              hintText: 'Search jobs, companies, skills...',
              prefixIcon: const Icon(Icons.search_rounded,
                  color: AppColors.textHint, size: 20),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                icon: const Icon(Icons.close_rounded,
                    size: 18, color: AppColors.textHint),
                onPressed: () {
                  _searchController.clear();
                  _filterJobs();
                },
              )
                  : null,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),

        // Result count
        if (_searchController.text.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${_filteredJobs.length} result${_filteredJobs.length == 1 ? '' : 's'}',
                style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textHint,
                    fontWeight: FontWeight.w500),
              ),
            ),
          ),

        // Job list
        Expanded(
          child: _filteredJobs.isEmpty
              ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: const BoxDecoration(
                    color: AppColors.primaryLight,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.work_outline_rounded,
                      size: 36, color: AppColors.primary),
                ),
                const SizedBox(height: 16),
                Text(
                  _jobs.isEmpty
                      ? 'No jobs posted yet'
                      : 'No jobs match your search',
                  style: AppTextStyles.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  _jobs.isEmpty
                      ? 'Be the first to post a job!'
                      : 'Try different keywords',
                  style: AppTextStyles.bodyMedium,
                ),
              ],
            ),
          )
              : RefreshIndicator(
            color: AppColors.primary,
            onRefresh: _fetchJobs,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              itemCount: _filteredJobs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                return JobCard(
                  job: _filteredJobs[index],
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          JobDetailPage(job: _filteredJobs[index]),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// Job Card
// ─────────────────────────────────────────────

class JobCard extends StatelessWidget {
  final Map<String, dynamic> job;
  final VoidCallback? onTap;

  const JobCard({super.key, required this.job, this.onTap});

  @override
  Widget build(BuildContext context) {
    final rawTags = job['tags'];
    final tags = rawTags == null
        ? <String>[]
        : rawTags is List
        ? List<String>.from(rawTags)
        : (rawTags as String)
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    const color = Color(0xFF6366F1);

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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.business_center_rounded,
                      color: color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        job['title'] ?? 'Untitled Job',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        job['company'] ?? '',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.bookmark_border_rounded,
                      size: 18, color: AppColors.textHint),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.location_on_outlined,
                    size: 13, color: AppColors.textHint),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    job['location'] ?? 'Remote',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textHint),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    job['budget'] ?? '',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
            if (tags.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: tags
                    .take(3)
                    .map((tag) => Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    tag,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ))
                    .toList(),
              ),
            ],
            const SizedBox(height: 12),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.schedule_rounded,
                    size: 12, color: AppColors.textHint),
                const SizedBox(width: 4),
                Text(
                  job['posted'] ?? 'Just now',
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textHint),
                ),
                const SizedBox(width: 12),
                const Icon(Icons.people_outline_rounded,
                    size: 12, color: AppColors.textHint),
                const SizedBox(width: 4),
                Text(
                  '${job['applicants'] ?? 0} applicants',
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textHint),
                ),
                const Spacer(),
                _QuickApplyButton(job: job),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Quick Apply Button
// Checks for an existing application before inserting to avoid
// unique-constraint crashes on double-tap or accidental re-tap.
// Uses a server-side increment via .rpc to avoid the stale read-
// then-write race condition on the applicants counter.
// ─────────────────────────────────────────────

class _QuickApplyButton extends StatefulWidget {
  final Map<String, dynamic> job;
  const _QuickApplyButton({required this.job});

  @override
  State<_QuickApplyButton> createState() => _QuickApplyButtonState();
}

class _QuickApplyButtonState extends State<_QuickApplyButton> {
  bool _loading = false;
  bool _applied = false;

  @override
  void initState() {
    super.initState();
    _checkAlreadyApplied();
  }

  Future<void> _checkAlreadyApplied() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      final rows = await Supabase.instance.client
          .from('applications')
          .select('id')
          .eq('job_id', widget.job['id'])
          .eq('user_id', user.id);
      if (mounted && (rows as List).isNotEmpty) {
        setState(() => _applied = true);
      }
    } catch (_) {}
  }

  Future<void> _apply() async {
    if (_applied || _loading) return;
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    setState(() => _loading = true);
    try {
      // Guard: re-check on the server before inserting so a double-tap
      // within the same session doesn't race past the local flag.
      final existing = await Supabase.instance.client
          .from('applications')
          .select('id')
          .eq('job_id', widget.job['id'])
          .eq('user_id', user.id);
      if ((existing as List).isNotEmpty) {
        if (mounted) setState(() => _applied = true);
        return;
      }

      await Supabase.instance.client.from('applications').insert({
        'job_id': widget.job['id'],
        'user_id': user.id,
        'user_email': user.email,
      });

      // Server-side increment avoids the stale read-then-write race.
      // Requires a Postgres function: increment_job_applicants(job_id uuid)
      // that runs: UPDATE jobs SET applicants = applicants + 1 WHERE id = job_id
      // Falls back to client-side update if RPC is unavailable.
      try {
        await Supabase.instance.client.rpc(
          'increment_job_applicants',
          params: {'job_id': widget.job['id']},
        );
      } catch (_) {
        // Fallback: read current value fresh, then increment.
        final fresh = await Supabase.instance.client
            .from('jobs')
            .select('applicants')
            .eq('id', widget.job['id'])
            .single();
        await Supabase.instance.client
            .from('jobs')
            .update({'applicants': ((fresh['applicants'] as int?) ?? 0) + 1})
            .eq('id', widget.job['id']);
      }

      await Supabase.instance.client.from('notifications').insert({
        'user_id': user.id,
        'title': 'Application Submitted',
        'body':
            'You applied for "${widget.job['title'] ?? 'job'}" at ${widget.job['company'] ?? 'the company'}.',
        'type': 'job',
        'is_read': false,
      });

      if (mounted) {
        setState(() => _applied = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 Application submitted!'),
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
    if (_applied) {
      return Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.success.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.success.withOpacity(0.4)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_rounded, size: 14, color: AppColors.success),
            SizedBox(width: 4),
            Text(
              'Applied',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.success),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      height: 32,
      child: ElevatedButton(
        onPressed: _loading ? null : _apply,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.primary.withOpacity(0.5),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          minimumSize: Size.zero,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
          textStyle:
              const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
        child: _loading
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : const Text('Apply'),
      ),
    );
  }
}