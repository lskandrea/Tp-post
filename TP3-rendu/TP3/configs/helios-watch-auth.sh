#!/usr/bin/bash
# Compte les connexions SSH en echec sur dix minutes et bloque au-dela de cinq.
set -euo pipefail
export LC_ALL=C PATH=/usr/sbin:/usr/bin:/sbin:/bin
readonly TAG=helios-watch-auth IPSET=helios-blacklist
readonly STATE_DIR=/var/lib/helios-watch-auth
readonly WINDOW=10 THRESHOLD=5
readonly -a WHITELIST=(192.168.56.1)
log() { logger -t "$TAG" -- "$*"; }
exec 9>/run/lock/helios-watch-auth.lock
if ! flock -n 9; then log 'Une instance est deja en cours (rc=2).'; exit 2; fi
trap 'rc=$?; log "Erreur ligne $LINENO (rc=$rc)."; exit "$rc"' ERR
firewall-cmd --state >/dev/null
firewall-cmd --get-ipsets | tr ' ' '\n' | grep -qx "$IPSET"
install -d -m 0700 "$STATE_DIR"
work=$(mktemp -d /run/helios-watch-auth.XXXXXX)
trap 'rm -rf -- "$work"' EXIT
journalctl -u sshd.service --since "-${WINDOW} minutes" --no-pager -o json > "$work/events.json"
python3 - "$work/events.json" > "$work/counts" <<'PY'
import collections, ipaddress, json, re, sys
connections=collections.defaultdict(set)
pattern=re.compile(r'(?:Invalid user \S+|Failed (?:password|publickey|keyboard-interactive/pam) for (?:invalid user )?\S+) from (\S+)')
for line in open(sys.argv[1],encoding='utf-8'):
    try:
        event=json.loads(line)
        match=pattern.search(event.get('MESSAGE',''))
        if not match: continue
        address=ipaddress.ip_address(match.group(1))
        if address.version!=4: continue
        # Ne pas compter deux fois Invalid user puis Failed pour la meme connexion.
        connections[str(address)].add((event.get('_BOOT_ID'),event.get('_PID')))
    except (ValueError,TypeError): continue
for address,ids in sorted(connections.items()): print(address,len(ids))
PY
blocked=0
while read -r ip count; do
 [ "$count" -gt "$THRESHOLD" ] || continue
 allowed=no
 for good in "${WHITELIST[@]}"; do [ "$ip" != "$good" ] || allowed=yes; done
 if [ "$allowed" = yes ]; then continue; fi
 if firewall-cmd --ipset="$IPSET" --query-entry="$ip" >/dev/null; then continue; fi
 firewall-cmd --ipset="$IPSET" --add-entry="$ip" >/dev/null
 firewall-cmd --permanent --ipset="$IPSET" --add-entry="$ip" >/dev/null
 printf '%s %s %s\n' "$(date --iso-8601=seconds)" "$ip" "$count" >> "$STATE_DIR/blocked.txt"
 chmod 0600 "$STATE_DIR/blocked.txt"
 log "BLOCAGE source=$ip echecs=$count fenetre=${WINDOW}min seuil=$THRESHOLD"
 blocked=$((blocked+1))
done < "$work/counts"
log "Controle termine nouveaux_blocages=$blocked fenetre=${WINDOW}min"
exit 0
