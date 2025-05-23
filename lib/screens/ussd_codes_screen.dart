import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:url_launcher/url_launcher.dart';

class UssdCodesScreen extends StatefulWidget {
  const UssdCodesScreen({super.key});

  @override
  State<UssdCodesScreen> createState() => _UssdCodesScreenState();
}

class _UssdCodesScreenState extends State<UssdCodesScreen> {
  List<dynamic> _ussdData = [];
  bool _isLoading = true;
  String? _selectedOperator;

  @override
  void initState() {
    super.initState();
    _loadUssdData();
  }

  Future<void> _loadUssdData() async {
    try {
      final String response = await rootBundle.loadString('assets/ussd_data.json');
      final data = await json.decode(response);
      setState(() {
        _ussdData = data;
        if (_ussdData.isNotEmpty) {
          _selectedOperator = _ussdData[0]['operator']; // Select first operator by default
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      // Handle error loading data
      print('Error loading USSD data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur lors du chargement des codes USSD.')),
        );
      }
    }
  }

  Future<void> _launchUssd(String code) async {
    // Replace placeholders like {CODE} or {NUMERO}
    // For now, we handle simple codes. Complex codes with inputs need more logic.
    if (code.contains('{')) {
      // Placeholder for future implementation: Show a dialog to input the required value
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ce code nécessite une saisie manuelle : $code')),
        );
      }
      return;
    }

    final Uri url = Uri(scheme: 'tel', path: Uri.encodeComponent(code));
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      } else {
        throw Exception('Could not launch $url');
      }
    } catch (e) {
      print('Could not launch $url: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Impossible de lancer le code USSD : $code')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // No separate AppBar needed as it's part of HomeScreen
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _ussdData.isEmpty
              ? const Center(child: Text('Aucun code USSD trouvé.'))
              : Column(
                  children: [
                    _buildOperatorSelector(),
                    Expanded(
                      child: _buildOperatorCodes(),
                    ),
                  ],
                ),
    );
  }

  Widget _buildOperatorSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      // Use a surface color for background for better theme adaptation
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: DropdownButton<String>(
        value: _selectedOperator,
        isExpanded: true,
        underline: Container(), // Remove underline
        // Style dropdown to match modern theme
        icon: const Icon(Icons.arrow_drop_down_outlined),
        style: Theme.of(context).textTheme.titleMedium,
        dropdownColor: Theme.of(context).colorScheme.surfaceContainer,
        onChanged: (String? newValue) {
          setState(() {
            _selectedOperator = newValue;
          });
        },
        items: _ussdData.map<DropdownMenuItem<String>>((dynamic operatorData) {
          return DropdownMenuItem<String>(
            value: operatorData['operator'],
            child: Text(operatorData['operator']),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildOperatorCodes() {
    if (_selectedOperator == null) {
      return const Center(child: Text('Sélectionnez un opérateur.'));
    }

    final operatorData = _ussdData.firstWhere((op) => op['operator'] == _selectedOperator);
    final categories = operatorData['categories'] as List<dynamic>;

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80), // Add padding to avoid FAB overlap
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        final codes = category['codes'] as List<dynamic>;
        return ExpansionTile(
          // Style ExpansionTile for modern look
          shape: const Border(), // Remove default border
          collapsedShape: const Border(), // Remove default border when collapsed
          leading: const Icon(Icons.category_outlined), // Modernized icon
          title: Text(category['name'], style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
          children: codes.map<Widget>((codeData) {
            return ListTile(
              title: Text(codeData['description']),
              subtitle: Text(codeData['code']),
              trailing: IconButton(
                icon: const Icon(Icons.dialpad_outlined), // Modernized icon
                onPressed: () => _launchUssd(codeData['code']),
                tooltip: 'Composer',
              ),
              onTap: () => _launchUssd(codeData['code']), // Also dial on tap
            );
          }).toList(),
        );
      },
    );
  }
}

