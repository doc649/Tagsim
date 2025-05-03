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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erreur lors du chargement des codes USSD.')),
      );
    }
  }

  Future<void> _launchUssd(String code) async {
    // Replace placeholders like {CODE} or {NUMERO}
    // For now, we handle simple codes. Complex codes with inputs need more logic.
    if (code.contains('{')) {
      // Placeholder for future implementation: Show a dialog to input the required value
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ce code nécessite une saisie manuelle : $code')),
      );
      return;
    }

    final Uri url = Uri(scheme: 'tel', path: Uri.encodeComponent(code));
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      print('Could not launch $url');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible de lancer le code USSD : $code')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Codes USSD Algérie'),
        elevation: 0, // Remove shadow for a cleaner look integrated with body
      ),
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
      color: Theme.of(context).primaryColor.withOpacity(0.1),
      child: DropdownButton<String>(
        value: _selectedOperator,
        isExpanded: true,
        underline: Container(), // Remove underline
        onChanged: (String? newValue) {
          setState(() {
            _selectedOperator = newValue;
          });
        },
        items: _ussdData.map<DropdownMenuItem<String>>((dynamic operatorData) {
          return DropdownMenuItem<String>(
            value: operatorData['operator'],
            child: Text(operatorData['operator'], style: const TextStyle(fontWeight: FontWeight.bold)),
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
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        final codes = category['codes'] as List<dynamic>;
        return ExpansionTile(
          title: Text(category['name'], style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
          children: codes.map<Widget>((codeData) {
            return ListTile(
              title: Text(codeData['description']),
              subtitle: Text(codeData['code']),
              trailing: IconButton(
                icon: const Icon(Icons.dialpad),
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

