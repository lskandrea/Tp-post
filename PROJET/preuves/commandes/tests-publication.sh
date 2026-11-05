set -euo pipefail
echo '=== CODE 1 : ligne invalide dans un espace de montage isole ==='
work=$(mktemp -d /var/tmp/helios-publication.XXXXXXXX)
printf 'ceci,nest,pas,une,mesure\n' > "$work/invalide.csv"
chmod 0644 "$work/invalide.csv"
before=$(sha256sum /var/lib/helios/telemetry.csv | cut -d' ' -f1)
set +e
unshare --mount --propagation private bash -c 'mount --bind "$1" /var/lib/helios/telemetry.csv; runuser -u helios-suivi -- /usr/local/sbin/helios-suivi-publish.sh' bash "$work/invalide.csv"
rc=$?; set -e
echo "Ligne invalide rc=$rc (attendu 1)"; test "$rc" -eq 1
echo '=== CODE 3 : telemetrie illisible dans un espace isole ==='
chmod 000 "$work/invalide.csv"
set +e
unshare --mount --propagation private bash -c 'mount --bind "$1" /var/lib/helios/telemetry.csv; runuser -u helios-suivi -- /usr/local/sbin/helios-suivi-publish.sh' bash "$work/invalide.csv"
rc=$?;set -e
echo "Telemetrie illisible rc=$rc (attendu 3)";test "$rc" -eq 3
echo '=== ATOMICITE : lectures pendant 20 publications ==='
python3 - <<'PY' &
import json,time
end=time.monotonic()+5;n=0
while time.monotonic()<end:
 with open('/srv/helios/suivi/www/etat.json') as f:json.load(f)
 n+=1
print('Lectures JSON valides sans fichier partiel :',n)
PY
reader=$!
for i in $(seq 20); do runuser -u helios-suivi -- /usr/local/sbin/helios-suivi-publish.sh; done
wait "$reader"
systemctl start helios-suivi-publish.service
echo '=== UNITS VERIFIEES ==='
systemd-analyze verify /etc/systemd/system/helios-suivi*.service /etc/systemd/system/helios-suivi*.timer
echo '=== ETAT FINAL ==='
curl -fsS http://127.0.0.1:8080/etat.json
