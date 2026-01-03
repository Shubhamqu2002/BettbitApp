// lib/components/register/email_register_tab.dart
import 'package:flutter/material.dart';

import '../primary_button.dart';
import '../text_input_field.dart';

class EmailRegisterTab extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController phoneController;
  final TextEditingController emailController;
  final TextEditingController passwordController;

  final bool isLoading;
  final bool obscurePassword;
  final VoidCallback onTogglePassword;

  final DateTime? selectedDob;
  final String? selectedGender;
  final VoidCallback onPickDob;
  final ValueChanged<String?> onGenderChanged;

  final String? nameError;
  final String? phoneError;
  final String? emailError;
  final String? passwordError;
  final String? dobError;
  final String? genderError;

  final Widget detectedCountryWidget;
  final VoidCallback onRegister;

  const EmailRegisterTab({
    super.key,
    required this.nameController,
    required this.phoneController,
    required this.emailController,
    required this.passwordController,
    required this.isLoading,
    required this.obscurePassword,
    required this.onTogglePassword,
    required this.selectedDob,
    required this.selectedGender,
    required this.onPickDob,
    required this.onGenderChanged,
    required this.nameError,
    required this.phoneError,
    required this.emailError,
    required this.passwordError,
    required this.dobError,
    required this.genderError,
    required this.detectedCountryWidget,
    required this.onRegister,
  });

  String _formatDob(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final da = d.day.toString().padLeft(2, '0');
    return '$y-$m-$da';
  }

  Widget _errorText(String? msg) {
    if (msg == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          msg,
          style: const TextStyle(color: Colors.redAccent, fontSize: 12),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          TextInputField(
            label: 'Full Name',
            hintText: 'Enter your full name',
            controller: nameController,
            prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
          ),
          _errorText(nameError),
          const SizedBox(height: 18),

          TextInputField(
            label: 'Phone Number',
            hintText: 'Enter your phone number',
            controller: phoneController,
            keyboardType: TextInputType.phone,
            prefixIcon: const Icon(Icons.phone_outlined, size: 20),
          ),
          _errorText(phoneError),
          const SizedBox(height: 18),

          TextInputField(
            label: 'Email',
            hintText: 'Enter your email',
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            prefixIcon: const Icon(Icons.email_outlined, size: 20),
          ),
          _errorText(emailError),
          const SizedBox(height: 18),

          // Password
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Set Password',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, letterSpacing: 0.3),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: passwordController,
                obscureText: obscurePassword,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.08),
                  hintText: 'Create a strong password',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 14),
                  prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20, color: Colors.white70),
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      size: 20,
                      color: Colors.white70,
                    ),
                    onPressed: onTogglePassword,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFF00C9A7), width: 2),
                  ),
                ),
                style: const TextStyle(color: Colors.white),
              ),
              _errorText(passwordError),
            ],
          ),
          const SizedBox(height: 18),

          // DOB + Gender row
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
                    _errorText(dobError),
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
                    _errorText(genderError),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          detectedCountryWidget,
          const SizedBox(height: 22),

          PrimaryButton(
            label: 'Register',
            onPressed: onRegister,
            isLoading: isLoading,
          ),
          const SizedBox(height: 18),

          Text.rich(
            TextSpan(
              text: 'By registering, you agree to our ',
              style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.6)),
              children: const [
                TextSpan(
                  text: 'Terms & Conditions',
                  style: TextStyle(
                    color: Color(0xFF00C9A7),
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
