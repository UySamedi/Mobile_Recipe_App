import "package:flutter/material.dart";
import "package:get/get.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:url_launcher/url_launcher.dart";
import "dart:convert";

import "../../models/recipe.dart";
import "../../services/recipe_api.dart";
import "../../Auth/loginScreen.dart";
import "../FavoritesScreen/favorites_controller.dart";

class RecipeDetailView extends StatefulWidget {
  const RecipeDetailView({super.key, required this.recipe});

  final Recipe recipe;

  @override
  State<RecipeDetailView> createState() => _RecipeDetailViewState();
}

class _RecipeDetailViewState extends State<RecipeDetailView> {
  int userRating = 0;
  bool _isSubmitting = false;
  bool _hasRated = false;

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

  String _ratingsKeyForUser(SharedPreferences prefs) {
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
    _loadSavedRating();
  }

  Future<void> _loadSavedRating() async {
    final prefs = await SharedPreferences.getInstance();
    int? saved;

    // User-scoped store so each account sees only its own ratings.
    final rawRatings = prefs.getString(_ratingsKeyForUser(prefs));
    if (rawRatings != null && rawRatings.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawRatings);
        if (decoded is Map<String, dynamic>) {
          final item = decoded['${widget.recipe.id}'];
          if (item is Map<String, dynamic>) {
            final value = item['rating'];
            if (value is int) {
              saved = value;
            } else if (value is num) {
              saved = value.toInt();
            }
          }
        }
      } catch (_) {
        // Ignore malformed local cache.
      }
    }

    if (saved != null && mounted) {
      setState(() {
        userRating = saved!;
        _hasRated = true;
      });
    } else if (mounted) {
      // Important for account switching: clear stale in-memory rating state.
      setState(() {
        userRating = 0;
        _hasRated = false;
      });
    }
  }

  Future<void> _persistUserRating(int stars) async {
    final prefs = await SharedPreferences.getInstance();

    // Legacy keys (already used in profile and kept for compatibility)
    await prefs.setInt('rating_${widget.recipe.id}', stars);
    await prefs.setString(
      'rating_name_${widget.recipe.id}',
      widget.recipe.name,
    );

    // Canonical user-scoped rating store keyed by recipe id.
    Map<String, dynamic> ratingStore = {};
    final scopedKey = _ratingsKeyForUser(prefs);
    final raw = prefs.getString(scopedKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          ratingStore = decoded;
        }
      } catch (_) {
        ratingStore = {};
      }
    }

    ratingStore['${widget.recipe.id}'] = {
      'recipeId': widget.recipe.id,
      'recipeName': widget.recipe.name,
      'rating': stars,
      'updatedAt': DateTime.now().toIso8601String(),
    };
    await prefs.setString(scopedKey, jsonEncode(ratingStore));
  }

  @override
  Widget build(BuildContext context) {
    final steps = _splitSteps(widget.recipe.instructions);
    final hasVideo =
        widget.recipe.youtubeLink != null &&
        widget.recipe.youtubeLink!.isNotEmpty;
    final FavoritesController favoritesController =
        Get.isRegistered<FavoritesController>()
        ? Get.find<FavoritesController>()
        : Get.put(FavoritesController());

    return Scaffold(
      body: Stack(
        children: [
          SizedBox(
            height: 300,
            width: double.infinity,
            child: Image.network(
              widget.recipe.imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: Colors.grey.shade200,
                  alignment: Alignment.center,
                  child: const Icon(Icons.image_not_supported, size: 48),
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _iconButton(Icons.arrow_back, () {
                    Navigator.pop(context);
                  }),
                  Obx(() {
                    final isFavorite = favoritesController.isFavorite(
                      widget.recipe,
                    );
                    return _iconButton(
                      isFavorite ? Icons.favorite : Icons.favorite_border,
                      () => _handleFavoriteTap(favoritesController),
                      color: isFavorite ? Colors.red : Colors.black,
                    );
                  }),
                ],
              ),
            ),
          ),
          DraggableScrollableSheet(
            initialChildSize: 0.65,
            minChildSize: 0.65,
            maxChildSize: 0.95,
            builder: (_, controller) {
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: SingleChildScrollView(
                  controller: controller,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.recipe.name,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.category, size: 16),
                          const SizedBox(width: 4),
                          Text(widget.recipe.category.name),
                          const SizedBox(width: 12),
                          const Icon(
                            Icons.star,
                            size: 16,
                            color: Colors.orange,
                          ),
                          const SizedBox(width: 4),
                          Text(widget.recipe.rating.toStringAsFixed(1)),
                          const SizedBox(width: 12),
                          const Icon(Icons.local_fire_department, size: 16),
                          const SizedBox(width: 4),
                          Text(widget.recipe.calory?.toString() ?? "N/A"),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _metaChip(
                            Icons.trending_up,
                            widget.recipe.difficulty.isEmpty
                                ? "មិនមានកម្រិតលំបាក"
                                : widget.recipe.difficulty,
                          ),
                          _metaChip(
                            Icons.schedule,
                            "ត្រៀម ${_formatMinutes(widget.recipe.preparationTimeMinutes)}",
                          ),
                          _metaChip(
                            Icons.timer_outlined,
                            "ចម្អិន ${_formatMinutes(widget.recipe.cookTimeMinutes)}",
                          ),
                          _metaChip(
                            Icons.timelapse,
                            "សរុប ${_formatMinutes(widget.recipe.totalTimeMinutes)}",
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (widget.recipe.description.isNotEmpty) ...[
                        Text(
                          widget.recipe.description,
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                        const SizedBox(height: 20),
                      ],
                      Text(
                        _hasRated ? "ការវាយតម្លៃរបស់អ្នក" : "វាយតម្លៃរូបមន្តនេះ",
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: List.generate(5, (index) {
                          return GestureDetector(
                            onTap: _isSubmitting
                                ? null
                                : () => _submitRating(index + 1),
                            child: Icon(
                              Icons.star,
                              size: 32,
                              color: index < userRating
                                  ? Colors.orange
                                  : Colors.grey.shade300,
                            ),
                          );
                        }),
                      ),
                      if (_isSubmitting)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      if (userRating > 0) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              _hasRated
                                  ? Icons.check_circle
                                  : Icons.info_outline,
                              size: 16,
                              color: _hasRated
                                  ? Colors.green
                                  : Colors.grey.shade600,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _hasRated
                                  ? "អ្នកបានផ្តល់ $userRating ផ្កាយ"
                                  : "អ្នកបានផ្តល់: $userRating ផ្កាយ",
                              style: TextStyle(
                                color: _hasRated
                                    ? Colors.green
                                    : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 20),
                      if (widget.recipe.nutrition != null) ...[
                        const Text(
                          "អាហារូបត្ថម្ភ",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _nutritionChip(
                              "កាឡូរី",
                              _formatValue(
                                widget.recipe.nutrition!.calories,
                                "កាឡូរី",
                              ),
                            ),
                            _nutritionChip(
                              "ប្រូតេអ៊ីន",
                              _formatValue(
                                widget.recipe.nutrition!.proteinGrams,
                                "ក្រាម",
                              ),
                            ),
                            _nutritionChip(
                              "កាបូអ៊ីដ្រាត",
                              _formatValue(
                                widget.recipe.nutrition!.carbsGrams,
                                "ក្រាម",
                              ),
                            ),
                            _nutritionChip(
                              "ជាតិខ្លាញ់",
                              _formatValue(
                                widget.recipe.nutrition!.fatGrams,
                                "ក្រាម",
                              ),
                            ),
                            _nutritionChip(
                              "ជាតិសរសៃ",
                              _formatValue(
                                widget.recipe.nutrition!.fiberGrams,
                                "ក្រាម",
                              ),
                            ),
                            _nutritionChip(
                              "ជាតិស្ករ",
                              _formatValue(
                                widget.recipe.nutrition!.sugarGrams,
                                "ក្រាម",
                              ),
                            ),
                            _nutritionChip(
                              "សូដ្យូម",
                              _formatValue(
                                widget.recipe.nutrition!.sodiumMg,
                                "មីលីក្រាម",
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                      ],
                      const Text(
                        "គ្រឿងផ្សំ",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (widget.recipe.ingredients.isEmpty)
                        const Text("មិនមានគ្រឿងផ្សំទេ")
                      else
                        ...widget.recipe.ingredients.map(
                          (item) => _ingredientCard(
                            item.ingredient.name,
                            item.quantity,
                            item.imageUrl ?? item.ingredient.imageUrl,
                          ),
                        ),
                      const SizedBox(height: 20),
                      const Text(
                        "ការណែនាំ",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (steps.isEmpty)
                        const Text("មិនមានការណែនាំទេ។")
                      else
                        ...steps.asMap().entries.map(
                          (entry) => _step(entry.key + 1, entry.value),
                        ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.play_circle),
                          label: const Text("មើលនៅលើ YouTube"),
                          onPressed: hasVideo
                              ? () => _openYoutubeLink(
                                  context,
                                  widget.recipe.youtubeLink!,
                                )
                              : null,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.all(14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _submitRating(int stars) async {
    // Check if user is logged in
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null || token.isEmpty) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('តម្រូវឱ្យចូលគណនី'),
          content: const Text('សូមចូលគណនីដើម្បីវាយតម្លៃរូបមន្តនេះ។'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('បោះបង់'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CB050),
              ),
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const Loginscreen()));
              },
              child: const Text('ចូលគណនី', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await RecipeApi.rateRecipe(recipeId: widget.recipe.id, stars: stars);
      if (!mounted) return;
      await _persistUserRating(stars);
      if (!mounted) return;
      setState(() {
        userRating = stars;
        _isSubmitting = false;
        _hasRated = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("បានផ្តល់ $stars ផ្កាយ ⭐"),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      final errorText = e.toString();
      final message = errorText.contains('(403)')
          ? errorText.replaceFirst('Exception: ', '')
          : errorText.contains('(401)')
          ? 'ផុតកំណត់សម័យ។ សូមចូលគណនីម្តងទៀត។'
          : 'បរាជ័យក្នុងការវាយតម្លៃ: $e';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _handleFavoriteTap(FavoritesController controller) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null || token.isEmpty) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('តម្រូវឱ្យចូលគណនី'),
          content: const Text('សូមចូលគណនីដើម្បីបញ្ចូលរូបមន្តទៅក្នុងចំណូលចិត្ត។'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('បោះបង់'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CB050),
              ),
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const Loginscreen()));
              },
              child: const Text('ចូលគណនី', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      return;
    }

    final before = controller.isFavorite(widget.recipe);
    await controller.toggleFavorite(widget.recipe);
    if (!mounted) return;

    if (controller.errorMessage.value.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('បរាជ័យ: ${controller.errorMessage.value}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    final after = controller.isFavorite(widget.recipe);
    final added = !before && after;
    final removed = before && !after;
    if (added || removed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            added ? 'បានបន្ថែមទៅចំណូលចិត្ត' : 'បានលុបពីចំណូលចិត្ត',
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  static Future<void> _openYoutubeLink(BuildContext context, String url) async {
    final uri = _normalizeYoutubeUrl(url);
    if (uri == null) {
      _showErrorSnack(context, "Invalid YouTube link.");
      return;
    }
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (launched) {
      return;
    }
    if (!context.mounted) {
      return;
    }
    final fallback = await launchUrl(uri, mode: LaunchMode.platformDefault);
    if (!context.mounted) {
      return;
    }
    if (!fallback) {
      _showErrorSnack(context, "Could not open YouTube.");
    }
  }

  static Uri? _normalizeYoutubeUrl(String raw) {
    final cleaned = raw.trim();
    if (cleaned.isEmpty) {
      return null;
    }
    Uri? uri = Uri.tryParse(cleaned);
    if (uri == null) {
      return null;
    }
    if (uri.scheme.isEmpty) {
      final looksLikeId =
          !cleaned.contains("/") &&
          !cleaned.contains(".") &&
          cleaned.length >= 8;
      final candidate = looksLikeId
          ? "https://www.youtube.com/watch?v=$cleaned"
          : "https://$cleaned";
      uri = Uri.tryParse(candidate);
    }
    return uri;
  }

  static void _showErrorSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  static List<String> _splitSteps(String instructions) {
    return instructions
        .split(RegExp(r"[.\n]"))
        .map((step) => step.trim())
        .where((step) => step.isNotEmpty)
        .toList();
  }

  static Widget _iconButton(
    IconData icon,
    VoidCallback onTap, {
    Color color = Colors.black,
  }) {
    return CircleAvatar(
      backgroundColor: Colors.white,
      child: IconButton(
        icon: Icon(icon, color: color),
        onPressed: onTap,
      ),
    );
  }

  static Widget _ingredientCard(String name, String qty, String? imageUrl) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          color: Colors.grey.shade50,
        ),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              // Ingredient image
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey.shade200,
                ),
                child: imageUrl != null && imageUrl.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.grey.shade200,
                              child: const Icon(
                                Icons.image_not_supported,
                                size: 24,
                                color: Colors.grey,
                              ),
                            );
                          },
                        ),
                      )
                    : const Icon(
                        Icons.image_not_supported,
                        size: 24,
                        color: Colors.grey,
                      ),
              ),
              const SizedBox(width: 12),
              // Ingredient name and quantity
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      qty,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _step(int index, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: Colors.green,
            child: Text(
              index.toString(),
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  static Widget _metaChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade700),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(color: Colors.grey.shade800, fontSize: 12),
          ),
        ],
      ),
    );
  }

  static Widget _nutritionChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.green.shade100),
      ),
      child: Text(
        "$label: $value",
        style: TextStyle(
          fontSize: 12,
          color: Colors.green.shade900,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  static String _formatMinutes(int? minutes) {
    if (minutes == null || minutes <= 0) {
      return "N/A";
    }
    return "${minutes}m";
  }

  static String _formatValue(int? value, String unit) {
    if (value == null) {
      return "N/A";
    }
    return "$value $unit";
  }
}
