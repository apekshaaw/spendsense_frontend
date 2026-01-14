import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../../app/routes.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/network/auth_headers.dart';

class AddGoalView extends StatefulWidget {
  const AddGoalView({super.key});

  @override
  State<AddGoalView> createState() => _AddGoalViewState();
}

class _AddGoalViewState extends State<AddGoalView> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _targetController = TextEditingController();
  final _notesController = TextEditingController();

  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _targetController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _showGoalCreatedPopup(String goalName) async {
    if (!mounted) return;

    bool dismissed = false;

    // Auto-close after 5 seconds (if user doesn't tap OK)
    Future.delayed(const Duration(seconds: 5)).then((_) {
      if (!mounted) return;
      if (!dismissed && Navigator.of(context).canPop()) {
        Navigator.of(context).pop(); // closes dialog
      }
    });

    await showDialog(
      context: context,
      barrierDismissible: false, // user must tap OK (or wait 5s)
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text("Goal set! 🎉"),
          content: Text(
            "Your new goal “$goalName” is ready.\n\nLet’s keep the momentum going 🔥",
          ),
          actions: [
            TextButton(
              onPressed: () {
                dismissed = true;
                Navigator.of(context).pop();
              },
              child: const Text("OK"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _submitGoal() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);

    try {
      final headers = await AuthHeaders.json();

      final goalName = _nameController.text.trim();
      final targetAmount = double.parse(_targetController.text.trim());
      final notes = _notesController.text.trim();

      final response = await http.post(
        Uri.parse('${ApiEndpoints.baseUrl}/api/goals'),
        headers: headers,
        body: jsonEncode({
          'name': goalName,
          'targetAmount': targetAmount,
          'notes': notes,

          // ✅ IMPORTANT:
          // tells backend: this is a NEW goal, reset currentAmount to 0,
          // and archive/store previous goal in history.
          'resetProgress': true,
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        // ✅ 5 seconds popup + OK dismiss
        await _showGoalCreatedPopup(goalName);

        // ✅ Return to HomeView so Home reloads immediately
        // HomeView already does: pushNamed(AddGoal).then((_) => _loadHome());
        Navigator.of(context).pop(true);
      } else {
        dynamic data;
        try {
          data = jsonDecode(response.body);
        } catch (_) {
          data = null;
        }

        final message = (data is Map && data['message'] != null)
            ? data['message'].toString()
            : 'Failed to add goal. Please try again.';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } on Failure catch (f) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(f.message)),
      );

      if (f.message.toLowerCase().contains('no token')) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          AppRoutes.login,
          (route) => false,
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                ),
                const SizedBox(height: 8),
                const Center(
                  child: Text(
                    'ADD GOAL',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  decoration: BoxDecoration(
                    color: AppColors.authCard,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    children: [
                      _GoalTextField(
                        label: 'Goal Name',
                        hint: 'Name',
                        controller: _nameController,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter a goal name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      _GoalTextField(
                        label: 'Goal Target',
                        hint: 'Enter price',
                        controller: _targetController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter a target amount';
                          }
                          final num? parsed = num.tryParse(value.trim());
                          if (parsed == null || parsed <= 0) {
                            return 'Enter a valid amount';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      _GoalTextField(
                        label: 'Notes',
                        hint: 'Add a short note',
                        controller: _notesController,
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submitGoal,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Text(
                            'Add Goal',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(fontSize: 16),
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
}

class _GoalTextField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final int maxLines;

  const _GoalTextField({
    required this.label,
    required this.hint,
    required this.controller,
    this.keyboardType,
    this.validator,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          validator: validator,
          keyboardType: keyboardType,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}
