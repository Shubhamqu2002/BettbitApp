import 'package:flutter/material.dart';
import '../../services/profile_service.dart';
import '../../services/update_profile_service.dart';

class AccountInfoSection extends StatefulWidget {
  final GamerProfile profile;

  /// DOB state controlled outside
  final DateTime? dob;
  final VoidCallback onPickDob;

  final TextEditingController fullNameController;
  final TextEditingController emailController;
  final TextEditingController phoneController;

  const AccountInfoSection({
    super.key,
    required this.profile,
    required this.dob,
    required this.onPickDob,
    required this.fullNameController,
    required this.emailController,
    required this.phoneController,
  });

  @override
  State<AccountInfoSection> createState() => _AccountInfoSectionState();
}

class _AccountInfoSectionState extends State<AccountInfoSection> {
  bool _savingName = false;
  bool _savingDob = false;

  // banner
  String? _bannerText;
  bool _bannerSuccess = false;

  // track originals to detect changes
  late String _initialFullName;
  DateTime? _initialDob;

  // dirty flags
  bool _nameDirty = false;
  bool _dobDirty = false;

  @override
  void initState() {
    super.initState();

    _initialFullName = widget.fullNameController.text.trim();
    _initialDob = widget.dob;

    widget.fullNameController.addListener(_onNameChanged);
    _recalcDobDirty();
  }

  @override
  void didUpdateWidget(covariant AccountInfoSection oldWidget) {
    super.didUpdateWidget(oldWidget);

    // DOB changed by parent date picker
    if (oldWidget.dob != widget.dob) {
      _recalcDobDirty();
    }

    // If initial name was empty but controller got populated later
    if (_initialFullName.isEmpty && widget.fullNameController.text.trim().isNotEmpty) {
      _initialFullName = widget.fullNameController.text.trim();
      _onNameChanged();
    }
  }

  @override
  void dispose() {
    widget.fullNameController.removeListener(_onNameChanged);
    super.dispose();
  }

  void _onNameChanged() {
    final now = widget.fullNameController.text.trim();
    final dirty = now != _initialFullName;
    if (dirty != _nameDirty) {
      setState(() => _nameDirty = dirty);
    }
  }

  void _recalcDobDirty() {
    final dirty = !_sameDate(widget.dob, _initialDob);
    if (dirty != _dobDirty) {
      setState(() => _dobDirty = dirty);
    }
  }

  bool _sameDate(DateTime? a, DateTime? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _formatDob(DateTime? dob) {
    if (dob == null) return 'Not set';
    final y = dob.year.toString().padLeft(4, '0');
    final m = dob.month.toString().padLeft(2, '0');
    final d = dob.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  void _showBanner({required bool success, required String text}) {
    setState(() {
      _bannerSuccess = success;
      _bannerText = text;
    });

    Future.delayed(const Duration(seconds: 4), () {
      if (!mounted) return;
      setState(() => _bannerText = null);
    });
  }

  String _bestGamerId(GamerProfile p) {
    final dynamic maybeId = (p as dynamic).gamerId ??
        (p as dynamic).id ??
        (p as dynamic).userId ??
        (p as dynamic).uuid;

    return (maybeId?.toString().trim() ?? "");
  }

  Future<void> _saveNameOnly() async {
    if (_savingName || !_nameDirty) return;

    final name = widget.fullNameController.text.trim();
    if (name.isEmpty) {
      _showBanner(success: false, text: "Full Name can’t be empty.");
      return;
    }

    final gamerId = _bestGamerId(widget.profile);
    if (gamerId.isEmpty) {
      _showBanner(success: false, text: "GamerId not found in profile.");
      return;
    }

    setState(() => _savingName = true);

    final result = await UpdateProfileService.updateProfile(
      gamerId: gamerId,
      firstName: name, // only this field
      dob: null,
    );

    setState(() => _savingName = false);

    if (result.success) {
      // ✅ Update baseline so dirty becomes false after success
      _initialFullName = name;
      setState(() => _nameDirty = false);

      // ✅ Banner success
      _showBanner(success: true, text: result.message);
      // ✅ Header is already bound to controller, so it updates instantly
    } else {
      final code = result.statusCode;
      final codeText = code <= 0 ? "" : " (HTTP $code)";
      _showBanner(success: false, text: "${result.message}$codeText");
    }
  }

  Future<void> _saveDobOnly() async {
    if (_savingDob || !_dobDirty) return;

    if (widget.dob == null) {
      _showBanner(success: false, text: "Please select your Date of Birth.");
      return;
    }

    final gamerId = _bestGamerId(widget.profile);
    if (gamerId.isEmpty) {
      _showBanner(success: false, text: "GamerId not found in profile.");
      return;
    }

    setState(() => _savingDob = true);

    final result = await UpdateProfileService.updateProfile(
      gamerId: gamerId,
      firstName: null,
      dob: _formatDob(widget.dob), // only this field
    );

    setState(() => _savingDob = false);

    if (result.success) {
      _initialDob = widget.dob;
      setState(() => _dobDirty = false);
      _showBanner(success: true, text: result.message);
    } else {
      final code = result.statusCode;
      final codeText = code <= 0 ? "" : " (HTTP $code)";
      _showBanner(success: false, text: "${result.message}$codeText");
    }
  }

  Widget _banner() {
    if (_bannerText == null) return const SizedBox.shrink();

    final bg = _bannerSuccess
        ? const LinearGradient(
            colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : const LinearGradient(
            colors: [Color(0xFFF97316), Color(0xFFEF4444)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );

    final icon = _bannerSuccess ? Icons.check_circle_rounded : Icons.error_rounded;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: bg,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _bannerText!,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(
            onPressed: () => setState(() => _bannerText = null),
            icon: const Icon(Icons.close_rounded, color: Colors.white),
            splashRadius: 18,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF3B82F6), Color(0xFFA855F7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF3B82F6).withOpacity(0.35),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(icon, size: 20, color: Colors.white),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: 0.6),
        ),
      ],
    );
  }

