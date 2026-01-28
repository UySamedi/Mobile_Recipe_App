import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/recipe.dart';
import '../../services/recipe_api.dart';
import '../Recipe_Detail_Screen/recipe_detail_view.dart';

class SearchView extends StatefulWidget {
  const SearchView({super.key});

  @override
  State<SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<SearchView> {
  late Future<List<Recipe>> _resultsFuture;
  late Future<List<Recipe>> _allRecipesFuture;
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  int? _selectedCategoryId;
  Timer? _debounce;
  final Set<String> _selectedIngredients = <String>{};
  List<Recipe> _allRecipesCache = const <Recipe>[];

  @override
  void initState() {
    super.initState();
    _refreshAllRecipes(updateResults: true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search'),
      ),
      body: FutureBuilder<List<Recipe>>(
        future: _resultsFuture,
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
              'Could not load recipes.',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              error?.toString() ?? 'Unknown error',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                if (_query.trim().isEmpty) {
                  _refreshAllRecipes(updateResults: true);
                } else {
                  _runSearch();
                }
              },
              child: const Text('Retry'),
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
    final results = _sortByRating(filtered);
    final ingredientOptions = _buildIngredientOptions(
      _allRecipesCache.isEmpty ? recipes : _allRecipesCache,
    );

    final topSection = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search ingredients (comma separated)',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _query = '';
                        _selectedIngredients.clear();
                        _selectedCategoryId = null;
                        _resultsFuture = _allRecipesFuture;
                      });
                    },
                  ),
            filled: true,
            fillColor: Colors.grey.shade200,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          onChanged: (value) {
            _onQueryChanged(value);
          },
        ),
        const SizedBox(height: 16),
        if (ingredientOptions.isNotEmpty) ...[
          const Text(
            'Ingredients',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ingredientOptions.map((option) {
              final selected = _selectedIngredients.contains(option.name);
              return FilterChip(
                label: Text(
                  option.name,
                  style: const TextStyle(fontSize: 10),
                ),
                selected: selected,
                onSelected: (value) {
                  _onIngredientChipToggled(option.name, value);
                },
                selectedColor: Colors.green.shade200,
                backgroundColor: Colors.grey.shade200,
                checkmarkColor: Colors.green.shade900,
                labelPadding: const EdgeInsets.symmetric(horizontal: 5),
                padding: const EdgeInsets.symmetric(horizontal: 3),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
        ],
        if (categories.length > 1) ...[
          const Text(
            'Filter by category',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: categories.map(_categoryChip).toList(),
            ),
          ),
          const SizedBox(height: 16),
        ],
        Text(
          _query.trim().isEmpty
              ? 'Popular recipes'
              : 'Results (${results.length})',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
      ],
    );

    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverToBoxAdapter(
              child: topSection,
            ),
          ),
          if (results.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _emptyState(),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    if (index.isOdd) {
                      return const SizedBox(height: 12);
                    }
                    final recipe = results[index ~/ 2];
                    return _recipeRow(context, recipe);
                  },
                  childCount: results.isEmpty ? 0 : results.length * 2 - 1,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.search_off, size: 48, color: Colors.grey),
            SizedBox(height: 12),
            Text(
              'No recipes match those ingredients.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _refreshAllRecipes({bool updateResults = false}) {
    final future = RecipeApi.fetchRecipes();
    _allRecipesFuture = future;
    if (updateResults) {
      _resultsFuture = future;
    }
    future.then((value) {
      if (!mounted) {
        return;
      }
      setState(() {
        _allRecipesCache = value;
      });
    });
  }

  void _onQueryChanged(String value) {
    setState(() {
      _query = value;
      _selectedCategoryId = null;
      _setSelectedIngredients(_parseIngredients(value));
    });
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) {
        return;
      }
      _runSearch();
    });
  }

  void _runSearch() {
    final names = _parseIngredients(_query);
    setState(() {
      _resultsFuture =
          names.isEmpty ? _allRecipesFuture : RecipeApi.searchByIngredients(names);
    });
  }

  void _onIngredientChipToggled(String name, bool selected) {
    _debounce?.cancel();
    setState(() {
      if (selected) {
        _selectedIngredients.add(name);
      } else {
        _selectedIngredients.remove(name);
      }
      _selectedCategoryId = null;
      _query = _selectedIngredients.join(', ');
      _searchController.text = _query;
      _searchController.selection = TextSelection.collapsed(
        offset: _searchController.text.length,
      );
      _resultsFuture = _selectedIngredients.isEmpty
          ? _allRecipesFuture
          : RecipeApi.searchByIngredients(_selectedIngredients.toList());
    });
  }

  void _setSelectedIngredients(List<String> names) {
    _selectedIngredients
      ..clear()
      ..addAll(names);
  }

  List<String> _parseIngredients(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      return const <String>[];
    }
    return trimmed
        .split(RegExp(r"[,\n;]"))
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
  }

  List<_CategoryFilter> _buildCategories(List<Recipe> recipes) {
    final Map<int, String> byId = {};
    for (final recipe in recipes) {
      byId.putIfAbsent(recipe.category.id, () => recipe.category.name);
    }
    final entries = byId.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    return [
      const _CategoryFilter(null, 'All'),
      ...entries.map((entry) => _CategoryFilter(entry.key, entry.value)),
    ];
  }

  List<Recipe> _filterByCategory(List<Recipe> recipes, int? selectedId) {
    if (selectedId == null) {
      return recipes;
    }
    return recipes.where((recipe) => recipe.category.id == selectedId).toList();
  }

  List<Recipe> _sortByRating(List<Recipe> recipes) {
    final sorted = [...recipes]
      ..sort((a, b) => b.rating.compareTo(a.rating));
    return sorted;
  }

  List<_IngredientOption> _buildIngredientOptions(List<Recipe> recipes) {
    final Map<String, int> counts = {};
    for (final recipe in recipes) {
      for (final item in recipe.ingredients) {
        final name = item.ingredient.name.trim();
        if (name.isEmpty) {
          continue;
        }
        counts.update(name, (value) => value + 1, ifAbsent: () => 1);
      }
    }
    final options = counts.entries
        .map((entry) => _IngredientOption(entry.key, entry.value))
        .toList()
      ..sort((a, b) {
        final countCompare = b.count.compareTo(a.count);
        if (countCompare != 0) {
          return countCompare;
        }
        return a.name.compareTo(b.name);
      });
    const maxChips = 18;
    if (options.length <= maxChips) {
      return options;
    }
    return options.sublist(0, maxChips);
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

  Widget _recipeRow(BuildContext context, Recipe recipe) {
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
              color: Colors.black.withOpacity(0.08),
            ),
          ],
        ),
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                recipe.imageUrl,
                width: 90,
                height: 90,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 90,
                    height: 90,
                    color: Colors.grey.shade200,
                    alignment: Alignment.center,
                    child: const Icon(Icons.image_not_supported),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recipe.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
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
                      const SizedBox(width: 10),
                      const Icon(Icons.local_fire_department, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        recipe.calory?.toString() ?? 'N/A',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    recipe.category.name,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                  if (recipe.description.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      recipe.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
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

class _IngredientOption {
  const _IngredientOption(this.name, this.count);

  final String name;
  final int count;
}
