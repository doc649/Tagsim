import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart'; // Import SharedPreferences
import 'package:url_launcher/url_launcher.dart';

// Model class for a promotion
class Promotion {
  final String operator;
  final String title;
  final String description;
  final String validity;
  final String? link; // Link can be optional
  final double priceNumeric; // Added for sorting
  final String? badge; // Added for badges
  final String id; // Added for favorites

  Promotion({
    required this.operator,
    required this.title,
    required this.description,
    required this.validity,
    this.link,
    required this.priceNumeric,
    this.badge,
    required this.id, // Generate or assign a unique ID
  });

  factory Promotion.fromJson(Map<String, dynamic> json, int index) {
    return Promotion(
      operator: json["operator"] ?? "Unknown",
      title: json["name"] ?? "No Title", // Use 'name' from JSON
      description: json["description"] ?? "No Description",
      validity: json['validity'] ?? 'N/A',
      link: json['link'], // Keep link as nullable
      priceNumeric: (json['price_numeric'] ?? 9999.0).toDouble(), // Default high price if missing
      badge: json['badge'],
      id: '${json["operator"]}_${json["name"]}_$index', // Simple unique ID based on operator, name, and index
    );
  }
}

class OfferComparatorScreen extends StatefulWidget {
  const OfferComparatorScreen({super.key});

  @override
  State<OfferComparatorScreen> createState() => _OfferComparatorScreenState();
}

enum SortOption { name, price }

