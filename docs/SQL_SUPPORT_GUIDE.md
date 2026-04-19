# Guide SQL Support

Ce document regroupe les requetes SQL utilisees par l'application cote backend PHP.

Objectif:
- aider le support a comprendre quelles tables sont lues ou ecrites
- retrouver rapidement dans quel fichier une requete est construite
- fournir une base de travail pour interroger la base manuellement

Important:
- les requetes ci-dessous sont celles trouvees dans le code actuel
- certaines sont dynamiques: le SQL final depend des filtres recus ou de la presence de colonnes
- les exemples ci-dessous simplifient parfois l'affichage pour privilegier la lecture

## Tables Metier Principales

| Table | Role |
| --- | --- |
| `llx_missionsplanet_mission` | missions |
| `llx_user` | utilisateurs et interpretes |
| `llx_societe` | societes clientes |
| `llx_socpeople` | contacts clients |
| `llx_product` | langues / produits |
| `tble_mission_billed` | statut de facturation interprete |
| `tble_client_billed` | facturation client |
| `tble_client_invoice_lines` | lignes de facture client |
| `tble_user_rights` | droits affectes aux utilisateurs |
| `tble_rights` | catalogue des droits |
| `llx_c_payment_term` | conditions de reglement |
| `llx_bank_account` | comptes bancaires |
| `llx_const` | constantes de configuration entreprise |
| `llx_c_country` | pays |

## Requetes Par Fichier

### `api/get_missions_datatable.php`

Usage:
- tableau des missions
- pagination
- export CSV
- filtres sur societe, statut, date, type, facturation

#### Verification de schema

```sql
SHOW COLUMNS FROM llx_missionsplanet_mission LIKE 'fk_user_creat';
SHOW COLUMNS FROM llx_missionsplanet_mission LIKE 'fk_user_creator';
SHOW COLUMNS FROM llx_missionsplanet_mission LIKE 'fk_user_create';
SHOW COLUMNS FROM llx_missionsplanet_mission LIKE 'fk_user_modif';
SHOW COLUMNS FROM llx_missionsplanet_mission LIKE 'tms';
SHOW COLUMNS FROM llx_missionsplanet_mission LIKE 'mission_types';
```

But:
- adapter la requete au schema reel de la base

#### Requete de comptage

```sql
SELECT COUNT(*) AS total
FROM llx_missionsplanet_mission m
LEFT JOIN llx_user u ON m.nominterprete = u.rowid
LEFT JOIN llx_product p ON m.langue = p.rowid
LEFT JOIN llx_societe s ON s.rowid = m.fk_soc
LEFT JOIN (
    SELECT bb.ref, bb.status
    FROM tble_mission_billed bb
    INNER JOIN (
        SELECT ref, MAX(billed_at) AS max_billed_at
        FROM tble_mission_billed
        GROUP BY ref
    ) last ON last.ref = bb.ref AND last.max_billed_at = bb.billed_at
) b ON b.ref = m.ref
LEFT JOIN (
    SELECT cb_inner.mission_ref,
           cb_inner.invoice_number,
           cb_inner.status_label
    FROM tble_client_billed cb_inner
    INNER JOIN (
        SELECT mission_ref, MAX(billed_at) AS max_billed_at
        FROM tble_client_billed
        WHERE category = 'client'
        GROUP BY mission_ref
    ) latest_cb ON latest_cb.mission_ref = cb_inner.mission_ref
               AND latest_cb.max_billed_at = cb_inner.billed_at
    WHERE cb_inner.category = 'client'
) cb ON cb.mission_ref = m.ref
WHERE 1=1;
```

Filtres dynamiques possibles ajoutes a `WHERE`:

```sql
AND (m.ref LIKE :q OR u.firstname LIKE :q OR u.lastname LIKE :q OR s.nom LIKE :q OR p.ref LIKE :q OR cb.invoice_number LIKE :q OR cb.status_label LIKE :q)
AND s.nom LIKE :requestingCompany
AND m.datemission >= :dateStart
AND m.datemission < :dateEndExclusive
AND LOWER(b.status) = :billedStatus
AND m.status = :missionStatus
AND LOWER(m.mission_types) LIKE :missionType
```

#### Requete principale de chargement

