import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_sim_dz/utils/operator_detector.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Operator _sim1Operator = Operator.unknown;
  Operator _sim2Operator = Operator.unknown;
  bool _isPremium = false; // Ajouter le statut premium
  bool _isLoading = true;

  // Clés pour SharedPreferences
  static const String sim1PrefKey = 'sim1_operator';
  static const String sim2PrefKey = 'sim2_operator';
  static const String premiumStatusKey = 'is_premium'; // Clé pour le statut premium

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _sim1Operator = Operator.values[prefs.getInt(sim1PrefKey) ?? Operator.unknown.index];
      _sim2Operator = Operator.values[prefs.getInt(sim2PrefKey) ?? Operator.unknown.index];
      _isPremium = prefs.getBool(premiumStatusKey) ?? false; // Charger le statut premium
      _isLoading = false;
    });
  }

  Future<void> _saveSimConfiguration(int simSlot, Operator selectedOperator) async {
    final prefs = await SharedPreferences.getInstance();
    final key = simSlot == 1 ? sim1PrefKey : sim2PrefKey;
    await prefs.setInt(key, selectedOperator.index);
    setState(() {
      if (simSlot == 1) {
        _sim1Operator = selectedOperator;
      } else {
        _sim2Operator = selectedOperator;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Configuration SIM $simSlot sauvegardée: ${getOperatorName(selectedOperator)}')), 
    );
  }

  // Placeholder pour la demande de premium
  void _requestPremium() {
    // Afficher une boîte de dialogue avec les instructions (à définir)
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Passer à Premium'),
        content: const SingleChildScrollView(
          child: Text(
              'Pour supprimer les publicités, veuillez effectuer un paiement de [Montant à définir] DA via [Méthode à définir, ex: CCP, BaridiMob] et envoyer une preuve (capture d\`écran, référence) à [Contact à définir, ex: email, WhatsApp].\n\nVotre compte sera activé manuellement après vérification.'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuration'), // Titre généralisé
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView( // Utiliser ListView pour permettre le défilement si nécessaire
              padding: const EdgeInsets.all(16.0),
              children: [
                // Section Configuration SIM
                Text(
                  'Configuration des SIMs',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Assignez l\'opérateur correspondant à chaque emplacement SIM de votre téléphone.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                _buildSimSelector(1, _sim1Operator),
                const SizedBox(height: 16),
                _buildSimSelector(2, _sim2Operator),
                const SizedBox(height: 16),
                Text(
                  'Note: Cette configuration permet à l\'application de recommander la bonne SIM pour appeler vos contacts.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const Divider(height: 40),

                // Section Premium
                Text(
                  'Version Premium',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 16),
                if (_isPremium)
                  const ListTile(
                    leading: Icon(Icons.check_circle, color: Colors.green),
                    title: Text('Vous êtes un utilisateur Premium !'),
                    subtitle: Text('Merci pour votre soutien. Aucune publicité ne sera affichée.'),
                  )
                else
                  ListTile(
                    leading: const Icon(Icons.star_border),
                    title: const Text('Supprimer les publicités'),
                    subtitle: const Text('Passez à la version Premium pour une expérience sans publicité.'),
                    trailing: ElevatedButton(
                      onPressed: _requestPremium,
                      child: const Text('Obtenir Premium'),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildSimSelector(int simSlot, Operator currentOperator) {
    List<Operator> availableOperators = [
      Operator.unknown,
      Operator.mobilis,
      Operator.djezzy,
      Operator.ooredoo,
    ];

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SIM $simSlot',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<Operator>(
              value: currentOperator,
              decoration: InputDecoration(
                // labelText: 'Opérateur pour SIM $simSlot',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: availableOperators.map((Operator operator) {
                return DropdownMenuItem<Operator>(
                  value: operator,
                  child: Row(
                    children: [
                      if (operator != Operator.unknown)
                        CircleAvatar(
                          backgroundColor: getOperatorColor(operator),
                          radius: 10,
                        ),
                      if (operator != Operator.unknown)
                        const SizedBox(width: 8),
                      Text(getOperatorName(operator)),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (Operator? newValue) {
                if (newValue != null) {
                  _saveSimConfiguration(simSlot, newValue);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

