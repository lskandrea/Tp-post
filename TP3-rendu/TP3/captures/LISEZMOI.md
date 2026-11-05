# Preuves du TP3

Les fichiers texte sont les sorties réelles des commandes sur srv-core et srv-edge.
Les captures 01, 02, 04, 06, 07, 08, 10 et 11 montrent des contrôles exécutés directement dans la console VirtualBox.
Les captures 03, 05 et 09 affichent une relecture identifiée des scans, tests SSH et du blocage déjà enregistrés.
Le scan avant correspond à l'état avant durcissement SSH, après préparation des paquets du labo.
core-journaux-audit.txt et les fichiers ausearch montrent les événements d'audit.
core-investigation.txt contient les cinq requêtes journald et les recherches complémentaires.
blocage-ipset.txt, edge-bloquee.txt et deblocage.txt montrent l'ajout à la liste noire puis le nettoyage du poste de test.
core-controle-final.txt et timer-final.txt décrivent l'état final après expiration de la fenêtre des échecs simulés.
Les essais d'audit en mode immuable sont dans core-bonus-avant-reboot.txt ; le retour en enabled 1 est vérifié après redémarrage.
