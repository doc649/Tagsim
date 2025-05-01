# Documentation Smart SIM DZ

Ce document fournit les informations nécessaires pour comprendre, compiler et modifier l'application Smart SIM DZ.

## 1. Prérequis

Pour compiler et exécuter ce projet, vous aurez besoin de :

*   **Flutter SDK:** Assurez-vous d'avoir installé Flutter sur votre machine. Suivez les instructions officielles : [https://docs.flutter.dev/get-started/install](https://docs.flutter.dev/get-started/install)
*   **Android SDK:** Flutter nécessite l'Android SDK pour la compilation Android. Celui-ci est généralement installé avec Android Studio. Assurez-vous que les outils de ligne de commande (`cmdline-tools`) sont installés via le SDK Manager d'Android Studio.
*   **Un éditeur de code:** Visual Studio Code avec l'extension Flutter est recommandé, mais Android Studio ou IntelliJ IDEA fonctionnent également.
*   **Un appareil Android (ou émulateur):** Pour tester l'application (Android 7.0 Nougat - API 24 ou supérieur).

## 2. Configuration du projet

1.  **Récupérer le code source:** Placez le dossier `smart_sim_dz` (que je vous fournirai) sur votre ordinateur.
2.  **Ouvrir le projet:** Ouvrez le dossier `smart_sim_dz` dans votre éditeur de code (VS Code, Android Studio...). 
3.  **Installer les dépendances:** Ouvrez un terminal à la racine du projet (`smart_sim_dz`) et exécutez la commande suivante :
    ```bash
    flutter pub get
    ```
    Cela téléchargera toutes les bibliothèques nécessaires définies dans `pubspec.yaml`.

## 3. Compilation de l'APK

Une fois les dépendances installées, vous pouvez compiler l'APK.

*   **Pour un test rapide (APK de débogage):**
    ```bash
    flutter build apk --debug
    ```
    L'APK se trouvera dans `build/app/outputs/flutter-apk/app-debug.apk`.

*   **Pour une version "Release" (APK optimisé):**
    ```bash
    flutter build apk --release
    ```
    L'APK se trouvera dans `build/app/outputs/flutter-apk/app-release.apk`. Cet APK est généralement non signé. Pour une distribution (par exemple sur le Play Store), vous devrez configurer la signature de l'application. Suivez les instructions officielles : [https://docs.flutter.dev/deployment/android#signing-the-app](https://docs.flutter.dev/deployment/android#signing-the-app)

## 4. Installation de l'APK

1.  **Transférer l'APK:** Copiez le fichier `.apk` généré (par exemple `app-release.apk`) sur votre appareil Android.
2.  **Autoriser les sources inconnues:** Sur votre appareil Android, allez dans les Paramètres -> Sécurité (ou Applications & notifications -> Accès spécial des applications -> Installation d'applis inconnues) et autorisez l'installation d'applications depuis votre gestionnaire de fichiers ou votre navigateur.
3.  **Installer:** Ouvrez le fichier `.apk` via un gestionnaire de fichiers sur votre appareil et suivez les instructions pour l'installer.




## 5. Structure du Projet

Le projet suit une structure Flutter standard, avec les répertoires clés suivants :

*   `/lib`: Contient tout le code source Dart de l'application.
    *   `/main.dart`: Point d'entrée de l'application, initialise Flutter et AdMob, définit le thème.
    *   `/screens`: Contient les différents écrans (widgets `Scaffold`) de l'application.
        *   `home_screen.dart`: Écran principal affichant la liste des contacts, la recherche, le compteur d'économies, la bannière publicitaire et les boutons d'appel.
        *   `settings_screen.dart`: Écran de configuration permettant d'assigner les opérateurs aux SIMs et de gérer le statut premium.
    *   `/models`: Contient les modèles de données.
        *   `contact_with_operator.dart`: Modèle combinant un `Contact` Flutter avec son `Operator` détecté.
    *   `/utils`: Contient les fonctions utilitaires.
        *   `operator_detector.dart`: Logique pour détecter l'opérateur basé sur le préfixe du numéro et pour obtenir le nom/couleur de l'opérateur.
*   `/android`: Contient les fichiers spécifiques à la plateforme Android (configuration, `AndroidManifest.xml`, `build.gradle`).
*   `/ios`: Contient les fichiers spécifiques à la plateforme iOS (non utilisé activement dans ce projet initial).
*   `/assets`: Pourrait contenir des ressources statiques comme des images ou des polices (non utilisé dans cette version).
*   `pubspec.yaml`: Fichier de configuration du projet Flutter, listant les dépendances, les ressources, etc.
*   `README.md`: Ce fichier de documentation.

## 6. Modifications Courantes

### a) Modifier les Préfixes Opérateurs

La logique de détection des opérateurs se trouve dans le fichier `lib/utils/operator_detector.dart`.

Pour modifier ou ajouter des préfixes :

1.  Ouvrez le fichier `lib/utils/operator_detector.dart`.
2.  Localisez la fonction `detectOperator(String phoneNumber)`.
3.  Modifiez les conditions `startsWith()` pour ajuster les préfixes existants ou ajoutez de nouvelles conditions pour de nouveaux opérateurs.
    *Exemple : Si Djezzy utilise aussi le préfixe '078', ajoutez `|| cleanedNumber.startsWith("078")` à la condition pour `Operator.djezzy`.*
4.  Si vous ajoutez un nouvel opérateur, vous devrez également :
    *   Ajouter une valeur à l'énumération `Operator`.
    *   Ajouter une couleur correspondante dans la fonction `getOperatorColor(Operator operator)`.
    *   Ajouter un nom correspondant dans la fonction `getOperatorName(Operator operator)`.

### b) Modifier les Textes de l'Application

La plupart des textes visibles par l'utilisateur se trouvent directement dans les fichiers de widgets sous `/lib/screens` (`home_screen.dart`, `settings_screen.dart`). Recherchez le texte que vous souhaitez modifier et remplacez-le directement dans le code.

*Pour une application multilingue (future évolution), il faudrait extraire ces chaînes dans des fichiers de localisation dédiés.*

### c) Modifier les Informations de Paiement Premium

Les instructions affichées pour obtenir la version premium (paiement manuel) se trouvent dans `lib/screens/settings_screen.dart`, dans la fonction `_requestPremium()`. Modifiez le texte dans `AlertDialog` pour mettre à jour le montant, la méthode de paiement ou les informations de contact.

### d) Remplacer les ID AdMob de Test

Avant de publier l'application, vous **devez** remplacer les ID AdMob de test par vos propres ID réels :

1.  **ID d'Application AdMob :** Dans `/android/app/src/main/AndroidManifest.xml`, remplacez la valeur `android:value` pour `com.google.android.gms.ads.APPLICATION_ID`.
2.  **ID de Bloc d'Annonces (Bannière) :** Dans `lib/screens/home_screen.dart`, modifiez la valeur de la variable `_adUnitId`.

Créez ces ID depuis votre compte AdMob ([https://admob.google.com/](https://admob.google.com/)).


