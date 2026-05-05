import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../main.dart';

class PostPage extends StatelessWidget {
  const PostPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'What do you want to post?',
            style: TextStyle(
              fontSize: 22, fontWeight: FontWeight.w800,
              color: AppColors.textPrimary, height: 1.2, letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Choose the type of listing to create.',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 28),
          PostOptionCard(
            icon: Icons.work_outline_rounded,
            color: const Color(0xFF6366F1),
            title: 'Post a Job',
            description: 'Looking to hire? List a job and receive applications from skilled professionals.',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const PostJobPage()));
            },
          ),
          const SizedBox(height: 16),
          PostOptionCard(
            icon: Icons.handyman_rounded,
            color: const Color(0xFF10B981),
            title: 'Offer a Service',
            description: 'A skilled provider? Create your service listing and start getting bookings.',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const OfferServicePage()));
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class PostOptionCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String description;
  final VoidCallback onTap;

  const PostOptionCard({
    super.key, required this.icon, required this.color,
    required this.title, required this.description, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.2), width: 1.5),
          boxShadow: [
            BoxShadow(color: color.withOpacity(0.08),
                blurRadius: 16, offset: const Offset(0, 6)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 54, height: 54,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
                  const SizedBox(height: 4),
                  Text(description, style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary, height: 1.4)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Icon(Icons.chevron_right_rounded, color: color, size: 22),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Post a Job Form
// ─────────────────────────────────────────────

class PostJobPage extends StatefulWidget {
  const PostJobPage({super.key});

  @override
  State<PostJobPage> createState() => _PostJobPageState();
}

class _PostJobPageState extends State<PostJobPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _companyCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _budgetCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _reqCtrl = TextEditingController();
  final _tagsCtrl = TextEditingController();

  String _selectedCategory = 'Technology';
  String _selectedType = 'Full-time';
  bool _isRemote = false;
  bool _isLoading = false;

  static const _categories = [
    'Technology', 'Design', 'Marketing', 'Finance',
    'Healthcare', 'Education', 'Engineering', 'Other'
  ];
  static const _types = ['Full-time', 'Part-time', 'Contract', 'Freelance'];

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final tags = _tagsCtrl.text
          .split(',')
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .toList();

      await Supabase.instance.client.from('jobs').insert({
        // ✅ Added: user_id so RLS 'INSERT: auth.uid() = user_id' policy passes
        'user_id': user.id,
        'title': _titleCtrl.text.trim(),
        'company': _companyCtrl.text.trim(),
        'location': _isRemote ? 'Remote' : _locationCtrl.text.trim(),
        'budget': _budgetCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'requirements': _reqCtrl.text.trim(),
        'category': _selectedCategory,
        'type': _selectedType,
        'tags': tags,
        'posted': 'Just now',
        'applicants': 0,
      });

      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            title: const Row(children: [
              Icon(Icons.check_circle_rounded,
                  color: AppColors.primary, size: 28),
              SizedBox(width: 8),
              Text('Job Posted!',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ]),
            content: const Text(
                'Your job is now live and visible to professionals.'),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(80, 40),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Done'),
              ),
            ],
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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose(); _companyCtrl.dispose(); _locationCtrl.dispose();
    _budgetCtrl.dispose(); _descCtrl.dispose(); _reqCtrl.dispose();
    _tagsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface, elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 18, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Post a Job', style: AppTextStyles.titleLarge),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _field('Job Title *', _titleCtrl, 'e.g. Web Developer'),
            _field('Company Name *', _companyCtrl, 'e.g. SMATO GLOBAL'),
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
                'e.g. Ethical Hacking,Video Editing, Programmer',
                required: false,
                helperText: 'Separate with commas'),
            _field('Job Description', _descCtrl,
                'Describe the role and responsibilities...', maxLines: 5,
                required: false),
            _field('Requirements', _reqCtrl,
                'List the qualifications and experience needed...', maxLines: 4,
                required: false),
            const SizedBox(height: 24),
            GradientButton(
              label: 'Post Job',
              onPressed: _isLoading ? () {} : _submit,
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
          controller: ctrl, maxLines: maxLines,
          decoration: InputDecoration(hintText: hint, helperText: helperText),
          validator: required
              ? (v) => v == null || v.isEmpty ? 'Required' : null
              : null,
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
            color: AppColors.surface, borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: DropdownButton<String>(
            value: value, isExpanded: true, underline: const SizedBox(),
            items: items.map((i) =>
                DropdownMenuItem(value: i, child: Text(i))).toList(),
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
        color: AppColors.surface, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.label),
          Switch(value: value, onChanged: onChanged,
              activeColor: AppColors.primary),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Offer a Service Form
// ─────────────────────────────────────────────

class OfferServicePage extends StatefulWidget {
  const OfferServicePage({super.key});

  @override
  State<OfferServicePage> createState() => _OfferServicePageState();
}

class _OfferServicePageState extends State<OfferServicePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _expCtrl = TextEditingController();

  String _selectedCategory = 'Design';
  String _selectedPer = 'per project';
  bool _isAvailable = true;
  bool _isLoading = false;

  static const _categories = [
    'Design', 'Development', 'Marketing', 'Writing',
    'Finance', 'Consulting', 'Photography', 'Other'
  ];
  static const _perOptions = [
    'per project', 'per hour', 'per day', 'per month'
  ];

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      await Supabase.instance.client.from('services').insert({
        // ✅ Added: provider_id (user's UUID) — required by RLS policy
        'provider_id': user.id,
        'provider': _nameCtrl.text.trim(),
        'title': _titleCtrl.text.trim(),
        'price': '₦${_priceCtrl.text.trim()}',
        'per': _selectedPer,
        'category': _selectedCategory,
        'location': _locationCtrl.text.trim(),
        // ✅ Fixed: was 'isAvailable' (camelCase) — DB column is 'is_available'
        'is_available': _isAvailable,
        'rating': 5.0,
        'reviews': 0,
        // ✅ Added: description and experience columns now included
        'description': _descCtrl.text.trim(),
        'experience': _expCtrl.text.trim(),
      });

      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            title: const Row(children: [
              Icon(Icons.check_circle_rounded,
                  color: AppColors.success, size: 28),
              SizedBox(width: 8),
              Text('Service Listed!',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ]),
            content: const Text(
                'Your service is now live and visible to clients.'),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  minimumSize: const Size(80, 40),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Done'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'),
              backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _titleCtrl.dispose(); _priceCtrl.dispose();
    _locationCtrl.dispose(); _descCtrl.dispose(); _expCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface, elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 18, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Offer a Service', style: AppTextStyles.titleLarge),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _field('Full Name *', _nameCtrl, 'Your full name'),
            _field('Service Title *', _titleCtrl, 'e.g. Professional Logo Design'),
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
              label: 'List My Service',
              onPressed: _isLoading ? () {} : _submit,
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
          controller: ctrl, maxLines: maxLines,
          decoration: InputDecoration(hintText: hint),
          validator: required
              ? (v) => v == null || v.isEmpty ? 'Required' : null
              : null,
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
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
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
                  value: _selectedPer, isExpanded: true,
                  underline: const SizedBox(),
                  items: _perOptions.map((i) =>
                      DropdownMenuItem(value: i, child: Text(i))).toList(),
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
            color: AppColors.surface, borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: DropdownButton<String>(
            value: value, isExpanded: true, underline: const SizedBox(),
            items: items.map((i) =>
                DropdownMenuItem(value: i, child: Text(i))).toList(),
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
        color: AppColors.surface, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.label),
          Switch(value: value, onChanged: onChanged,
              activeColor: AppColors.success),
        ],
      ),
    );
  }
}