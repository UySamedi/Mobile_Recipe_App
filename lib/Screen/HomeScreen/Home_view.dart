import "package:flutter/material.dart";

import "../../models/recipe.dart";
import "../../services/recipe_api.dart";
import "../Recipe_Detail_Screen/recipe_detail_view.dart";

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  late Future<List<Recipe>> _recipesFuture;
  int? _selectedCategoryId;
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _recipesFuture = RecipeApi.fetchRecipes();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Khmer Recipes"),
      ),
      body: FutureBuilder<List<Recipe>>(
        future: _recipesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _errorState(context, snapshot.error);
          }
          final recipes = snapshot.data ?? const <Recipe>[];
          return _buildContent(context, recipes);
        },
      ),
    );
  }

  Widget _errorState(BuildContext context, Object? error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Could not load recipes.",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              error?.toString() ?? "Unknown error",
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _recipesFuture = RecipeApi.fetchRecipes();
                });
              },
              child: const Text("Retry"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, List<Recipe> recipes) {
    final categories = _buildCategories(recipes);
    if (_selectedCategoryId != null &&
        !categories.any((category) => category.id == _selectedCategoryId)) {
      _selectedCategoryId = null;
    }
    final filtered = _filterByCategory(recipes, _selectedCategoryId);
    final searched = _filterBySearch(filtered, _searchQuery);
    final featured = _pickFeatured(searched);
    final popular = _pickPopular(searched);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            decoration: InputDecoration(
              hintText: "Search recipes or ingredients",
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.grey.shade200,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),
          const SizedBox(height: 20),
          const Text(
            "Categories",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: categories.map(_categoryChip).toList(),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            "Featured",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          if (featured == null)
            const Text("No recipes available.")
          else
            _featuredCard(context, featured),
          const SizedBox(height: 20),
          const Text(
            "Popular Recipes",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          if (popular.isEmpty)
            const Text("No recipes available.")
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: popular.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.8,
              ),
              itemBuilder: (context, index) {
                return _recipeCard(context, popular[index]);
              },
            ),
        ],
      ),
    );
  }

  List<_CategoryFilter> _buildCategories(List<Recipe> recipes) {
    final Map<int, String> byId = {};
    for (final recipe in recipes) {
      byId.putIfAbsent(recipe.category.id, () => recipe.category.name);
    }
    final entries = byId.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    return [
      const _CategoryFilter(null, "All"),
      ...entries.map((entry) => _CategoryFilter(entry.key, entry.value)),
    ];
  }

  List<Recipe> _filterByCategory(List<Recipe> recipes, int? selectedId) {
    if (selectedId == null) {
      return recipes;
    }
    return recipes.where((recipe) => recipe.category.id == selectedId).toList();
  }

  List<Recipe> _filterBySearch(List<Recipe> recipes, String query) {
    final trimmed = query.trim().toLowerCase();
    if (trimmed.isEmpty) {
      return recipes;
    }
    return recipes.where((recipe) {
      final nameMatch = recipe.name.toLowerCase().contains(trimmed);
      final descMatch = recipe.description.toLowerCase().contains(trimmed);
      final categoryMatch = recipe.category.name.toLowerCase().contains(trimmed);
      final ingredientMatch = recipe.ingredients.any(
        (item) => item.ingredient.name.toLowerCase().contains(trimmed),
      );
      return nameMatch || descMatch || categoryMatch || ingredientMatch;
    }).toList();
  }

  Recipe? _pickFeatured(List<Recipe> recipes) {
    if (recipes.isEmpty) {
      return null;
    }
    return recipes.reduce(
      (current, next) => next.rating >= current.rating ? next : current,
    );
  }

  List<Recipe> _pickPopular(List<Recipe> recipes) {
    final sorted = [...recipes]
      ..sort((a, b) => b.rating.compareTo(a.rating));
    return sorted;
  }

  Widget _categoryChip(_CategoryFilter category) {
    final isSelected = _selectedCategoryId == category.id;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(category.name),
        selected: isSelected,
        onSelected: (_) {
          setState(() {
            _selectedCategoryId = category.id;
          });
        },
        selectedColor: Colors.green.shade300,
        backgroundColor: Colors.green.shade100,
      ),
    );
  }

  Widget _featuredCard(BuildContext context, Recipe recipe) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RecipeDetailView(recipe: recipe),
          ),
        );
      },
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          image: DecorationImage(
            image: NetworkImage(recipe.imageUrl),
            fit: BoxFit.cover,
            onError: (_, __) {},
          ),
        ),
        child: Container(
          padding: const EdgeInsets.all(12),
          alignment: Alignment.bottomLeft,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.black.withOpacity(0.7),
              ],
            ),
          ),
          child: Text(
            "${recipe.name} \u2605${recipe.rating.toStringAsFixed(1)}",
            style: const TextStyle(color: Colors.white, fontSize: 18),
          ),
        ),
      ),
    );
  }

  Widget _recipeCard(BuildContext context, Recipe recipe) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RecipeDetailView(recipe: recipe),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              blurRadius: 6,
              color: Colors.black.withOpacity(0.1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(12)),
                child: Image.network(
                  recipe.imageUrl,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey.shade200,
                      alignment: Alignment.center,
                      child: const Icon(Icons.image_not_supported),
                    );
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recipe.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.star, size: 14, color: Colors.orange),
                      const SizedBox(width: 4),
                      Text(
                        recipe.rating.toStringAsFixed(1),
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.local_fire_department, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        recipe.calory?.toString() ?? "N/A",
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    recipe.category.name,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryFilter {
  const _CategoryFilter(this.id, this.name);

  final int? id;
  final String name;
}
