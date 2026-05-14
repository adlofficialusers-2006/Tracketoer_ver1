import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

class AppUser {
  final String userId;
  final String name;
  final String email;
  final String passwordHash;
  final String role; // 'user' or 'admin'
  final String createdAt;

  const AppUser({
    required this.userId,
    required this.name,
    required this.email,
    required this.passwordHash,
    required this.role,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'name': name,
        'email': email,
        'passwordHash': passwordHash,
        'role': role,
        'createdAt': createdAt,
      };

  factory AppUser.fromMap(Map map) => AppUser(
        userId: map['userId'] as String? ?? 'unknown',
        name: map['name'] as String? ?? 'User',
        email: map['email'] as String? ?? '',
        passwordHash: map['passwordHash'] as String? ?? '',
        role: map['role'] as String? ?? 'user',
        createdAt:
            map['createdAt'] as String? ?? DateTime.now().toIso8601String(),
      );
}

class AuthService extends ChangeNotifier {
  static const _usersBoxName = 'users';
  static const _settingsBoxName = 'settings';

  // Default admin credentials (can be overridden by env at build time)
  static const _defaultAdminEmail = 'admin@natpac.in';
  static const _defaultAdminPassword = 'Admin@2024';

  AppUser? _currentUser;

  AppUser? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  String get currentRole => _currentUser?.role ?? '';
  String get currentUserId => _currentUser?.userId ?? '';
  String get currentUserName => _currentUser?.name ?? 'User';

  Box get _usersBox => Hive.box(_usersBoxName);
  Box get _settingsBox => Hive.box(_settingsBoxName);

  /// Call once after Hive boxes are open. Synchronous — Hive reads are sync.
  void initialize() {
    _ensureDefaultAdmin();
    _restoreSession();
  }

  void _ensureDefaultAdmin() {
    const adminKey = 'admin_$_defaultAdminEmail';
    if (_usersBox.containsKey(adminKey)) return;
    final admin = AppUser(
      userId: 'natpac_admin_001',
      name: 'NATPAC Admin',
      email: _defaultAdminEmail,
      passwordHash: _hashPassword(_defaultAdminPassword),
      role: 'admin',
      createdAt: DateTime.now().toIso8601String(),
    );
    _usersBox.put(adminKey, admin.toMap());
  }

  void _restoreSession() {
    final userId = _settingsBox.get('currentUserId') as String?;
    if (userId == null) return;
    for (final key in _usersBox.keys) {
      final raw = _usersBox.get(key);
      if (raw is! Map) continue;
      final map = Map<dynamic, dynamic>.from(raw);
      if (map['userId'] == userId) {
        _currentUser = AppUser.fromMap(map);
        return;
      }
    }
    // Session pointed to deleted user — clear it.
    _settingsBox.delete('currentUserId');
  }

  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    return sha256.convert(bytes).toString();
  }

  String _generateUserId() {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final rnd = Random().nextInt(99999);
    return 'usr_${ts}_$rnd';
  }

  /// Registers a new user. Returns an error string or null on success.
  Future<String?> register(String name, String email, String password) async {
    final emailKey = 'user_${email.toLowerCase().trim()}';
    if (_usersBox.containsKey(emailKey)) {
      return 'An account with this email already exists.';
    }
    final user = AppUser(
      userId: _generateUserId(),
      name: name.trim(),
      email: email.toLowerCase().trim(),
      passwordHash: _hashPassword(password),
      role: 'user',
      createdAt: DateTime.now().toIso8601String(),
    );
    await _usersBox.put(emailKey, user.toMap());
    await _persistSession(user);
    return null;
  }

  /// Logs in an existing user. Returns an error string or null on success.
  Future<String?> login(
    String email,
    String password, {
    String role = 'user',
  }) async {
    final prefix = role == 'admin' ? 'admin_' : 'user_';
    final key = '$prefix${email.toLowerCase().trim()}';
    final raw = _usersBox.get(key);
    if (raw == null) {
      return role == 'admin'
          ? 'No admin account found with this email.'
          : 'No account found with this email. Please register first.';
    }
    final user = AppUser.fromMap(Map<dynamic, dynamic>.from(raw as Map));
    if (user.passwordHash != _hashPassword(password)) {
      return 'Incorrect password.';
    }
    await _persistSession(user);
    return null;
  }

  Future<void> _persistSession(AppUser user) async {
    _currentUser = user;
    await _settingsBox.put('currentUserId', user.userId);
    notifyListeners();
  }

  Future<void> logout() async {
    _currentUser = null;
    await _settingsBox.delete('currentUserId');
    notifyListeners();
  }

  // ── Location consent ──────────────────────────────────────────────────────

  bool get hasLocationConsent =>
      (_settingsBox.get('location_consent_given') as bool?) ?? false;

  /// Called by ConsentScreen after permission is granted. Persists to Hive
  /// and notifies listeners so _AuthGate re-routes to HomeScreen.
  Future<void> notifyConsentGranted() async {
    await _settingsBox.put('location_consent_given', true);
    notifyListeners();
  }

  /// Returns all registered non-admin users.
  List<AppUser> getAllUsers() {
    return _usersBox.values
        .whereType<Map>()
        .map((m) => AppUser.fromMap(Map<dynamic, dynamic>.from(m)))
        .where((u) => u.role == 'user')
        .toList();
  }

  /// Changes the current user's password. Returns an error string or null.
  Future<String?> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    final user = _currentUser;
    if (user == null) return 'Not logged in.';
    if (user.passwordHash != _hashPassword(currentPassword)) {
      return 'Current password is incorrect.';
    }
    final updated = AppUser(
      userId: user.userId,
      name: user.name,
      email: user.email,
      passwordHash: _hashPassword(newPassword),
      role: user.role,
      createdAt: user.createdAt,
    );
    final prefix = user.role == 'admin' ? 'admin_' : 'user_';
    final key = '$prefix${user.email}';
    await _usersBox.put(key, updated.toMap());
    _currentUser = updated;
    notifyListeners();
    return null;
  }

  /// Looks up a user by their userId (for display in admin dashboard).
  AppUser? getUserById(String userId) {
    for (final key in _usersBox.keys) {
      final raw = _usersBox.get(key);
      if (raw is! Map) continue;
      final map = Map<dynamic, dynamic>.from(raw);
      if (map['userId'] == userId) return AppUser.fromMap(map);
    }
    return null;
  }
}
