<?php
require_once "config.php";

header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");

$data = json_decode(file_get_contents("php://input"), true);

if (!$data) {
    echo json_encode(["error" => "Aucune donnée reçue"]);
    exit;
}

try {
    $sql = "
        INSERT INTO tble_annuaire_interpretes (
            Numero,
            Nom,
            Prenom,
            Email,
            Tel_Mobile,
            Tel_domicile,
            Langues_parlees,
            Adresse,
            Code_postal,
            Ville,
            Pays,
            Commentaires
        ) VALUES (
            :numero, :nom, :prenom, :email, :mobile, :domicile,
            :langues, :adresse, :cp, :ville, :pays, :commentaires
        )
    ";

    $stmt = $pdo->prepare($sql);

    $stmt->execute([
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

    echo json_encode(["message" => "Interprète ajouté avec succès"]);

} catch (Exception $e) {
    echo json_encode(["error" => $e->getMessage()]);
}