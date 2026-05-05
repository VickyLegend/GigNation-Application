import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../main.dart';

// ─────────────────────────────────────────────
// My Posts Page — lists, edits, and deletes the
// current user's jobs and services.
// ─────────────────────────────────────────────

class MyPostsPage extends StatefulWidget {
  const MyPostsPage({super.key});

  @override
  State<MyPostsPage> createState() => _MyPostsPageState();
}

class _MyPostsPageState extends State<MyPostsPage>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  late final TabController _tabs;

  List<Map<String, dynamic>> _jobs = [];
  List<Map<String, dynamic>> _services = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final uid = _supabase.auth.currentUser?.id;
      if (uid == null) return;

      final results = await Future.wait([
        _supabase
            .from('jobs')
            .select()
            .eq('user_id', uid)
            .order('created_at', ascending: false),
        _supabase
            .from('services')
            .select()
            .eq('provider_id', uid)
            .order('created_at', ascending: false),
      ]);

      if (mounted) {
        setState(() {
          _jobs = List<Map<String, dynamic>>.from(results[0]);
          _services = List<Map<String, dynamic>>.from(results[1]);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showError('Failed to load your posts: $e');
      }
    }
  }

  // ── Delete ──────────────────────────────────

  Future<void> _deleteJob(Map<String, dynamic> job) async {
    final confirmed = await _confirmDelete(job['title'] ?? 'this job');
    if (!confirmed) return;
    try {
      await _supabase.from('jobs').delete().eq('id', job['id']);
      setState(() => _jobs.removeWhere((j) => j['id'] == job['id']));
      _showSuccess('Job deleted.');
    } catch (e) {
      _showError('Delete failed: $e');
    }
  }

  Future<void> _deleteService(Map<String, dynamic> service) async {
    final confirmed =
        await _confirmDelete(service['title'] ?? 'this service');
    if (!confirmed) return;
    try {
      await _supabase.from('services').delete().eq('id', service['id']);
      setState(
          () => _services.removeWhere((s) => s['id'] == service['id']));
      _showSuccess('Service deleted.');
    } catch (e) {
      _showError('Delete failed: $e');
    }
  }

  Future<bool> _confirmDelete(String name) async {
    return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            title: const Text('Delete Post',
                style: TextStyle(fontWeight: FontWeight.w700)),
            content: Text(
                'Are you sure you want to delete "$name"? This cannot be undone.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel',
                    style: TextStyle(color: AppColors.textSecondary)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
  }

  // ── Edit ────────────────────────────────────

  Future<void> _editJob(Map<String, dynamic> job) async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => EditJobPage(job: job)),
    );
    if (updated == true) _load();
  }

  Future<void> _editService(Map<String, dynamic> service) async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
          builder: (_) => EditServicePage(service: service)),
    );
    if (updated == true) _load();
  }

  // ── Helpers ─────────────────────────────────

  void _showSuccess(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: AppColors.success,
    ));
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: AppColors.error,
    ));
  }

  // ── Build ────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 18, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('My Posts', style: AppTextStyles.titleLarge),
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textHint,
          indicatorColor: AppColors.primary,
          indicatorSize: TabBarIndicatorSize.label,
          labelStyle:
              const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          tabs: [
            Tab(text: 'Jobs (${_jobs.length})'),
            Tab(text: 'Services (${_services.length})'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : TabBarView(
              controller: _tabs,
              children: [
                _buildJobsList(),
                _buildServicesList(),
              ],
            ),
    );
  }

  Widget _buildJobsList() {
    if (_jobs.isEmpty) return _buildEmpty('No jobs posted yet.');
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _jobs.length,
        itemBuilder: (_, i) => _JobPostCard(
          job: _jobs[i],
          onEdit: () => _editJob(_jobs[i]),
          onDelete: () => _deleteJob(_jobs[i]),
        ),
      ),
    );
  }

  Widget _buildServicesList() {
    if (_services.isEmpty) return _buildEmpty('No services listed yet.');
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _services.length,
        itemBuilder: (_, i) => _ServicePostCard(
          service: _services[i],
          onEdit: () => _editService(_services[i]),
          onDelete: () => _deleteService(_services[i]),
        ),
      ),
    );
  }

  Widget _buildEmpty(String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.inbox_outlined,
              size: 56, color: AppColors.textHint),
          const SizedBox(height: 14),
          Text(message, style: AppTextStyles.bodyMedium),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Job Post Card
