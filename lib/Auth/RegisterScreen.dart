import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

import 'dart:convert';
import 'loginScreen.dart';

// Change API base URL for mobile access
const String apiBaseUrl = 'http://10.0.2.2:8080'; // For Android emulator
// If using a physical device, replace with your PC's IP, e.g. 'http://192.168.1.100:8080'

class Registerscreen extends StatefulWidget {
  const Registerscreen({super.key});

  @override
  State<Registerscreen> createState() => _RegisterscreenState();
}

class _RegisterscreenState extends State<Registerscreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
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
                        'បង្កើតគណនី',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'ចុះឈ្មោះដើម្បីចាប់ផ្តើមស្វែងរករូបមន្តឆ្ងាញ់ៗ និងរក្សាទុកចំណូលចិត្តរបស់អ្នក។',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 15, color: Colors.black54),
                      ),
                      const SizedBox(height: 32),
                      Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            // Username Field
                            TextFormField(
                              controller: _usernameController,
                              decoration: InputDecoration(
                                prefixIcon: const Icon(Icons.person),
                                hintText: 'ឈ្មោះអ្នកប្រើប្រាស់',
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'សូមបញ្ចូលឈ្មោះអ្នកប្រើប្រាស់របស់អ្នក';
                                }
                                if (value.length < 3) {
                                  return 'ឈ្មោះអ្នកប្រើប្រាស់ត្រូវមានយ៉ាងហោចណាស់ ៣ តួអក្សរ';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            // Email Field
                            TextFormField(
                              controller: _emailController,
                              decoration: InputDecoration(
                                prefixIcon: const Icon(Icons.email_outlined),
                                hintText: 'អាសយដ្ឋានអ៊ីមែល',
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
                                if (!RegExp(
                                  r'^[^@]+@[^@]+\.[^@]+',
                                ).hasMatch(value)) {
                                  return 'សូមបញ្ចូលអ៊ីមែលត្រឹមត្រូវ';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            // Password Field
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
                            const SizedBox(height: 16),
                            // Confirm Password Field
                            TextFormField(
                              controller: _confirmPasswordController,
                              obscureText: _obscureConfirmPassword,
                              decoration: InputDecoration(
                                prefixIcon: const Icon(Icons.lock_outline),
                                hintText: 'បញ្ជាក់ពាក្យសម្ងាត់',
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  borderSide: BorderSide.none,
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscureConfirmPassword
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscureConfirmPassword =
                                          !_obscureConfirmPassword;
                                    });
                                  },
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'សូមបញ្ជាក់ពាក្យសម្ងាត់របស់អ្នក';
                                }
                                if (value != _passwordController.text) {
                                  return 'ពាក្យសម្ងាត់មិនត្រូវគ្នាទេ';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 24),
                            // Register Button
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
                                      var response = await http.post(
                                        Uri.parse(
                                          '$apiBaseUrl/api/auth/register',
                                        ),
                                        headers: {
                                          'Content-Type': 'application/json',
                                        },
                                        body: jsonEncode({
                                          'username': _usernameController.text,
                                          'email': _emailController.text,
                                          'password': _passwordController.text,
                                        }),
                                      );
                                      if (response.statusCode == 200 ||
                                          response.statusCode == 201) {
                                        // Clear the form
                                        _usernameController.clear();
                                        _emailController.clear();
                                        _passwordController.clear();
                                        _confirmPasswordController.clear();

                                        if (mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'ការចុះឈ្មោះទទួលបានជោគជ័យ! សូមចូលគណនី។',
                                              ),
                                            ),
                                          );
                                        }
                                        Get.to(() => const Loginscreen());
                                      } else if (response.statusCode == 400) {
                                        if (mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'ឈ្មោះអ្នកប្រើប្រាស់ ឬអ៊ីមែលមានរួចហើយ',
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
                                                'ការចុះឈ្មោះបរាជ័យ: ${response.body}',
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
                                  'ចុះឈ្មោះ',
                                  style: TextStyle(fontSize: 18),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Login Link
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text('មានគណនីរួចហើយមែនទេ? '),
                                GestureDetector(
                                  onTap: () {
                                    Get.to(() => const Loginscreen());
                                  },
                                  child: const Text(
                                    'ចូលគណនីនៅទីនេះ',
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
