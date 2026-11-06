set -euo pipefail
python3 -u - <<'PY'
import urllib.request,json,pathlib,time,subprocess,datetime
secret=json.loads(pathlib.Path('/root/.helios-zabbix.json').read_text());token=None
state=json.loads(pathlib.Path('/root/helios-bonus-state.json').read_text());tids=[x['triggerid'] for x in state['triggers']];iids=[x['itemid'] for x in state['items']]
def api(method,params,auth=True):
 body={'jsonrpc':'2.0','method':method,'params':params,'id':1}
 if auth:body['auth']=token
 req=urllib.request.Request('http://127.0.0.1/zabbix/api_jsonrpc.php',json.dumps(body).encode(),{'Content-Type':'application/json-rpc'})
 with urllib.request.urlopen(req,timeout=15) as r:d=json.load(r)
 if 'error' in d:raise RuntimeError(method+': '+str(d['error']))
 return d['result']
def cmd(*args):subprocess.run(args,check=True)
def snap(label):
 items=api('item.get',{'itemids':iids,'output':['itemid','key_','lastvalue','lastclock','state','error']})
 triggers=api('trigger.get',{'triggerids':tids,'output':['triggerid','description','priority','value','lastchange']})
 print('\n=== '+label+' '+datetime.datetime.now().astimezone().isoformat()+' ===',flush=True)
 print(json.dumps({'items':items,'triggers':triggers},ensure_ascii=False,indent=2),flush=True)
 return items,triggers
def wait_trigger(index,wanted,timeout=180):
 end=time.monotonic()+timeout
 while time.monotonic()<end:
  t=api('trigger.get',{'triggerids':[tids[index]],'output':['value']})
  if t and t[0]['value']==str(wanted):return
  time.sleep(5)
 raise RuntimeError('Declencheur '+str(index)+' ne passe pas a '+str(wanted))
token=api('user.login',{'username':'Admin','password':secret['admin_password']},False)
start=int(time.time())
try:
 end=time.monotonic()+160
 while time.monotonic()<end:
  items=api('item.get',{'itemids':iids,'output':['key_','lastvalue','lastclock','state','error']})
  if len(items)==2 and all(x['lastclock']!='0' and x['state']=='0' for x in items):break
  time.sleep(5)
 else:raise RuntimeError('Valeurs initiales non collectees : '+str(items))
 snap('ETAT INITIAL')
 cmd('systemctl','stop','helios-suivi.service')
 wait_trigger(0,1)
 snap('PANNE REELLE HTTP : alerte Haute active')
 time.sleep(45)
 cmd('systemctl','start','helios-suivi.service')
 wait_trigger(0,0)
 snap('HTTP RETABLI')
 cmd('systemctl','start','helios-suivi-publish.service')
 cmd('systemctl','stop','helios-suivi-publish.timer')
 print('Timer arrete ; attente reelle de plus de 300 secondes, sans modifier la date du fichier.',flush=True)
 wait_trigger(1,1,timeout=390)
 snap('PANNE REELLE PUBLICATION : alerte Moyenne active')
 time.sleep(45)
 cmd('systemctl','start','helios-suivi-publish.service','helios-suivi-publish.timer')
 wait_trigger(1,0)
 snap('PUBLICATION RETABLIE')
 events=api('event.get',{'objectids':tids,'time_from':start,'output':['eventid','objectid','clock','value','name','severity'],'sortfield':['clock'],'sortorder':'ASC'})
 print('\n=== EVENEMENTS ZABBIX REELS ===\n'+json.dumps(events,ensure_ascii=False,indent=2),flush=True)
 for i in tids:
  ev=[e for e in events if e['objectid']==i]
  if not any(e['value']=='1' for e in ev) or not any(e['value']=='0' for e in ev):raise RuntimeError('Evenements probleme/retablissement incomplets '+i)
 print('Deux problemes et leurs retablissements verifies dans les evenements du serveur.',flush=True)
finally:
 cmd('systemctl','start','helios-suivi.service','helios-suivi-publish.timer')
 cmd('systemctl','start','helios-suivi-publish.service')
 if token:
  try:api('user.logout',[])
  except Exception:pass
PY
echo '=== AUDIT FINAL APRES BONUS ==='
/usr/local/sbin/helios-suivi-audit.sh
