set -euo pipefail
python3 - <<'PY'
import urllib.request,json,pathlib,time
secret=pathlib.Path('/root/.helios-zabbix.json');data=json.loads(secret.read_text());token=None
def api(method,params,auth=True):
 body={'jsonrpc':'2.0','method':method,'params':params,'id':1}
 if auth:body['auth']=token
 req=urllib.request.Request('http://127.0.0.1/zabbix/api_jsonrpc.php',json.dumps(body).encode(),{'Content-Type':'application/json-rpc'})
 with urllib.request.urlopen(req,timeout=30) as r:result=json.load(r)
 if 'error' in result:raise RuntimeError(method+': '+json.dumps(result['error']))
 return result['result']
version=api('apiinfo.version',{},False);print('Version API :',version)
try:token=api('user.login',{'username':'Admin','password':data['admin_password']},False)
except RuntimeError:
 token=api('user.login',{'username':'Admin','password':'zabbix'},False)
 api('user.update',{'userid':'1','current_passwd':'zabbix','passwd':data['admin_password']})
 token=api('user.login',{'username':'Admin','password':data['admin_password']},False)
print('Connexion API Admin reussie ; mot de passe par defaut remplace (non exporte).')
hosts=api('host.get',{'filter':{'host':['Zabbix server']},'selectInterfaces':'extend'})
if not hosts:raise RuntimeError('Hote Zabbix server absent')
h=hosts[0];hid=h['hostid']
api('host.update',{'hostid':hid,'status':0})
interface=next(i for i in h['interfaces'] if i['type']=='1')
api('hostinterface.update',{'interfaceid':interface['interfaceid'],'ip':'127.0.0.1','dns':'','useip':1,'port':'10050'})
items=[]
for key,name in [('helios.suivi.http','Helios - code HTTP du portail'),('helios.suivi.age','Helios - age du fichier etat.json')]:
 params={'hostid':hid,'name':name,'key_':key,'type':0,'value_type':3,'interfaceid':interface['interfaceid'],'delay':'10s','history':'7d','trends':'30d','status':0,'tags':[{'tag':'service','value':'helios-suivi'}]}
 if key.endswith('.age'):params['units']='s'
 existing=api('item.get',{'hostids':[hid],'filter':{'key_':[key]},'output':['itemid']})
 if existing:
  params['itemid']=existing[0]['itemid'];api('item.update',params);iid=params['itemid']
 else:iid=api('item.create',params)['itemids'][0]
 items.append({'itemid':iid,'key_':key,'delay':'10s','value_type':3});print('Element cree/configure :',key,'id='+iid)
triggers=[]
for name,expression,priority in [('Helios - portail HTTP indisponible','last(/Zabbix server/helios.suivi.http)<>200',4),('Helios - publication figee depuis plus de 5 minutes','last(/Zabbix server/helios.suivi.age)>300',3)]:
 params={'description':name,'expression':expression,'priority':priority,'status':0,'tags':[{'tag':'service','value':'helios-suivi'}]}
 existing=api('trigger.get',{'hostids':[hid],'filter':{'description':[name]},'output':['triggerid']})
 if existing:
  params['triggerid']=existing[0]['triggerid'];api('trigger.update',params);tid=params['triggerid']
 else:tid=api('trigger.create',params)['triggerids'][0]
 triggers.append({'triggerid':tid,'description':name,'expression':expression,'priority':priority});print('Declencheur cree/configure :',name,'priorite='+str(priority))
state={'hostid':hid,'host':'Zabbix server','items':items,'triggers':triggers}
pathlib.Path('/root/helios-bonus-state.json').write_text(json.dumps(state,indent=2))
export=api('configuration.export',{'options':{'hosts':[hid]},'format':'json'})
pathlib.Path('/tmp/helios-zabbix-export.json').write_text(export)
api('user.logout',[])
print('Export configuration sans identifiants : /tmp/helios-zabbix-export.json')
PY
zabbix_server -R config_cache_reload
echo '=== CONFORMITE PROJET APRES INSTALLATION DU BONUS ==='
/usr/local/sbin/helios-suivi-audit.sh
