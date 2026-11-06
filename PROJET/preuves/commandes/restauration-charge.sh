set -euo pipefail
export LC_ALL=C
echo '=== RESTAURATION ==='
start=$(date +%s%N)
archive=$(find /srv/helios/archives/suivi -name 'suivi-*.tar.gz' -type f | sort | tail -1)
echo "Archive : $archive"
(cd /srv/helios/archives/suivi; sha256sum -c "${archive##*/}.sha256")
testdir=$(mktemp -d /var/tmp/helios-restauration.XXXXXXXX)
echo "Extraction test : $testdir"
tar --acls --xattrs --selinux --numeric-owner -xzf "$archive" -C "$testdir"
getfacl -cp /srv/helios/suivi/www > "$testdir/acl-production"
getfacl -cp "$testdir/srv/helios/suivi/www" > "$testdir/acl-restauree"
diff -u "$testdir/acl-production" "$testdir/acl-restauree"
echo 'Comparaison ACL de www : identiques (diff rc=0)'
getfacl -p "$testdir/srv/helios/suivi/www"
getfacl -cp /srv/helios/suivi/www/index.html > "$testdir/index-acl-avant"
sha256sum /srv/helios/suivi/www/index.html
rm -- /srv/helios/suivi/www/index.html
curl -s -o /dev/null -w 'HTTP index apres suppression = %{http_code}\n' http://127.0.0.1:8080/index.html
tar --acls --xattrs --selinux --numeric-owner -xzf "$archive" -C / srv/helios/suivi/www/index.html
getfacl -cp /srv/helios/suivi/www/index.html > "$testdir/index-acl-apres"
diff -u "$testdir/index-acl-avant" "$testdir/index-acl-apres"
echo 'Comparaison ACL index restaure : identiques (diff rc=0)'
cmp /srv/helios/suivi/www/index.html "$testdir/srv/helios/suivi/www/index.html"
sha256sum /srv/helios/suivi/www/index.html
curl -s -o /dev/null -w 'HTTP index restaure = %{http_code}\n' http://127.0.0.1:8080/index.html
end=$(date +%s%N); echo "Temps restauration complet en ms : $(( (end-start)/1000000 ))"
echo '=== SUDO REEL LEA ==='
runuser -l lea -c 'sudo -k; printf "Helios-Suivi-2026\n" | sudo -S -p "" /usr/bin/systemctl status helios-suivi.service --no-pager'
echo '=== MESURE SOUS CHARGE ==='
systemctl show -p CPUUsageNSec -p MemoryCurrent helios-suivi.service
cg=$(systemctl show -p ControlGroup --value helios-suivi.service)
echo 'cpu.stat AVANT'; cat "/sys/fs/cgroup$cg/cpu.stat"
sar -u 1 30 > "$testdir/sar-charge.txt" & sar_pid=$!
t0=$(date +%s%N)
for i in $(seq 2000); do curl -s -o /dev/null http://127.0.0.1:8080/etat.json; done
t1=$(date +%s%N)
echo "2000 requetes en ms : $(( (t1-t0)/1000000 ))"
systemctl show -p CPUUsageNSec -p MemoryCurrent helios-suivi.service
echo 'cpu.stat APRES'; cat "/sys/fs/cgroup$cg/cpu.stat"
wait "$sar_pid"; cat "$testdir/sar-charge.txt"
echo '=== ECRITURES INTERDITES DANS ESPACE DU SERVEUR ==='
pid=$(systemctl show -p MainPID --value helios-suivi.service)
for path in /srv/helios/suivi/www/.test-ecriture /tmp/.test-ecriture /dev/shm/.test-ecriture; do
 if nsenter -t "$pid" -m -- runuser -u helios-suivi -- touch "$path"; then echo "ERREUR ecriture possible $path"; exit 1; else echo "Ecriture refusee : $path"; fi
done
echo '=== NON REGRESSION UNITS TP1-TP3 ==='
sha256sum /etc/systemd/system/helios-archive.service /etc/systemd/system/helios-collect.service /etc/systemd/system/helios-watch-auth.service /etc/systemd/system/helios-archive.timer /etc/systemd/system/helios-watch-auth.timer
