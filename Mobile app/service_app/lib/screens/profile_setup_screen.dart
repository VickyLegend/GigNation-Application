import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';
import 'home.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen>
    with SingleTickerProviderStateMixin {
  int _currentStep = 0;
  bool _isLoading = false;

  // Step 1 — Required
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  String? _selectedRole;

  // Step 2 — Optional
  final _skillsController = TextEditingController();
  final _portfolioController = TextEditingController();
  final _bioController = TextEditingController();
  String? _cvFileName;
  PlatformFile? _cvFile;

  // Step 3 — Optional
  final List<Map<String, TextEditingController>> _projects = [
    {'title': TextEditingController(), 'description': TextEditingController()}
  ];

  // Errors
  String? _nameError;
  String? _phoneError;
  String? _roleError;

  late final AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(1, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
    _slideController.forward();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _skillsController.dispose();
    _portfolioController.dispose();
    _bioController.dispose();
    _slideController.dispose();
    for (final p in _projects) {
      p['title']!.dispose();
      p['description']!.dispose();
    }
    super.dispose();
  }

  void _animateNext() {
    _slideController.reset();
    _slideController.forward();
  }

  bool _validateStep1() {
    setState(() {
      _nameError = null;
      _phoneError = null;
      _roleError = null;
    });
    bool valid = true;
    if (_nameController.text.trim().isEmpty) {
      setState(() => _nameError = 'Full name is required');
      valid = false;
    }
    if (_phoneController.text.trim().isEmpty) {
      setState(() => _phoneError = 'Phone number is required');
      valid = false;
    }
    if (_selectedRole == null) {
      setState(() => _roleError = 'Please select your role');
      valid = false;
    }
    return valid;
  }

  Future<void> _pickCV() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx'],
      withData: true,
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _cvFile = result.files.first;
        _cvFileName = result.files.first.name;
      });
    }
  }

  Future<String?> _uploadCV(String userId) async {
    if (_cvFile == null) return null;
    try {
      final ext = _cvFile!.extension ?? 'pdf';
      final filePath =
          '$userId/${DateTime.now().millisecondsSinceEpoch}_${_cvFile!.name}';

      Uint8List? bytes;
      if (_cvFile!.bytes != null) {
        bytes = _cvFile!.bytes!;
      } else if (_cvFile!.path != null) {
        bytes = await File(_cvFile!.path!).readAsBytes();
      }

      if (bytes == null) return null;

      final contentType =
          ext == 'pdf' ? 'application/pdf' : 'application/msword';

      await Supabase.instance.client.storage.from('cvs').uploadBinary(
            filePath,
            bytes,
            fileOptions: FileOptions(contentType: contentType, upsert: true),
          );

      return Supabase.instance.client.storage
          .from('cvs')
          .getPublicUrl(filePath);
    } catch (e) {
      debugPrint('CV upload error: $e');
      return null;
    }
  }

  void _addProject() {
    setState(() {
      _projects.add({
        'title': TextEditingController(),
        'description': TextEditingController(),
      });
    });
  }

  void _removeProject(int index) {
    if (_projects.length > 1) {
      setState(() {
        _projects[index]['title']!.dispose();
        _projects[index]['description']!.dispose();
        _projects.removeAt(index);
      });
    }
  }

  Future<void> _submitProfile() async {
    setState(() => _isLoading = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        debugPrint('❌ No user found — cannot save profile');
        _showError('Session expired. Please log in again.');
        return;
      }

      debugPrint('✅ Saving profile for user: ${user.id}');

      // Upload CV if picked
      final cvUrl = await _uploadCV(user.id);
      debugPrint('📄 CV URL: $cvUrl');

      final projects = _projects
          .map((p) => {
                'title': p['title']!.text.trim(),
                'description': p['description']!.text.trim(),
              })
          .where((p) => (p['title'] as String).isNotEmpty)
          .toList();

      final payload = {
        'id': user.id,
        'full_name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'role': _selectedRole,
        'skills': _skillsController.text.trim(),
        'portfolio_url': _portfolioController.text.trim(),
        'bio': _bioController.text.trim(),
        'past_projects': projects,
        'profile_complete': true,
        'updated_at': DateTime.now().toIso8601String(),
        if (cvUrl != null) 'cv_url': cvUrl,
      };

      debugPrint('📦 Payload: $payload');

      await Supabase.instance.client.from('profile').upsert(payload);

      debugPrint('✅ Profile saved successfully — navigating to HomePage');

      if (!mounted) return;

      // Navigate to home, clear the entire stack
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomePage()),
        (route) => false,
      );
    } catch (e, stack) {
      debugPrint('❌ Profile save error: $e');
      debugPrint('Stack: $stack');
      _showError('Something went wrong: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: GigColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _nextStep() {
    // Step 1 is ALWAYS validated — cannot skip
    if (_currentStep == 0) {
      if (!_validateStep1()) return;
      setState(() => _currentStep++);
      _animateNext();
      return;
    }
    // Step 2 — optional, can proceed without filling
    if (_currentStep == 1) {
      setState(() => _currentStep++);
      _animateNext();
      return;
    }
    // Step 3 — submit
    if (_currentStep == 2) {
      _submitProfile();
    }
  }

  void _prevStep() {
    if (_currentStep == 0) return;
    setState(() => _currentStep--);
    _animateNext();
  }

  void _skipStep() {
    // Skip is ONLY allowed on steps 2 and 3
    if (_currentStep == 0) return;
    if (_currentStep == 1) {
      setState(() => _currentStep++);
      _animateNext();
      return;
    }
    if (_currentStep == 2) {
      _submitProfile();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = GigColors.backgroundOf(context);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar ──
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  // Back button (not shown on step 1)
                  if (_currentStep > 0)
                    GestureDetector(
                      onTap: _prevStep,
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white10 : Colors.black.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 16,
                          color: GigColors.textPrimaryOf(context),
                        ),
                      ),
                    )
                  else
                    const SizedBox(width: 38),

                  const Spacer(),

                  // Step dots
                  Row(
                    children: List.generate(3, (i) {
                      final isActive = i == _currentStep;
                      final isDone = i < _currentStep;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: isActive ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isDone || isActive
                              ? GigColors.primary
                              : (isDark ? Colors.white12 : Colors.black12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),

                  const Spacer(),

                  // Skip — only steps 2 & 3
                  if (_currentStep > 0)
                    GestureDetector(
                      onTap: _skipStep,
                      child: Text(
                        'Skip',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white38 : Colors.black38,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    )
                  else
                    const SizedBox(width: 38),
                ],
              ),
            ),

            // ── Content ──
            Expanded(
              child: SlideTransition(
                position: _slideAnimation,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _buildStep(),
                ),
              ),
            ),

            // ── CTA ──
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
              child: _GigButton(
                label: _currentStep == 2 ? 'Finish & Enter App' : 'Continue',
                isLoading: _isLoading,
                onPressed: _nextStep,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep() {
    switch (_currentStep) {
      case 0:
        return _buildStep1();
      case 1:
        return _buildStep2();
      case 2:
        return _buildStep3();
      default:
        return const SizedBox();
    }
  }

  // ── Step 1: Required ──
  Widget _buildStep1() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text('Set up your\nprofile',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: GigColors.textPrimaryOf(context),
              height: 1.2,
              letterSpacing: -0.5,
            )),
        const SizedBox(height: 6),
        Text('Step 1 of 3 — Required info',
            style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white38 : Colors.black45)),
        // Required badge
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: GigColors.error.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: GigColors.error.withOpacity(0.3)),
          ),
          child: const Text(
            '⚠️  This step cannot be skipped',
            style: TextStyle(
                fontSize: 11,
                color: GigColors.error,
                fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 28),
        _SetupField(
          label: 'Full name',
          hint: 'Chiamaka Okonkwo',
          controller: _nameController,
          icon: Icons.person_outline_rounded,
          errorText: _nameError,
        ),
        const SizedBox(height: 16),
        _SetupField(
          label: 'Phone number',
          hint: '+234 812 345 6789',
          controller: _phoneController,
          icon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
          errorText: _phoneError,
        ),
        const SizedBox(height: 24),
        _FieldLabel('I am a'),
        const SizedBox(height: 10),
        Row(
          children: [
            _RoleChip(
              label: 'Freelancer',
              icon: Icons.work_outline_rounded,
              selected: _selectedRole == 'freelancer',
              onTap: () => setState(() => _selectedRole = 'freelancer'),
            ),
            const SizedBox(width: 10),
            _RoleChip(
              label: 'Client',
              icon: Icons.business_outlined,
              selected: _selectedRole == 'client',
              onTap: () => setState(() => _selectedRole = 'client'),
            ),
            const SizedBox(width: 10),
            _RoleChip(
              label: 'Both',
              icon: Icons.people_outline_rounded,
              selected: _selectedRole == 'both',
              onTap: () => setState(() => _selectedRole = 'both'),
            ),
          ],
        ),
        if (_roleError != null) ...[
          const SizedBox(height: 8),
          Text(_roleError!,
              style:
                  const TextStyle(fontSize: 12, color: GigColors.error)),
        ],
        const SizedBox(height: 32),
      ],
    );
  }

  // ── Step 2: Optional ──
  Widget _buildStep2() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text('Skills &\nexpertise',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: GigColors.textPrimaryOf(context),
              height: 1.2,
              letterSpacing: -0.5,
            )),
        const SizedBox(height: 6),
        Text('Step 2 of 3 — Optional',
            style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white38 : Colors.black45)),
        const SizedBox(height: 28),
        _SetupField(
          label: 'Top skills',
          hint: 'e.g. UI Design, Video Editing, Copywriting',
          controller: _skillsController,
          icon: Icons.star_outline_rounded,
        ),
        const SizedBox(height: 16),
        _SetupField(
          label: 'Portfolio / website link',
          hint: 'behance.net/yourname',
          controller: _portfolioController,
          icon: Icons.link_rounded,
          keyboardType: TextInputType.url,
        ),
        const SizedBox(height: 16),
        _FieldLabel('CV / Résumé'),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _pickCV,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withOpacity(0.05)
                  : Colors.black.withOpacity(0.03),
              border: Border.all(
                color: _cvFileName != null
                    ? GigColors.primary
                    : (isDark
                        ? Colors.white24
                        : Colors.black12),
                width: 1,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                Icon(
                  _cvFileName != null
                      ? Icons.check_circle_outline_rounded
                      : Icons.upload_file_rounded,
                  color: _cvFileName != null
                      ? GigColors.primary
                      : (isDark ? Colors.white38 : Colors.black38),
                  size: 28,
                ),
                const SizedBox(height: 8),
                Text(
                  _cvFileName ?? 'Tap to upload PDF or DOCX',
                  style: TextStyle(
                    fontSize: 13,
                    color: _cvFileName != null
                        ? GigColors.primary
                        : (isDark ? Colors.white38 : Colors.black38),
                    fontWeight: _cvFileName != null
                        ? FontWeight.w600
                        : FontWeight.w400,
                  ),
                ),
                if (_cvFileName == null)
                  Text('Max 5MB',
                      style: TextStyle(
                          fontSize: 11,
                          color:
                              isDark ? Colors.white24 : Colors.black26)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _SetupField(
          label: 'Short bio',
          hint: 'Tell clients a bit about yourself…',
          controller: _bioController,
          icon: Icons.notes_rounded,
          maxLines: 4,
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  // ── Step 3: Optional ──
  Widget _buildStep3() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text('Past\nprojects',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: GigColors.textPrimaryOf(context),
              height: 1.2,
              letterSpacing: -0.5,
            )),
        const SizedBox(height: 6),
        Text('Step 3 of 3 — Optional',
            style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white38 : Colors.black45)),
        const SizedBox(height: 28),
        ...List.generate(_projects.length, (i) {
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withOpacity(0.05)
                  : Colors.black.withOpacity(0.03),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: isDark ? Colors.white12 : Colors.black.withOpacity(0.08),
                  width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Project ${i + 1}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: GigColors.primary,
                        )),
                    if (_projects.length > 1)
                      GestureDetector(
                        onTap: () => _removeProject(i),
                        child: Icon(Icons.remove_circle_outline_rounded,
                            size: 18,
                            color:
                                isDark ? Colors.white24 : Colors.black26),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                _SetupField(
                  label: 'Project title',
                  hint: 'e.g. E-commerce App for Lagos Brand',
                  controller: _projects[i]['title']!,
                  icon: Icons.folder_outlined,
                ),
                const SizedBox(height: 12),
                _SetupField(
                  label: 'Brief description',
                  hint: 'What did you build or do?',
                  controller: _projects[i]['description']!,
                  icon: Icons.description_outlined,
                  maxLines: 3,
                ),
              ],
            ),
          );
        }),
        GestureDetector(
          onTap: _addProject,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              border: Border.all(
                  color: GigColors.primary.withOpacity(0.4), width: 1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_rounded, size: 18, color: GigColors.primary),
                SizedBox(width: 6),
                Text('Add another project',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: GigColors.primary,
                    )),
              ],
            ),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// Local widgets
