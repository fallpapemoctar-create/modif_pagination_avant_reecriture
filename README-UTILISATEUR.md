# Guide utilisateur — Ami

## Introduction
- Objet : Ce guide explique l'utilisation de l'application de gestion des interprètes, missions et de l'administration.
- Public : Gestionnaires interprètes, gestionnaires missions et administrateurs.

## Prérequis et installation
- Environnement : Flutter SDK (compatible Windows), serveur PHP local (ex. WAMP), Dart/Flutter configurés.
- Installer dépendances depuis le dossier du projet :

```bash
flutter pub get
```

- Analyser le projet :

```bash
flutter analyze
```

- Lancer l'application (ex. Windows) :

```bash
flutter run -d windows
```

- Backend API : le projet utilise un serveur local (ex. `http://ami.yourbizapps.com/api/...`). Vérifiez `lib/services/*` pour les endpoints.

## Authentification et déconnexion
- Login : utilisez l'écran de connexion. La route `/login` est utilisée pour rediriger après la déconnexion.
- Logout : le bouton Déconnexion efface l'état d'authentification via `AuthManager` et renvoie à la page de connexion.
- Rôles (gérés par `UserRights`) :
  - Admin : accès complet (CRUD global).
  - Gestionnaire interprètes : gère interprètes (CRUD), peut consulter missions.
  - Gestionnaire missions : gère missions (CRUD), peut consulter interprètes.

## Navigation générale
- Écran Interprètes : liste, recherche par nom/téléphone, actions selon rôle.
- Écran Missions ("Missions par interprètes") :
  - Grand écran : vue en deux colonnes (gauche = interprètes, droite = missions).
  - Petit écran : navigation vers une page détaillée pour les missions d'un interprète.
- Bouton flottant (+) pour ajouter une mission (visible selon droits).

## Gestion des interprètes (CRUD)
- Créer : formulaire "Ajouter interprète" depuis l'écran Interprètes (si autorisé).
- Consulter : cliquer un interprète pour voir ses missions.
- Modifier : bouton Éditer (selon droits), modifier et enregistrer.
- Supprimer : confirmation avant suppression, appel API puis actualisation.

## Gestion des missions (CRUD)
- Créer une mission : sélectionner un interprète puis cliquer sur `+` ou "Ajouter" ; renseigner :
  - Référence, Produit, Début (YYYY-MM-DD), Fin (YYYY-MM-DD), Montant, Statut paiement.
- Modifier : bouton Éditer sur la mission.
- Supprimer : bouton Supprimer avec confirmation.
- Format des dates : saisie attendue `YYYY-MM-DD`, affichage `dd/MM/yyyy`.
- Montant : saisissez un nombre ; affichage en € via `NumberFormat`.

## Comportement asynchrone et notifications
- Les dialogues et SnackBar informent de la réussite/erreur des opérations asynchrones.
- Bonnes pratiques : vérifier `mounted` après `await` avant d'utiliser `BuildContext`.

## Intégration backend & format des données
- Consultez `lib/services/mission_service.dart` et `lib/services/interpreter_service.dart` pour les endpoints.
- Si le serveur PHP répond "Aucune donnée reçue" :
  - Vérifiez l'en-tête `Content-Type` et le corps envoyé.
  - PHP qui lit `$_POST` attend `application/x-www-form-urlencoded`.
  - PHP qui lit `php://input` attend souvent du JSON (`application/json`).
- Utilisez Postman ou `curl` pour reproduire et diagnostiquer les appels.

Exemples `curl` :

JSON :
```bash
curl -X POST http://ami.yourbizapps.com/api/add_mission.php -H "Content-Type: application/json" -d '{"interpreter_id":1,"reference_devis":"R001","montant_mission":100}'
```

Form-encodé :
```bash
curl -X POST http://ami.yourbizapps.com/api/add_mission.php -d "interpreter_id=1&reference_devis=R001&montant_mission=100"
```

## Diagnostics & dépannage
- Analyse statique : `flutter analyze`.
- Logs serveur PHP : consulter les logs WAMP (ex. `C:\wamp64\logs` ou `php_error.log`).
- Problèmes d'UI après édition : vérifier les doublons d'importation ou classes multiples (ex. `lib/pages/missions_page.dart`).
- Tester manuellement : ajouter/éditer/supprimer une mission et vérifier la réponse backend.

## Commandes utiles
- `flutter pub get` — installer dépendances
- `flutter analyze` — analyse statique
- `flutter run -d windows` — lancer l'app
- Tester API avec `curl` ou Postman (exemples ci-dessus)

## Fichiers importants
- `lib/services/mission_service.dart`
- `lib/services/interpreter_service.dart`
- `lib/pages/missions_page.dart`
- `lib/core/auth_manager.dart`

## Bonnes pratiques pour les développeurs
- Toujours vérifier `mounted` après un `await` avant d'utiliser `context`.
- Centraliser les formats de date et de monnaie via `DateFormat` et `NumberFormat`.
- Tester les endpoints backend séparément pour isoler les problèmes client/serveur.

---

Si vous le souhaitez, je peux aussi :
- Committer `README-UTILISATEUR.md` au repo (si vous voulez que je fasse le commit),
- Adapter `MissionService` pour envoyer des données dans le format attendu par votre backend, ou
- Exécuter des tests POST manuels et partager les résultats.
