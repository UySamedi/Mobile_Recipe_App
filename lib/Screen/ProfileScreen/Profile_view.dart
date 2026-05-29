import 'package:final_project/Auth/loginScreen.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import '../../services/auth_api.dart';

class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  String? name;
  String? email;
  String? profileImage;
  String? token;
  File? _selectedImage;
  bool _isLoading = false;
  bool _isEditing = false;
  Map<String, int> _userRatings = {};

  late TextEditingController _nameController;
  final ImagePicker _imagePicker = ImagePicker();

  String _normalizeScopePart(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9@._-]'), '_');
  }

  String? _extractUserIdentityFromToken(String token) {
    try {
      final parts = token.split('.');
      if (parts.length < 2) {
        return null;
      }
      final payload = utf8.decode(
        base64Url.decode(base64Url.normalize(parts[1])),
      );
      final decoded = jsonDecode(payload);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }

      final userId = decoded['userId'] ?? decoded['id'] ?? decoded['sub'];
      if (userId != null && userId.toString().trim().isNotEmpty) {
        return 'id_${_normalizeScopePart(userId.toString())}';
      }

      final email = decoded['email'];
      if (email is String && email.trim().isNotEmpty) {
        return 'email_${_normalizeScopePart(email)}';
      }
    } catch (_) {
      // Ignore malformed token payload and use fallback sources.
    }
    return null;
  }

  String _ratingsKeyForCurrentUser(SharedPreferences prefs) {
    final token = prefs.getString('token');
    if (token != null && token.trim().isNotEmpty) {
      final fromToken = _extractUserIdentityFromToken(token);
      if (fromToken != null && fromToken.isNotEmpty) {
        return 'user_ratings_$fromToken';
      }
    }

    final rawEmail = (prefs.getString('email') ?? '').trim();
    if (rawEmail.isNotEmpty) {
      return 'user_ratings_email_${_normalizeScopePart(rawEmail)}';
    }

    return 'user_ratings_unknown';
  }

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      token = prefs.getString('token');

      if (token != null) {
        final profileData = await AuthApi.getProfile();
        setState(() {
          name = profileData['name'] ?? 'Unknown';
          email = profileData['email'];
          if (email == null || email!.isEmpty) {
            email = prefs.getString('email') ?? '';
          }
          profileImage = profileData['profile_image'];
          _nameController.text = name ?? '';
        });

        await prefs.setString('name', name ?? '');
        if (email != null && email!.isNotEmpty) {
          await prefs.setString('email', email!);
        }
        if (profileImage != null) {
          await prefs.setString('profile_image', profileImage!);
        }
      } else {
        setState(() {
          name = prefs.getString('name') ?? 'Unknown';
          email = prefs.getString('email') ?? '';
          profileImage = prefs.getString('profile_image');
          _nameController.text = name ?? '';
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('មានកំហុសក្នុងការផ្ទុកគណនី: $e')));
      }
    } finally {
      setState(() => _isLoading = false);
      _loadUserRatings();
    }
  }

  Future<void> _loadUserRatings() async {
    final prefs = await SharedPreferences.getInstance();
    final ratings = <String, int>{};

    // Prefer current user-scoped JSON store.
    final rawStore = prefs.getString(_ratingsKeyForCurrentUser(prefs));
    if (rawStore != null && rawStore.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawStore);
        if (decoded is Map<String, dynamic>) {
          for (final entry in decoded.entries) {
            final recipeId = entry.key;
            final item = entry.value;
            if (item is! Map<String, dynamic>) {
              continue;
            }
            final rawRating = item['rating'];
            final rating = rawRating is int
                ? rawRating
                : (rawRating is num ? rawRating.toInt() : null);
            if (rating == null) {
              continue;
            }
            final recipeName = (item['recipeName'] as String?)?.trim();
            final displayName = (recipeName == null || recipeName.isEmpty)
                ? 'Recipe #$recipeId'
                : '$recipeName (#$recipeId)';
            ratings[displayName] = rating;
          }
        }
      } catch (_) {
        // Fall back to legacy key scanning below.
      }
    }

    // Legacy fallback for older non-scoped JSON key.
    if (ratings.isEmpty) {
      final legacyStore = prefs.getString('user_ratings');
      if (legacyStore != null && legacyStore.isNotEmpty) {
        try {
          final decoded = jsonDecode(legacyStore);
          if (decoded is Map<String, dynamic>) {
            for (final entry in decoded.entries) {
              final recipeId = entry.key;
              final item = entry.value;
              if (item is! Map<String, dynamic>) {
                continue;
              }
              final rawRating = item['rating'];
              final rating = rawRating is int
                  ? rawRating
                  : (rawRating is num ? rawRating.toInt() : null);
              if (rating == null) {
                continue;
              }
              final recipeName = (item['recipeName'] as String?)?.trim();
              final displayName = (recipeName == null || recipeName.isEmpty)
                  ? 'Recipe #$recipeId'
                  : '$recipeName (#$recipeId)';
              ratings[displayName] = rating;
            }
          }
        } catch (_) {
          // Continue to key-scan fallback.
        }
      }
    }

    // Backward-compatible fallback for previously saved rating_* keys.
    if (ratings.isEmpty) {
      final allKeys = prefs.getKeys();
      for (final key in allKeys) {
        if (key.startsWith('rating_') && !key.startsWith('rating_name_')) {
          final recipeId = key.replaceFirst('rating_', '');
          final value = prefs.getInt(key);
          if (value != null) {
            final recipeName =
                prefs.getString('rating_name_$recipeId') ?? 'Recipe #$recipeId';
            ratings['$recipeName (#$recipeId)'] = value;
          }
        }
      }
    }

    if (mounted) {
      setState(() => _userRatings = ratings);
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
      );
      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('មានកំហុសក្នុងការយករូបភាព: $e')));
      }
    }
  }

  Future<void> _updateProfile() async {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('សូមបញ្ចូលឈ្មោះ')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final result = await AuthApi.updateProfile(
        name: _nameController.text,
        imagePath: _selectedImage?.path,
      );

      setState(() {
        name = result['name'] ?? _nameController.text;
        email = result['email'] ?? email;
        profileImage = result['profile_image'] ?? profileImage;
        _selectedImage = null;
        _isEditing = false;
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('name', name ?? '');
      if (profileImage != null) {
        await prefs.setString('profile_image', profileImage!);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('គណនីបានធ្វើបច្ចុប្បន្នភាពដោយជោគជ័យ!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('មានកំហុសក្នុងការធ្វើបច្ចុប្បន្នភាពគណនី: $e')));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _cancelEdit() {
    setState(() {
      _isEditing = false;
      _selectedImage = null;
      _nameController.text = name ?? '';
    });
  }

  Future<void> _logout() async {
    try {
      await AuthApi.logout();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const Loginscreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('មានកំហុសក្នុងការចាកចេញ: $e')));
      }
    }
  }

  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('ចាកចេញ'),
          content: const Text('តើអ្នកពិតជាចង់ចាកចេញមែនទេ?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('បោះបង់'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _logout();
              },
              child: const Text('ចាកចេញ', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('គណនី'),
        elevation: 0,
        actions: [
          if (!_isEditing && token != null && token!.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                setState(() => _isEditing = true);
              },
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : (token == null || token!.isEmpty)
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.account_circle,
                    size: 100,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'មិនមានគណនីទេ',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'សូមចូលគណនីដើម្បីមើលប្រវត្តិរូបរបស់អ្នក',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const Loginscreen(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4CB050),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 40,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'ចូលគណនី',
                      style: TextStyle(fontSize: 18, color: Colors.white),
                    ),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: () async {
                await _loadProfile();
              },
              color: const Color(0xFF4CB050),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Profile Image
                        GestureDetector(
                          onTap: _isEditing ? _pickImage : null,
                          child: Stack(
                            children: [
                              CircleAvatar(
                                radius: 60,
                                backgroundImage: _selectedImage != null
                                    ? FileImage(_selectedImage!)
                                          as ImageProvider
                                    : (profileImage != null &&
                                              profileImage!.isNotEmpty
                                          ? NetworkImage(
                                              profileImage!.startsWith('http')
                                                  ? profileImage!
                                                  : '${AuthApi.baseUrl}$profileImage',
                                            )
                                          : null),
                                child:
                                    (_selectedImage == null &&
                                        profileImage == null)
                                    ? const Icon(Icons.person, size: 60)
                                    : null,
                              ),
                              if (_isEditing)
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF4CB050),
                                      shape: BoxShape.circle,
                                    ),
                                    padding: const EdgeInsets.all(8),
                                    child: const Icon(
                                      Icons.camera_alt,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Name Section
                        if (_isEditing)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'ឈ្មោះ',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _nameController,
                                decoration: InputDecoration(
                                  hintText: 'បញ្ចូលឈ្មោះរបស់អ្នក',
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: Colors.grey,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: Color(0xFF4CB050),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                          )
                        else
                          Column(
                            children: [
                              Text(
                                name ?? 'មិនស្គាល់',
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              if (email != null && email!.isNotEmpty)
                                Text(
                                  email!,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey,
                                  ),
                                ),
                              const SizedBox(height: 16),
                            ],
                          ),

                        // Action Buttons
                        if (_isEditing)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SizedBox(
                                height: 48,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF4CB050),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onPressed: _isLoading ? null : _updateProfile,
                                  child: _isLoading
                                      ? const SizedBox(
                                          height: 24,
                                          width: 24,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  Colors.white,
                                                ),
                                          ),
                                        )
                                      : const Text(
                                          'រក្សាទុកការផ្លាស់ប្តូរ',
                                          style: TextStyle(fontSize: 16),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                height: 48,
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    side: const BorderSide(color: Colors.grey),
                                  ),
                                  onPressed: _cancelEdit,
                                  child: const Text(
                                    'បោះបង់',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),

                        // Information Display Section (when not editing)
                        if (!_isEditing)
                          Column(
                            children: [
                              const SizedBox(height: 24),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.email,
                                          color: Color(0xFF4CB050),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                'អ៊ីមែល',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                              Text(
                                                (email == null ||
                                                        email!.isEmpty)
                                                    ? 'មិនបានផ្តល់ឱ្យ'
                                                    : email!,
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),
                              // My Ratings Section
                              _buildMyRatingsSection(),
                              const SizedBox(height: 24),
                              SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onPressed: _showLogoutConfirmation,
                                  child: const Text(
                                    'ចាកចេញ',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildMyRatingsSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.star, color: Colors.orange.shade600),
              const SizedBox(width: 8),
              Text(
                'ការវាយតម្លៃរបស់ខ្ញុំ',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade800,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'បានវាយតម្លៃ ${_userRatings.length}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.orange.shade700,
                  ),
                ),
              ),
            ],
          ),
          if (_userRatings.isEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'អ្នកមិនទាន់បានវាយតម្លៃរូបមន្តណាមួយនៅឡើយទេ',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
          ] else ...[
            const SizedBox(height: 12),
            ..._userRatings.entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        entry.key,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(
                        5,
                        (i) => Icon(
                          Icons.star,
                          size: 18,
                          color: i < entry.value
                              ? Colors.orange
                              : Colors.grey.shade300,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