// ─────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        color: GigColors.primary,
        letterSpacing: 0.1,
      ),
    );
  }
}

class _SetupField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final IconData icon;
  final TextInputType keyboardType;
  final int maxLines;
  final String? errorText;

  const _SetupField({
    required this.label,
    required this.hint,
    required this.controller,
    required this.icon,
    this.keyboardType = TextInputType.text,
    this.maxLines = 1,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = GigColors.textPrimaryOf(context);
    final hintColor = isDark ? Colors.white30 : Colors.black38;
    final fillColor = isDark
        ? Colors.white.withOpacity(0.07)
        : Colors.black.withOpacity(0.04);
    final borderColor = isDark ? Colors.white12 : Colors.black12;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          style: TextStyle(
              fontSize: 14, color: textColor, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: hintColor, fontSize: 14),
            prefixIcon: Icon(icon, size: 18, color: hintColor),
            errorText: errorText,
            errorStyle:
                const TextStyle(color: GigColors.error, fontSize: 12),
            filled: true,
            fillColor: fillColor,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: borderColor, width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: borderColor, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide:
                  const BorderSide(color: GigColors.primary, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide:
                  const BorderSide(color: GigColors.error, width: 1),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide:
                  const BorderSide(color: GigColors.error, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

class _RoleChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _RoleChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: selected
                ? GigColors.primary.withOpacity(0.15)
                : (isDark
                    ? Colors.white.withOpacity(0.05)
                    : Colors.black.withOpacity(0.03)),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? GigColors.primary
                  : (isDark ? Colors.white12 : Colors.black12),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon,
                  size: 20,
                  color: selected
                      ? GigColors.primary
                      : (isDark ? Colors.white38 : Colors.black38)),
              const SizedBox(height: 6),
              Text(label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? GigColors.primary
                        : (isDark ? Colors.white38 : Colors.black38),
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

class _GigButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final bool isLoading;

  const _GigButton({
    required this.label,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onPressed,
      child: Container(
        width: double.infinity,
        height: 54,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [GigColors.primary, GigColors.accent],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: GigColors.primary.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : Text(label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.2,
                  )),
        ),
      ),
    );
  }
}