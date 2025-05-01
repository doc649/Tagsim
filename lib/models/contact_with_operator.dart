import 'package:contacts_service/contacts_service.dart';
import 'package:smart_sim_dz/utils/operator_detector.dart';

// Classe pour encapsuler un contact et son opérateur détecté
class ContactWithOperator {
  final Contact contact;
  final Operator operator;
  final String? primaryPhoneNumber; // Stocker le numéro utilisé pour la détection

  ContactWithOperator({
    required this.contact,
    required this.operator,
    this.primaryPhoneNumber,
  });
}

