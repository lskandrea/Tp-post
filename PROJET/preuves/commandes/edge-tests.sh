set -u
date -Is
if curl --max-time 5 -sS -o /tmp/etat-projet.json -w 'HTTP metier = %{http_code}\n' http://10.42.0.10:8080/etat.json; then
 cat /tmp/etat-projet.json
else exit 1; fi
nc -zv -w2 192.168.56.10 8080; echo "Port admin rc=$? (attendu non nul)"
