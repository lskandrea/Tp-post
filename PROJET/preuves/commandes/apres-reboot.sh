set -euo pipefail
date -Is
uptime
who -b
systemctl is-active helios-collect.service helios-archive.timer helios-watch-auth.timer helios-suivi.service helios-suivi-publish.timer helios-suivi-backup.timer zabbix-agent2 sysstat-collect.timer
systemctl show helios-suivi.service -p ReadOnlyPaths -p ProtectSystem -p MemoryMax -p CPUQuotaPerSecUSec -p User
curl -fsS http://127.0.0.1:8080/etat.json
echo
zabbix_get -s 127.0.0.1 -k helios.suivi.http
zabbix_get -s 127.0.0.1 -k helios.suivi.age
firewall-cmd --zone=internal --query-port=8080/tcp
firewall-cmd --permanent --zone=internal --query-port=8080/tcp
getenforce
/usr/local/sbin/helios-suivi-audit.sh
echo '=== EMPREINTES UNITS PRECEDENTES ==='
sha256sum /etc/systemd/system/helios-archive.service /etc/systemd/system/helios-collect.service /etc/systemd/system/helios-watch-auth.service /etc/systemd/system/helios-archive.timer /etc/systemd/system/helios-watch-auth.timer
