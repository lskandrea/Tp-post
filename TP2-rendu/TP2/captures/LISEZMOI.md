# Preuves TP2

Les .txt sont les sorties réelles des commandes et sessions SSH sur srv-core.
evasion-vim.txt contient les séquences de contrôle du terminal ; la preuve uid=0(root) y figure.
Les *-extrait.txt sélectionnent des passages de ces résultats pour la présentation.
Les neuf PNG dans ecrans/ sont des captures de la console VirtualBox affichant ces extraits enregistrés, et non une nouvelle exécution interactive.
sudo-resultats.json correspond aux tests initiaux ; validation-sudo.json aux règles finales.
controle-final.txt contient les assertions finales, les ACL héritées et la relecture d'une session sudo.
preparation.txt contient l'installation des outils puis constate l'absence initiale de profil authselect ; comptes.txt montre sa sélection et sa validation.
