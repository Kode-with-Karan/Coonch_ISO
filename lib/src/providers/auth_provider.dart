import 'dart:io';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

/// A simple ChangeNotifier that centralizes authentication state.
///
/// Responsibilities:
/// - Perform login/register via [ApiService]
/// - Persist token via [ApiService.setToken]
/// - Clear token on logout
/// - Expose current user profile (raw map) and auth status
class AuthProvider extends ChangeNotifier {
  final ApiService api;

  AuthProvider(this.api) {
    _init();
  }

  Map<String, dynamic>? _user;
  bool _loading = false;
  int _unreadNotifications = 0;

  Map<String, dynamic>? get user => _user;
  bool get loading => _loading;
  bool get isAuthenticated => _user != null;
  int get unreadNotifications => _unreadNotifications;

  Future<void> _init() async {
    // Try to fetch profile if a token is already present in ApiService
    _loading = true;
    notifyListeners();
    final expired = await api.isInactiveLongerThan(const Duration(hours: 24));
    if (expired) {
      await api.clearToken();
      _user = null;
      _loading = false;
      notifyListeners();
      return;
    }
    try {
      final res = await api.getProfile();
      if (res['success'] == 1 && res['data'] != null) {
        _user = Map<String, dynamic>.from(res['data'] as Map);
        await api.markActiveNow();
      } else {
        _user = null;
      }
    } catch (_) {
      // ignore: set to unauthenticated
      _user = null;
    }
    _loading = false;
    notifyListeners();
  }

  /// Load unread notifications count from the API and notify listeners.
  Future<void> loadUnreadCount() async {
    try {
      final count = await api.getUnreadNotificationsCount();
      _unreadNotifications = count;
      notifyListeners();
    } catch (_) {}
  }

  /// Set unread count locally (useful after marking read client-side)
  void setUnreadCount(int count) {
    _unreadNotifications = count;
    notifyListeners();
  }

  /// Attempt to log in. Returns the API response map for further handling.
  Future<Map<String, dynamic>> login(String email, String password) async {
    _loading = true;
    notifyListeners();
    try {
      final res = await api.login(username: email, password: password);

      // Refresh profile state
      try {
        final pr = await api.getProfile();
        if (pr['success'] == 1 && pr['data'] != null) {
          _user = Map<String, dynamic>.from(pr['data'] as Map);
          await api.markActiveNow();
        }
      } catch (_) {}

      return res;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Register using ApiService.register and initialize user state if token present.
  Future<Map<String, dynamic>> register({
    required String username,
    required String email,
    required String password,
    required String otp,
    String phone = '',
  }) async {
    _loading = true;
    notifyListeners();
    try {
      final res = await api.register(
          username: username,
          email: email,
          password: password,
          phone: phone,
          otp: otp);

      // If register persisted token, fetch profile
      try {
        final pr = await api.getProfile();
        if (pr['success'] == 1 && pr['data'] != null) {
          _user = Map<String, dynamic>.from(pr['data'] as Map);
          await api.markActiveNow();
        }
      } catch (_) {}

      return res;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    _loading = true;
    notifyListeners();
    try {
      await api.logLogout();
    } catch (_) {}
    await api.clearToken();
    _user = null;
    _loading = false;
    notifyListeners();
  }

  /// Refresh profile from backend
  Future<void> refreshProfile() async {
    _loading = true;
    notifyListeners();
    try {
      final pr = await api.getProfile();
      if (pr['success'] == 1 && pr['data'] != null) {
        _user = Map<String, dynamic>.from(pr['data'] as Map);
        await api.markActiveNow();
      }
    } catch (_) {}
    _loading = false;
    notifyListeners();
  }

  /// Update profile fields (sends PATCH to backend) and updates local user
  /// Update profile fields. Optionally include [avatar] to upload a new profile photo.
  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> data,
      {File? avatar}) async {
    _loading = true;
    notifyListeners();
    try {
      Map<String, dynamic> payload = Map<String, dynamic>.from(data);

      // If uploading avatar, we must use multipart and string fields
      if (avatar != null) {
        final fields = <String, String>{};
        payload.forEach((k, v) {
          if (v != null) fields[k] = v.toString();
        });
        final res = await api.updateProfileMultipart(fields, avatar: avatar);
        // handle response
        try {
          if (res['success'] == 1 && res['data'] != null) {
            _user = Map<String, dynamic>.from(res['data'] as Map);
          } else {
            // fallback: refresh profile
            await refreshProfile();
          }
        } catch (_) {
          await refreshProfile();
        }
        return res;
      }

      // JSON patch path supports complex fields like lists (social_links)
      final res = await api.updateProfile(payload);
      // If success, merge returned data into _user
      try {
        if (res['success'] == 1 && res['data'] != null) {
          _user = Map<String, dynamic>.from(res['data'] as Map);
          await api.markActiveNow();
        } else {
          // fallback: refresh profile
          await refreshProfile();
        }
      } catch (_) {
        await refreshProfile();
      }
      return res;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Change password
  Future<Map<String, dynamic>> updatePassword(
      String currentPassword, String newPassword) async {
    _loading = true;
    notifyListeners();
    try {
      final res = await api.updatePassword(currentPassword, newPassword);
      return res;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Request delete-account OTP
  Future<Map<String, dynamic>> requestDeleteAccountOtp() async {
    _loading = true;
    notifyListeners();
    try {
      final res = await api.requestDeleteAccountOtp();
      return res;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Delete current user's account using OTP verification.
  Future<Map<String, dynamic>> deleteAccount(String otp) async {
    _loading = true;
    notifyListeners();
    try {
      final res = await api.deleteAccount(otp);
      // On success clear local auth state
      if (res['success'] == 1) {
        await api.clearToken();
        _user = null;
      }
      return res;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Set selected categories for user
  Future<Map<String, dynamic>> setCategories(List<int> categories) async {
    _loading = true;
    notifyListeners();
    try {
      final res = await api.setCategories(categories);
      await refreshProfile();
      return res;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
