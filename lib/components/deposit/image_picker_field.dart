import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'deposit_theme.dart';

class ImagePickerField extends StatefulWidget {
  final String title;
  final String subtitle;
  final File? initialFile;
  final ValueChanged<File?> onChanged;

  const ImagePickerField({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onChanged,
    this.initialFile,
  });

  @override
  State<ImagePickerField> createState() => _ImagePickerFieldState();
}

class _ImagePickerFieldState extends State<ImagePickerField> {
  File? _file;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _file = widget.initialFile;
  }

  Future<void> _pick(ImageSource source) async {
    final XFile? picked = await _picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1800,
    );
    if (picked == null) return;
    final f = File(picked.path);
    setState(() => _file = f);
    widget.onChanged(f);
  }

  void _openSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Container(
          margin: const EdgeInsets.all(14),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(
              colors: [DepositTheme.c2, DepositTheme.c3],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 30,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 52,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.35),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  "Upload Proof",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.95),
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 14),

                _SheetTile(
                  icon: Icons.camera_alt_rounded,
                  title: "Camera",
                  subtitle: "Take a new photo",
                  onTap: () async {
                    Navigator.pop(context);
                    await _pick(ImageSource.camera);
                  },
                ),
                const SizedBox(height: 10),
                _SheetTile(
                  icon: Icons.photo_library_rounded,
                  title: "Gallery",
                  subtitle: "Choose from your photos",
                  onTap: () async {
                    Navigator.pop(context);
                    await _pick(ImageSource.gallery);
                  },
                ),
                const SizedBox(height: 12),

                if (_file != null)
                  TextButton.icon(
                    onPressed: () {
                      setState(() => _file = null);
                      widget.onChanged(null);
                    },
                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.white),
                    label: const Text("Remove selected", style: TextStyle(color: Colors.white)),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _openSheet,
      borderRadius: BorderRadius.circular(22),
      child: Ink(
        decoration: DepositTheme.glassCard(),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: LinearGradient(
                    colors: [
                      DepositTheme.c1.withOpacity(0.95),
                      DepositTheme.c3.withOpacity(0.95),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: _file == null
                      ? Icon(Icons.cloud_upload_rounded, color: Colors.white.withOpacity(0.95), size: 30)
                      : Image.file(_file!, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.95),
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _file == null ? widget.subtitle : "Selected ✅ Tap to change",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.70),
                        fontSize: 12.5,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(Icons.chevron_right_rounded, color: Colors.white.withOpacity(0.85)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SheetTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: Colors.white.withOpacity(0.12),
          border: Border.all(color: Colors.white.withOpacity(0.18)),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
