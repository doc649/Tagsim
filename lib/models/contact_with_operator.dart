import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:tagsim/utils/operator_detector.dart';

// Classe pour encapsuler un contact et son opérateur détecté
class ContactWithOperator {
  final Contact contact;
  final AlgerianMobileOperator operator;
  final String? primaryPhoneNumber; // Stocker le numéro utilisé pour la détection
  final String? countryFlagEmoji; // Stocker l'emoji drapeau du pays

  ContactWithOperator({
    required this.contact,
    required this.operator,
    this.primaryPhoneNumber,
    this.countryFlagEmoji, // Ajouter le paramètre au constructeur
  });
}
