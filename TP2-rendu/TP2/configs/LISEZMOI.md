# Configurations TP2

Ces fichiers proviennent de srv-core après les tests du 3 novembre 2026.

| Fichier | Destination / utilisation |
|---|---|
| login.defs.diff | Diff par rapport à la configuration du TP1 |
| login.defs | Référence finale : /etc/login.defs |
| 50-helios.conf | /etc/security/pwquality.conf.d/50-helios.conf (0644) |
| faillock.conf | /etc/security/faillock.conf ; authselect sssd avec with-faillock |
| helios-umask.sh | /etc/profile.d/helios-umask.sh (0644) |
| 90-helios-ops | /etc/sudoers.d/90-helios-ops (0440) ; valider par visudo -c |
| 90-helios-ops-enonce | Version initiale fournie, conservée pour comparaison ; ne pas installer en plus |
| 91-nadia-edition | /etc/sudoers.d/91-nadia-edition (0440), un fichier exact autorisé |
| helios-lastlog.c | Source pour /usr/local/bin/helios-lastlog, root:telemetry, 2755 |
| skel-bashrc.ajout | Bloc ajouté à /etc/skel/.bashrc, pas un fichier .bashrc complet |
| authselect.txt | Profil et fonctionnalités observés |
| acl-transport-2026-11-03.txt | Sauvegarde finale avec noms relatifs |
| transport.tgz | Projet final archivé avec tar --acls --xattrs |

Restauration ACL depuis /srv/helios/projets :
    setfacl -P --restore=/chemin/acl-transport-2026-11-03.txt

Pour conserver les ACL d'une archive :
    tar --acls --xattrs -xzf /chemin/transport.tgz

Les comptes et groupes doivent correspondre aux UID/GID décrits dans le rapport.
Les scripts setuid de démonstration et la règle sudo vim temporaire ont été supprimés.
Le masque final des fichiers ordinaires est rw-, celui des répertoires rwx.
Les ACL par défaut utilisent audit-ext:r-x pour permettre la traversée des futurs sous-dossiers.
