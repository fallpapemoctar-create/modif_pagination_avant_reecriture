<?php
require_once "config.php";

header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");

$data = json_decode(file_get_contents("php://input"), true);

if (!$data || !isset($data["id_tble_annuaire_interpretes"])) {
    echo json_encode(["error" => "ID manquant"]);
    exit;
}

try {
    $sql = "
        UPDATE tble_annuaire_interpretes SET
            id_tble_annuaire_interpretes = :userId,
            Numero = :numero,
            Nom = :nom,
            Prenom = :prenom,
            Email = :email,
            Tel_Mobile = :mobile,
            Tel_domicile = :domicile,
            Langues_parlees = :langues,
            Adresse = :adresse,
            Code_postal = :cp,
            Ville = :ville,
            Pays = :pays,
            Commentaires = :commentaires
        WHERE id_tble_annuaire_interpretes = :id
    ";

    $stmt = $pdo->prepare($sql);

    $stmt->execute([
        ":id"           => $data["id_tble_annuaire_interpretes"],
        ":userId"       => $data["id_vers_tble_users_v"],
        ":numero"       => $data["Numero"],
        ":nom"          => $data["Nom"],
        ":prenom"       => $data["Prenom"],
        ":email"        => $data["Email"],
        ":mobile"       => $data["Tel_Mobile"],
        ":domicile"     => $data["Tel_domicile"],
        ":langues"      => $data["Langues_parlees"],
        ":adresse"      => $data["Adresse"],
        ":cp"           => $data["Code_postal"],
        ":ville"        => $data["Ville"],
        ":pays"         => $data["Pays"],
        ":commentaires" => $data["Commentaires"]
    ]);

    echo json_encode(["message" => "Interprète mis à jour"]);

} catch (Exception $e) {
    echo json_encode(["error" => $e->getMessage()]);
}