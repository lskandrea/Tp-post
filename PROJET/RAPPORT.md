# Projet — Mise en production du portail de suivi des tournées

Andrea Garcia Magnanon · BTC2 · Administration Linux · 5 novembre 2026

Le portail est installé sur **srv-core**, sous Rocky Linux 9.8. Les tests réseau sont effectués depuis **srv-edge**. Le service publie la page déposée par Léa et l'état de la collecte du TP1. Les fichiers de configuration livrés dans `configs/` sont les copies de ceux installés sur la VM ; les sorties brutes sont dans `preuves/`.

## 1. Tableau de conformité

| Exigence | Commandes de preuve | Résultat observé et preuve |
|---|---|---|
| E1 — Comptes | `id lea`, `getent passwd helios-suivi`, `chage -l lea` | `lea` : uid 5104, gid 5003, groupe unique `suivi`. Compte de service : uid 993, `/sbin/nologin`, domicile `/srv/helios/suivi`. Vieillissement : minimum 1, maximum 90, avertissement 14, inactivité 7. [Sorties E1](preuves/verification-E1-E9.txt), [comptes](configs/comptes.txt). |
| E2 — Setgid et ACL | `getfacl -p /srv/helios/suivi/www`, `su - lea`, `runuser -u ... -- cat/ls/stat` | `root:suivi`, `2770`. Fichier créé par Léa avec umask 077 : `lea:suivi`, groupe effectivement `rw-`, service effectivement `r--`, autres `---`. Lecture par le service : rc 0 ; par Nadia : rc 1 ; liste par Zabbix : rc 2 ; stat par Zabbix : rc 0. [Sorties E2](preuves/verification-E1-E9.txt), [ACL](configs/www.getfacl.txt). |
| E3 — Publication | `runuser -u helios-suivi -- /usr/local/sbin/helios-suivi-publish.sh`, `flock`, `python3 -m json.tool`, `journalctl -t helios-suivi-publish` | Succès rc 0, verrou occupé rc 2, prérequis manquant rc 3. Ligne invalide rc 1 dans un espace de montage isolé. JSON valide avec les six champs imposés. 218 069 lectures JSON sans fichier partiel pendant 20 publications. [Tests initiaux E3](preuves/verification-E1-E9.txt), [tests complémentaires](preuves/publication-tests-complementaires.txt). |
| E4 — Systemd | `systemctl show`, `systemctl list-dependencies helios.target`, `systemctl list-timers`, `systemd-analyze security`, `curl`, `kill -9` | Portail sous `helios-suivi`, 128 Mio, quota 50 %, système de fichiers en lecture seule. Exposition **1,5**. `/` et `/etat.json` : 200. Après `kill -9`, nouveau PID et HTTP 200 au contrôle quatre secondes plus tard. Timer de publication toutes les deux minutes. [Sorties E4](preuves/verification-E1-E9.txt), [score](preuves/security.txt), [refus d'écriture](preuves/restauration-charge.txt). |
| E5 — Sudo | `visudo -c`, `sudo -l -U lea`, `sudo -l -U lea /usr/bin/systemctl restart sshd` | Syntaxe valide ; cinq commandes exactes, sans joker ni NOPASSWD. Redémarrage du portail autorisé rc 0 ; redémarrage SSH et options supplémentaires journalctl refusés rc 1. Léa a réellement consulté le service avec sudo et son mot de passe de lab. [Sorties E5](preuves/verification-E1-E9.txt), [essai réel](preuves/restauration-charge.txt). |
| E6 — Pare-feu | `firewall-cmd --zone=internal --query-port=8080/tcp`, variante `--permanent`, contrôle de toutes les zones, `nft list ruleset`, tests depuis edge | 8080 présent uniquement dans `internal`, en runtime et permanent. Zone par défaut `drop`. Depuis edge : métier `10.42.0.10:8080/etat.json` → 200 ; administration `192.168.56.10:8080` → échec rc 1. [Contrôle des zones E6](preuves/verification-E1-E9.txt), [tests edge](preuves/pare-feu-depuis-edge.txt), [configuration](configs/firewall-internal.txt). |
| E7 — Non-régression | `sshd -T`, tentative SSH en `lea`, `journalctl -u sshd`, `systemctl is-active`, `getenforce` | SSH : 2242, root interdit, mots de passe interdits, AllowGroups ssh-admins. Refus SSH de Léa et ligne `none of user's groups are listed in AllowGroups`. Collecte et timers précédents actifs, journald persistant, SELinux Enforcing. Empreintes des cinq anciennes units identiques avant/après. [SSH Léa](preuves/ssh-lea.txt), [contrôles E7](preuves/verification-E1-E9.txt), [empreintes](preuves/restauration-charge.txt). |
| E8 — Supervision | `systemctl is-active/is-enabled zabbix-agent2 sysstat sysstat-collect.timer`, `zabbix_get -s 127.0.0.1 -k helios.suivi.http`, clé `helios.suivi.age` | Agent 7.0.32 installé depuis le dépôt officiel ; Server=127.0.0.1. Agent et collecte actifs et activés au boot. Sondes via l'agent : **200** et **19** secondes lors du premier contrôle. [Installation](preuves/installation-paquets.txt), [sorties E8](preuves/verification-E1-E9.txt). |
| E9 — Sauvegarde/restauration | `systemctl start helios-suivi-backup.service`, `sha256sum -c`, `tar --acls`, `diff`, `systemctl cat helios-suivi-backup.timer` | Archives avec ACL et SHA-256 valide ; répertoire parent `helios:helios 0750`. Sauvegarde à 03:15, Persistent=yes. Extraction test et restauration ciblée réussies, ACL et contenu identiques. Après huit sauvegardes supplémentaires : exactement sept archives conservées. [Restauration](preuves/restauration-charge.txt), [rétention](preuves/tests-pannes-audit.txt). |
| E10 — Audit, bonus | `/usr/local/sbin/helios-suivi-audit.sh` | Une ligne par E1–E9, **Bilan : 9/9**, rc 0. Les cinq pannes demandées produisent un KO et rc 1 ; retour à 9/9 après réparation. [Audit final](preuves/audit.txt), [pannes provoquées](preuves/tests-pannes-audit.txt). |

Les prérequis de départ sont enregistrés dans [prerequis.txt](preuves/prerequis.txt). L'instantané `03-fin-TP3` était l'instantané courant de srv-core ; `04-debut-projet` a été pris sur les deux VM avant les modifications. Les units TP1–TP3 n'ont pas été remplacées. Les seuls changements de droits sur la télémétrie sont une traversée ciblée et une lecture ciblée pour le nouveau compte de service.

Zabbix a été installé **avant les ACL**, pour disposer de son compte système. Aucun dépôt EPEL n'était configuré sur cette VM. Le dépôt officiel 7.0 a donc été utilisé directement, sans conflit EPEL. Références : [installation officielle Rocky 9](https://www.zabbix.com/download?zabbix=7.0&os_distribution=rocky_linux&os_version=9&components=agent&db=&ws=), [exclusion EPEL documentée](https://www.zabbix.com/documentation/7.0/en/manual/installation/known_issues).

## 2. Trois justifications

### a. Durcissement du portail

Le portail n'a aucun privilège Linux et tourne sous le compte système dédié. `NoNewPrivileges`, les capacités vides, les protections du noyau, les restrictions d'appels système et de namespaces réduisent ses possibilités. `ProtectSystem=strict` et l'absence de `ReadWritePaths` rendent les données non inscriptibles depuis le service. Les répertoires temporaires privés et `/dev/shm` sont aussi montés en lecture seule ; les trois tentatives d'écriture de la preuve ont échoué. Le score obtenu est **1,5**. Aucune directive bloquante n'a dû être retirée. `PrivateNetwork` n'est pas activé, car le portail doit recevoir les connexions métier. La publication utilise une unit distincte, autorisée à écrire uniquement dans `www` ; son verrou porte sur le répertoire ouvert, et son temporaire est créé dans `www`.

### b. Traversée Zabbix : `--x`, pas `r-x`

Zabbix connaît déjà le chemin d'`etat.json` : il doit traverser les répertoires pour appeler `stat`, sans obtenir la liste de leurs noms. Une ACL `--x` est donc suffisante sur `suivi` et `www` ; `r-x` permettrait de lister `www`. Sans l'entrée de traversée sur `www`, le test réel `stat` a échoué, rc 1. Après remise de l'ACL, `stat` fonctionne tandis que `ls www` échoue, rc 2. Le fichier JSON reste illisible par Zabbix au niveau des droits de fichier ; la sonde HTTP lit la ressource via le portail.

### c. Risque du joker sudo pour journalctl

Dans sudoers, un joker dans les arguments peut englober des espaces et plusieurs options. Il pourrait donc autoriser l'ajout de `--vacuum-time=1s`, qui purge des journaux archivés avec les droits root. Ici, les arguments sont entièrement écrits : unit précise, `-n 100`, `--no-pager`, sans joker. `--no-pager` évite aussi un pager interactif lancé par root. L'essai avec `--vacuum-time=1s` ajouté a été refusé. Un second test a introduit temporairement une permission de redémarrer SSH : l'audit a bien signalé E5 KO, puis la règle initiale a été restaurée.

## 3. Test de restauration

Commandes exécutées, avec le chemin d'archive choisi dans la preuve :

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

La dernière archive au moment de l'essai était `suivi-20261105-013802.tar.gz`. `sha256sum -c` a renvoyé `OK`. Les deux `diff` n'ont produit aucune différence. Après suppression, `/index.html` répondait **404** ; après restauration du seul fichier, il répondait **200**. Le SHA-256 d'index était identique avant/après : `dc09d1c8055a642e4672877c5815862f7e636628ac35ec5c62a4e83243a00003`.

Le test automatisé complet, de la vérification de l'empreinte au retour HTTP 200, a duré **137 ms**. Cette mesure ne comprend pas le temps humain de diagnostic. Voir la [sortie brute](preuves/restauration-charge.txt). La rétention a ensuite supprimé les anciennes archives conformément à la limite de sept.

## 4. Mesure sous charge

La boucle imposée de **2 000 requêtes séquentielles** a pris **22,141 s**. `sar -u 1 30` couvrait toute la boucle et quelques secondes après. Sa moyenne sur les 30 secondes est : user **41,70 %**, nice **0,43 %**, system **16,49 %**, idle **41,38 %**. Elle mesure la VM entière, y compris les processus `curl`.

| Mesure du service | Avant | Après |
|---|---:|---:|
| CPUUsageNSec | 91 625 000 | 1 814 024 000 |
| MemoryCurrent, octets | 10 584 064 | 10 584 064 |
| nr_throttled, cpu.stat | 0 | 0 |
| throttled_usec | 0 | 0 |

Le quota de 50 % n'a **pas limité cette boucle** : le compteur de throttling est resté à zéro. Le service a consommé environ **1,722 s CPU** en 22,141 s, soit **7,8 % d'un cœur** ; la charge totale de la VM vient aussi des clients `curl`. [Mesures complètes](preuves/restauration-charge.txt).

## 5. Limites connues

- Le bonus de frontend Zabbix avec serveur, base de données et déclencheurs n'est pas réalisé. Les deux sondes de l'agent sont installées et testées via `zabbix_get` ; leurs valeurs réagissent aux pannes réelles.
- Le serveur HTTP Python est celui imposé pour le laboratoire. Avec une journée de plus, je prévoirais une solution adaptée à un véritable service web, une authentification et du TLS, selon les besoins métier.
- Les sauvegardes sont locales à la VM. Elles protègent une suppression de fichier, pas la perte du disque de la VM ; une copie hors machine compléterait le dispositif.
- L'audit vérifie la configuration locale et les sondes locales. Il ne remplace pas le test de bout en bout depuis srv-edge ; celui-ci est fourni séparément. Les scénarios de restauration et les codes de sortie de publication sont prouvés par des essais, sans être reproduits par l'audit en lecture seule.
- L'héritage ACL est vérifié pour une création normale de fichier, même avec umask 077. Il ne peut pas empêcher un propriétaire de retirer volontairement des droits avec un chmod explicite.
- Le premier redémarrage logiciel s'est bloqué avant Linux, avec `PXE-E06: Option ROM requires DDIM support` dans la console VirtualBox. Un arrêt/démarrage à froid a rétabli le démarrage du disque, sans restauration d'instantané ni modification des données. Les captures de console sont conservées dans `preuves/`. Après démarrage à froid, les services sont repartis automatiquement et l'audit a retrouvé 9/9. Les premières preuves portent l'horloge de la VM reprise de son état enregistré ; après démarrage à froid, l'horloge est revenue à celle de l'hôte. Les sorties brutes n'ont pas été retouchées.

Un second **redémarrage logiciel** a ensuite réussi sans intervention sur la console : contrôle à 11:06, huit services/timers actifs, HTTP 200, âge du JSON 28 secondes, SELinux Enforcing et audit **9/9**. Les anciennes units ont conservé leurs empreintes. La sortie est dans [apres-redemarrage.txt](preuves/apres-redemarrage.txt), et le test réseau final dans [pare-feu-apres-redemarrage.txt](preuves/pare-feu-apres-redemarrage.txt). Le bonus d'astreinte est fourni dans [RUNBOOK.md](RUNBOOK.md).