class _OfferComparatorScreenState extends State<OfferComparatorScreen> {
  List<Promotion> _allPromotions = [];
  List<Promotion> _filteredPromotions = [];
  bool _isLoading = true;
  String? _errorLoading;
  final TextEditingController _searchController = TextEditingController();
  Set<String> _selectedOperators = {}; // For filtering
  SortOption _sortOption = SortOption.name; // Default sort
  Set<String> _favoriteOfferIds = {}; // For favorites

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(_filterPromotions);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterPromotions);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorLoading = null;
    });
    try {
      // Load SharedPreferences for favorites
      final prefs = await SharedPreferences.getInstance();
      _favoriteOfferIds = (prefs.getStringList('favorite_offers') ?? []).toSet();

      // Load promotions
      final String jsonString = await rootBundle.loadString('assets/data/promotions.json');
      final List<dynamic> jsonList = json.decode(jsonString);
      final List<Promotion> loadedPromotions = [];
      for (int i = 0; i < jsonList.length; i++) {
        loadedPromotions.add(Promotion.fromJson(jsonList[i], i));
      }

      if (mounted) {
        setState(() {
          _allPromotions = loadedPromotions;
          _selectedOperators = _allPromotions.map((p) => p.operator).toSet(); // Select all by default
          _filterPromotions(); // Apply initial filter/sort
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading data: $e');
      if (mounted) {
        setState(() {
          _errorLoading = 'Impossible de charger les données.';
          _isLoading = false;
        });
      }
    }
  }

  void _filterPromotions() {
    List<Promotion> tempPromotions = _allPromotions;

    // Filter by search query
    final query = _searchController.text.toLowerCase();
    if (query.isNotEmpty) {
      tempPromotions = tempPromotions.where((promo) {
        return promo.title.toLowerCase().contains(query) ||
               promo.operator.toLowerCase().contains(query) ||
               promo.description.toLowerCase().contains(query);
      }).toList();
    }

    // Filter by selected operators
    if (_selectedOperators.isNotEmpty && _selectedOperators.length < _allPromotions.map((p) => p.operator).toSet().length) {
       tempPromotions = tempPromotions.where((promo) => _selectedOperators.contains(promo.operator)).toList();
    }

    // Sort promotions
    tempPromotions.sort((a, b) {
      if (_sortOption == SortOption.name) {
        return a.title.compareTo(b.title);
      } else { // SortOption.price
        return a.priceNumeric.compareTo(b.priceNumeric);
      }
    });

    setState(() {
      _filteredPromotions = tempPromotions;
    });
  }

  Future<void> _toggleFavorite(String offerId) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (_favoriteOfferIds.contains(offerId)) {
        _favoriteOfferIds.remove(offerId);
      } else {
        _favoriteOfferIds.add(offerId);
      }
    });
    await prefs.setStringList('favorite_offers', _favoriteOfferIds.toList());
  }

  Future<void> _launchURL(String? urlString) async {
    if (urlString == null || urlString.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucun lien disponible pour cette offre.')),
      );
      return;
    }
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
       ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible d\'ouvrir le lien: $urlString')),
      );
    }
  }

  String _getOperatorLogoPath(String operatorName) {
    switch (operatorName.toLowerCase()) {
      case 'mobilis':
        return 'assets/logos/mobilis_logo.png'; // Updated path
      case 'djezzy':
        return 'assets/logos/djezzy_logo_simple.png'; // Use simplified logo
      case 'ooredoo':
        return 'assets/logos/ooredoo_logo.png'; // Updated path
      default:
        return 'assets/logos/generated_app_logo.png'; // Fallback
    }
  }

  Color _getBadgeColor(String? badge) {
      switch (badge?.toLowerCase()) {
        case 'nouveau':
          return Colors.blue;
        case 'populaire':
          return Colors.orange;
        default:
          return Colors.transparent; // No color if no badge
      }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorLoading != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(_errorLoading!, textAlign: TextAlign.center),
        ),
      );
    }

    final allOperators = _allPromotions.map((p) => p.operator).toSet().toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0), // Reduced vertical padding
          child: TextField(
            controller: _searchController,
            style: const TextStyle(color: Colors.black87), // Force darker text color
            decoration: InputDecoration(
              hintText: 'Rechercher par nom, opérateur...', // French hint text
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(25.0),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.grey[200],
              contentPadding: const EdgeInsets.symmetric(vertical: 10.0), // Reduce height of TextField itself
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0), // Reduced vertical padding
          child: Wrap( // Use Wrap for filters/sorts
            spacing: 4.0, // Reduced spacing
            runSpacing: 0.0, // Reduced runSpacing
            children: [
              // Operator Filters
              ...allOperators.map((op) => FilterChip(
                label: Text(op),
                labelPadding: const EdgeInsets.symmetric(horizontal: 4.0), // Reduce padding
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap, // Reduce tap target size
                selected: _selectedOperators.contains(op),
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedOperators.add(op);
                    } else {
                      _selectedOperators.remove(op);
                    }
                    _filterPromotions();
                  });
                },
              )).toList(),
              // Sort Options
              ChoiceChip(
                label: const Text('Trier par Nom'),
                labelPadding: const EdgeInsets.symmetric(horizontal: 4.0), // Reduce padding
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap, // Reduce tap target size
                selected: _sortOption == SortOption.name,
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      _sortOption = SortOption.name;
                      _filterPromotions();
                    });
                  }
                },
              ),
              ChoiceChip(
                label: const Text("Trier par Prix"),
                labelPadding: const EdgeInsets.symmetric(horizontal: 4.0), // Reduce padding
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap, // Reduce tap target size
                selected: _sortOption == SortOption.price,
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      _sortOption = SortOption.price;
                      _filterPromotions();
                    });
                  }
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: _filteredPromotions.isEmpty
              ? const Center(child: Text('Aucune offre ne correspond aux critères.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(8.0),
                  itemCount: _filteredPromotions.length,
                  itemBuilder: (context, index) {
                    final promo = _filteredPromotions[index];
                    final isFavorite = _favoriteOfferIds.contains(promo.id);
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                      elevation: 2,
                      clipBehavior: Clip.antiAlias, // Ensures InkWell splash is contained
                      child: InkWell( // Make the whole card clickable
                        onTap: () => _launchURL(promo.link),
                        child: Stack( // Use Stack for badge and logo overlay
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      // Operator Logo (adjusted position)
                                      // Image.asset(
                                      //   _getOperatorLogoPath(promo.operator),
                                      //   height: 24,
                                      //   errorBuilder: (context, error, stackTrace) => const Icon(Icons.business, size: 24),
                                      // ),
                                      // const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          promo.title,
                                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      // Favorite Icon
                                      IconButton(
                                        icon: Icon(
                                          isFavorite ? Icons.star : Icons.star_border,
                                          color: isFavorite ? Colors.amber : Colors.grey,
                                        ),
                                        onPressed: () => _toggleFavorite(promo.id),
                                      ),
                                    ],
                                  ),
                                  const Divider(height: 16),
                                  Text(promo.description),
                                  const SizedBox(height: 8),
                                  Row( // Row for Validity Icon and Text
                                    children: [
                                      const Icon(Icons.calendar_today, size: 14, color: Colors.grey), // Validity Icon
                                      const SizedBox(width: 4),
                                      Text(
                                        'Validité: ${promo.validity}',
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
                                      ),
                                    ],
                                  ),
                                  // Removed the specific button, handled by InkWell
                                ],
                              ),
                            ),
                            // Operator Logo (Top Left)
                            Positioned(
                              top: 8,
                              left: 8,
                              child: Image.asset(
                                _getOperatorLogoPath(promo.operator),
                                height: 20, // Smaller logo
                                errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(), // Hide if error
                              ),
                            ),
                            // Badge (Top Right)
                            if (promo.badge != null)
                              Positioned(
                                top: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _getBadgeColor(promo.badge),
                                    borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(8)),
                                  ),
                                  child: Text(
                                    promo.badge!,
                                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

