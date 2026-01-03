// lib/components/register/phone_register_tab.dart
import 'package:flutter/material.dart';

import '../primary_button.dart';
import '../text_input_field.dart';

class PhoneRegisterTab extends StatelessWidget {
  final TextEditingController fullNameController;
  final TextEditingController phoneController;
  final TextEditingController emailOptionalController;

  final DateTime? selectedDob;
  final String? selectedGender;
  final VoidCallback onPickDob;
  final ValueChanged<String?> onGenderChanged;

  final VoidCallback onRegister;
  final Widget detectedCountryWidget;

  const PhoneRegisterTab({
    super.key,
    required this.fullNameController,
    required this.phoneController,
    required this.emailOptionalController,
    required this.selectedDob,
    required this.selectedGender,
    required this.onPickDob,
    required this.onGenderChanged,
    required this.onRegister,
    required this.detectedCountryWidget,
  });

  String _formatDob(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final da = d.day.toString().padLeft(2, '0');
    return '$y-$m-$da';
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          // small info chip

          const SizedBox(height: 16),

          TextInputField(
            label: 'Full Name',
            hintText: 'Enter your full name',
            controller: fullNameController,
            prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
          ),
          const SizedBox(height: 18),

          TextInputField(
            label: 'Phone Number',
            hintText: 'Enter your phone number',
            controller: phoneController,
            keyboardType: TextInputType.phone,
            prefixIcon: const Icon(Icons.phone_outlined, size: 20),
          ),
          const SizedBox(height: 18),

          TextInputField(
            label: 'Email Address (Optional)',
            hintText: 'Enter email (optional)',
            controller: emailOptionalController,
            keyboardType: TextInputType.emailAddress,
            prefixIcon: const Icon(Icons.email_outlined, size: 20),
          ),
          const SizedBox(height: 18),

          // DOB + Gender
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Date of Birth',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, letterSpacing: 0.3),
                    ),
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: onPickDob,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white.withOpacity(0.2)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today_outlined, size: 18, color: Colors.white70),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                selectedDob == null ? 'Select DOB' : _formatDob(selectedDob!),
                                style: TextStyle(
                                  color: selectedDob == null
                                      ? Colors.white.withOpacity(0.4)
                                      : Colors.white,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Gender',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, letterSpacing: 0.3),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withOpacity(0.2)),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedGender,
                          hint: Text(
                            'Select gender',
                            style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 14),
                          ),
                          dropdownColor: const Color(0xFF05070A),
                          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white70),
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          items: const [
                            DropdownMenuItem(value: 'male', child: Text('Male')),
                            DropdownMenuItem(value: 'female', child: Text('Female')),
                            DropdownMenuItem(value: 'transgender', child: Text('Transgender')),
                          ],
                          onChanged: onGenderChanged,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ✅ Same detected text at last (as you asked)
          detectedCountryWidget,
          const SizedBox(height: 22),

          PrimaryButton(
            label: 'Register',
            onPressed: onRegister,
            isLoading: false,
          ),
        ],
      ),
    );
  }
}
