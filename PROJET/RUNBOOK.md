# Astreinte — Portail Hélios

Cible : srv-core. Accès administrateur : SSH 2242 avec clé, compte autorisé dans ssh-admins. Léa utilise les commandes sudo déléguées depuis sa session locale. Les commandes de restauration et de pare-feu nécessitent un administrateur root.

## 1. Le portail ne répond plus

- **Symptôme :** `helios.suivi.http` différent de 200, ou échec de curl.
- **Diagnostic :** `systemctl status helios-suivi.service --no-pager` ; `journalctl -u helios-suivi.service -n 100 --no-pager`.
- **Réparation :** Léa : `sudo /usr/bin/systemctl restart helios-suivi.service`. Si nouvel échec, faire intervenir l'administrateur ; ne pas désactiver SELinux.
- **Vérification :** `curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:8080/etat.json` → 200.

## 2. etat.json est figé

- **Symptôme :** `helios.suivi.age` dépasse 300 secondes.
- **Diagnostic :** `systemctl list-timers helios-suivi-publish.timer` ; `journalctl -u helios-suivi-publish.service -n 100 --no-pager` ; admin : `tail -1 /var/lib/helios/telemetry.csv`.
- **Réparation :** Léa : `sudo /usr/bin/systemctl start helios-suivi-publish.service` ; admin : corriger la cause puis `systemctl enable --now helios-suivi-publish.timer` ; vérifier aussi le collecteur.
- **Vérification :** `zabbix_get -s 127.0.0.1 -k helios.suivi.age` → nombre inférieur à 300 ; `derniere_mesure` doit progresser.

## 3. Service actif mais inaccessible du réseau métier

- **Symptôme :** curl local répond 200 ; depuis srv-edge, le portail ne répond pas.
- **Diagnostic :** `firewall-cmd --get-active-zones` ; `firewall-cmd --zone=internal --query-port=8080/tcp` ; `ip -br a` ; vérifier aussi l'ipset de blocage du TP3 avant toute suppression d'entrée.
- **Réparation :** admin, seulement si la règle manque : `firewall-cmd --zone=internal --add-port=8080/tcp` puis la même commande avec `--permanent`. Ne pas ouvrir une autre zone.
- **Vérification :** depuis edge : `curl -f http://10.42.0.10:8080/etat.json` réussit ; `nc -zv -w2 192.168.56.10 8080` échoue.

## 4. Fichier supprimé ou corrompu

- **Symptôme :** page absente, contenu incorrect ou contrôle d'intégrité en échec.
- **Diagnostic :** root : `a=$(find /srv/helios/archives/suivi -name 'suivi-*.tar.gz' | sort | tail -1)` ; `(cd /srv/helios/archives/suivi && sha256sum -c "${a##*/}.sha256")`. Arrêter si l'empreinte échoue.
- **Réparation :** pour index seul : `tar --acls --xattrs --selinux --numeric-owner -xzf "$a" -C / srv/helios/suivi/www/index.html`. Pour tout reconstruire, extraire d'abord en test, recréer les comptes avec les identifiants de `configs/comptes.txt` et les ACL des parents, restaurer puis `systemctl daemon-reload` et réactiver le portail, ses timers et Zabbix.
- **Vérification :** `getfacl /srv/helios/suivi/www/index.html`, HTTP 200 et `/usr/local/sbin/helios-suivi-audit.sh` → Bilan : 9/9, rc 0.
