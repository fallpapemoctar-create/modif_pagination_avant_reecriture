<?php
require_once "config.php";

header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");

$sql = "SELECT llx_missionsplanet_mission.nominterprete, llx_user.firstname, llx_user.lastname FROM llx_missionsplanet_mission INNER JOIN llx_user ON llx_missionsplanet_mission.nominterprete = llx_user.rowid group by (llx_missionsplanet_mission.nominterprete) order by llx_user.lastname asc";
$result = $pdo->query($sql);

$missions = [];
while ($row = $result->fetch()) {
    $missions[] = $row;
}

echo json_encode($missions);