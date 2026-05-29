import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../Screen/Bottom_nav_bar/Main_Nav_Bar.dart';
import 'RegisterScreen.dart';

// Change API base URL for mobile access
const String apiBaseUrl = 'http://10.0.2.2:8080'; // For Android emulator
// If using a physical device, replace with your PC's IP, e.g. 'http://192.168.1.100:8080'

class Loginscreen extends StatefulWidget {
  const Loginscreen({super.key});

  @override
  State<Loginscreen> createState() => _LoginscreenState();
}

class _LoginscreenState extends State<Loginscreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _rememberMe = false;
  bool _obscurePassword = true;

  String? _extractAccessToken(dynamic responseBody) {
    if (responseBody is! Map<String, dynamic>) {
      return null;
    }

    final direct =
        responseBody['access_token'] ??
        responseBody['accessToken'] ??
        responseBody['token'] ??
        responseBody['jwt'];
    if (direct != null && direct.toString().trim().isNotEmpty) {
      return direct.toString().trim();
    }

    final data = responseBody['data'];
    if (data is Map<String, dynamic>) {
      final nested =
          data['access_token'] ??
          data['accessToken'] ??
          data['token'] ??
          data['jwt'];
      if (nested != null && nested.toString().trim().isNotEmpty) {
        return nested.toString().trim();
      }
    }

    return null;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 16.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Column(
                    children: [
                      const Text(
                        'ចូលគណនី',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'បញ្ចូលអ៊ីមែល និងពាក្យសម្ងាត់របស់អ្នក ដើម្បីចូលប្រើប្រាស់គណនី និងគ្រប់គ្រងសេវាកម្មរបស់អ្នកដោយសុវត្ថិភាព។',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 15, color: Colors.black54),
                      ),
                      const SizedBox(height: 32),
                      Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _emailController,
                              decoration: InputDecoration(
                                prefixIcon: const Icon(Icons.person),
                                hintText: 'អ៊ីមែល',
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'សូមបញ្ចូលអ៊ីមែលរបស់អ្នក';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              decoration: InputDecoration(
                                prefixIcon: const Icon(Icons.lock_outline),
                                hintText: 'ពាក្យសម្ងាត់',
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  borderSide: BorderSide.none,
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'សូមបញ្ចូលពាក្យសម្ងាត់របស់អ្នក';
                                }
                                if (value.length < 6) {
                                  return 'ពាក្យសម្ងាត់ត្រូវមានយ៉ាងហោចណាស់ ៦ តួអក្សរ';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Checkbox(
                                  value: _rememberMe,
                                  onChanged: (val) {
                                    setState(() {
                                      _rememberMe = val ?? false;
                                    });
                                  },
                                ),
                                const Text('ចងចាំខ្ញុំ'),
                                const Spacer(),
                                TextButton(
                                  onPressed: () {
                                    // TODO: Implement forgot password
                                  },
                                  child: const Text('ភ្លេចពាក្យសម្ងាត់'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF4CB050),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                ),
                                onPressed: () async {
                                  if (_formKey.currentState!.validate()) {
                                    try {
                                      final email = _emailController.text
                                          .trim();
                                      final password = _passwordController.text;

                                      var response = await http.post(
                                        Uri.parse('$apiBaseUrl/api/auth/login'),
                                        headers: {
                                          'Content-Type': 'application/json',
                                        },
                                        body: jsonEncode({
                                          'email': email,
                                          'password': password,
                                        }),
                                      );
                                      if (response.statusCode == 200) {
                                        // Parse the response
                                        final jsonResponse = jsonDecode(
                                          response.body,
                                        );

                                        // Save token and email to SharedPreferences
                                        final prefs =
                                            await SharedPreferences.getInstance();
                                        final token = _extractAccessToken(
                                          jsonResponse,
                                        );

                                        if (token == null ||
                                            token.toString().trim().isEmpty) {
                                          if (mounted) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'ការឆ្លើយតបការចូលគណនីបាត់ token។ សូមព្យាយាមម្តងទៀត។',
                                                ),
                                              ),
                                            );
                                          }
                                          return;
                                        }

                                        // Clear previous session then store new one.
                                        await prefs.remove('token');
                                        await prefs.remove('access_token');
                                        await prefs.remove('email');
                                        await prefs.setString(
                                          'token',
                                          token.toString().trim(),
                                        );
                                        await prefs.setString(
                                          'access_token',
                                          token.toString().trim(),
                                        );
                                        await prefs.setString('email', email);

                                        // Clear the form
                                        _emailController.clear();
                                        _passwordController.clear();

                                        // Show success message
                                        if (mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'ចូលគណនីបានជោគជ័យ!',
                                              ),
                                            ),
                                          );
                                        }

                                        // Navigate to MainNavBar and remove all previous routes
                                        Get.offAll(() => MainNavBar());
                                      } else if (response.statusCode == 401) {
                                        if (mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'ឈ្មោះអ្នកប្រើប្រាស់ ឬពាក្យសម្ងាត់មិនត្រឹមត្រូវទេ',
                                              ),
                                            ),
                                          );
                                        }
                                      } else {
                                        if (mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'ការចូលគណនីបរាជ័យ: ${response.body}',
                                              ),
                                            ),
                                          );
                                        }
                                      }
                                    } catch (e) {
                                      if (mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(content: Text('កំហុស: $e')),
                                        );
                                      }
                                    }
                                  }
                                },
                                child: const Text(
                                  'ចូលគណនី',
                                  style: TextStyle(fontSize: 18),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text("មិនមានគណនីទេ? "),
                                GestureDetector(
                                  onTap: () {
                                    Get.to(() => const Registerscreen());
                                  },
                                  child: const Text(
                                    'ចុះឈ្មោះនៅទីនេះ',
                                    style: TextStyle(
                                      color: Color(0xFF4CB050),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
