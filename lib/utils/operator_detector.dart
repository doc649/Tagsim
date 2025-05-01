import 'package:flutter/material.dart';

enum Operator {
  mobilis,
  djezzy,
  ooredoo,
  unknown
}

// Fonction pour détecter l'opérateur basé sur le préfixe
Operator detectOperator(String phoneNumber) {
  // Nettoyer le numéro (supprimer espaces, +, etc.)
  String cleanedNumber = phoneNumber.replaceAll(RegExp(r'\s+|-|\(|\)|\+'), '');

  // Gérer les numéros internationaux algériens
  if (cleanedNumber.startsWith("213")) {
    cleanedNumber = "0${cleanedNumber.substring(3)}";
  }

  // Vérifier les préfixes
  if (cleanedNumber.startsWith("06")) {
    return Operator.mobilis;
  } else if (cleanedNumber.startsWith("07")) {
    return Operator.djezzy;
  } else if (cleanedNumber.startsWith("05")) {
    return Operator.ooredoo;
  } else {
    return Operator.unknown;
  }
}

// Fonction pour obtenir la couleur associée à l'opérateur
Color getOperatorColor(Operator operator) {
  switch (operator) {
    case Operator.mobilis:
      return Colors.blue; // Bleu pour Mobilis
    case Operator.djezzy:
      return Colors.red; // Rouge pour Djezzy
    case Operator.ooredoo:
      return Colors.orange; // Orange pour Ooredoo
    case Operator.unknown:
    default:
      return Colors.grey; // Gris pour inconnu
  }
}

// Fonction pour obtenir le nom de l'opérateur
String getOperatorName(Operator operator) {
  switch (operator) {
    case Operator.mobilis:
      return "Mobilis";
    case Operator.djezzy:
      return "Djezzy";
    case Operator.ooredoo:
      return "Ooredoo";
    case Operator.unknown:
    default:
      return "Inconnu";
  }
}

