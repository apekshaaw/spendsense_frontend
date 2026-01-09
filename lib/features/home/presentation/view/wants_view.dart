import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/network/auth_headers.dart';
import '../../../alerts/alerts_service.dart';

class WantsView extends StatefulWidget {
  const WantsView({super.key});

  @override
  State<WantsView> createState() => _WantsViewState();
}

class _WantsViewState extends State<WantsView> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _notesController = TextEditingController();

  bool _isLoading = false;

  _ReminderOption? _selectedOption;

  final List<_ReminderOption> _options = const [
    _ReminderOption(label: '10 seconds (test)', seconds: 10),
    _ReminderOption(label: '1 hour', minutes: 60),
    _ReminderOption(label: '6 hours', minutes: 360),
    _ReminderOption(label: '24 hours', minutes: 1440),
    _ReminderOption(label: '3 days', minutes: 4320),
    _ReminderOption(label: '1 week', minutes: 10080),
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String _extractWantIdFromCreateResponse(dynamic decoded) {
    // Supports multiple common backend shapes:
    // 1) { _id: "..." }
    // 2) { want: { _id: "..." } }
    // 3) { data: { _id: "..." } }
    if (decoded is Map) {
      final direct = decoded['_id'];
      if (direct != null) return direct.toString();

      final wantObj = decoded['want'];
      if (wantObj is Map && wantObj['_id'] != null) {
        return wantObj['_id'].toString();
      }

      final dataObj = decoded['data'];
      if (dataObj is Map && dataObj['_id'] != null) {
        return dataObj['_id'].toString();
      }
    }
    return '';
  }

  Duration _selectedDuration() {
    // safe fallback: 1 minute
    final opt = _selectedOption;
    if (opt == null) return const Duration(minutes: 1);
    if (opt.seconds != null) return Duration(seconds: opt.seconds!);
    return Duration(minutes: opt.minutes ?? 1);
  }

  Future<void> _submitWant() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_selectedOption == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a reminder time')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final headers = await AuthHeaders.json();

      final name = _nameController.text.trim();
      final price = double.parse(_priceController.text.trim());
      final notes = _notesController.text.trim();

      final duration = _selectedDuration();
      final remindAt = DateTime.now().add(duration).toIso8601String();

      final response = await http.post(
        Uri.parse('${ApiEndpoints.baseUrl}/api/wants'),
        headers: headers,
        body: jsonEncode({
          'name': name,
          'price': price,
          'notes': notes,
          'remindAt': remindAt,
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        dynamic decoded;
        try {
          decoded = jsonDecode(response.body);
        } catch (_) {
          decoded = null;
        }

        final wantId = _extractWantIdFromCreateResponse(decoded);

        // ✅ Log in-app alert that the temptation was created
        await AlertsService.instance.logAction(
          title: 'Temptation added ✅',
          message: 'You logged "$name" (Rs${price.toStringAsFixed(0)}).',
          wantId: wantId.isEmpty ? null : wantId,
        );

        if (wantId.isNotEmpty) {
          await AlertsService.instance.scheduleReminderForWant(
  wantId: wantId,
  after: duration,
  wantName: name,
  wantPrice: price,
);


          await AlertsService.instance.logAction(
            title: 'Timer started ⏱️',
            message: 'Reminder set for ${_selectedOption!.label}.',
            wantId: wantId,
          );
        } else {
          // If backend didn’t return wantId, we can’t attach actions to notification
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Saved, but could not schedule reminder (missing want id).'),
            ),
          );
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Temptation logged successfully')),
        );

        Navigator.of(context).pop();
      } else {
        dynamic data;
        try {
          data = jsonDecode(response.body);
        } catch (_) {
          data = null;
        }

        final message = (data is Map && data['message'] != null)
            ? data['message'].toString()
            : 'Failed to log temptation. Try again.';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } on Failure catch (f) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(f.message)),
      );
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
                    'ADD ITEM',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 8),
                const Center(
                  child: Text(
                    'LOG TEMPTATION',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  decoration: BoxDecoration(
                    color: AppColors.authCard,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    children: [
                      _Field(
                        label: 'Item Name',
                        hint: 'Name',
                        controller: _nameController,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter item name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      _Field(
                        label: 'Price',
                        hint: 'Enter price',
                        controller: _priceController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter price';
                          }
                          final num? parsed = num.tryParse(value.trim());
                          if (parsed == null || parsed <= 0) {
                            return 'Enter valid amount';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      _Field(
                        label: 'Notes',
                        hint: 'Add a short note',
                        controller: _notesController,
                        maxLines: 2,
                      ),
                      const SizedBox(height: 16),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Remind me after',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ..._options.map(
                            (opt) => ChoiceChip(
                              label: Text(opt.label),
                              selected: _selectedOption == opt,
                              onSelected: (_) => setState(() => _selectedOption = opt),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submitWant,
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
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'Save & Start Timer',
                            style: TextStyle(fontSize: 16, color: Colors.white),
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
                    child: const Text('Cancel', style: TextStyle(fontSize: 16)),
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

class _ReminderOption {
  final String label;
  final int? minutes;
  final int? seconds;

  const _ReminderOption({
    required this.label,
    this.minutes,
    this.seconds,
  }) : assert(
          (minutes != null) ^ (seconds != null),
          'Provide either minutes OR seconds (not both).',
        );
}

class _Field extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final int maxLines;

  const _Field({
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
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
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
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
