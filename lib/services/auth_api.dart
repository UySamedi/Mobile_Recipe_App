import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthApi {
  static final Dio _dio = Dio();

  static String _authHeaderValue(String token) {
    final normalized = token.trim();
    if (normalized.toLowerCase().startsWith('bearer ')) {
      return normalized;
    }
    return 'Bearer $normalized';
  }

  static String? _readAccessToken(SharedPreferences prefs) {
    return (prefs.getString('access_token') ?? prefs.getString('token'))
        ?.trim();
  }

  static String get baseUrl {
    if (kIsWeb) {
      return "http://localhost:8080";
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      // Android emulator uses 10.0.2.2 to reach the host machine's localhost
      return "http://10.0.2.2:8080";
    }

    return "http://localhost:8080";
  }

  /// Get current user profile (protected endpoint)
  /// GET {{base_url}}/api/auth/me
  static Future<Map<String, dynamic>> getProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = _readAccessToken(prefs);

      if (token == null || token.isEmpty) {
        throw Exception('No authentication token found');
      }

      final response = await _dio.get(
        '$baseUrl/api/auth/me',
        options: Options(
          headers: {
            'Authorization': _authHeaderValue(token),
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200) {
        return response.data as Map<String, dynamic>;
      } else {
        throw Exception(
          'Failed to fetch profile: ${response.statusCode} - ${response.statusMessage}',
        );
      }
    } catch (e) {
      throw Exception('Error fetching profile: $e');
    }
  }

  /// Update user profile with optional image upload (protected endpoint)
  /// PUT {{base_url}}/api/auth/profile
  /// Body type: form-data
  /// - name (Text): User name
  /// - profile_image (File): Profile image file
  static Future<Map<String, dynamic>> updateProfile({
    required String name,
    String? imagePath,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = _readAccessToken(prefs);

      if (token == null || token.isEmpty) {
        throw Exception('No authentication token found');
      }

      // Create form data
      FormData formData = FormData.fromMap({'name': name});

      // Add image if provided
      if (imagePath != null && imagePath.isNotEmpty) {
        formData.files.add(
          MapEntry(
            'profile_image',
            await MultipartFile.fromFile(
              imagePath,
              filename: imagePath.split('/').last,
            ),
          ),
        );
      }

      final response = await _dio.put(
        '$baseUrl/api/auth/profile',
        data: formData,
        options: Options(headers: {'Authorization': _authHeaderValue(token)}),
      );

      if (response.statusCode == 200) {
        return response.data as Map<String, dynamic>;
      } else {
        throw Exception(
          'Failed to update profile: ${response.statusCode} - ${response.statusMessage}',
        );
      }
    } catch (e) {
      throw Exception('Error updating profile: $e');
    }
  }

  /// Logout user - clears local data
  static Future<void> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Keep user rating history across sessions, clear only auth/session data.
      await prefs.remove('token');
      await prefs.remove('access_token');
      await prefs.remove('name');
      await prefs.remove('email');
      await prefs.remove('profile_image');
    } catch (e) {
      throw Exception('Error logging out: $e');
    }
  }
}