  Widget _miniSaveButton({
    required bool visible,
    required bool loading,
    required VoidCallback onTap,
  }) {
    if (!visible) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(right: 6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF3B82F6), Color(0xFFA855F7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3B82F6).withOpacity(0.25),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: loading ? null : onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (loading) ...[
                  const SizedBox(
                    height: 14,
                    width: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    "Saving",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12),
                  ),
                ] else ...[
                  const Icon(Icons.check_rounded, size: 18, color: Colors.white),
                  const SizedBox(width: 6),
                  const Text(
                    "Save",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextFieldCard({
    required IconData icon,
    required String label,
    required TextEditingController controller,
    TextInputType? keyboardType,
    bool enabled = true,
    Widget? trailing,
    bool showEditIcon = true,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [Colors.white.withOpacity(0.06), Colors.white.withOpacity(0.02)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white.withOpacity(0.12), width: 1.4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              enabled: enabled && !_savingName && !_savingDob,
              readOnly: !enabled,
              keyboardType: keyboardType,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: enabled ? Colors.white : Colors.white.withOpacity(0.75),
              ),
              decoration: InputDecoration(
                labelText: label,
                labelStyle: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withOpacity(0.6),
                  fontWeight: FontWeight.w600,
                ),
                prefixIcon: Container(
                  margin: const EdgeInsets.all(12),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFFA855F7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 18, color: Colors.white),
                ),
                suffixIcon: showEditIcon
                    ? Icon(
                        enabled ? Icons.edit_rounded : Icons.lock_rounded,
                        size: 18,
                        color: Colors.white.withOpacity(enabled ? 0.4 : 0.55),
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              ),
            ),
          ),
          if (trailing != null) trailing,
          const SizedBox(width: 6),
        ],
      ),
    );
  }

  Widget _buildInfoRow({required IconData icon, required String label, required String value}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          colors: [Colors.white.withOpacity(0.06), Colors.white.withOpacity(0.02)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF3B82F6), Color(0xFFA855F7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withOpacity(0.52),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value.isEmpty ? '—' : value,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _banner(),

        // ✅ HEADER: now bound to controller so it updates instantly
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: widget.fullNameController,
          builder: (context, value, _) {
            final liveName = value.text.trim().isEmpty ? p.fullName : value.text.trim();
            final avatarLetter = liveName.isNotEmpty ? liveName[0].toUpperCase() : 'U';

            return Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4C1D95), Color(0xFF1D4ED8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1D4ED8).withOpacity(0.55),
                    blurRadius: 22,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withOpacity(0.4), width: 3),
                    ),
                    child: CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.white.withOpacity(0.18),
                      child: Text(
                        avatarLetter,
                        style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    liveName,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.6,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.16),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '@${p.userName}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),

        const SizedBox(height: 28),

        _buildSectionTitle('Editable Information', Icons.edit_rounded),
        const SizedBox(height: 16),

        _buildTextFieldCard(
          icon: Icons.person_rounded,
          label: 'Full Name',
          controller: widget.fullNameController,
          enabled: true,
          trailing: _miniSaveButton(
            visible: _nameDirty,
            loading: _savingName,
            onTap: _saveNameOnly,
          ),
        ),

        _buildTextFieldCard(
          icon: Icons.email_rounded,
          label: 'Email Address',
          controller: widget.emailController,
          keyboardType: TextInputType.emailAddress,
          enabled: false,
        ),

        _buildTextFieldCard(
          icon: Icons.phone_rounded,
          label: 'Phone Number',
          controller: widget.phoneController,
          keyboardType: TextInputType.phone,
          enabled: false,
        ),

        // DOB
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [Colors.white.withOpacity(0.06), Colors.white.withOpacity(0.02)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: Colors.white.withOpacity(0.12), width: 1.4),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Date of Birth',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.64),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  _miniSaveButton(
                    visible: _dobDirty,
                    loading: _savingDob,
                    onTap: _saveDobOnly,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: (_savingDob || _savingName) ? null : widget.onPickDob,
                child: Opacity(
                  opacity: (_savingDob || _savingName) ? 0.6 : 1,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF3B82F6), Color(0xFFA855F7)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF3B82F6).withOpacity(0.4),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.22),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.cake_rounded, size: 18, color: Colors.white),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _formatDob(widget.dob),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const Icon(Icons.edit_calendar_rounded, size: 20, color: Colors.white),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 28),

        _buildSectionTitle('Account Details', Icons.info_rounded),
        const SizedBox(height: 16),

        _buildInfoRow(icon: Icons.flag_rounded, label: 'Country', value: p.country),
        _buildInfoRow(icon: Icons.currency_exchange_rounded, label: 'Currency', value: p.currency),

        const SizedBox(height: 24),
      ],
    );
  }
}
