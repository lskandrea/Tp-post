set -u
section() { printf '\n===== %s =====\n' "$*"; }
section E1
id lea; id helios-suivi; getent group suivi; getent passwd lea helios-suivi; chage -l lea
section E2
ls -ld /srv/helios/suivi/www; getfacl -p /srv/helios/suivi /srv/helios/suivi/www
su - lea -c 'umask 077; echo "preuve creation lea umask 077" > /srv/helios/suivi/www/test-lea.txt'
ls -l /srv/helios/suivi/www/index.html /srv/helios/suivi/www/test-lea.txt
getfacl -p /srv/helios/suivi/www/test-lea.txt
runuser -u helios-suivi -- cat /srv/helios/suivi/www/test-lea.txt; echo "lecture service rc=$?"
runuser -u nadia -- cat /srv/helios/suivi/www/test-lea.txt; echo "lecture nadia rc=$? (attendu 1)"
runuser -u zabbix -- ls /srv/helios/suivi/www; echo "liste zabbix rc=$? (attendu 2)"
runuser -u zabbix -- stat /srv/helios/suivi/www/etat.json; echo "stat zabbix rc=$?"
setfacl -x u:zabbix /srv/helios/suivi/www
runuser -u zabbix -- stat /srv/helios/suivi/www/etat.json; echo "stat sans ACL rc=$? (attendu 1)"
setfacl -m u:zabbix:--x /srv/helios/suivi/www
section E3
runuser -u helios-suivi -- /usr/local/sbin/helios-suivi-publish.sh; echo "publication rc=$? (attendu 0)"
flock /srv/helios/suivi/www runuser -u helios-suivi -- /usr/local/sbin/helios-suivi-publish.sh; echo "verrou rc=$? (attendu 2)"
runuser -u nadia -- /usr/local/sbin/helios-suivi-publish.sh; echo "prerequis rc=$? (attendu 3)"
python3 -m json.tool /srv/helios/suivi/www/etat.json
journalctl -t helios-suivi-publish -n 8 --no-pager
section E4
systemctl show helios-suivi.service -p User -p Group -p ExecStart -p MemoryMax -p CPUQuotaPerSecUSec -p ProtectSystem -p ReadWritePaths -p ReadOnlyPaths -p Restart -p MainPID
systemctl list-dependencies helios.target --no-pager
systemctl list-timers 'helios-suivi*' --no-pager
curl -s -o /dev/null -w 'HTTP / = %{http_code}\n' http://127.0.0.1:8080/
curl -s -o /dev/null -w 'HTTP etat = %{http_code}\n' http://127.0.0.1:8080/etat.json
pid=$(systemctl show -p MainPID --value helios-suivi.service); echo "PID avant kill -9: $pid"
kill -9 "$pid"
sleep 4
systemctl is-active helios-suivi.service
systemctl show -p MainPID -p NRestarts helios-suivi.service
curl -s -o /dev/null -w 'HTTP apres crash = %{http_code}\n' http://127.0.0.1:8080/etat.json
section E5
visudo -c
sudo -l -U lea
sudo -l -U lea /usr/bin/systemctl restart helios-suivi.service; echo "autorise rc=$?"
sudo -l -U lea /usr/bin/systemctl restart sshd; echo "sshd rc=$? (attendu 1)"
sudo -l -U lea /usr/bin/journalctl -u helios-suivi.service -n 100 --no-pager --vacuum-time=1s; echo "options en plus rc=$? (attendu 1)"
section E6
for mode in '' --permanent; do
 for zone in $(firewall-cmd $mode --get-zones); do
  echo "$mode zone=$zone"; firewall-cmd $mode --zone="$zone" --query-port=8080/tcp
  firewall-cmd $mode --zone="$zone" --list-rich-rules
 done
done
firewall-cmd --zone=internal --list-all
nft list ruleset | grep 8080
section E7
sshd -T | grep -E '^(port|permitrootlogin|passwordauthentication|allowgroups) '
systemctl is-active helios-collect.service helios-watch-auth.timer helios-archive.timer
ls -ld /var/log/journal; systemd-analyze cat-config systemd/journald.conf | grep -E 'Storage=|^# /'
getenforce
section E8
systemctl is-active zabbix-agent2 sysstat sysstat-collect.timer
systemctl is-enabled zabbix-agent2 sysstat sysstat-collect.timer
grep '^Server=' /etc/zabbix/zabbix_agent2.conf
zabbix_get -s 127.0.0.1 -k helios.suivi.http
zabbix_get -s 127.0.0.1 -k helios.suivi.age
sar -u 1 2
section E9
systemctl start helios-suivi-backup.service; echo "sauvegarde rc=$?"
ls -ld /srv/helios/archives /srv/helios/archives/suivi
ls -l /srv/helios/archives/suivi
systemctl cat helios-suivi-backup.timer
ausearch -m AVC -ts recent | tail -20
