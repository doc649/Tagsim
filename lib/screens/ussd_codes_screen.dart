import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

// Helper function to get Material IconData from string name
// (This is a simplified example; a real app might use a map or code generation)
IconData getIconData(String iconName) {
  // Add more mappings as needed based on ussd_icon_mapping.json
  switch (iconName) {
    case 'account_balance_wallet':
      return Icons.account_balance_wallet;
    case 'add_card':
      return Icons.add_card;
    case 'send_to_mobile':
      return Icons.send_to_mobile;
    case 'perm_identity':
      return Icons.perm_identity;
    case 'phone_callback':
      return Icons.phone_callback;
    case 'notifications_active':
      return Icons.notifications_active;
    case 'notifications_off':
      return Icons.notifications_off;
    case 'visibility_off':
      return Icons.visibility_off;
    case 'cancel_schedule_send':
      return Icons.cancel_schedule_send;
    case 'local_offer':
      return Icons.local_offer;
    case 'dialpad':
      return Icons.dialpad;
    case 'data_usage':
      return Icons.data_usage;
    default:
      return Icons.help_outline; // Default icon
  }
}

class UssdCodesScreen extends StatefulWidget {
  const UssdCodesScreen({super.key});

  @override
  State<UssdCodesScreen> createState() => _UssdCodesScreenState();
}

class _UssdCodesScreenState extends State<UssdCodesScreen>
    with SingleTickerProviderStateMixin {
  List<dynamic> _ussdData = [];
  Map<String, dynamic> _iconMapping = {};
  late TabController _tabController;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      // Load USSD data
      final String ussdResponse = await rootBundle.loadString('assets/ussd_data.json');
      final List<dynamic> ussdData = json.decode(ussdResponse);

      // Load icon mapping
      final String iconResponse = await rootBundle.loadString('assets/ussd_icon_mapping.json');
      final Map<String, dynamic> iconMapping = json.decode(iconResponse);

      setState(() {
        _ussdData = ussdData;
        _iconMapping = iconMapping;
        _tabController = TabController(length: _ussdData.length, vsync: this);
        _isLoading = false;
      });
    } catch (e) {
      // Handle loading errors (e.g., show an error message)
      print('Erreur de chargement des données USSD: $e');
      setState(() {
        _isLoading = false;
      });
      // Optionally show a snackbar or dialog
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erreur de chargement des données USSD.')),
      );
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _launchUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url)) {
      print('Impossible de lancer $urlString');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible de lancer le code : $urlString')),
      );
    }
  }

  void _handleCodeTap(String code, String description) {
    // Regex to find parameters like {PARAM_NAME}
    final RegExp paramRegex = RegExp(r'\{([^}]+)\}');
    final Iterable<RegExpMatch> matches = paramRegex.allMatches(code);

    if (matches.isEmpty) {
      // No parameters, launch directly
      final String url = 'tel:${Uri.encodeComponent(code)}';
      _launchUrl(url);
    } else {
      // Parameters found, show dialog
      _showParameterDialog(code, description, matches.toList());
    }
  }

  Future<void> _showParameterDialog(String codeTemplate, String description, List<RegExpMatch> matches) async {
    final Map<String, TextEditingController> controllers = {};
    final List<Widget> fields = [];

    for (final match in matches) {
      final String paramName = match.group(1)!; // Get the name inside {}
      final controller = TextEditingController();
      controllers[paramName] = controller;
      fields.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.phone, // Adjust as needed (number, text)
            decoration: InputDecoration(
              labelText: paramName.replaceAll('_', ' '), // User-friendly label
              hintText: 'Entrez ${paramName.replaceAll('_', ' ').toLowerCase()}',
              border: const OutlineInputBorder(),
            ),
          ),
        ),
      );
    }

    return showDialog<void>(
      context: context,
      barrierDismissible: true, // Allow dismissing by tapping outside
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(description),
          content: SingleChildScrollView(
            child: ListBody(
              children: fields,
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Annuler'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Valider et Lancer'),
              onPressed: () {
                String finalCode = codeTemplate;
                bool allFilled = true;
                controllers.forEach((paramName, controller) {
                  if (controller.text.isEmpty) {
                    allFilled = false;
                  } else {
                    finalCode = finalCode.replaceAll('{$paramName}', controller.text);
                  }
                });

                if (allFilled) {
                  Navigator.of(context).pop();
                  final String url = 'tel:${Uri.encodeComponent(finalCode)}';
                  _launchUrl(url);
                } else {
                  // Show error if fields are empty
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Veuillez remplir tous les champs.')),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Codes USSD Algérie'),
        bottom: _isLoading || _ussdData.isEmpty
            ? null
            : TabBar(
                controller: _tabController,
                isScrollable: true,
                labelColor: Theme.of(context).colorScheme.onPrimary, // Couleur du texte de l'onglet sélectionné
                unselectedLabelColor: Theme.of(context).colorScheme.onPrimary.withOpacity(0.7), // Couleur du texte des onglets non sélectionnés
                indicatorColor: Theme.of(context).colorScheme.onPrimary, // Couleur de l'indicateur
                tabs: _ussdData.map((op) => Tab(text: op["operator"])).toList(),
              ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _ussdData.isEmpty
              ? const Center(child: Text('Aucune donnée USSD trouvée.'))
              : TabBarView(
                  controller: _tabController,
                  children: _ussdData.map<Widget>((operatorData) {
                    final List<dynamic> categories = operatorData['categories'];
                    return ListView.builder(
                      padding: const EdgeInsets.all(8.0),
                      itemCount: categories.length,
                      itemBuilder: (context, categoryIndex) {
                        final category = categories[categoryIndex];
                        final List<dynamic> codes = category['codes'];
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
                              child: Text(
                                category['name'],
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ),
                            GridView.builder(
                              shrinkWrap: true, // Important for GridView inside ListView
                              physics: const NeverScrollableScrollPhysics(), // Disable GridView's own scrolling
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3, // Adjust number of columns
                                crossAxisSpacing: 8.0,
                                mainAxisSpacing: 8.0,
                                childAspectRatio: 1.0, // Adjust aspect ratio (icon vs text)
                              ),
                              itemCount: codes.length,
                              itemBuilder: (context, codeIndex) {
                                final codeInfo = codes[codeIndex];
                                final String description = codeInfo['description'];
                                final String code = codeInfo['code'];
                                final String iconName = _iconMapping[description] ?? 'help_outline';
                                final IconData iconData = getIconData(iconName);

                                return InkWell(
                                  onTap: () => _handleCodeTap(code, description),
                                  borderRadius: BorderRadius.circular(8.0),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(iconData, size: 36.0), // Adjust icon size
                                      const SizedBox(height: 8.0),
                                      Text(
                                        description,
                                        textAlign: TextAlign.center,
                                        style: Theme.of(context).textTheme.bodySmall,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                            const Divider(),
                          ],
                        );
                      },
                    );
                  }).toList(),
                ),
    );
  }
}

