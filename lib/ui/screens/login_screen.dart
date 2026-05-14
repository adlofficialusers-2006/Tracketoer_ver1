import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../modules/auth/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildTabBar(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: const [_UserTab(), _AdminTab()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.neonPurple.withValues(alpha: 0.5),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.asset(
                    'assets/images/logo.jpeg',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'NATPAC',
                    style: TextStyle(
                      color: AppColors.neonPurple,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                  Text(
                    'Travel Tracker',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Welcome back',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Sign in to continue capturing your travel data.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: TabBar(
          controller: _tabController,
          dividerColor: Colors.transparent,
          indicator: BoxDecoration(
            color: AppColors.neonPurple.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.neonPurple.withValues(alpha: 0.6),
            ),
          ),
          labelColor: Colors.white,
          unselectedLabelColor: AppColors.textSecondary,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
          tabs: const [Tab(text: 'User'), Tab(text: 'Admin')],
        ),
      ),
    );
  }
}

// ── User tab (login + register toggle) ───────────────────────────────────────

class _UserTab extends StatefulWidget {
  const _UserTab();

  @override
  State<_UserTab> createState() => _UserTabState();
}

class _UserTabState extends State<_UserTab> {
  bool _showRegister = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      child: _showRegister
          ? _RegisterForm(
              key: const ValueKey('reg'),
              onBackToLogin: () => setState(() => _showRegister = false),
            )
          : _LoginForm(
              key: const ValueKey('login'),
              role: 'user',
              onRegisterTap: () => setState(() => _showRegister = true),
            ),
    );
  }
}

// ── Admin tab (login only) ────────────────────────────────────────────────────

class _AdminTab extends StatelessWidget {
  const _AdminTab();

  @override
  Widget build(BuildContext context) {
    return const _LoginForm(role: 'admin');
  }
}

// ── Shared login form ─────────────────────────────────────────────────────────

class _LoginForm extends StatefulWidget {
  const _LoginForm({super.key, required this.role, this.onRegisterTap});

  final String role;
  final VoidCallback? onRegisterTap;

  @override
  State<_LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<_LoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    final error = await context.read<AuthService>().login(
          _emailCtrl.text,
          _passwordCtrl.text,
          role: widget.role,
        );

    if (!mounted) return;
    setState(() => _loading = false);

    if (error != null) {
      setState(() => _error = error);
    }
    // On success, AuthService.notifyListeners() fires → _AuthGate re-routes.
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.role == 'admin') ...[
              _InfoBanner(
                icon: Icons.admin_panel_settings_rounded,
                text: 'Default credentials:\nadmin@natpac.in / Admin@2024',
                color: AppColors.neonBlue,
              ),
              const SizedBox(height: 16),
            ],
            _AppField(
              controller: _emailCtrl,
              label: 'Email address',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Email is required';
                if (!v.contains('@')) return 'Enter a valid email';
                return null;
              },
            ),
            const SizedBox(height: 16),
            _AppField(
              controller: _passwordCtrl,
              label: 'Password',
              icon: Icons.lock_outline_rounded,
              obscureText: _obscure,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscure
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: AppColors.textSecondary,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Password is required' : null,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              _InfoBanner(
                icon: Icons.error_outline,
                text: _error!,
                color: Colors.redAccent,
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.role == 'admin'
                      ? AppColors.neonBlue
                      : AppColors.neonPurple,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.black,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        widget.role == 'admin' ? 'Sign in as Admin' : 'Sign in',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            if (widget.onRegisterTap != null) ...[
              const SizedBox(height: 20),
              Center(
                child: TextButton(
                  onPressed: widget.onRegisterTap,
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                      children: [
                        const TextSpan(text: "Don't have an account? "),
                        TextSpan(
                          text: 'Register',
                          style: TextStyle(
                            color: AppColors.neonPurple,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Register form ─────────────────────────────────────────────────────────────

class _RegisterForm extends StatefulWidget {
  const _RegisterForm({super.key, required this.onBackToLogin});

  final VoidCallback onBackToLogin;

  @override
  State<_RegisterForm> createState() => _RegisterFormState();
}

class _RegisterFormState extends State<_RegisterForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    final error = await context.read<AuthService>().register(
          _nameCtrl.text,
          _emailCtrl.text,
          _passwordCtrl.text,
        );

    if (!mounted) return;
    setState(() => _loading = false);

    if (error != null) {
      setState(() => _error = error);
    }
    // On success, AuthService.notifyListeners() fires → _AuthGate re-routes.
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _AppField(
              controller: _nameCtrl,
              label: 'Full name',
              icon: Icons.person_outline_rounded,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Name is required' : null,
            ),
            const SizedBox(height: 16),
            _AppField(
              controller: _emailCtrl,
              label: 'Email address',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Email is required';
                if (!v.contains('@')) return 'Enter a valid email';
                return null;
              },
            ),
            const SizedBox(height: 16),
            _AppField(
              controller: _passwordCtrl,
              label: 'Password (min. 6 characters)',
              icon: Icons.lock_outline_rounded,
              obscureText: _obscure,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscure
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: AppColors.textSecondary,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Password is required';
                if (v.length < 6) return 'At least 6 characters required';
                return null;
              },
            ),
            const SizedBox(height: 16),
            _AppField(
              controller: _confirmCtrl,
              label: 'Confirm password',
              icon: Icons.lock_outline_rounded,
              obscureText: _obscure,
              validator: (v) =>
                  v != _passwordCtrl.text ? 'Passwords do not match' : null,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              _InfoBanner(
                icon: Icons.error_outline,
                text: _error!,
                color: Colors.redAccent,
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.neonPurple,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.black,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Create account',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: TextButton(
                onPressed: widget.onBackToLogin,
                child: RichText(
                  text: TextSpan(
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                    children: [
                      const TextSpan(text: 'Already have an account? '),
                      TextSpan(
                        text: 'Sign in',
                        style: TextStyle(
                          color: AppColors.neonPurple,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Reusable form field ───────────────────────────────────────────────────────

class _AppField extends StatelessWidget {
  const _AppField({
    required this.controller,
    required this.label,
    required this.icon,
    this.obscureText = false,
    this.suffixIcon,
    this.keyboardType,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscureText;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: AppColors.textSecondary),
        prefixIcon: Icon(icon, color: AppColors.textSecondary, size: 20),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.neonPurple, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
        ),
      ),
    );
  }
}

// ── Info / error banner ───────────────────────────────────────────────────────

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: color, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

