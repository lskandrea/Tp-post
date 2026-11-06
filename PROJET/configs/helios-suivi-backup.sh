#!/bin/bash
set -Eeuo pipefail
export PATH=/usr/sbin:/usr/bin:/sbin:/bin
readonly DEST=/srv/helios/archives/suivi
tmp='' sumtmp=''
log() { logger -t helios-suivi-backup -- "$*"; }
cleanup() { test -z "$tmp" || rm -f -- "$tmp"; test -z "$sumtmp" || rm -f -- "$sumtmp"; }
trap cleanup EXIT
trap 'log "ERREUR interne ligne $LINENO"; exit 1' ERR
if [[ $EUID -ne 0 || ! -d $DEST || ! -w $DEST ]]; then log 'Prerequis manquant'; exit 3; fi
exec 9<"$DEST"
if ! flock -n 9; then log 'Sauvegarde deja en cours'; exit 2; fi
name="suivi-$(date +%Y%m%d-%H%M%S).tar.gz"
if [[ -e $DEST/$name ]]; then log 'Archive de cette seconde deja presente'; exit 2; fi
paths=(srv/helios/suivi etc/sudoers.d/92-helios-suivi etc/zabbix/zabbix_agent2.d/helios-suivi.conf usr/local/sbin/helios-suivi-publish.sh usr/local/sbin/helios-suivi-backup.sh)
for f in /etc/systemd/system/helios-suivi*.service /etc/systemd/system/helios-suivi*.timer; do paths+=("${f#/}"); done
[[ ! -f /usr/local/sbin/helios-suivi-audit.sh ]] || paths+=(usr/local/sbin/helios-suivi-audit.sh)
for f in "${paths[@]}"; do [[ -r /$f ]] || { log "Prerequis illisible : /$f"; exit 3; }; done
tmp=$(mktemp "$DEST/.archive.XXXXXXXX")
tar --acls --xattrs --selinux --numeric-owner -czf "$tmp" -C / "${paths[@]}"
sumtmp=$(mktemp "$DEST/.sha256.XXXXXXXX")
hash=$(sha256sum "$tmp"); printf '%s  %s\n' "${hash%% *}" "$name" > "$sumtmp"
mv -T "$tmp" "$DEST/$name"; tmp=''
mv -T "$sumtmp" "$DEST/$name.sha256"; sumtmp=''
(cd "$DEST"; sha256sum -c "$name.sha256")
mapfile -t old < <(find "$DEST" -maxdepth 1 -type f -name 'suivi-????????-??????.tar.gz' -printf '%f\n' | sort -r | tail -n +8)
for f in "${old[@]}"; do rm -f -- "$DEST/$f" "$DEST/$f.sha256"; done
log "Sauvegarde $name terminee, retention 7 archives"
exit 0
