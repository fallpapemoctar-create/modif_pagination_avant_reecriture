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

---

## Module Devis (AMI v1.4)

Le module Devis permet de créer, modifier, suivre et convertir des devis commerciaux directement depuis les missions.

### Accès rapide — depuis le tableau des missions

1. Ouvrir le menu **Missions** (onglet principal).
2. Sur la ligne d'une mission, cliquer sur le bouton **Devis** (icône 📋).
3. Si aucun devis actif n'existe pour cette mission, un nouveau devis est créé automatiquement pré-rempli (client, référence mission, lignes de base).
4. L'écran d'édition du devis s'ouvre.

> **Règles :**
> - Une mission déjà facturée ne peut pas être utilisée pour créer un devis (message d'erreur 409).
> - Il ne peut exister qu'un seul devis en statut *brouillon* ou *envoyé* pour une même mission.

---

### Cycle de vie d'un devis

```
Mission → Devis (brouillon) → Envoyé → Accepté → Facturé
                                      ↘ Rejeté
                                      ↘ Expiré
```

| Statut | Libellé | Actions disponibles |
|---|---|---|
| `draft` | Brouillon | Modifier, Sauvegarder, Envoyer, Générer PDF |
| `sent` | Envoyé | Marquer Accepté / Rejeté / Expiré, Générer PDF |
| `accepted` | Accepté | Créer la facture, Générer PDF |
| `rejected` | Rejeté | Dupliquer, Générer PDF |
| `expired` | Expiré | Dupliquer, Générer PDF |
| `accepted_converted` | Converti en facture | Lecture seule, Générer PDF |

---

### Écran d'édition du devis

#### Champs affichés

| Champ | Modifiable | Description |
|---|---|---|
| Client | Non (lecture seule) | Nom du client lié à la mission |
| Mission | Non (lecture seule) | Référence de la mission source |
| Statut | Via boutons | Statut actuel du devis |
| Date de validité | Oui (si brouillon/envoyé) | Date limite de validité du devis |
| Notes | Oui (si brouillon/envoyé) | Commentaires libres |
| Lignes (désignation, quantité, P.U. HT, TVA %) | Oui (si brouillon/envoyé) | Détail des prestations |

#### Boutons de l'AppBar

| Bouton | Visible quand | Action |
|---|---|---|
| **Sauvegarder** | Brouillon ou Envoyé | Enregistre les modifications des lignes, notes, validité |
| **PDF** | Toujours | Génère et télécharge le PDF du devis |
| **Envoyer** | Brouillon | Passe le devis en statut *Envoyé* |
| **···** (menu) | Brouillon ou Envoyé | Autres transitions de statut |
| **Créer la facture** | Accepté | Convertit le devis en facture (vert) |
| **Dupliquer** | Rejeté ou Expiré | Crée un nouveau devis à partir de la même mission |

---

### Générer le PDF d'un devis

1. Ouvrir le devis (depuis l'onglet Devis ou depuis le tableau des missions).
2. Cliquer sur **PDF** dans la barre d'actions.
3. Le PDF est téléchargé automatiquement (navigateur web) ou envoyé vers l'imprimante/partage (application mobile/desktop).

Le PDF contient :
- En-tête : numéro de devis, statut, dates
- Tableau des prestations : désignation, TVA %, P.U. HT, quantité, total HT
- Totaux : Total HT et Total TTC
- Notes éventuelles

---

### Envoyer le devis

1. En statut **Brouillon**, cliquer sur **Envoyer**.
2. Le statut passe à *Envoyé* immédiatement.
3. Le devis reste modifiable en statut *Envoyé*.

> L'envoi est un changement de statut dans l'application. La transmission par e-mail est manuelle (exporter le PDF puis l'envoyer au client).

---

### Convertir un devis accepté en facture

1. Marquer le devis comme **Accepté** (via le menu ···).
2. Le bouton **Créer la facture** (vert) apparaît.
3. Cliquer sur **Créer la facture** : un numéro de facture est réservé et la facture est créée dans le module Facturation.
4. Le devis passe en statut *Converti en facture* et devient lecture seule.

---

### Dupliquer un devis rejeté ou expiré

1. Ouvrir le devis en statut *Rejeté* ou *Expiré*.
2. Cliquer sur **Dupliquer**.
3. Un nouveau devis *Brouillon* est créé pour la même mission.
4. L'écran s'ouvre directement sur le nouveau devis.

---

### Onglet Devis — dans Facturation

L'onglet **Devis** est accessible depuis le menu **Facturation** → sous-onglet **Devis**.

- Un filtre permet d'afficher les devis par statut : *Brouillons*, *Envoyés*, *Acceptés*, *Rejetés*, *Expirés*, *Convertis*.
- Cliquer sur un devis dans la liste ouvre l'écran d'édition.

---

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
