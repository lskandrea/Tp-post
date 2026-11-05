set -euo pipefail
AUDIT=/usr/local/sbin/helios-suivi-audit.sh
WWW=/srv/helios/suivi/www
work=$(mktemp -d /var/tmp/helios-tests-audit.XXXXXXXX)
cp -a /etc/sudoers.d/92-helios-suivi "$work/sudoers"
archive=$(find /srv/helios/archives/suivi -name 'suivi-*.tar.gz' | sort | tail -1)
cp -a "$archive.sha256" "$work/empreinte"
restore() {
 cp -a "$work/sudoers" /etc/sudoers.d/92-helios-suivi
 cp -a "$work/empreinte" "$archive.sha256"
 firewall-cmd --zone=internal --add-port=8080/tcp >/dev/null
 systemctl start helios-suivi.service helios-suivi-publish.timer
 systemctl start helios-suivi-publish.service
}
trap restore EXIT
expect_ko() {
 echo "=== PANNE : $1 ==="
 if "$AUDIT"; then echo 'ERREUR audit aurait du echouer'; exit 1; else echo "Audit retourne KO comme attendu (rc=$?)"; fi
}
systemctl stop helios-suivi.service
expect_ko 'portail arrete'
systemctl start helios-suivi.service
firewall-cmd --zone=internal --remove-port=8080/tcp
expect_ko '8080 retire en runtime'
firewall-cmd --zone=internal --add-port=8080/tcp
systemctl stop helios-suivi-publish.timer
touch -d '10 minutes ago' "$WWW/etat.json"
expect_ko 'etat.json vieux de dix minutes'
systemctl start helios-suivi-publish.service helios-suivi-publish.timer
printf '\nlea ALL=(root) /usr/bin/systemctl restart sshd\n' >> /etc/sudoers.d/92-helios-suivi
expect_ko 'delegation sudo excessive'
cp -a "$work/sudoers" /etc/sudoers.d/92-helios-suivi
printf '%064d  %s\n' 0 "${archive##*/}" > "$archive.sha256"
expect_ko 'empreinte sauvegarde invalide'
cp -a "$work/empreinte" "$archive.sha256"
echo '=== RETENTION : 8 sauvegardes supplementaires ==='
for i in $(seq 8); do /usr/local/sbin/helios-suivi-backup.sh; sleep 1; done
count=$(find /srv/helios/archives/suivi -type f -name 'suivi-*.tar.gz' | wc -l)
echo "Archives conservees : $count (attendu 7)"
test "$count" -eq 7
echo '=== ETAT REPARE ==='
"$AUDIT"
trap - EXIT
