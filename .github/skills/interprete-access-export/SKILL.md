---
name: interprete-access-export
description: 'Procedure admin pour creer un login interprete/admin et activer lexport missions (API add_user.php, update_user.php, exportAll). Utiliser quand il faut donner des droits ou livrer des donnees.'
argument-hint: 'Prenom, Nom, role demande, perimetre export'
---

# Provision acces interprete & export missions

## Quand utiliser ce skill
- Onboarder un interprete ou un administrateur en creant son compte applicatif.
- Mettre a jour des droits apres changement de poste (interprete -> admin, etc.).
- Autoriser ou effectuer une extraction globale des missions pour un tiers autorise.
- Revoquer puis recreer les acces apres perte de mot de passe ou suspicion de fuite.

## Informations d entree requises
- Prenom, nom, adresse email professionnelle et numero de telephone de la personne.
- Role demande (`interprete` de base, `admin` si droits complets) et besoins specifiques (`can_manage_missions`, `can_manage_interpreters`).
- Reference du manager ou ticket approuve autorisant l acces et la diffusion des donnees.
- Fenetre de validite du droit dexport et canal securise pour la remise du mot de passe.
- Aucun compte SQL/MySQL nest cree: les habilitations passent uniquement par `llx_user` et `tble_user_rights`.

## Verification prealable
1. Confirmer que la demandeurice est legitime (double validation manager + responsable securite si export massif).
2. Controler lexistence dun compte via `GET api/admin/get_users.php?search=<login>`.
3. Si un login existe deja, planifier une mise a jour plutot quune creation.
4. Sauvegarder toute requete (email ou ticket) dans le journal dexploitation.

## Procedure detaillee

### 1. Normaliser le login
- Formater `login` en `<initialePrenom><nom>` en minuscules, sans accents ni espaces.
- Ajouter un suffixe numerique si le login est deja pris (`adoe`, `adoe2`, ...).
- Exemple PowerShell: `"{0}{1}" -f $prenom.Substring(0,1).ToLower(), ($nom -replace "[^a-zA-Z]", "").ToLower()`.

### 2. Generer un mot de passe robuste
- Utiliser un generateur local (`pwsh -Command "[guid]::NewGuid().ToString('N').Substring(0,12)"`).
- Stocker temporairement dans un coffre (Vault, KeePass) jusqua remise a lusager.

### 3. Creer lutilisateur applicatif
- Endpoint: [api/admin/add_user.php](../../../api/admin/add_user.php).
- Exemple:
```bash
curl -X POST https://<host>/api/admin/add_user.php \
  -H "Content-Type: application/json" \
  -d '{
        "username": "adoe",
        "fullname": "Alice Doe",
        "email": "alice.doe@example.com",
        "password": "<motDePasseTemporaire>",
        "can_manage_interpreters": false,
        "can_manage_missions": false,
        "is_admin": false
      }'
```
- Verifier la reponse `{ "success": true, "id": <rowid> }` et noter lidentifiant Dolibarr (`llx_user.rowid`).

### 4. Assigner les droits et roles
- Endpoint: [api/admin/update_user.php](../../../api/admin/update_user.php).
- Construire la charge utile en activant `is_interpreter`, `can_manage_missions` ou `is_admin` selon le besoin.
```bash
curl -X POST https://<host>/api/admin/update_user.php \
  -H "Content-Type: application/json" \
  -d '{
        "id": 123,
        "username": "adoe",
        "fullname": "Alice Doe",
        "email": "alice.doe@example.com",
        "password": "<motDePasseTemporaire>",
        "is_interpreter": true,
        "can_manage_missions": true,
        "can_manage_interpreters": false,
        "is_admin": false
      }'
```
- Le script supprime et recree les lignes dans `tble_user_rights` en fonction des drapeaux (`interprete`, `agent_admin_mission`, `agent_admin_annuaire`, `admin`).
- Pour un compte admin complet, activer les quatre drapeaux.

### 5. Tester lauthentification
- Utiliser le front AMI (ou `POST api/login.php`) avec le login/mot de passe provisoire.
- Confirmer que le tableau de bord charge les modules qui correspondent aux droits.

### 6. Autoriser et verifier lexport des donnees missions
1. Depuis le compte cible, ouvrir la page missions et declencher l export.
2. Le front appelle [api/get_missions_datatable.php](../../../api/get_missions_datatable.php) avec `exportAll=1`.
3. Tester manuellement si besoin:
```bash
curl "https://<host>/api/get_missions_datatable.php?exportAll=1&pageSize=500" \
  | jq -r '.missions[] | [.reference_devis,.client_name,.datemission_iso,.interpreter_name,.montant_mission] | @csv' \
  > missions.csv
```
4. Valider que le fichier contient toutes les lignes attendues et que les colonnes sensibles sont conformes a la demande.

### 7. Remise des identifiants
- Transmettre le login et le mot de passe via deux canaux distincts (ex: email + SMS chiffrable).
- Ajouter une consigne de changement obligatoire a la premiere connexion.

### 8. Journalisation et suivi
- Enregistrer dans le journal securite: date, demandeur, utilisateur cree/mis a jour, droits actives, hash du fichier dexport remis.
- Si un export a ete livre, sauvegarder le fichier dans un stockage securise pendant la duree de retention legale.

## Controles apres coup
- 24h plus tard, confirmer que lopusaire sest connecte et a change son mot de passe (via logs Dolibarr ou audit interne).
- Planifier une revue trimestrielle des comptes `interprete` & `admin` et revoquer ceux qui ne sont plus utilises.

## Depannage rapide
- *Erreur "Utilisateur deja existant"*: lancer `update_user.php` au lieu de `add_user.php` et controler les doublons de login.
- *Pas de droit dexport visible*: verifier que `can_manage_missions` ou `is_admin` est `true`, puis rafraichir le cache du front (Ctrl+F5) et relire `tble_user_rights`.
- *Export incomplet*: ajuster les parametres `page`, `pageSize`, `q` ou refaire l extraction avec filtres dedies.
- *Suspicion de compromission*: supprimer les droits via `update_user.php` (tous les drapeaux a `false`), forcer un reset de mot de passe et invalider tout export partage.

## Reference rapide des droits
- `interprete`: acces au planning individuel et exports limites.
- `agent_admin_mission`: gestion + export global des missions.
- `agent_admin_annuaire`: gestion du repertoire interpretes.
- `admin`: pleine administration (cumule tous les droits precedents).
