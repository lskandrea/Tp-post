#!/bin/bash
set -Eeuo pipefail
export PATH=/usr/sbin:/usr/bin:/sbin:/bin
readonly WWW=/srv/helios/suivi/www CSV=/var/lib/helios/telemetry.csv
tmp=''
log() { logger -t helios-suivi-publish -- "$*"; }
cleanup() { test -z "$tmp" || rm -f -- "$tmp"; }
trap cleanup EXIT
trap 'log "ERREUR interne ligne $LINENO"; exit 1' ERR
if [[ ! -r $CSV || ! -d $WWW || ! -w $WWW || ! -x $WWW ]]; then
 log 'Prerequis manquant : telemetrie illisible ou www non inscriptible'; exit 3
fi
# flock sur le repertoire : aucun fichier verrou a creer hors de www.
exec 9<"$WWW"
if ! flock -n 9; then log 'Une publication est deja en cours'; exit 2; fi
tmp=$(mktemp "$WWW/.etat.XXXXXXXX")
python3 - "$CSV" "$tmp" <<'PY'
import csv,datetime,json,math,socket,sys
with open(sys.argv[1],newline='') as f:
 rows=list(csv.reader(f))
if not rows or len(rows[-1])!=3:raise ValueError('Telemetrie vide ou ligne invalide')
last=rows[-1]
datetime.datetime.fromisoformat(last[0])
load=float(last[1]); mem=int(last[2])
if not math.isfinite(load) or load<0 or mem<0:raise ValueError('Valeur de telemetrie invalide')
data=dict(genere=datetime.datetime.now(datetime.timezone.utc).isoformat(),hote=socket.gethostname(),derniere_mesure=last[0],charge_1min=load,mem_dispo_ko=mem,mesures=len(rows))
with open(sys.argv[2],'w') as f:
 json.dump(data,f,ensure_ascii=False,allow_nan=False); f.write('\n');f.flush()
 import os;os.fsync(f.fileno())
PY
chmod 0660 "$tmp"
mv -fT -- "$tmp" "$WWW/etat.json"
tmp=''
log 'Publication atomique de etat.json terminee'
exit 0
