# Configurations du TP3

Fichiers récupérés sur srv-core après les contrôles du 4 novembre 2026.

| Fichier | Destination ou rôle |
|---|---|
| zones.txt, zones-actives.txt, zones-permanentes.txt | États firewalld observés |
| work.xml, internal.xml, drop.xml | Définitions de zones ; les interfaces sont associées par NetworkManager |
| helios-blacklist.xml | /etc/firewalld/ipsets/ ; liste vide après déblocage du poste de test |
| nftables.txt | Règles générées par firewalld, à consulter ; ne pas charger en parallèle de firewalld |
| 10-helios-hardening.conf | /etc/ssh/sshd_config.d/10-helios-hardening.conf |
| 05-helios-crypto.conf | /etc/ssh/sshd_config.d/05-helios-crypto.conf, lu avant 50-redhat.conf |
| sshd_config et sshd_config.diff | Fichier principal et changement de la définition SFTP |
| sshd-effectif*.txt | Configuration calculée par sshd -T, dont le cas de Julien |
| issue.net | /etc/issue.net |
| 50-helios.conf | /etc/systemd/journald.conf.d/50-helios.conf |
| 90-helios.rules | /etc/audit/rules.d/90-helios.rules ; état final -e 1 |
| audit-regles-chargees.txt | Règles présentes dans le noyau |
| helios-watch-auth.sh | /usr/local/sbin/helios-watch-auth.sh (0750 root:root) |
| helios-watch-auth.service et .timer | /etc/systemd/system/ |
| 10-helios-network.conf | /etc/systemd/system/sshd.service.d/ |
| selinux-ssh-port.txt | Déclaration de 2242 dans ssh_port_t |
| crypto-policy.txt | Politique DEFAULT:NO-SHA1 |

Le script de détection est un livrable demandé dans le sujet. Les scripts qui ont servi à préparer les exercices ne font pas partie du rendu.
Le détecteur stocke son état dans /var/lib/helios-watch-auth, réservé à root.
Les clés privées ne sont pas jointes. Une clé publique autorisée et un compte membre de ssh-admins sont nécessaires pour SSH.
Vérifier sshd -t, firewall-cmd --check-config et systemd-analyze verify avant d'appliquer une modification.