```sql
SELECT
    m.rowid,
    m.ref AS reference_devis,
    m.label,
    m.nominterprete,
    m.fk_soc AS client_id,
    m.contactdemandeur AS contact_id,
    m.description AS commentaires,
    m.datemission,
    m.heuredebutmission,
    m.dureemission,
    m.status AS mission_status,
    m.mission_types,
    m.date_creation,
    m.tms AS date_modification_raw,
    u.firstname,
    u.lastname,
    p.ref AS produit_ref,
    p.label AS produit_label,
    p.price AS produit_price,
    p.tva_tx AS produit_tva_tx,
    p.rowid AS id_produit_service,
    s.nom AS client_name,
    s.code_client AS client_code,
    s.address AS client_address,
    s.zip AS client_zip,
    s.town AS client_town,
    socp.firstname AS prenom_demandeur,
    socp.lastname AS nom_demandeur,
    socp.phone AS phone,
    socp.phone_mobile AS phone_mobile,
    b.status AS billed_status,
    cb.status_code AS client_billed_status,
    cb.status_label AS client_billed_status_label,
    cb.invoice_number AS client_invoice_number,
    cb.billed_at AS client_billed_at
FROM llx_missionsplanet_mission m
LEFT JOIN llx_user u ON m.nominterprete = u.rowid
LEFT JOIN llx_product p ON m.langue = p.rowid
LEFT JOIN llx_societe s ON s.rowid = m.fk_soc
LEFT JOIN llx_socpeople socp ON socp.rowid = m.contactdemandeur
LEFT JOIN (
    SELECT bb.ref, bb.status
    FROM tble_mission_billed bb
    INNER JOIN (
        SELECT ref, MAX(billed_at) AS max_billed_at
        FROM tble_mission_billed
        GROUP BY ref
    ) last ON last.ref = bb.ref AND last.max_billed_at = bb.billed_at
) b ON b.ref = m.ref
LEFT JOIN (
    SELECT cb_inner.mission_ref,
           cb_inner.invoice_number,
           cb_inner.status_code,
           cb_inner.status_label,
           cb_inner.billed_at
    FROM tble_client_billed cb_inner
    INNER JOIN (
        SELECT mission_ref, MAX(billed_at) AS max_billed_at
        FROM tble_client_billed
        WHERE category = 'client'
        GROUP BY mission_ref
    ) latest_cb ON latest_cb.mission_ref = cb_inner.mission_ref
               AND latest_cb.max_billed_at = cb_inner.billed_at
    WHERE cb_inner.category = 'client'
) cb ON cb.mission_ref = m.ref
WHERE 1=1
ORDER BY m.datemission DESC, m.heuredebutmission DESC
LIMIT :limit OFFSET :offset;
```

Support:
- retrouver les missions d'une societe: `AND s.nom LIKE '%NomSociete%'`
- controler le dernier statut de facturation interprete: table `tble_mission_billed`
- controler le dernier statut de facturation client: table `tble_client_billed`

### `api/get_missions_by_interpreter.php`

Usage:
- missions d'un interprete
- listing des interpretes ayant des missions

```sql
SELECT m.rowid, m.ref, m.nominterprete, m.debutmission, m.finmission, ...
FROM llx_missionsplanet_mission m
INNER JOIN llx_user u ON m.nominterprete = u.rowid
LEFT JOIN ...
WHERE m.nominterprete = :interpreter_id
  AND m.status <> 9;
```

```sql
SELECT u.rowid, u.firstname, u.lastname, COUNT(m.rowid) AS missions_count
FROM llx_user u
INNER JOIN llx_missionsplanet_mission m ON m.nominterprete = u.rowid
WHERE m.status <> 9
GROUP BY u.rowid
HAVING COUNT(m.rowid) >= 1;
```

Support:
- `status <> 9` exclut les missions annulees

### `api/add_mission_interpreter.php`

Usage:
- creation d'une mission

```sql
SHOW COLUMNS FROM llx_missionsplanet_mission LIKE 'mission_types';
```

```sql
SELECT MAX(CAST(SUBSTRING(ref, $startPos) AS UNSIGNED)) AS max_num
FROM llx_missionsplanet_mission
WHERE ref LIKE :pattern
  AND ref REGEXP :regex;
```

```sql
SELECT COUNT(*)
FROM llx_missionsplanet_mission
WHERE ref = :ref;
```

```sql
SELECT rowid
FROM llx_product
WHERE ref = :ref
LIMIT 1;
```

```sql
INSERT INTO llx_missionsplanet_mission (
    ref, nominterprete, datemission, debutmission, finmission,
    langue, status, ...
) VALUES (...);
```

