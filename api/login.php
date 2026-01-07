<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Methods: POST");

require_once "config.php"; // Connexion PDO

/*Récupérer login et mot de passe saisi****/
$data = json_decode(file_get_contents("php://input"), true);
$login = $data["login"] ?? "";
$password = $data["password"] ?? "";

/*$login = 'afall';
$password = 'Senegal2024#';*/

if (empty($login) || empty($password)) {
    echo json_encode([
        "success" => false,
        "message" => "login ou mot de passe manquant"
    ]);
    exit;
}

// 1. Vérifier si l'utilisateur existe
$stmt = $pdo->prepare("SELECT rowid, firstname, lastname, login, pass_crypted
                       FROM llx_user 
                       WHERE login = ? LIMIT 1");
$stmt->execute([$login]);
$user = $stmt->fetch(PDO::FETCH_ASSOC);

if (!$user) {
    echo json_encode([
        "success" => false,
        "message" => "Utilisateur introuvable"
    ]);
    exit;
}

// 2. Vérifier le mot de passe

if (!password_verify($password, $user["pass_crypted"])) {
    echo json_encode([
        "success" => false,
        "message" => "Mot de passe incorrect"
    ]);
    exit;
}

// 3. Charger les droits de l'utilisateur
$stmt = $pdo->prepare("
    SELECT r.name
    FROM tble_user_rights ur
    JOIN tble_rights r ON ur.right_id = r.id
    WHERE ur.user_id = ?
");
$stmt->execute([$user["rowid"]]);
$rights = $stmt->fetchAll(PDO::FETCH_COLUMN);

// 4. Réponse finale
echo json_encode([
    "success" => true,
    "user" => [
        "id" => $user["rowid"],
        "prenom" => $user["firstname"],
        "nom" => $user["lastname"],
        "login" => $user["login"]
    ],
    "rights" => $rights
]);