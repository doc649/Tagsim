import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:url_launcher/url_launcher.dart'; // Import url_launcher

// Model class for a promotion
class Promotion {
  final String operator;
  final String title;
  final String description;
  final String validity;
  final String? link; // Link can be optional

  Promotion({
    required this.operator,
    required this.title,
    required this.description,
    required this.validity,
    this.link,
  });

  factory Promotion.fromJson(Map<String, dynamic> json) {
    return Promotion(
      operator: json['operator'] ?? 'Unknown',
      title: json['title'] ?? 'No Title',
      description: json['description'] ?? 'No Description',
      validity: json['validity'] ?? 'N/A',
      link: json['link'], // Keep link as nullable
    );
  }
}

class OfferComparatorScreen extends StatefulWidget {
  const OfferComparatorScreen({super.key});

  @override
  State<OfferComparatorScreen> createState() => _OfferComparatorScreenState();
}

class _OfferComparatorScreenState extends State<OfferComparatorScreen> {
  List<Promotion> _promotions = [];
  bool _isLoading = true;
  String? _errorLoading;

  @override
  void initState() {
    super.initState();
    _loadPromotions();
  }

  Future<void> _loadPromotions() async {
    setState(() {
      _isLoading = true;
      _errorLoading = null;
    });
    try {
      final String jsonString = await rootBundle.loadString('assets/data/promotions.json');
      final List<dynamic> jsonList = json.decode(jsonString);
      final List<Promotion> loadedPromotions = jsonList.map((jsonItem) => Promotion.fromJson(jsonItem)).toList();

      if (mounted) {
        setState(() {
          _promotions = loadedPromotions;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading or parsing promotions.json: $e');
      if (mounted) {
        setState(() {
          _errorLoading = 'Impossible de charger les promotions. Vérifiez le fichier promotions.json.';
          _isLoading = false;
        });
      }
    }
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
        SnackBar(content: Text('Impossible d\ouvrir le lien: $urlString')),
      );
    }
  }

  // Helper to get operator logo path (similar to contacts_screen)
  String _getOperatorLogoPath(String operatorName) {
    switch (operatorName.toLowerCase()) {
      case 'mobilis':
        return 'assets/images/mobilis_logo.png'; // Assuming PNG is preferred
      case 'djezzy':
        return 'assets/images/djezzy_logo.png';
      case 'ooredoo':
        return 'assets/images/ooredoo_logo.png';
      default:
        return 'assets/images/app_logo_final.png'; // Fallback or generic icon
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // AppBar is handled by HomeScreen now
      // appBar: AppBar(
      //   title: const Text('Comparateur d\offres'),
      // ),
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

    if (_promotions.isEmpty) {
      return const Center(child: Text('Aucune promotion trouvée dans promotions.json.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8.0),
      itemCount: _promotions.length,
      itemBuilder: (context, index) {
        final promo = _promotions[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Image.asset(
                      _getOperatorLogoPath(promo.operator),
                      height: 24, // Small logo
                      errorBuilder: (context, error, stackTrace) => const Icon(Icons.business, size: 24),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        promo.title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 16),
                Text(promo.description),
                const SizedBox(height: 8),
                Text(
                  'Validité: ${promo.validity}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
                ),
                if (promo.link != null && promo.link!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        icon: const Icon(Icons.open_in_new, size: 18),
                        label: const Text('Voir l\offre'),
                        onPressed: () => _launchURL(promo.link),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

