import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../main.dart';

// ─────────────────────────────────────────────
// Edit Profile Page
// Requires:
//   - pubspec.yaml: image_picker: ^1.1.2
//   - Supabase Storage bucket named "avatars" (public)
//   - profile table: id, full_name, phone, bio, skills, avatar_url, updated_at
// ─────────────────────────────────────────────

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _supabase = Supabase.instance.client;
  final _picker = ImagePicker();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _skillsController = TextEditingController();
  final _bioController = TextEditingController();

  bool _isSaving = false;
  bool _isLoading = true;
  bool _isUploadingPhoto = false;

  String? _avatarUrl;
  File? _localImageFile;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _skillsController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final data = await _supabase
          .from('profile')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (data != null) {
        _nameController.text = data['full_name'] ?? '';
        _phoneController.text = data['phone'] ?? '';
        _skillsController.text = data['skills'] ?? '';
        _bioController.text = data['bio'] ?? '';
        _avatarUrl = data['avatar_url'];
      } else {
        _nameController.text = user.userMetadata?['full_name'] ?? '';
      }
    } catch (_) {
      final user = _supabase.auth.currentUser;
      _nameController.text = user?.userMetadata?['full_name'] ?? '';
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickAndUploadPhoto(ImageSource source) async {
    Navigator.pop(context);

    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 800,
      );
      if (picked == null) return;

      final file = File(picked.path);
      setState(() {
        _localImageFile = file;
        _isUploadingPhoto = true;
      });

      final user = _supabase.auth.currentUser!;
      final fileExt = picked.path.split('.').last.toLowerCase();

      // ✅ Fixed: was uploading as a flat file (fileName only).
      // RLS policy on avatars bucket requires path: {userId}/{fileName}
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      final storagePath = '${user.id}/$fileName';

      await _supabase.storage.from('avatars').upload(
        storagePath,
        file,
        fileOptions: const FileOptions(upsert: true),
      );

      // ✅ Fixed: getPublicUrl must use the same path used in upload
      final publicUrl =
      _supabase.storage.from('avatars').getPublicUrl(storagePath);

      await _supabase.from('profile').upsert(
        {
          'id': user.id,
          'avatar_url': publicUrl,
          'updated_at': DateTime.now().toIso8601String(),
        },
        onConflict: 'id',
      );

      if (mounted) {
        setState(() {
          _avatarUrl = publicUrl;
          _isUploadingPhoto = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                SizedBox(width: 10),
                Text('Photo updated!',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _localImageFile = null;
          _isUploadingPhoto = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Photo upload failed: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  Future<void> _removePhoto() async {
    Navigator.pop(context);
    try {
      final user = _supabase.auth.currentUser!;
      await _supabase.from('profile').upsert(
        {
          'id': user.id,
          'avatar_url': null,
          'updated_at': DateTime.now().toIso8601String(),
        },
        onConflict: 'id',
      );
      setState(() {
        _avatarUrl = null;
        _localImageFile = null;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error removing photo: $e'),
              backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      await _supabase.from('profile').upsert(
        {
          'id': user.id,
          // Include email so the row is complete on first creation.
          // On subsequent saves this is a no-op because email doesn't change.
          'email': user.email,
          'full_name': _nameController.text.trim(),
          'phone': _phoneController.text.trim(),
          'skills': _skillsController.text.trim(),
          'bio': _bioController.text.trim(),
          'updated_at': DateTime.now().toIso8601String(),
        },
        onConflict: 'id',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                SizedBox(width: 10),
                Text('Profile updated successfully!',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving profile: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
            child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

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
        title: const Text('Edit Profile', style: AppTextStyles.titleLarge),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.primary),
            )
                : const Text(
              'Save',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // ── Avatar Section ──
            _buildAvatarSection(),
            const SizedBox(height: 28),

            // ── Personal Info ──
            _sectionLabel('PERSONAL INFORMATION'),
            const SizedBox(height: 12),
            _buildField(
              label: 'Full Name',
              controller: _nameController,
              icon: Icons.person_outline_rounded,
              hint: 'Your full name',
              validator: (v) =>
              v == null || v.trim().isEmpty ? 'Name is required' : null,
            ),
            const SizedBox(height: 16),
            _buildField(
              label: 'Phone Number',
              controller: _phoneController,
              icon: Icons.phone_outlined,
              hint: '+234 800 000 0000',
              keyboardType: TextInputType.phone,
            ),

            const SizedBox(height: 16),
            _buildField(
              label: 'Skills',
              controller: _skillsController,
              icon: Icons.bolt_rounded,
              hint: 'e.g. Web Developer, Design, Marketing',
              helperText: 'Separate skills with commas',
            ),

            const SizedBox(height: 28),

            // ── About ──
            _sectionLabel('ABOUT YOU'),
            const SizedBox(height: 12),
            _buildField(
              label: 'Bio',
              controller: _bioController,
              icon: Icons.notes_rounded,
              hint: 'Tell people about yourself...',
              maxLines: 4,
              helperText: 'Keep it short and professional',
            ),

            const SizedBox(height: 36),

            // ── Save Button ──
            GradientButton(
              label: 'Save Changes',
              onPressed: _save,
              isLoading: _isSaving,
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarSection() {
    return Center(
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [AppColors.gradientStart, AppColors.gradientEnd],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: _isUploadingPhoto
                      ? const Center(
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                      : _localImageFile != null
                      ? Image.file(_localImageFile!, fit: BoxFit.cover)
                      : _avatarUrl != null
                      ? Image.network(
                    _avatarUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(
                        Icons.person_rounded,
                        color: Colors.white,
                        size: 52),
                  )
                      : const Icon(Icons.person_rounded,
                      color: Colors.white, size: 52),
                ),
              ),
              Positioned(
                bottom: 2,
                right: 2,
                child: GestureDetector(
                  onTap: _showPhotoPicker,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.background, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.camera_alt_rounded,
                        color: Colors.white, size: 16),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: _showPhotoPicker,
            child: const Text(
              'Change Photo',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showPhotoPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Text(
              'Update Profile Photo',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 20),
            _sheetOption(
              icon: Icons.camera_alt_rounded,
              label: 'Take a Photo',
              color: AppColors.primary,
              onTap: () => _pickAndUploadPhoto(ImageSource.camera),
            ),
            const SizedBox(height: 12),
            _sheetOption(
              icon: Icons.photo_library_rounded,
              label: 'Choose from Gallery',
              color: const Color(0xFF10B981),
              onTap: () => _pickAndUploadPhoto(ImageSource.gallery),
            ),
            if (_avatarUrl != null || _localImageFile != null) ...[
              const SizedBox(height: 12),
              _sheetOption(
                icon: Icons.delete_outline_rounded,
                label: 'Remove Photo',
                color: AppColors.error,
                onTap: _removePhoto,
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _sheetOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Text(label,
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Text(label,
        style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textHint,
            letterSpacing: 0.5));
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    String? helperText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          validator: validator,
          style: const TextStyle(
              fontSize: 15,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle:
            const TextStyle(color: AppColors.textHint, fontSize: 14),
            helperText: helperText,
            helperStyle:
            const TextStyle(fontSize: 11, color: AppColors.textHint),
            prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
            filled: true,
            fillColor: AppColors.surface,
            contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.border)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                const BorderSide(color: AppColors.primary, width: 1.5)),
            errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.error)),
            focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                const BorderSide(color: AppColors.error, width: 1.5)),
          ),
        ),
      ],
    );
  }
}