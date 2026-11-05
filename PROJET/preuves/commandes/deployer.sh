set -euo pipefail
getent group suivi >/dev/null || groupadd -g 5003 suivi
id lea >/dev/null 2>&1 || useradd -u 5104 -g suivi -c 'Lea Fabre - responsable suivi des tournees' -m lea
printf 'lea:Helios-Suivi-2026\n' | chpasswd
chage -M 90 -m 1 -W 14 -I 7 lea
id helios-suivi >/dev/null 2>&1 || useradd -r -g suivi -d /srv/helios/suivi -s /sbin/nologin -M helios-suivi
install -d -o root -g suivi -m 0750 /srv/helios/suivi
setfacl -m u:zabbix:--x /srv/helios/suivi
install -d -o root -g suivi -m 2770 /srv/helios/suivi/www
setfacl -m u:helios-suivi:rwx,u:zabbix:--x,m:rwx,o:--- /srv/helios/suivi/www
setfacl -d -m u::rwx,u:helios-suivi:r-x,g::rwx,m:rwx,o:--- /srv/helios/suivi/www
# Acces cible a la telemetrie, sans modifier les units precedentes.
setfacl -m u:helios-suivi:--x /var/lib/helios
setfacl -m u:helios-suivi:r-- /var/lib/helios/telemetry.csv
su - lea -c 'umask 077; printf "<!doctype html><html lang=fr><meta charset=utf-8><title>Helios suivi</title><h1>Suivi des tournees Helios</h1><p>Portail exploite par Lea Fabre. <a href=etat.json>Etat de la collecte</a></p></html>\n" > /srv/helios/suivi/www/index.html'
for f in helios-suivi-publish.sh helios-suivi-backup.sh; do install -o root -g root -m 0755 /tmp/projet-$f /usr/local/sbin/$f; done
for f in /tmp/projet-helios-suivi*.service /tmp/projet-helios-suivi*.timer; do install -o root -g root -m 0644 "$f" "/etc/systemd/system/${f#/tmp/projet-}"; done
visudo -cf /tmp/projet-92-helios-suivi
install -o root -g root -m 0440 /tmp/projet-92-helios-suivi /etc/sudoers.d/92-helios-suivi
install -o root -g root -m 0644 /tmp/projet-helios-suivi.conf /etc/zabbix/zabbix_agent2.d/helios-suivi.conf
install -d -o helios -g helios -m 0750 /srv/helios/archives
install -d -o root -g root -m 0700 /srv/helios/archives/suivi
firewall-cmd --zone=internal --add-port=8080/tcp
firewall-cmd --permanent --zone=internal --add-port=8080/tcp
restorecon -RF /srv/helios/suivi /usr/local/sbin/helios-suivi* /etc/systemd/system/helios-suivi* /etc/zabbix/zabbix_agent2.d/helios-suivi.conf
systemctl daemon-reload
systemctl enable --now helios-suivi.service helios-suivi-publish.timer helios-suivi-backup.timer
systemctl restart zabbix-agent2
curl -fsS http://127.0.0.1:8080/etat.json
systemd-analyze security --no-pager helios-suivi.service
