import 'package:flutter/material.dart';
import 'package:tagsim/services/user_preferences.dart'; // Import UserPreferences

class BonusConfigScreen extends StatefulWidget {
  const BonusConfigScreen({super.key});

  @override
  State<BonusConfigScreen> createState() => _BonusConfigScreenState();
}

class _BonusConfigScreenState extends State<BonusConfigScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers for SIM 1
  final TextEditingController _sim1CreditController = TextEditingController();
  final TextEditingController _sim1BonusAmountController = TextEditingController();
  final TextEditingController _sim1BonusValidityController = TextEditingController();
  String? _sim1BonusType;

  // Controllers for SIM 2
  final TextEditingController _sim2CreditController = TextEditingController();
  final TextEditingController _sim2BonusAmountController = TextEditingController();
  final TextEditingController _sim2BonusValidityController = TextEditingController();
  String? _sim2BonusType;

  // Controller for estimated call duration
  final TextEditingController _estimatedDurationController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  void _loadPreferences() {
    // Load SIM 1 data
    _sim1CreditController.text = UserPreferences.getSim1Credit().toStringAsFixed(2); // Format to 2 decimal places
    _sim1BonusType = UserPreferences.getSim1BonusType();
    _sim1BonusAmountController.text = UserPreferences.getSim1BonusAmount() ?? '';
    _sim1BonusValidityController.text = UserPreferences.getSim1BonusValidity() ?? '';

    // Load SIM 2 data
    _sim2CreditController.text = UserPreferences.getSim2Credit().toStringAsFixed(2);
    _sim2BonusType = UserPreferences.getSim2BonusType();
    _sim2BonusAmountController.text = UserPreferences.getSim2BonusAmount() ?? '';
    _sim2BonusValidityController.text = UserPreferences.getSim2BonusValidity() ?? '';

    // Load Estimated Duration
    _estimatedDurationController.text = UserPreferences.getEstimatedDuration().toString();

    // Update the state to reflect loaded dropdown values if needed
    // setState(() {}); // Usually not needed if controllers are updated before build
  }


  @override
  void dispose() {
    _sim1CreditController.dispose();
    _sim1BonusAmountController.dispose();
    _sim1BonusValidityController.dispose();
    _sim2CreditController.dispose();
    _sim2BonusAmountController.dispose();
    _sim2BonusValidityController.dispose();
    _estimatedDurationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuration Bonus & Crédits'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text('SIM 1', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              _buildCreditInput(_sim1CreditController, 'Crédit actuel SIM 1 (DA)'),
              _buildBonusSection('Bonus SIM 1', _sim1BonusType, (val) => setState(() => _sim1BonusType = val), _sim1BonusAmountController, _sim1BonusValidityController),
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 20),
              const Text('SIM 2', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              _buildCreditInput(_sim2CreditController, 'Crédit actuel SIM 2 (DA)'),
              _buildBonusSection('Bonus SIM 2', _sim2BonusType, (val) => setState(() => _sim2BonusType = val), _sim2BonusAmountController, _sim2BonusValidityController),
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 20),
              const Text('Appel', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              _buildDurationInput(_estimatedDurationController, 'Durée estimée de l\'appel (minutes)'),
              const SizedBox(height: 30),
              Center(
                child: ElevatedButton(
                  onPressed: _saveConfiguration,
                  child: const Text('Enregistrer la configuration'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCreditInput(TextEditingController controller, String label) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(labelText: label),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Veuillez entrer une valeur';
        }
        final credit = double.tryParse(value);
        if (credit == null || credit < 0) {
          return 'Veuillez entrer un nombre positif valide';
        }
        return null;
      },
    );
  }

  Widget _buildBonusSection(String title, String? selectedType, ValueChanged<String?> onTypeChanged, TextEditingController amountController, TextEditingController validityController) {
    // Ensure the selectedType exists in the items list, otherwise set it to null
    final List<String> bonusTypes = ['Crédit Appels', 'Volume Data', 'Appels Illimités', 'Autre'];
    final String? currentSelectedType = bonusTypes.contains(selectedType) ? selectedType : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
        DropdownButtonFormField<String>(
          value: currentSelectedType, // Use the validated selected type
          hint: const Text('Type de bonus (Optionnel)'),
          onChanged: onTypeChanged,
          items: bonusTypes.map<DropdownMenuItem<String>>((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(value),
            );
          }).toList(),
        ),
        TextFormField(
          controller: amountController,
          decoration: const InputDecoration(labelText: 'Montant/Volume du bonus (Optionnel)'),
          keyboardType: TextInputType.text, // Can be text for 'Illimités'
          // Add validation if needed, e.g., ensure numeric if type is 'Crédit Appels'
        ),
        TextFormField(
          controller: validityController,
          decoration: const InputDecoration(labelText: 'Validité du bonus (JJ/MM/AAAA) (Optionnel)'),
          keyboardType: TextInputType.datetime,
          validator: (value) {
            if (value == null || value.isEmpty) return null; // Optional field
            try {
              // Basic format check (doesn't validate date logic like day/month range)
              final RegExp dateRegex = RegExp(r'^\d{2}/\d{2}/\d{4}$');
              if (!dateRegex.hasMatch(value)) {
                 return 'Format JJ/MM/AAAA requis';
              }
              // Could add more robust date parsing/validation here if needed
            } catch (e) {
              return 'Format de date invalide';
            }
            return null;
          },
        ),
      ],
    );
  }

   Widget _buildDurationInput(TextEditingController controller, String label) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(labelText: label),
      keyboardType: TextInputType.number,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Veuillez entrer une durée';
        }
        final duration = int.tryParse(value);
        if (duration == null || duration <= 0) {
          return 'Veuillez entrer un nombre entier positif';
        }
        return null;
      },
    );
  }

  Future<void> _saveConfiguration() async { // Make async
    if (_formKey.currentState!.validate()) {
      try {
        // Parse values safely
        final double sim1Credit = double.parse(_sim1CreditController.text);
        final String? sim1BonusAmount = _sim1BonusAmountController.text.isNotEmpty ? _sim1BonusAmountController.text : null;
        final String? sim1BonusValidity = _sim1BonusValidityController.text.isNotEmpty ? _sim1BonusValidityController.text : null;

        final double sim2Credit = double.parse(_sim2CreditController.text);
        final String? sim2BonusAmount = _sim2BonusAmountController.text.isNotEmpty ? _sim2BonusAmountController.text : null;
        final String? sim2BonusValidity = _sim2BonusValidityController.text.isNotEmpty ? _sim2BonusValidityController.text : null;

        final int estimatedDuration = int.parse(_estimatedDurationController.text);

        // Save using UserPreferences
        await UserPreferences.saveBonusConfiguration(
          sim1Credit: sim1Credit,
          sim1BonusType: _sim1BonusType,
          sim1BonusAmount: sim1BonusAmount,
          sim1BonusValidity: sim1BonusValidity,
          sim2Credit: sim2Credit,
          sim2BonusType: _sim2BonusType,
          sim2BonusAmount: sim2BonusAmount,
          sim2BonusValidity: sim2BonusValidity,
          estimatedDuration: estimatedDuration,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Configuration sauvegardée avec succès !')),
        );

        // Optionally pop the screen after saving
        if (mounted) {
           Navigator.pop(context);
        }

      } catch (e) {
        print('Error saving configuration: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la sauvegarde: ${e.toString()}')),
        );
      }
    }
  }
}