Support:
- la langue est resolue via `llx_product`
- la reference mission est generee a partir du plus grand suffixe existant

### `api/update_mission_interpreter.php`

Usage:
- modification d'une mission

```sql
SHOW COLUMNS FROM llx_missionsplanet_mission LIKE 'label';
SHOW COLUMNS FROM llx_missionsplanet_mission LIKE 'mission_types';
SHOW COLUMNS FROM llx_missionsplanet_mission LIKE 'client';
SHOW COLUMNS FROM llx_missionsplanet_mission LIKE 'contact';
SHOW COLUMNS FROM llx_missionsplanet_mission LIKE 'description';
SHOW COLUMNS FROM llx_missionsplanet_mission LIKE 'montant';
SHOW COLUMNS FROM llx_missionsplanet_mission LIKE 'status_payment';
```

```sql
SELECT rowid FROM llx_product WHERE ref = :ref LIMIT 1;
```

```sql
SELECT debutmission, finmission
FROM llx_missionsplanet_mission
WHERE rowid = :id;
```

```sql
UPDATE llx_missionsplanet_mission
SET ...
WHERE rowid = :id;
```

### `api/delete_mission_interpreter.php`

Usage:
- suppression logique d'une mission

```sql
UPDATE llx_missionsplanet_mission
SET status = 9
WHERE rowid = :id;
```

Support:
- une mission supprimee n'est pas forcement effacee physiquement
- verifier le `status = 9`

### `api/get_clients.php`

Usage:
- autocompletion societes

```sql
SELECT rowid AS id, nom AS name
FROM llx_societe
WHERE nom IS NOT NULL
  AND nom <> ''
  AND nom LIKE :search
ORDER BY nom ASC
LIMIT :limit;
```

### `api/get_contacts.php`

Usage:
- contacts d'une societe

```sql
SELECT rowid AS id, firstname, lastname, email, phone, phone_mobile
FROM llx_socpeople
WHERE fk_soc = :socid
  AND (firstname LIKE :search OR lastname LIKE :search)
LIMIT :limit;
```

### `api/get_interpretes.php`

Usage:
- annuaire interpretes

```sql
SELECT u.rowid, u.lastname, u.firstname, ...
FROM llx_user u
LEFT JOIN llx_c_country c ON c.rowid = u.fk_country
WHERE u.entity = 1
  AND (
    EXISTS (
      SELECT 1
      FROM tble_user_rights ur
      ...
    )
    OR COALESCE(u.interp_langues, ...) IS NOT NULL
  );
```

Support:
- un interprete peut etre retrouve par son droit ou par ses champs langues selon les donnees disponibles

### `api/login.php`

Usage:
- authentification

```sql
SELECT rowid, firstname, lastname, login, pass_crypted
FROM llx_user
WHERE login = ?
LIMIT 1;
```

```sql
SELECT r.name
FROM tble_user_rights ur
JOIN tble_rights r ON ur.right_id = r.id
WHERE ur.user_id = ?;
```

### `api/add_interprete.php`

```sql
INSERT INTO llx_user (
    login, pass_crypted, lastname, firstname, email,
    office_phone, office_fax, user_mobile, address,
    zip, town, fk_country, interp_langues,
    interp_commentaires, selectdispo, datec
) VALUES (...);
```

```sql
INSERT INTO tble_user_rights (user_id, right_id)
VALUES (:uid, :rid);
```

### `api/update_interprete.php`

```sql
UPDATE llx_user
SET lastname = :lastname,
    firstname = :firstname,
    email = :email,
    ...,
    selectdispo = :selectdispo
WHERE rowid = :id;
```

### `api/delete_interprete.php`

```sql
DELETE FROM tble_user_rights WHERE user_id = :id;
DELETE FROM llx_user WHERE rowid = :id;
```

### `api/add_language.php`

```sql
SELECT rowid FROM llx_product WHERE ref = :ref LIMIT 1;
```

```sql
INSERT INTO llx_product (
    ref, label, price, price_ttc, tva_tx,
    type, entity, datec, tms
) VALUES (...);
```

### `api/get_languages.php`

```sql
SELECT rowid, ref, label, price, price_ttc, tva_tx, type
FROM llx_product
WHERE (ref IS NOT NULL AND ref <> '')
ORDER BY label ASC
LIMIT :limit;
```

### `api/get_company_info.php`

```sql
SELECT MIN(tms) AS createdAt, MAX(tms) AS updatedAt
FROM llx_const
WHERE entity = :entity
  AND name LIKE 'MAIN_INFO_SOCIETE_%';
```

