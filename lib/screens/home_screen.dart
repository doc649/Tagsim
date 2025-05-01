import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart'; // Importer Share Plus
import 'package:smart_sim_dz/models/contact_with_operator.dart';
import 'package:smart_sim_dz/utils/operator_detector.dart';
import 'package:smart_sim_dz/screens/settings_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoading = true;
  bool _permissionDenied = false;
  List<ContactWithOperator> _processedContacts = [];
  List<ContactWithOperator> _filteredContacts = [];
  final TextEditingController _searchController = TextEditingController();

  Operator _sim1Operator = Operator.unknown;
  Operator _sim2Operator = Operator.unknown;
  int _smartCallCounter = 0;
  bool _isPremium = false;

  // AdMob Banner Ad
  BannerAd? _bannerAd;
  bool _isBannerAdLoaded = false;
  final String _adUnitId = "ca-app-pub-3940256099942544/6300978111"; // ID de test

  // Clés pour SharedPreferences
  static const String sim1PrefKey = 'sim1_operator';
  static const String sim2PrefKey = 'sim2_operator';
  static const String smartCallCounterKey = 'smart_call_counter';
  static const String premiumStatusKey = 'is_premium';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterContacts);
    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    await _loadPreferences();
    // La permission est demandée dans _loadAndProcessContacts avec flutter_contacts
    await _loadAndProcessContacts();
    if (!_isPremium) {
      _loadBannerAd();
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterContacts);
    _searchController.dispose();
    _bannerAd?.dispose();
    super.dispose();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    // Vérifier si le widget est toujours monté
    if (!mounted) return;
    setState(() {
      _sim1Operator = Operator.values[prefs.getInt(sim1PrefKey) ?? Operator.unknown.index];
      _sim2Operator = Operator.values[prefs.getInt(sim2PrefKey) ?? Operator.unknown.index];
      _smartCallCounter = prefs.getInt(smartCallCounterKey) ?? 0;
      _isPremium = prefs.getBool(premiumStatusKey) ?? false;
    });
  }

  void _loadBannerAd() {
    if (_isPremium || !mounted) return;

    _bannerAd = BannerAd(
      adUnitId: _adUnitId,
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (mounted) {
            setState(() {
              _isBannerAdLoaded = true;
            });
          }
        },
        onAdFailedToLoad: (ad, err) {
          print('BannerAd failed to load: $err');
          ad.dispose();
        },
      ),
    )..load();
  }

  Future<void> _incrementSmartCallCounter() async {
    final prefs = await SharedPreferences.getInstance();
    int currentCount = prefs.getInt(smartCallCounterKey) ?? 0;
    currentCount++;
    await prefs.setInt(smartCallCounterKey, currentCount);
    if (mounted) {
      setState(() {
        _smartCallCounter = currentCount;
      });
    }
  }

  // Note: La demande de permission est maintenant intégrée dans _loadAndProcessContacts
  // Future<void> _requestContactsPermission() async { ... }

  Future<void> _loadAndProcessContacts() async {
    if (!mounted) return;
    setState(() { _isLoading = true; });
    try {
      // Demander la permission si ce n'est pas déjà fait (flutter_contacts le gère aussi, mais double vérification)
      if (!await FlutterContacts.requestPermission(readonly: true)) {
        if (mounted) {
          setState(() {
            _permissionDenied = true;
            _isLoading = false;
          });
        }
        return;
      }

      // Récupérer les contacts avec les numéros de téléphone
      final List<Contact> contacts = await FlutterContacts.getContacts(withProperties: true, withPhoto: false);
      if (!mounted) return;

      List<ContactWithOperator> processed = [];
      for (var contact in contacts) {
        // Prendre le premier numéro de téléphone s'il existe
        String? phoneNumber = contact.phones.isNotEmpty ? contact.phones.first.number : null;

        Operator operator = Operator.unknown;
        if (phoneNumber != null) {
          operator = detectOperator(phoneNumber);
        }

        processed.add(ContactWithOperator(
          contact: contact,
          operator: operator,
          primaryPhoneNumber: phoneNumber,
        ));
      }

      // Trier les contacts par nom d'affichage
      processed.sort((a, b) => (a.contact.displayName).toLowerCase().compareTo((b.contact.displayName).toLowerCase()));

      if (mounted) {
        setState(() {
          _processedContacts = processed;
          _filteredContacts = processed;
          _isLoading = false;
          _permissionDenied = false; // Assurer que permissionDenied est false si on arrive ici
        });
      }
    } catch (e) {
      print('Erreur lors du chargement/traitement des contacts: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          // On pourrait considérer _permissionDenied = true ici aussi si l'erreur est liée aux permissions
        });
      }
    }
  }

  void _filterContacts() {
    final query = _searchController.text.toLowerCase();
    if (mounted) {
      setState(() {
        _filteredContacts = _processedContacts.where((c) {
          final name = c.contact.displayName.toLowerCase();
          final phone = c.primaryPhoneNumber?.toLowerCase() ?? '';
          return name.contains(query) || phone.contains(query);
        }).toList();
      });
    }
  }

  int? _getRecommendedSimSlot(Operator contactOperator) {
    if (contactOperator == Operator.unknown) return null;
    if (_sim1Operator == contactOperator) return 1;
    if (_sim2Operator == contactOperator) return 2;
    return null;
  }

  Future<void> _makeCall(String? phoneNumber, int? recommendedSimSlot) async {
    if (phoneNumber == null) return;

    if (recommendedSimSlot != null) {
      await _incrementSmartCallCounter();
    }

    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (!mounted) return;
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Impossible de lancer l\'appel vers $phoneNumber')),
        );
      }
    }
  }

  // Fonction pour partager l'application
  void _shareApp() {
    // TODO: Remplacer par le vrai lien de l'application une fois publiée
    const String appLink = "https://play.google.com/store/apps/details?id=com.example.smart_sim_dz"; // Placeholder
    const String message = "Découvrez Smart SIM DZ, l'application qui vous aide à choisir la bonne SIM pour appeler en Algérie et économiser ! Téléchargez-la ici : $appLink";
    Share.share(message) ;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart SIM DZ'),
        actions: [
          // Bouton Partager
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Partager l\'application',
            onPressed: _shareApp,
          ),
          // Bouton Configuration
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Configuration',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
              await _loadPreferences();
              if (!_isPremium && !_isBannerAdLoaded) {
                 _loadBannerAd();
              }
              if (_isPremium && _isBannerAdLoaded) {
                if (mounted) {
                  setState(() {
                    _isBannerAdLoaded = false;
                    _bannerAd?.dispose();
                    _bannerAd = null;
                  });
                }
              }
            },
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: !_isPremium && _isBannerAdLoaded && _bannerAd != null
          ? SizedBox(
              height: _bannerAd!.size.height.toDouble(),
              width: _bannerAd!.size.width.toDouble(),
              child: AdWidget(ad: _bannerAd!),
            )
          : null,
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    } else if (_permissionDenied) {
      return _buildPermissionDeniedWidget();
    } else {
      return Column(
        children: [
          _buildSmartCallCounterWidget(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Rechercher par nom ou numéro...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Theme.of(context).inputDecorationTheme.fillColor ?? Colors.grey[800],
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
              ),
            ),
          ),
          Expanded(
            child: _filteredContacts.isEmpty
                ? Center(child: Text(_searchController.text.isEmpty ? 'Aucun contact à afficher.' : 'Aucun contact trouvé pour "${_searchController.text}"'))
                : ListView.builder(
                    itemCount: _filteredContacts.length,
                    itemBuilder: (context, index) {
                      final item = _filteredContacts[index];
                      final contactName = item.contact.displayName;
                      final phoneNumber = item.primaryPhoneNumber ?? 'Numéro inconnu';
                      final operator = item.operator;
                      final recommendedSim = _getRecommendedSimSlot(operator);

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: getOperatorColor(operator),
                          child: Text(
                            operator != Operator.unknown ? getOperatorName(operator).substring(0, 1) : '?',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(contactName),
                        subtitle: Text(phoneNumber),
                        trailing: recommendedSim != null
                            ? ElevatedButton.icon(
                                icon: const Icon(Icons.phone, size: 16),
                                label: Text('SIM $recommendedSim'),
                                onPressed: () => _makeCall(phoneNumber, recommendedSim),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: getOperatorColor(operator),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  textStyle: const TextStyle(fontSize: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                              )
                            : IconButton(
                                icon: const Icon(Icons.phone_forwarded),
                                tooltip: 'Appeler (Opérateur inconnu ou non configuré)',
                                onPressed: () => _makeCall(phoneNumber, null),
                              ),
                        onTap: () => _makeCall(phoneNumber, recommendedSim),
                      );
                    },
                  ),
          ),
        ],
      );
    }
  }

  Widget _buildSmartCallCounterWidget() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      color: Theme.of(context).primaryColor.withOpacity(0.1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.star, color: Colors.amber, size: 18),
          const SizedBox(width: 8),
          Text(
            '$_smartCallCounter appels optimisés !',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionDeniedWidget() {
     return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.contact_page_outlined, size: 60, color: Colors.grey),
              const SizedBox(height: 20),
              const Text(
                'Accès aux contacts requis',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text(
                'Smart SIM DZ a besoin de lire vos contacts pour identifier leur opérateur et vous aider à choisir la bonne SIM. Vos contacts restent sur votre téléphone.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14),
              ),
               const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.settings),
                label: const Text('Ouvrir les paramètres'),
                // Utiliser FlutterContacts pour ouvrir les paramètres si la permission est définitivement refusée
                onPressed: () => openAppSettings(), // Utilise permission_handler
              ),
            ],
          ),
        ),
      );
  }
}
