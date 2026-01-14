import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_colors.dart';
import '../view_model/profile_view_model.dart';
import '../view_model/profile_event.dart';
import '../view_model/profile_state.dart';

class EditProfileView extends StatefulWidget {
  const EditProfileView({super.key});

  @override
  State<EditProfileView> createState() => _EditProfileViewState();
}

class _EditProfileViewState extends State<EditProfileView> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();

  bool _darkTheme = false;
  String _avatarUrl = ""; // base64 or empty

  bool _initialized = false;
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // ✅ Prefill only once from current profile state
    if (_initialized) return;

    final state = context.read<ProfileViewModel>().state;
    final p = state.profile;

    if (p != null) {
      _nameCtrl.text = p.name;
      _emailCtrl.text = p.email;
      _phoneCtrl.text = p.phone;
      _darkTheme = p.darkMode;
      _avatarUrl = p.avatarUrl;
    }

    _initialized = true;
  }

  ImageProvider _avatarProvider(String avatarUrl) {
    if (avatarUrl.isEmpty) {
      return const AssetImage('assets/images/default_avatar.png');
    }
    try {
      final clean = avatarUrl.contains(',') ? avatarUrl.split(',').last : avatarUrl;
      final bytes = base64Decode(clean);
      return MemoryImage(bytes);
    } catch (_) {
      return const AssetImage('assets/images/default_avatar.png');
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final picker = ImagePicker();
      final XFile? picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70, // reduce size
      );

      if (picked == null) return;

      final file = File(picked.path);
      final bytes = await file.readAsBytes();
      final b64 = base64Encode(bytes);

      // ✅ store as base64 (can also prefix if you want)
      setState(() {
        _avatarUrl = b64;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to pick image: $e")),
      );
    }
  }

  void _saveProfile() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);

    context.read<ProfileViewModel>().add(
          UpdateProfile(
            name: _nameCtrl.text.trim(),
            email: _emailCtrl.text.trim(),
            phone: _phoneCtrl.text.trim(),
            darkMode: _darkTheme,
            avatarUrl: _avatarUrl,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ProfileViewModel, ProfileState>(
  listener: (context, state) {
    if (state.status == ProfileStatus.error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(state.errorMessage ?? "Something went wrong")),
      );
    }

    // ✅ If update succeeded, go back
    if (state.status == ProfileStatus.ready && _saving) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Profile updated ✅")),
      );
      Navigator.of(context).pop();
    }

    // stop loader if request ended (even if error)
    if (state.status != ProfileStatus.loading && _saving) {
      setState(() => _saving = false);
    }
  },
      child: Scaffold(
        backgroundColor: Colors.white,        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              children: [
                // Header
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const Spacer(),
                    const Text(
                      'PROFILE',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    const SizedBox(width: 48),
                  ],
                ),
                const SizedBox(height: 8),

                // Avatar (tap to change)
                GestureDetector(
                  onTap: _pickFromGallery,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 44,
                        backgroundImage: _avatarProvider(_avatarUrl),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Icon(
                            Icons.edit,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: _pickFromGallery,
                  child: const Text("Change photo"),
                ),

                const SizedBox(height: 12),

                Form(
                  key: _formKey,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                    decoration: BoxDecoration(
                      color: AppColors.authCard,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Username',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _nameCtrl,
                          decoration: _inputDecoration('Name'),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? 'Required' : null,
                        ),
                        const SizedBox(height: 14),

                        const Text(
                          'Email address',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _emailCtrl,
                          decoration: _inputDecoration('example@gmail.com'),
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Required';
                            if (!v.contains('@')) return 'Enter a valid email';
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        const Text(
                          'Phone',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _phoneCtrl,
                          decoration: _inputDecoration('Enter phone number'),
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 18),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Turn Dark Theme',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                            Switch(
                              value: _darkTheme,
                              onChanged: (val) => setState(() => _darkTheme = val),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving ? null : () async {
                      _saveProfile();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: _saving
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text(
                            'Update Profile',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
    );
  }
}
