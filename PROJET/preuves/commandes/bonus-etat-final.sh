set -euo pipefail
echo '=== SERVICES ET DEMARRAGE AUTOMATIQUE ==='
date -Is
systemctl is-active mariadb zabbix-server httpd php-fpm zabbix-agent2 helios-suivi.service helios-suivi-publish.timer
systemctl is-enabled mariadb zabbix-server httpd php-fpm
echo '=== FRONTEND ADMINISTRATION ==='
curl --max-time 10 -s -o /dev/null -w 'Frontend admin = %{http_code}\n' http://192.168.56.10/zabbix/index.php
ss -lnt | grep -E ':80 |:10051 '
firewall-cmd --zone=work --list-services
firewall-cmd --permanent --zone=work --list-services
echo '=== SELINUX ==='
getenforce
getsebool httpd_can_connect_zabbix httpd_can_network_connect_db
ausearch -m AVC -ts recent | tail -20 || true
echo '=== SAUVEGARDE ET AUDIT ==='
systemctl start helios-suivi-backup.service
/usr/local/sbin/helios-suivi-audit.sh