```sql
SELECT name, value
FROM llx_const
WHERE entity = :entity
  AND name LIKE 'MAIN_INFO_SOCIETE_%';
```

```sql
SELECT label, bank, code_banque, ...
FROM llx_bank_account
WHERE entity = :entity
  AND clos = 0
ORDER BY ...
LIMIT 1;
```

### `api/get_company_bank_accounts.php`

```sql
SELECT rowid, label, bank, code_banque, ...
FROM llx_bank_account
WHERE entity = :entity
  AND clos = 0
ORDER BY ...;
```

### `api/get_client_payment_terms.php`

```sql
SHOW COLUMNS FROM llx_c_payment_term LIKE 'active';
```

```sql
SELECT COALESCE(fk_cond_reglement, 0)
FROM llx_societe
WHERE rowid = :client_id
LIMIT 1;
```

```sql
SELECT rowid, code,
       COALESCE(NULLIF(TRIM(libelle_facture), ''), ..., CONCAT('Condition ', rowid)) AS label,
       nbjour, decalage
FROM llx_c_payment_term
ORDER BY ...;
```

### `api/get_client_invoices.php`

```sql
SELECT COUNT(DISTINCT cb.invoice_number)
FROM tble_client_billed cb
LEFT JOIN llx_missionsplanet_mission m ON m.ref = cb.mission_ref
WHERE ...;
```

```sql
SELECT cb.invoice_number,
       MAX(cb.id) AS id,
       COALESCE(MAX(NULLIF(cb.invoice_total_ht, 0)), SUM(COALESCE(cb.amount_ht, 0))) AS invoice_total_ht,
       ...,
       (
         SELECT MAX(cil.period_month)
         FROM tble_client_invoice_lines cil
         WHERE cil.invoice_number = cb.invoice_number
       ) AS period_month
FROM tble_client_billed cb
LEFT JOIN llx_missionsplanet_mission m ON m.ref = cb.mission_ref
GROUP BY cb.invoice_number
ORDER BY MAX(cb.billed_at) DESC
LIMIT :offset, :limit;
```

### `api/get_client_invoice_lines.php`

```sql
SELECT mission_ref, designation, tva_rate, unit_price_ht, quantity, total_ht, ...
FROM tble_client_invoice_lines
WHERE invoice_number = :invoice
ORDER BY sort_order ASC;
```

### `api/get_invoice_draft_lines.php`

```sql
SELECT mission_ref, designation, tva_rate, unit_price_ht, quantity, total_ht, notes, sort_order
FROM tble_client_invoice_lines
WHERE draft_key = :draft
ORDER BY sort_order ASC;
```

### `api/save_invoice_draft_lines.php`

```sql
DELETE FROM tble_client_invoice_lines WHERE draft_key = :draft;
```

```sql
INSERT INTO tble_client_invoice_lines (
    draft_key, client_name, period_month, mission_ref,
    designation, tva_rate, unit_price_ht, quantity,
    total_ht, notes, sort_order, created_by, created_by_name
) VALUES (...);
```

### `api/update_client_invoice_lines.php`

```sql
SELECT client_name, period_month
FROM tble_client_invoice_lines
WHERE invoice_number = :invoice
  AND mission_ref = :mission_ref
LIMIT 1;
```

```sql
DELETE FROM tble_client_invoice_lines
WHERE invoice_number = :invoice
  AND mission_ref = :mission_ref;
```

```sql
INSERT INTO tble_client_invoice_lines (...) VALUES (...);
```

```sql
SELECT COALESCE(SUM(total_ht), 0)
FROM tble_client_invoice_lines
WHERE invoice_number = :invoice
  AND mission_ref = :mission_ref;
```

```sql
SELECT COALESCE(SUM(total_ht), 0)
FROM tble_client_invoice_lines
WHERE invoice_number = :invoice;
```

```sql
UPDATE tble_client_billed
SET amount_ht = :amount_ht,
    updated_at = CURRENT_TIMESTAMP
WHERE invoice_number = :invoice
  AND mission_ref = :mission_ref;
```

```sql
UPDATE tble_client_billed
SET invoice_total_ht = :invoice_total_ht,
    updated_at = CURRENT_TIMESTAMP
WHERE invoice_number = :invoice;
```

### `api/update_client_invoice_status.php`

```sql
UPDATE tble_client_billed
SET status_code = :code,
    status_label = :label,
    updated_at = CURRENT_TIMESTAMP
WHERE invoice_number = :invoice;
```

