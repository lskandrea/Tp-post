set -u
hostname
cat /etc/os-release
systemctl is-active helios-collect.service helios-watch-auth.timer
systemctl cat helios.target
firewall-cmd --get-default-zone
firewall-cmd --get-active-zones
sshd -T | grep -E '^(port|permitrootlogin|allowgroups|passwordauthentication) '
tail -3 /var/lib/helios/telemetry.csv
ls -ld /srv/helios
getfacl -p /var/lib/helios/telemetry.csv
systemctl list-unit-files 'helios*'
rpm -q zabbix-agent2 sysstat
getenforce
ls /etc/yum.repos.d
sha256sum /etc/systemd/system/helios*.service /etc/systemd/system/helios*.timer
