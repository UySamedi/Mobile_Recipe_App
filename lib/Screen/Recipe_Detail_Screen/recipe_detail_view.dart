import "package:flutter/material.dart";
import "package:get/get.dart";
import "package:url_launcher/url_launcher.dart";

import "../../models/recipe.dart";
import "../FavoritesScreen/favorites_controller.dart";

class RecipeDetailView extends StatelessWidget {
  RecipeDetailView({super.key, required this.recipe});

  final Recipe recipe;
  final FavoritesController favoritesController =
      Get.isRegistered<FavoritesController>()
          ? Get.find<FavoritesController>()
          : Get.put(FavoritesController());

  @override
  Widget build(BuildContext context) {
    final steps = _splitSteps(recipe.instructions);
    final hasVideo = recipe.youtubeLink != null && recipe.youtubeLink!.isNotEmpty;

    return Scaffold(
      body: Stack(
        children: [
          SizedBox(
            height: 300,
            width: double.infinity,
            child: Image.network(
              recipe.imageUrl,
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
                    final isFavorite =
                        favoritesController.isFavorite(recipe);
                    return _iconButton(
                      isFavorite ? Icons.favorite : Icons.favorite_border,
                      () {
                        favoritesController.toggleFavorite(recipe);
                      },
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
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                ),
                child: SingleChildScrollView(
                  controller: controller,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        recipe.name,
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
                          Text(recipe.category.name),
                          const SizedBox(width: 12),
                          const Icon(Icons.star, size: 16, color: Colors.orange),
                          const SizedBox(width: 4),
                          Text(recipe.rating.toStringAsFixed(1)),
                          const SizedBox(width: 12),
                          const Icon(Icons.local_fire_department, size: 16),
                          const SizedBox(width: 4),
                          Text(recipe.calory?.toString() ?? "N/A"),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _metaChip(
                            Icons.trending_up,
                            recipe.difficulty.isEmpty
                                ? "Difficulty N/A"
                                : recipe.difficulty,
                          ),
                          _metaChip(
                            Icons.schedule,
                            "Prep ${_formatMinutes(recipe.preparationTimeMinutes)}",
                          ),
                          _metaChip(
                            Icons.timer_outlined,
                            "Cook ${_formatMinutes(recipe.cookTimeMinutes)}",
                          ),
                          _metaChip(
                            Icons.timelapse,
                            "Total ${_formatMinutes(recipe.totalTimeMinutes)}",
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (recipe.description.isNotEmpty) ...[
                        Text(
                          recipe.description,
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                        const SizedBox(height: 20),
                      ],
                      if (recipe.nutrition != null) ...[
                        const Text(
                          "Nutrition",
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
                              "Calories",
                              _formatValue(recipe.nutrition!.calories, "kcal"),
                            ),
                            _nutritionChip(
                              "Protein",
                              _formatValue(recipe.nutrition!.proteinGrams, "g"),
                            ),
                            _nutritionChip(
                              "Carbs",
                              _formatValue(recipe.nutrition!.carbsGrams, "g"),
                            ),
                            _nutritionChip(
                              "Fat",
                              _formatValue(recipe.nutrition!.fatGrams, "g"),
                            ),
                            _nutritionChip(
                              "Fiber",
                              _formatValue(recipe.nutrition!.fiberGrams, "g"),
                            ),
                            _nutritionChip(
                              "Sugar",
                              _formatValue(recipe.nutrition!.sugarGrams, "g"),
                            ),
                            _nutritionChip(
                              "Sodium",
                              _formatValue(recipe.nutrition!.sodiumMg, "mg"),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                      ],
                      const Text(
                        "Ingredients",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (recipe.ingredients.isEmpty)
                        const Text("No ingredients listed.")
                      else
                        ...recipe.ingredients.map(
                          (item) => _ingredient(
                            item.ingredient.name,
                            item.quantity,
                          ),
                        ),
                      const SizedBox(height: 20),
                      const Text(
                        "Instructions",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (steps.isEmpty)
                        const Text("No instructions provided.")
                      else
                        ...steps.asMap().entries.map(
                          (entry) => _step(entry.key + 1, entry.value),
                        ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.play_circle),
                          label: const Text("Watch on YouTube"),
                          onPressed: hasVideo
                              ? () => _openYoutubeLink(
                                    context,
                                    recipe.youtubeLink!,
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

  static Future<void> _openYoutubeLink(
    BuildContext context,
    String url,
  ) async {
    final uri = _normalizeYoutubeUrl(url);
    if (uri == null) {
      _showErrorSnack(context, "Invalid YouTube link.");
      return;
    }
    final launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (launched) {
      return;
    }
    if (!context.mounted) {
      return;
    }
    final fallback = await launchUrl(
      uri,
      mode: LaunchMode.platformDefault,
    );
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
          !cleaned.contains("/") && !cleaned.contains(".") && cleaned.length >= 8;
      final candidate = looksLikeId
          ? "https://www.youtube.com/watch?v=$cleaned"
          : "https://$cleaned";
      uri = Uri.tryParse(candidate);
    }
    return uri;
  }

  static void _showErrorSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
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

  static Widget _ingredient(String name, String qty) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.check_circle, size: 18, color: Colors.green),
          const SizedBox(width: 8),
          Expanded(child: Text(name)),
          Text(qty),
        ],
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