### `api/log_client_billing.php`

Usage:
- creation ou mise a jour de la facturation client

```sql
SELECT cb.invoice_number
FROM tble_client_billed cb
WHERE cb.client_name = :client_name
  AND cb.invoice_number <> :invoice_number
  AND LOWER(TRIM(cb.status_code)) IN ('draft', 'validated')
  AND EXISTS (
      SELECT 1
      FROM tble_client_invoice_lines cil
      WHERE cil.invoice_number = cb.invoice_number
        AND cil.period_month = :period_month
  );
```

```sql
INSERT INTO tble_client_billed (
    mission_ref, client_name, invoice_number, ...
) VALUES (...)
ON DUPLICATE KEY UPDATE updated_at = CURRENT_TIMESTAMP;
```

```sql
INSERT INTO tble_client_invoice_lines (...) VALUES (...);
```

```sql
DELETE FROM tble_client_invoice_lines WHERE invoice_number = :invoice;
```

### `api/reserve_client_invoice_number.php`

```sql
SELECT invoice_number
FROM tble_client_billed
WHERE invoice_number LIKE :prefix
ORDER BY invoice_number DESC
LIMIT 1;
```

### `api/update_company_info.php`

```sql
INSERT INTO llx_const (entity, name, value, type, visible, note, tms)
VALUES (...)
ON DUPLICATE KEY UPDATE
    value = VALUES(value),
    tms = NOW();
```

### `api/admin/add_user.php`

```sql
SELECT rowid FROM llx_user WHERE login = ? LIMIT 1;
INSERT INTO llx_user (login, pass_crypted, firstname, lastname, email, entity, statut, admin) VALUES (...);
SELECT id FROM tble_rights WHERE name = ? LIMIT 1;
INSERT INTO tble_user_rights (user_id, right_id) VALUES (:uid, :rid);
```

### `api/admin/update_user.php`

```sql
UPDATE llx_user
SET login = :login,
    firstname = :firstname,
    lastname = :lastname,
    email = :email,
    admin = :admin
WHERE rowid = :id;
```

```sql
DELETE FROM tble_user_rights WHERE user_id = ?;
SELECT id FROM tble_rights WHERE name = ? LIMIT 1;
INSERT INTO tble_user_rights (user_id, right_id) VALUES (:uid, :rid);
```

### `api/admin/delete_user.php`

```sql
DELETE FROM tble_user_rights WHERE user_id = ?;
DELETE FROM llx_user WHERE rowid = ?;
```

### `api/admin/get_users.php`

```sql
SELECT u.rowid AS id,
       u.login AS username,
       CONCAT(u.firstname, ' ', u.lastname) AS fullname,
       u.email,
       u.statut,
       u.admin,
       MAX(CASE WHEN r.name = 'agent_admin_annuaire' THEN 1 ELSE 0 END) AS can_manage_interpreters,
       MAX(CASE WHEN r.name = 'agent_admin_mission' THEN 1 ELSE 0 END) AS can_manage_missions,
       MAX(CASE WHEN r.name = 'interprete' THEN 1 ELSE 0 END) AS is_interpreter,
       MAX(CASE WHEN r.name = 'admin' THEN 1 ELSE 0 END) AS is_admin_from_rights
FROM llx_user u
LEFT JOIN tble_user_rights ur ON ur.user_id = u.rowid
LEFT JOIN tble_rights r ON r.id = ur.right_id
GROUP BY u.rowid
ORDER BY u.lastname, u.firstname;
```

## Helpers Et Migrations

### `api/billing_helpers.php`

Usage:
- creation et evolution du schema de facturation

```sql
SHOW COLUMNS FROM tble_client_billed LIKE ...;
SHOW INDEX FROM tble_client_invoice_lines WHERE Key_name = 'idx_invoice_lines_draft';
CREATE TABLE IF NOT EXISTS tble_client_billed (...);
CREATE TABLE IF NOT EXISTS tble_client_invoice_lines (...);
ALTER TABLE tble_client_invoice_lines ADD COLUMN ... AFTER ...;
ALTER TABLE tble_client_invoice_lines ADD KEY idx_invoice_lines_draft (draft_key);
SELECT status_code FROM tble_client_billed WHERE invoice_number = :invoice ORDER BY billed_at DESC LIMIT 1;
```

### `api/interprete_helpers.php`

