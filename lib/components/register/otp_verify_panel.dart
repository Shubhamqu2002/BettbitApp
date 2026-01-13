// lib/components/register/otp_verify_panel.dart
import 'package:flutter/material.dart';

class OtpVerifyPanel extends StatefulWidget {
  final String title;
  final String subtitle;
  final bool isLoading;
  final VoidCallback onBack;
  final ValueChanged<String> onCompleted;

  const OtpVerifyPanel({
    super.key,
    required this.title,
    required this.subtitle,
    required this.isLoading,
    required this.onBack,
    required this.onCompleted,
  });

  @override
  State<OtpVerifyPanel> createState() => _OtpVerifyPanelState();
}

class _OtpVerifyPanelState extends State<OtpVerifyPanel> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final boxSize = 46.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            InkWell(
              onTap: widget.isLoading ? null : widget.onBack,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.12)),
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded,
                    size: 16, color: Colors.white),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          widget.subtitle,
          style: TextStyle(
            color: Colors.white.withOpacity(0.75),
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 20),

        // Hidden input but we render boxes based on its text
        Opacity(
          opacity: 0,
          child: TextField(
            controller: _ctrl,
            focusNode: _focus,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: const InputDecoration(counterText: ""),
            onChanged: (v) {
              final digits = v.replaceAll(RegExp(r'[^0-9]'), '');
              if (digits != v) {
                _ctrl.text = digits;
                _ctrl.selection = TextSelection.collapsed(offset: digits.length);
              }
              setState(() {});
              if (digits.length == 6) widget.onCompleted(digits);
            },
          ),
        ),

        GestureDetector(
          onTap: () => _focus.requestFocus(),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(6, (i) {
              final ch = i < _ctrl.text.length ? _ctrl.text[i] : '';
              return Container(
                width: boxSize,
                height: boxSize,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: Colors.white.withOpacity(0.08),
                  border: Border.all(
                    color: ch.isNotEmpty
                        ? const Color(0xFF00C9A7).withOpacity(0.8)
                        : Colors.white.withOpacity(0.18),
                    width: 1.6,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00C9A7).withOpacity(0.12),
                      blurRadius: 16,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Text(
                  ch,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              );
            }),
          ),
        ),

        const SizedBox(height: 18),

        if (widget.isLoading)
          Row(
            children: const [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 10),
              Text("Verifying...",
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
            ],
          ),
      ],
    );
  }
}
