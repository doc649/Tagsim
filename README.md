Plan d’évolution TagSim v2.5 (Branche : `gpt-pilot-dev`)

## 🔧 Objectif général

Poursuivre le développement de l'application **TagSim** à partir de la branche `gpt-pilot-dev` (copie de `features-v2`), **sans casser la structure actuelle**.  
Toutes les nouvelles fonctionnalités doivent être **offline**, **compatibles Android 9+**, **sans IA ni API externe**, et **en respectant le code source existant**.

---

## ✅ Fonctionnalités existantes à garder (à relire/améliorer si nécessaire)

- 📞 Détection automatique des opérateurs à partir des préfixes (Djezzy, Mobilis, Ooredoo)
- 👥 Liste de contacts enrichie avec affichage par opérateur
- 📊 Dashboard statistiques par carte SIM
- 💬 Codes USSD : affichage et exécution pour chaque opérateur
- 🌙 Mode sombre activable
- 🛠️ Configuration manuelle des opérateurs si détection impossible
- 📶 Comparateur simple d’offres mobile (à améliorer)

> 🛠 GPT Pilot doit :
> - Lire et comprendre tout le code du projet
> - Détecter les fonctions déjà existantes, même incomplètes
> - Évaluer la qualité (structure, répétition, lisibilité)
> - Corriger ou améliorer sans détruire la logique actuelle
> - Ajouter uniquement des fonctions compatibles avec l'existant

---

## 🆕 Fonctionnalités à ajouter dans cette version

### 📸 1. Scanner de bon de recharge offline (OCR sans internet)
- Scan via caméra d’un bon de recharge imprimé
- Détection automatique d’un code à 14 chiffres avec `google_mlkit_text_recognition`
- Pré-remplissage du code dans une requête USSD (ex. : `*123*CODE#`)
- Confirmation utilisateur avant envoi

### 🔁 2. Rafraîchissement manuel du tableau de bord
- Ajout d’un bouton « Rafraîchir maintenant »
- Option de synchronisation automatique (si autorisation de l’utilisateur)

### ⭐ 3. Fonction de favoris sur les offres
- Ajout ou suppression d’une offre via une icône étoile
- Onglet « Mes Offres » avec les favoris stockés localement

### 🔄 4. Comparateur automatique intelligent
- Bouton « Comparer pour moi »
- Analyse du profil d’utilisation (appels, SMS, data)
- Suggestion automatique de la meilleure offre disponible

### 🧮 5. Calculateur de consommation mobile
- Formulaire simple (appels/jour, data/mois, etc.)
- Résultat : liste d’offres pertinentes selon l’usage estimé

---

## 🎯 Objectif version v2.5

- App complètement utilisable sans internet
- OCR de recharge fonctionnel
- Favoris et suggestions activées
- Interface stable et légère (Android 9 minimum)
- Aucune dépendance IA ou serveur externe

---

## ⚠️ Contraintes techniques

- ❌ Aucune API externe (pas de GPT, pas de backend)
- ✅ Fonctionnement full offline
- ✅ Optimisé pour Android 9+
- ✅ Pas de refactor complet : structure `features-v2` conservée
- ✅ Toutes les modifs dans la branche `gpt-pilot-dev` uniquement

---

## ✅ Statut

Ce plan est actif et constitue la feuille de route pour GPT Pilot.