```sql
SELECT 1 FROM llx_user WHERE login = ? LIMIT 1;
SELECT id FROM tble_rights WHERE name = :name LIMIT 1;
SELECT 1 FROM tble_user_rights WHERE user_id = :uid AND right_id = :rid LIMIT 1;
INSERT INTO tble_user_rights (user_id, right_id) VALUES (:uid, :rid);
SELECT rowid, code, code_iso, label FROM llx_c_country;
```

### `scripts/backfill_date_creation.php`

```sql
SHOW COLUMNS FROM llx_missionsplanet_mission LIKE :column;
SELECT rowid, ref, date_creation, {fallbackExpression} AS proposed_date_creation
FROM llx_missionsplanet_mission
WHERE date_creation IS NULL
   OR TRIM(date_creation) = ''
   OR date_creation = '0000-00-00';
```

```sql
UPDATE llx_missionsplanet_mission
SET date_creation = {fallbackExpression}
WHERE ...;
```

### `scripts/audit_mission_history.php`

```sql
SELECT COUNT(*) FROM llx_missionsplanet_mission WHERE date_creation IS NULL OR TRIM(date_creation) = '' OR date_creation = '0000-00-00';
SELECT COUNT(*) FROM llx_missionsplanet_mission WHERE mission_types IS NULL OR TRIM(mission_types) = '' OR mission_types = '[]';
SELECT rowid, ref, date_creation, datemission, debutmission, finmission, tms, mission_types, status
FROM llx_missionsplanet_mission
WHERE ...
ORDER BY rowid DESC
LIMIT 15;
```

### `scripts/apply_mission_types_migration.php`

```sql
SHOW COLUMNS FROM llx_missionsplanet_mission LIKE 'mission_types';
```

### `scripts/sql/add_mission_types_column.sql`

```sql
ALTER TABLE llx_missionsplanet_mission
    ADD COLUMN mission_types TEXT NULL
    COMMENT 'JSON array of mission types selected in the mission form'
    AFTER status;
```

### `api/requete_sql`

Usage:
- script legacy de migration / enrichissement interpretes

```sql
ALTER TABLE llx_user ADD COLUMN interp_langues VARCHAR(255) NULL, ...;
```

```sql
UPDATE llx_user u
JOIN tble_annuaire_interpretes i ON ...
SET u.user_mobile = i.Tel_Mobile,
    u.interp_langues = i.Langues_parlees,
    ...;
```

## Questions Support Frequentes

### Retrouver toutes les missions d'une societe

```sql
SELECT m.rowid, m.ref, m.datemission, m.status, s.nom AS client_name
FROM llx_missionsplanet_mission m
LEFT JOIN llx_societe s ON s.rowid = m.fk_soc
WHERE s.nom LIKE '%NomSociete%'
ORDER BY m.datemission DESC;
```

### Retrouver les contacts d'une societe

```sql
SELECT rowid, firstname, lastname, email, phone, phone_mobile
FROM llx_socpeople
WHERE fk_soc = :socid
ORDER BY lastname, firstname;
```

### Voir la derniere facture client d'une mission

```sql
SELECT mission_ref, invoice_number, status_code, status_label, billed_at
FROM tble_client_billed
WHERE mission_ref = :mission_ref
  AND category = 'client'
ORDER BY billed_at DESC
LIMIT 1;
```

### Voir la derniere facturation interprete d'une mission

```sql
SELECT ref, status, billed_at
FROM tble_mission_billed
WHERE ref = :mission_ref
ORDER BY billed_at DESC
LIMIT 1;
```

### Voir les lignes d'une facture

```sql
SELECT *
FROM tble_client_invoice_lines
WHERE invoice_number = :invoice
ORDER BY sort_order ASC;
```

## Conseils D'Interrogation Support

- verifier d'abord si la mission est annulee: `status = 9`
- pour les missions, la cle metier visible est souvent `m.ref`
- pour les societes, la jonction se fait en general via `m.fk_soc = s.rowid`
- pour les contacts, la jonction se fait via `m.contactdemandeur = socp.rowid`
- pour la langue, la jonction se fait via `m.langue = p.rowid`
- pour la facturation client, la reference de mission est `mission_ref`
- pour la facturation interprete, la reference de mission est `ref`

## Limites Du Guide

- certaines requetes sont dynamiques et changent selon les filtres recus
- certaines colonnes sont optionnelles selon le schema reel de la base
- le fichier `api/add_mission.php` pointe vers une table legacy `missions` qui semble distincte du schema principal actuel
