# Suivi Post-Livraison

Version fonctionnelle livree le vendredi 17/04/2026.

Plus tard apres signature contrat, ajouter une page pour gerer les langues.

On pourra ajouter plus tard un batch qu'on peut lancer depuis l'interface, pour creer l'ensemble des factures du mois pour chaque client.

On peut ajouter une fonctionnalite (formulaire pre-rempli) pour envoyer les factures au client depuis l'UI de l'AMI.

Pour FMI, il ne faudrait plus que lorsque l'utilisateur renseigne ses date, heure, ou duree de mission, que le statut mission genere par FMI ne soit pas persiste dans la colonne statut de la table mission.

Sachant que la facturation des interpretes est suivie sur la table tble_billed, le plus simple c'est de ne plus persister le statut planifie et termine affiche sur la carte mission et de les garder pour info sur la mission pour l'interprete.

Ajouter une fonctionnalite pour appliquer a la fois un changement de statut pour le suivi des factures des missions pour Mr Ba.