import "package:flutter/material.dart";
import "dart:math";

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
  String? _selectedCategoryName;
  String _searchQuery = "";
  List<Category> _categoriesCache = const <Category>[];
  final PageController _featuredPageController = PageController();
  int _featuredPageIndex = 0;
  List<Recipe> _featuredCache = const <Recipe>[];
  String _featuredSourceKey = "";

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  void _loadInitialData() {
    _recipesFuture = RecipeApi.fetchRecipes();
    RecipeApi.fetchCategories().then((value) {
      if (!mounted) {
        return;
      }
      setState(() {
        _categoriesCache = value;
      });
    }).catchError((_) {});
  }

  Future<void> _onRefresh() async {
    final recipes = RecipeApi.fetchRecipes();
    final categories = RecipeApi.fetchCategories().catchError((_) => _categoriesCache);
    final results = await Future.wait([recipes, categories]);
    if (!mounted) return;
    setState(() {
      _recipesFuture = Future.value(results[0] as List<Recipe>);
      _categoriesCache = results[1] as List<Category>;
      _featuredSourceKey = ""; // reset so featured picks refresh
    });
  }

  @override
  void dispose() {
    _featuredPageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Khmer Recipes"),
        automaticallyImplyLeading: false,
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
          return RefreshIndicator(
            onRefresh: _onRefresh,
            color: Colors.green,
            child: _buildContent(context, recipes),
          );
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
                  _loadInitialData();
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
    final categories = _buildCategories(recipes, _categoriesCache);
    if (_selectedCategoryName != null &&
        !categories.any((category) => category.id == _selectedCategoryName)) {
      _selectedCategoryName = null;
    }
    final filtered = _filterByCategory(recipes, _selectedCategoryName);
    final searched = _filterBySearch(filtered, _searchQuery);
    final featured = _resolveFeatured(searched);
    final popular = _pickPopular(searched);

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
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
          if (featured.isEmpty)
            const Text("No recipes available.")
          else
            _featuredCarousel(context, featured),
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

  List<_CategoryFilter> _buildCategories(
    List<Recipe> recipes,
    List<Category> categoriesFromApi,
  ) {
    final Set<String> names = {};
    for (final category in categoriesFromApi) {
      final name = category.name.trim();
      if (name.isNotEmpty) {
        names.add(name);
      }
    }
    if (names.isEmpty) {
      for (final recipe in recipes) {
        final name = recipe.category.name.trim();
        if (name.isNotEmpty) {
          names.add(name);
        }
      }
    }
    final sortedNames = names.toList()..sort();
    return [
      const _CategoryFilter(null, "All"),
      ...sortedNames.map((name) => _CategoryFilter(name, name)),
    ];
  }

  List<Recipe> _filterByCategory(List<Recipe> recipes, String? selectedName) {
    if (selectedName == null) {
      return recipes;
    }
    return recipes
        .where(
          (recipe) =>
              recipe.category.name.toLowerCase() == selectedName.toLowerCase(),
        )
        .toList();
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

  List<Recipe> _resolveFeatured(List<Recipe> recipes) {
    final sourceKey = recipes.map((recipe) => recipe.id).join(",");
    if (sourceKey == _featuredSourceKey) {
      return _featuredCache;
    }
    _featuredSourceKey = sourceKey;
    _featuredCache = _pickRandomFeatured(recipes);
    _featuredPageIndex = 0;
    if (_featuredPageController.hasClients) {
      _featuredPageController.jumpToPage(0);
    }
    return _featuredCache;
  }

  List<Recipe> _pickRandomFeatured(List<Recipe> recipes) {
    if (recipes.isEmpty) {
      return const <Recipe>[];
    }
    final randomized = [...recipes]..shuffle(Random());
    return randomized.take(3).toList();
  }

  List<Recipe> _pickPopular(List<Recipe> recipes) {
    final sorted = [...recipes]
      ..sort((a, b) => b.rating.compareTo(a.rating));
    return sorted;
  }

  Widget _categoryChip(_CategoryFilter category) {
    final isSelected = _selectedCategoryName == category.id;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(category.name),
        selected: isSelected,
        onSelected: (_) {
          setState(() {
            _selectedCategoryName = category.id;
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

  Widget _featuredCarousel(BuildContext context, List<Recipe> recipes) {
    return Column(
      children: [
        SizedBox(
          height: 200,
          child: PageView.builder(
            controller: _featuredPageController,
            itemCount: recipes.length,
            onPageChanged: (index) {
              setState(() {
                _featuredPageIndex = index;
              });
            },
            itemBuilder: (context, index) {
              return _featuredCard(context, recipes[index]);
            },
          ),
        ),
        if (recipes.length > 1) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(recipes.length, (index) {
              final selected = index == _featuredPageIndex;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: selected ? 18 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: selected ? Colors.green.shade400 : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              );
            }),
          ),
        ],
      ],
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

  final String? id;
  final String name;
}
