import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../modules/auth/auth_service.dart';
import '../../modules/storage/local_db.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final LocalDB _db = LocalDB();

  // ── Change password ────────────────────────────────────────────────────────

  void _showChangePasswordSheet(AuthService auth) {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    String? error;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            final bottomPad = MediaQuery.of(ctx).viewInsets.bottom;
            return Padding(
              padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomPad),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Change Password',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _PasswordField(
                      controller: currentCtrl,
                      label: 'Current password',
                    ),
                    const SizedBox(height: 14),
                    _PasswordField(
                      controller: newCtrl,
                      label: 'New password',
                      validator: (v) =>
                          (v != null && v.length >= 6) ? null : 'Min 6 chars',
                    ),
                    const SizedBox(height: 14),
                    _PasswordField(
                      controller: confirmCtrl,
                      label: 'Confirm new password',
                      validator: (v) =>
                          v == newCtrl.text ? null : 'Passwords do not match',
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        error!,
                        style: const TextStyle(
                            color: Colors.redAccent, fontSize: 13),
                      ),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.neonBlue,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () async {
                          if (!formKey.currentState!.validate()) return;
                          final err = await auth.changePassword(
                            currentCtrl.text,
                            newCtrl.text,
                          );
                          if (err != null) {
                            setSheet(() => error = err);
                          } else {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('Password updated.'),
                                backgroundColor: AppColors.neonBlue,
                              ),
                            );
                          }
                        },
                        child: const Text(
                          'Update Password',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ── Clear local data ───────────────────────────────────────────────────────

  void _confirmClearData() {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Clear local trip data?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'This will permanently delete all trips saved on this device. '
          'Trips already synced to the server are not affected.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              _db.box.clear();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Local trip data cleared.'),
                  backgroundColor: Colors.redAccent,
                ),
              );
            },
            child: const Text('Clear',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final user = auth.currentUser;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Settings'),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── Profile card ─────────────────────────────────────────────────
          _SectionCard(
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor:
                        AppColors.neonPurple.withValues(alpha: 0.2),
                    child: Text(
                      _initials(user?.name ?? '?'),
                      style: TextStyle(
                        color: AppColors.neonPurple,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.name ?? 'User',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user?.email ?? '',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.neonBlue.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'NATPAC Contributor',
                            style: TextStyle(
                                color: AppColors.neonBlue, fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Account ──────────────────────────────────────────────────────
          _SectionLabel(label: 'Account'),
          _SectionCard(
            children: [
              _SettingsTile(
                icon: Icons.lock_outline_rounded,
                label: 'Change Password',
                onTap: () => _showChangePasswordSheet(auth),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Data ─────────────────────────────────────────────────────────
          _SectionLabel(label: 'Data'),
          _SectionCard(
            children: [
              _SettingsTile(
                icon: Icons.delete_outline_rounded,
                label: 'Clear local trip data',
                destructive: true,
                onTap: _confirmClearData,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── About ─────────────────────────────────────────────────────────
          _SectionLabel(label: 'About'),
          _SectionCard(
            children: [
              _SettingsTile(
                icon: Icons.info_outline_rounded,
                label: 'NATPAC Travel Tracker',
                subtitle: 'v1.0.0',
                onTap: null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: children
            .expand((child) sync* {
              yield child;
              if (child != children.last) {
                yield Divider(
                    height: 1, color: AppColors.border, indent: 52);
              }
            })
            .toList(),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.label,
    this.subtitle,
    this.destructive = false,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final bool destructive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? Colors.redAccent : Colors.white;
    return ListTile(
      leading: Icon(icon, color: color, size: 22),
      title: Text(label, style: TextStyle(color: color, fontSize: 15)),
      subtitle: subtitle != null
          ? Text(subtitle!,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12))
          : null,
      trailing: onTap != null
          ? Icon(Icons.chevron_right_rounded,
              color: AppColors.textSecondary, size: 20)
          : null,
      onTap: onTap,
    );
  }
}

class _PasswordField extends StatefulWidget {
  const _PasswordField({
    required this.controller,
    required this.label,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final FormFieldValidator<String>? validator;

  @override
  State<_PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<_PasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: _obscure,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: widget.label,
        labelStyle: TextStyle(color: AppColors.textSecondary),
        filled: true,
        fillColor: AppColors.panel,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        suffixIcon: IconButton(
          icon: Icon(
            _obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
            color: AppColors.textSecondary,
            size: 20,
          ),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
      ),
      validator: widget.validator ??
          (v) => (v == null || v.isEmpty) ? 'Required' : null,
    );
  }
}
