import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../main.dart';

class JobDetailPage extends StatefulWidget {
  final Map<String, dynamic> job;

  const JobDetailPage({super.key, required this.job});

  @override
  State<JobDetailPage> createState() => _JobDetailPageState();
}

class _JobDetailPageState extends State<JobDetailPage> {
  bool _isApplying = false;
  bool _hasApplied = false;

  @override
  void initState() {
    super.initState();
    _checkIfApplied();
  }

  Future<void> _checkIfApplied() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      final result = await Supabase.instance.client
          .from('applications')
          .select('id')
          .eq('job_id', widget.job['id'])
          .eq('user_id', user.id);
      if (mounted) {
        setState(() => _hasApplied = (result as List).isNotEmpty);
      }
    } catch (_) {}
  }

  String _friendlyError(Object e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('duplicate') || msg.contains('unique'))
      return 'You have already applied for this job.';
    if (msg.contains('network') ||
        msg.contains('socket') ||
        msg.contains('connection'))
      return 'No internet connection. Please check your network.';
    if (msg.contains('permission') ||
        msg.contains('rls') ||
        msg.contains('policy'))
      return 'You don\'t have permission to do this.';
    if (msg.contains('not found') || msg.contains('404'))
      return 'This job no longer exists.';
    if (msg.contains('timeout'))
      return 'Request timed out. Please try again.';
    return 'Something went wrong. Please try again.';
  }

  Future<void> _apply() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    setState(() => _isApplying = true);
    try {
      await Supabase.instance.client.from('applications').insert({
        'job_id': widget.job['id'],
        'user_id': user.id,
        'user_email': user.email,
      });
      await Supabase.instance.client
          .from('jobs')
          .update({'applicants': (widget.job['applicants'] ?? 0) + 1}).eq(
              'id', widget.job['id']);
      await Supabase.instance.client.from('notifications').insert({
        'user_id': user.id,
        'title': 'Application Submitted',
        'body':
            'You applied for "${widget.job['title'] ?? 'job'}" at ${widget.job['company'] ?? 'the company'}.',
        'type': 'job',
        'is_read': false,
      });
      if (mounted) {
        setState(() => _hasApplied = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 Application submitted successfully!'),
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
      if (mounted) setState(() => _isApplying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final job = widget.job;

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

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
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
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color, color.withOpacity(0.75)],
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
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.business_center_rounded,
                            color: Colors.white, size: 26),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        job['title'] ?? 'Job',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        job['company'] ?? '',
                        style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                            fontWeight: FontWeight.w500),
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
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _InfoChip(
                        icon: Icons.location_on_outlined,
                        label: job['location'] ?? 'Remote',
                      ),
                      if ((job['budget'] ?? '').toString().isNotEmpty)
                        _InfoChip(
                          icon: Icons.payments_outlined,
                          label: job['budget'].toString(),
                          isHighlighted: true,
                        ),
                      if ((job['posted'] ?? '').toString().isNotEmpty)
                        _InfoChip(
                          icon: Icons.schedule_rounded,
                          label: job['posted'].toString(),
                        ),
                      _InfoChip(
                        icon: Icons.people_outline_rounded,
                        label: '${job['applicants'] ?? 0} applicants',
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  if (tags.isNotEmpty) ...[
                    const Text('Skills Required',
                        style: AppTextStyles.titleLarge),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: tags
                          .map((tag) => Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                      color: color.withOpacity(0.2)),
                                ),
                                child: Text(
                                  tag,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: color,
                                  ),
                                ),
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: 24),
                  ],

                  if ((job['description'] ?? '').toString().isNotEmpty) ...[
                    const Text('Job Description',
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
                        job['description'].toString(),
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                          height: 1.65,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  if ((job['requirements'] ?? '').toString().isNotEmpty) ...[
                    const Text('Requirements',
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
                        job['requirements'].toString(),
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                          height: 1.65,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  if ((job['description'] ?? '').toString().isEmpty &&
                      (job['requirements'] ?? '').toString().isEmpty) ...[
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
                          Icon(Icons.description_outlined,
                              size: 40, color: AppColors.textHint),
                          SizedBox(height: 10),
                          Text('No description provided',
                              style: TextStyle(
                                  color: AppColors.textHint,
                                  fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  _hasApplied
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
                                'Application Submitted',
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
                          label: 'Apply for this Job',
                          onPressed: _apply,
                          isLoading: _isApplying,
                        ),

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

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isHighlighted;

  const _InfoChip({
    required this.icon,
    required this.label,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: isHighlighted ? AppColors.primaryLight : AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isHighlighted
              ? AppColors.primary.withOpacity(0.3)
              : AppColors.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 13,
            color: isHighlighted ? AppColors.primary : AppColors.textHint,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color:
                  isHighlighted ? AppColors.primary : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}