// ─────────────────────────────────────────────

class _JobPostCard extends StatelessWidget {
  final Map<String, dynamic> job;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _JobPostCard({
    required this.job,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFF6366F1);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.12)),
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
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.business_center_rounded,
                    color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      job['title'] ?? 'Untitled',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      job['company'] ?? '',
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              _PostMenu(onEdit: onEdit, onDelete: onDelete),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if ((job['location'] ?? '').isNotEmpty)
                _Chip(
                    Icons.location_on_outlined, job['location'], color),
              if ((job['budget'] ?? '').isNotEmpty)
                _Chip(Icons.payments_outlined, job['budget'], color),
              _Chip(Icons.people_outline_rounded,
                  '${job['applicants'] ?? 0} applicants', color),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Service Post Card
// ─────────────────────────────────────────────

class _ServicePostCard extends StatelessWidget {
  final Map<String, dynamic> service;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ServicePostCard({
    required this.service,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFF10B981);
    final isAvailable = service['is_available'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.12)),
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
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.handyman_rounded,
                    color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      service['title'] ?? 'Untitled',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      service['category'] ?? '',
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              // Availability badge
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isAvailable
                      ? AppColors.success.withOpacity(0.1)
                      : AppColors.border,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isAvailable ? 'Available' : 'Unavailable',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isAvailable
                        ? AppColors.success
                        : AppColors.textHint,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              _PostMenu(onEdit: onEdit, onDelete: onDelete),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if ((service['price'] ?? '').isNotEmpty)
                _Chip(Icons.payments_outlined, service['price'], color),
              if ((service['location'] ?? '').isNotEmpty)
                _Chip(Icons.location_on_outlined,
                    service['location'], color),
              if ((service['per'] ?? '').isNotEmpty)
                _Chip(Icons.schedule_rounded, service['per'], color),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Shared mini-widgets
// ─────────────────────────────────────────────

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _Chip(this.icon, this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _PostMenu extends StatelessWidget {
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _PostMenu({required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert_rounded,
          color: AppColors.textHint, size: 20),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      onSelected: (v) {
        if (v == 'edit') onEdit();
        if (v == 'delete') onDelete();
      },
      itemBuilder: (_) => [
        const PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit_outlined,
                  size: 16, color: AppColors.primary),
              SizedBox(width: 10),
              Text('Edit', style: TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline_rounded,
                  size: 16, color: AppColors.error),
              SizedBox(width: 10),
              Text('Delete',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.error)),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// Edit Job Page
// ─────────────────────────────────────────────

class EditJobPage extends StatefulWidget {
  final Map<String, dynamic> job;
  const EditJobPage({super.key, required this.job});

  @override
  State<EditJobPage> createState() => _EditJobPageState();
}

class _EditJobPageState extends State<EditJobPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl;
  late final TextEditingController _companyCtrl;
  late final TextEditingController _locationCtrl;
  late final TextEditingController _budgetCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _reqCtrl;
  late final TextEditingController _tagsCtrl;

  late String _selectedCategory;
  late String _selectedType;
  late bool _isRemote;
  bool _isLoading = false;

  static const _categories = [
    'Technology', 'Design', 'Marketing', 'Finance',
    'Healthcare', 'Education', 'Engineering', 'Other'
  ];
  static const _types = ['Full-time', 'Part-time', 'Contract', 'Freelance'];

  @override
  void initState() {
    super.initState();
    final j = widget.job;
    _titleCtrl = TextEditingController(text: j['title'] ?? '');
    _companyCtrl = TextEditingController(text: j['company'] ?? '');
    _locationCtrl = TextEditingController(
        text: j['location'] == 'Remote' ? '' : (j['location'] ?? ''));
    _budgetCtrl = TextEditingController(text: j['budget'] ?? '');
    _descCtrl = TextEditingController(text: j['description'] ?? '');
    _reqCtrl = TextEditingController(text: j['requirements'] ?? '');

    final rawTags = j['tags'];
    final tagsStr = rawTags == null
        ? ''
        : rawTags is List
            ? rawTags.join(', ')
            : rawTags.toString();
    _tagsCtrl = TextEditingController(text: tagsStr);

    _selectedCategory =
        _categories.contains(j['category']) ? j['category'] : 'Technology';
    _selectedType =
        _types.contains(j['type']) ? j['type'] : 'Full-time';
    _isRemote = j['location'] == 'Remote';
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _companyCtrl.dispose();
    _locationCtrl.dispose();
    _budgetCtrl.dispose();
    _descCtrl.dispose();
    _reqCtrl.dispose();
    _tagsCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final tags = _tagsCtrl.text
          .split(',')
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .toList();

      await Supabase.instance.client.from('jobs').update({
        'title': _titleCtrl.text.trim(),
        'company': _companyCtrl.text.trim(),
        'location': _isRemote ? 'Remote' : _locationCtrl.text.trim(),
        'budget': _budgetCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'requirements': _reqCtrl.text.trim(),
        'category': _selectedCategory,
        'type': _selectedType,
        'tags': tags,
      }).eq('id', widget.job['id']);

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Save failed: $e'),
          backgroundColor: AppColors.error,
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 18, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Edit Job', style: AppTextStyles.titleLarge),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _field('Job Title *', _titleCtrl, 'e.g. Web Developer'),
            _field('Company Name *', _companyCtrl, 'e.g. Acme Corp'),
            _dropdown('Category', _selectedCategory, _categories,
                (v) => setState(() => _selectedCategory = v!)),
            _dropdown('Job Type', _selectedType, _types,
                (v) => setState(() => _selectedType = v!)),
            _toggle('Remote Position', _isRemote,
                (v) => setState(() => _isRemote = v)),
            if (!_isRemote)
              _field('Location', _locationCtrl, 'e.g. Lagos, Nigeria',
                  required: false),
            _field('Budget / Salary', _budgetCtrl, 'e.g. ₦200,000/month'),
            _field('Tags / Skills', _tagsCtrl,
                'e.g. Flutter, Dart', required: false,
                helperText: 'Separate with commas'),
            _field('Job Description', _descCtrl,
                'Describe the role...', maxLines: 5, required: false),
            _field('Requirements', _reqCtrl,
                'List qualifications...', maxLines: 4, required: false),
            const SizedBox(height: 24),
            GradientButton(
              label: 'Save Changes',
              onPressed: _save,
              isLoading: _isLoading,
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, String hint,
      {int maxLines = 1, bool required = true, String? helperText}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.label),
        const SizedBox(height: 8),
        TextFormField(
          controller: ctrl,
          maxLines: maxLines,
          decoration:
              InputDecoration(hintText: hint, helperText: helperText),
          validator:
              required ? (v) => v == null || v.isEmpty ? 'Required' : null : null,
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _dropdown(String label, String value, List<String> items,
      ValueChanged<String?> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.label),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: DropdownButton<String>(
            value: value,
            isExpanded: true,
            underline: const SizedBox(),
            items: items
                .map((i) => DropdownMenuItem(value: i, child: Text(i)))
                .toList(),
            onChanged: onChanged,
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _toggle(String label, bool value, ValueChanged<bool> onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.label),
          Switch(
              value: value,
              onChanged: onChanged,
              activeColor: AppColors.primary),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Edit Service Page
// ─────────────────────────────────────────────

class EditServicePage extends StatefulWidget {
  final Map<String, dynamic> service;
  const EditServicePage({super.key, required this.service});

  @override
  State<EditServicePage> createState() => _EditServicePageState();
}

class _EditServicePageState extends State<EditServicePage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _titleCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _locationCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _expCtrl;

  late String _selectedCategory;
  late String _selectedPer;
  late bool _isAvailable;
  bool _isLoading = false;

  static const _categories = [
    'Design', 'Development', 'Marketing', 'Writing',
    'Finance', 'Consulting', 'Photography', 'Other'
  ];
  static const _perOptions = [
    'per project', 'per hour', 'per day', 'per month'
  ];

  @override
  void initState() {
    super.initState();
    final s = widget.service;
    _nameCtrl = TextEditingController(text: s['provider'] ?? '');
    _titleCtrl = TextEditingController(text: s['title'] ?? '');
    // Strip the leading ₦ if present so the field stays numeric-friendly
    final rawPrice = (s['price'] ?? '').toString().replaceFirst('₦', '');
    _priceCtrl = TextEditingController(text: rawPrice);
    _locationCtrl = TextEditingController(text: s['location'] ?? '');
    _descCtrl = TextEditingController(text: s['description'] ?? '');
    _expCtrl = TextEditingController(text: s['experience'] ?? '');

    _selectedCategory =
        _categories.contains(s['category']) ? s['category'] : 'Design';
    _selectedPer =
        _perOptions.contains(s['per']) ? s['per'] : 'per project';
    _isAvailable = s['is_available'] != false;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _titleCtrl.dispose();
    _priceCtrl.dispose();
    _locationCtrl.dispose();
    _descCtrl.dispose();
    _expCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.from('services').update({
        'provider': _nameCtrl.text.trim(),
        'title': _titleCtrl.text.trim(),
        'price': '₦${_priceCtrl.text.trim()}',
        'per': _selectedPer,
        'category': _selectedCategory,
        'location': _locationCtrl.text.trim(),
        'is_available': _isAvailable,
        'description': _descCtrl.text.trim(),
        'experience': _expCtrl.text.trim(),
      }).eq('id', widget.service['id']);

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Save failed: $e'),
          backgroundColor: AppColors.error,
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 18, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title:
            const Text('Edit Service', style: AppTextStyles.titleLarge),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _field('Full Name *', _nameCtrl, 'Your full name'),
            _field('Service Title *', _titleCtrl,
                'e.g. Professional Logo Design'),
            _dropdown('Category', _selectedCategory, _categories,
                (v) => setState(() => _selectedCategory = v!)),
            _priceRow(),
            _field('Location', _locationCtrl, 'e.g. Lagos, Nigeria',
                required: false),
            _toggle('Available Now', _isAvailable,
                (v) => setState(() => _isAvailable = v)),
            _field('Service Description', _descCtrl,
                'Describe what you offer...', maxLines: 5, required: false),
            _field('Experience', _expCtrl,
                'Years of experience and past work...', maxLines: 3,
                required: false),
            const SizedBox(height: 24),
            GradientButton(
              label: 'Save Changes',
              onPressed: _save,
              isLoading: _isLoading,
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, String hint,
      {int maxLines = 1, bool required = true}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.label),
        const SizedBox(height: 8),
        TextFormField(
          controller: ctrl,
          maxLines: maxLines,
          decoration: InputDecoration(hintText: hint),
          validator:
              required ? (v) => v == null || v.isEmpty ? 'Required' : null : null,
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _priceRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Price *', style: AppTextStyles.label),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: _priceCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    hintText: '50,000', prefixText: '₦ '),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Required' : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: DropdownButton<String>(
                  value: _selectedPer,
                  isExpanded: true,
                  underline: const SizedBox(),
                  items: _perOptions
                      .map((i) =>
                          DropdownMenuItem(value: i, child: Text(i)))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedPer = v!),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _dropdown(String label, String value, List<String> items,
      ValueChanged<String?> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.label),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: DropdownButton<String>(
            value: value,
            isExpanded: true,
            underline: const SizedBox(),
            items: items
                .map((i) => DropdownMenuItem(value: i, child: Text(i)))
                .toList(),
            onChanged: onChanged,
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _toggle(String label, bool value, ValueChanged<bool> onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.label),
          Switch(
              value: value,
              onChanged: onChanged,
              activeColor: AppColors.success),
        ],
      ),
    );
  }
}