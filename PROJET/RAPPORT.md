# Projet — Mise en production du portail de suivi des tournées

Andrea Garcia Magnanon · BTC2 · Administration Linux · 5 novembre 2026

Le but du projet est de consulter l'état de la collecte du TP1 depuis une page web. Le portail tourne sur **srv-core**, sous Rocky Linux 9.8. Les tests d'accès passent par **srv-edge**. Léa peut gérer la page et relancer le service avec les droits prévus dans le sujet.

Les configurations installées sont dans `configs/`. Les résultats des commandes et les captures sont dans `preuves/`.

## 1. Tableau de conformité

| Exigence | Commandes de preuve | Résultat observé et preuve |
|---|---|---|
| E1 — Comptes | `id lea`, `getent passwd helios-suivi`, `chage -l lea` | `lea` : uid 5104, gid 5003, groupe unique `suivi`. Compte de service : uid 993, `/sbin/nologin`, domicile `/srv/helios/suivi`. Vieillissement : minimum 1, maximum 90, avertissement 14, inactivité 7. [Sorties E1](preuves/verification-E1-E9.txt), [comptes](configs/comptes.txt). |
| E2 — Setgid et ACL | `getfacl -p /srv/helios/suivi/www`, `su - lea`, `runuser -u ... -- cat/ls/stat` | `root:suivi`, `2770`. Fichier créé par Léa avec umask 077 : `lea:suivi`, groupe effectivement `rw-`, service effectivement `r--`, autres `---`. Lecture par le service : rc 0 ; par Nadia : rc 1 ; liste par Zabbix : rc 2 ; stat par Zabbix : rc 0. [Sorties E2](preuves/verification-E1-E9.txt), [ACL](configs/www.getfacl.txt). |
| E3 — Publication | `runuser -u helios-suivi -- /usr/local/sbin/helios-suivi-publish.sh`, `flock`, `python3 -m json.tool`, `journalctl -t helios-suivi-publish` | Succès rc 0, verrou occupé rc 2, prérequis manquant rc 3. Ligne invalide rc 1 dans un espace de montage isolé. JSON valide avec les six champs imposés. 218 069 lectures JSON sans fichier partiel pendant 20 publications. [Tests initiaux E3](preuves/verification-E1-E9.txt), [tests complémentaires](preuves/publication-tests-complementaires.txt). |
| E4 — Systemd | `systemctl show`, `systemctl list-dependencies helios.target`, `systemctl list-timers`, `systemd-analyze security`, `curl`, `kill -9` | Portail sous `helios-suivi`, 128 Mio, quota 50 %, système de fichiers en lecture seule. Exposition **1,5**. `/` et `/etat.json` : 200. Après `kill -9`, nouveau PID et HTTP 200 au contrôle quatre secondes plus tard. Timer de publication toutes les deux minutes. [Sorties E4](preuves/verification-E1-E9.txt), [score](preuves/security.txt), [refus d'écriture](preuves/restauration-charge.txt). |
| E5 — Sudo | `visudo -c`, `sudo -l -U lea`, `sudo -l -U lea /usr/bin/systemctl restart sshd` | Syntaxe valide ; cinq commandes exactes, sans joker ni NOPASSWD. Redémarrage du portail autorisé rc 0 ; redémarrage SSH et options supplémentaires journalctl refusés rc 1. Léa a réellement consulté le service avec sudo et son mot de passe de lab. [Sorties E5](preuves/verification-E1-E9.txt), [essai réel](preuves/restauration-charge.txt). |
| E6 — Pare-feu | `firewall-cmd --zone=internal --query-port=8080/tcp`, variante `--permanent`, contrôle de toutes les zones, `nft list ruleset`, tests depuis edge | 8080 présent uniquement dans `internal`, en runtime et permanent. Zone par défaut `drop`. Depuis edge : métier `10.42.0.10:8080/etat.json` → 200 ; administration `192.168.56.10:8080` → échec rc 1. [Contrôle des zones E6](preuves/verification-E1-E9.txt), [tests edge](preuves/pare-feu-apres-redemarrage.txt), [configuration](configs/firewall-internal.txt). |
| E7 — Non-régression | `sshd -T`, tentative SSH en `lea`, `journalctl -u sshd`, `systemctl is-active`, `getenforce` | SSH : 2242, root interdit, mots de passe interdits, AllowGroups ssh-admins. Refus SSH de Léa et ligne `none of user's groups are listed in AllowGroups`. Collecte et timers précédents actifs, journald persistant, SELinux Enforcing. Empreintes des cinq anciennes units identiques avant/après. [SSH Léa](preuves/ssh-lea.txt), [contrôles E7](preuves/verification-E1-E9.txt), [empreintes](preuves/restauration-charge.txt). |
| E8 — Supervision | `systemctl is-active/is-enabled zabbix-agent2 sysstat sysstat-collect.timer`, `zabbix_get -s 127.0.0.1 -k helios.suivi.http`, clé `helios.suivi.age` | Agent 7.0.32 installé depuis le dépôt officiel ; Server=127.0.0.1. Agent et collecte actifs et activés au boot. Sondes via l'agent : **200** et **19** secondes lors du premier contrôle. [Contrôles E8](preuves/verification-E1-E9.txt), [version Zabbix](preuves/bonus-configuration.txt). |
| E9 — Sauvegarde/restauration | `systemctl start helios-suivi-backup.service`, `sha256sum -c`, `tar --acls`, `diff`, `systemctl cat helios-suivi-backup.timer` | Archives avec ACL et SHA-256 valide ; répertoire parent `helios:helios 0750`. Sauvegarde à 03:15, Persistent=yes. Extraction test et restauration ciblée réussies, ACL et contenu identiques. Après huit sauvegardes supplémentaires : exactement sept archives conservées. [Restauration](preuves/restauration-charge.txt), [rétention](preuves/tests-pannes-audit.txt). |
| E10 — Audit, bonus | `/usr/local/sbin/helios-suivi-audit.sh` | Une ligne par E1–E9, **Bilan : 9/9**, rc 0. Les cinq pannes demandées produisent un KO et rc 1 ; retour à 9/9 après réparation. [Audit final](preuves/audit.txt), [pannes provoquées](preuves/tests-pannes-audit.txt). |

Le bonus Zabbix est aussi fait. Les deux éléments sont sur l'hôte `Zabbix server`. L'arrêt du portail déclenche l'alerte Haute ; l'arrêt de la publication pendant plus de cinq minutes déclenche l'alerte Moyenne. Les deux alertes disparaissent après remise en route. Les étapes et les captures sont dans [BONUS-ZABBIX.md](BONUS-ZABBIX.md), avec [les événements enregistrés](preuves/bonus-alertes-reelles.txt) et [le contrôle final](preuves/bonus-etat-final.txt). L'interface Zabbix utilise le port 80 en zone `work`. Le port 8080 du portail reste ouvert uniquement dans `internal`.

Avant de commencer, les contrôles du TP3 ont été vérifiés et enregistrés dans [prerequis.txt](preuves/prerequis.txt). srv-core était sur l'instantané `03-fin-TP3`. Un nouvel instantané, `04-debut-projet`, a été pris sur les deux VM. Les units des TP précédents ont été gardées. Pour lire la télémétrie, le compte `helios-suivi` a reçu le droit de traverser son dossier et de lire le fichier CSV.

L'agent Zabbix a été installé en premier, car son compte doit exister avant de poser les ACL. La VM n'avait pas de dépôt EPEL : les paquets viennent donc directement du dépôt officiel Zabbix 7.0. Les références utilisées sont [l'installation pour Rocky 9](https://www.zabbix.com/download?zabbix=7.0&os_distribution=rocky_linux&os_version=9&components=agent&db=&ws=) et [la consigne sur EPEL](https://www.zabbix.com/documentation/7.0/en/manual/installation/known_issues).

## 2. Trois justifications

### a. Durcissement du portail

Le serveur web tourne avec le compte `helios-suivi`, sans capacités Linux et avec `NoNewPrivileges`. Il sert seulement les fichiers : il n'a donc pas besoin d'écrire. `ProtectSystem=strict` et les montages en lecture seule bloquent aussi l'écriture dans `www`, `/tmp` et `/dev/shm`. Les trois essais ont bien échoué. Le score de `systemd-analyze security` est **1,5**, sous la limite de 4 demandée. Aucune directive n'a dû être retirée pour faire fonctionner le service. Le réseau reste disponible pour recevoir les connexions métier. La publication a sa propre unit : elle seule peut écrire dans `www`, où se trouvent aussi son fichier temporaire et son verrou sur le répertoire.

### b. Traversée Zabbix : `--x`, pas `r-x`

Zabbix doit connaître la date d'`etat.json` avec `stat`. Comme le chemin est déjà connu, le droit `--x` suffit pour traverser les dossiers. Ajouter `r` lui permettrait aussi de lister leur contenu, ce qui n'est pas demandé. Sans l'ACL sur `www`, `stat` échoue avec le code 1. Une fois l'ACL remise, `stat` réussit et `ls www` reste refusé avec le code 2. Zabbix ne peut pas lire directement le fichier JSON ; la sonde HTTP passe par le portail.

### c. Risque du joker sudo pour journalctl

Un `*` dans les arguments sudo pourrait accepter des options en plus, comme `--vacuum-time=1s`, et permettre à Léa de supprimer des journaux archivés avec les droits root. La règle fixe donc la commande complète : le nom du service, `-n 100` et `--no-pager`. Cette dernière option évite aussi d'ouvrir un pager interactif en root. Le test avec l'option de suppression ajoutée a été refusé. L'audit a également détecté une règle trop large autorisant le redémarrage de SSH ; cette règle de test a ensuite été retirée.

## 3. Test de restauration

Le test comporte deux étapes : extraire la sauvegarde dans un dossier de test, puis supprimer et restaurer seulement `index.html`. Voici les commandes utilisées :

```sh
archive=$(find /srv/helios/archives/suivi -name 'suivi-*.tar.gz' -type f | sort | tail -1)
(cd /srv/helios/archives/suivi; sha256sum -c "${archive##*/}.sha256")
testdir=$(mktemp -d /var/tmp/helios-restauration.XXXXXXXX)
tar --acls --xattrs --selinux --numeric-owner -xzf "$archive" -C "$testdir"
getfacl -cp /srv/helios/suivi/www > "$testdir/acl-production"
getfacl -cp "$testdir/srv/helios/suivi/www" > "$testdir/acl-restauree"
diff -u "$testdir/acl-production" "$testdir/acl-restauree"
getfacl -cp /srv/helios/suivi/www/index.html > "$testdir/index-acl-avant"
rm -- /srv/helios/suivi/www/index.html
tar --acls --xattrs --selinux --numeric-owner -xzf "$archive" -C / srv/helios/suivi/www/index.html
getfacl -cp /srv/helios/suivi/www/index.html > "$testdir/index-acl-apres"
diff -u "$testdir/index-acl-avant" "$testdir/index-acl-apres"
cmp /srv/helios/suivi/www/index.html "$testdir/srv/helios/suivi/www/index.html"
```

L'archive utilisée était `suivi-20261105-013802.tar.gz`. Son empreinte a été vérifiée : `sha256sum -c` renvoie `OK`. Les ACL du dossier extrait sont identiques à celles de la production. Après suppression d'index, `/index.html` répond **404**. Après restauration, il répond **200** et retrouve ses ACL. Son SHA-256 est le même avant et après : `dc09d1c8055a642e4672877c5815862f7e636628ac35ec5c62a4e83243a00003`.

Le script a effectué ce test en **137 ms**, de la vérification de l'archive au retour HTTP 200. C'est le temps des commandes automatisées, sans le temps de diagnostic. Le détail est dans [restauration-charge.txt](preuves/restauration-charge.txt). Un autre essai a confirmé qu'après huit sauvegardes supplémentaires, seules les sept plus récentes sont gardées.

## 4. Mesure sous charge

Les **2 000 requêtes**, envoyées l'une après l'autre, ont pris **22,141 s**. Pendant ce temps, `sar -u 1 30` a mesuré la charge de toute la VM. Sur les 30 secondes, les moyennes sont : user **41,70 %**, nice **0,43 %**, system **16,49 %** et idle **41,38 %**. Cela comprend les commandes `curl` et les quelques secondes après la boucle.

| Mesure du service | Avant | Après |
|---|---:|---:|
| CPUUsageNSec | 91 625 000 | 1 814 024 000 |
| MemoryCurrent, octets | 10 584 064 | 10 584 064 |
| nr_throttled, cpu.stat | 0 | 0 |
| throttled_usec | 0 | 0 |

Le quota de 50 % n'a pas été atteint : `nr_throttled` et `throttled_usec` sont restés à zéro. Le portail a utilisé environ **1,722 s CPU** sur 22,141 s, soit **7,8 % d'un cœur** ; le reste de la charge vient aussi des clients `curl`. [Résultats complets](preuves/restauration-charge.txt).

## 5. Limites connues

- Les sauvegardes sont sur le disque de la VM. Une copie sur une autre machine serait nécessaire pour se protéger d'une perte du disque. L'historique de la base Zabbix n'est pas sauvegardé avec le portail ; seul son export de configuration est fourni.
- Le serveur HTTP Python est celui demandé dans le sujet. Avec plus de temps, je travaillerais sur un serveur web adapté à une utilisation quotidienne, avec authentification et HTTPS.
- L'audit contrôle le serveur local. Les accès depuis srv-edge, la restauration et les codes de retour du script ont été testés séparément : l'audit ne refait pas ces essais, car il ne doit rien modifier.
- Les ACL sont héritées à la création d'un fichier, y compris avec umask 077. Elles n'empêchent pas son propriétaire de changer ensuite les droits avec `chmod`.

Le premier redémarrage s'est bloqué avant Linux avec le message `PXE-E06: Option ROM requires DDIM support`. Un arrêt puis un démarrage à froid de la VM a suffi à la relancer. Aucun instantané n'a été restauré. Les premières sorties utilisent l'heure de la VM reprise de son état enregistré ; après le démarrage à froid, son horloge est revenue à celle de l'hôte. Les heures présentes dans les preuves ont été gardées telles quelles.

Le deuxième redémarrage logiciel a réussi sans intervention. Au contrôle de 11:06, les huit services et timers vérifiés étaient actifs, le portail répondait 200 et le JSON avait 28 secondes. SELinux était toujours Enforcing et l'audit affichait **9/9**. Les empreintes des anciennes units n'avaient pas changé. Les résultats sont dans [apres-redemarrage.txt](preuves/apres-redemarrage.txt) et [pare-feu-apres-redemarrage.txt](preuves/pare-feu-apres-redemarrage.txt). Le guide d'astreinte demandé en bonus est dans [RUNBOOK.md](RUNBOOK.md).
