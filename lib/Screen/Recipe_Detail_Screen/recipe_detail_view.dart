import "package:flutter/material.dart";

import "../../models/recipe.dart";

class RecipeDetailView extends StatelessWidget {
  const RecipeDetailView({super.key, required this.recipe});

  final Recipe recipe;

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
                  _iconButton(Icons.favorite_border, () {}),
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
                      const SizedBox(height: 16),
                      if (recipe.description.isNotEmpty) ...[
                        Text(
                          recipe.description,
                          style: TextStyle(color: Colors.grey.shade700),
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
                              ? () => _showYoutubeLink(
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

  static void _showYoutubeLink(BuildContext context, String url) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("YouTube Link"),
          content: SelectableText(url),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Close"),
            ),
          ],
        );
      },
    );
  }

  static List<String> _splitSteps(String instructions) {
    return instructions
        .split(RegExp(r"[.\n]"))
        .map((step) => step.trim())
        .where((step) => step.isNotEmpty)
        .toList();
  }

  static Widget _iconButton(IconData icon, VoidCallback onTap) {
    return CircleAvatar(
      backgroundColor: Colors.white,
      child: IconButton(
        icon: Icon(icon, color: Colors.black),
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
}
