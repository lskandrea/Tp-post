#!/bin/bash
# Audit en lecture seule : aucune reparation, aucun fichier temporaire.
set -Eeuo pipefail
export PATH=/usr/sbin:/usr/bin:/sbin:/bin
if [[ $EUID -ne 0 ]]; then echo '[KO] Audit a lancer en root'; exit 1; fi
exec python3 - <<'PY'
import subprocess as sp,os,pwd,grp,stat,json,time,glob,hashlib,tarfile,re
WWW='/srv/helios/suivi/www'
def cmd(*args):
 p=sp.run(args,stdout=sp.PIPE,stderr=sp.PIPE,text=True,timeout=25)
 if p.returncode:raise RuntimeError(' '.join(args)+': '+p.stderr.strip()[:180])
 return p.stdout.strip()
def need(v,msg):
 if not v:raise RuntimeError(msg)
def active(*units):
 for u in units:need(cmd('systemctl','is-active',u)=='active',u+' inactif')
def enabled(*units):
 for u in units:need(cmd('systemctl','is-enabled',u)=='enabled',u+' non active au boot')
def prop(unit,key):return cmd('systemctl','show','-p',key,'--value',unit)
def denied(*args):
 p=sp.run(args,stdout=sp.PIPE,stderr=sp.PIPE,text=True,timeout=15)
 need(p.returncode!=0,'Commande indument autorisee: '+' '.join(args))
def e1():
 g=grp.getgrnam('suivi'); l=pwd.getpwnam('lea'); s=pwd.getpwnam('helios-suivi')
 need(g.gr_gid==5003 and l.pw_uid==5104 and l.pw_gid==5003,'Identifiants lea/suivi')
 need(l.pw_gecos=='Lea Fabre - responsable suivi des tournees','Commentaire lea')
 need(not set(cmd('id','-nG','lea').split())&{'wheel','ssh-admins'},'Groupes lea excessifs')
 need(s.pw_uid<1000 and s.pw_shell in ('/sbin/nologin','/usr/sbin/nologin') and s.pw_dir=='/srv/helios/suivi' and not os.path.exists('/home/helios-suivi'),'Compte de service')
 shadow=next(x.split(':') for x in open('/etc/shadow') if x.startswith('lea:'))
 need(shadow[3:7]==['1','90','14','7'],'Vieillissement mot de passe')
def e2():
 s=os.stat(WWW);need(s.st_uid==0 and s.st_gid==5003 and stat.S_IMODE(s.st_mode)==0o2770,'Proprietaire/mode www')
 acl=cmd('getfacl','-cp',WWW).splitlines()
 for line in ('user:helios-suivi:rwx','user:zabbix:--x','default:user::rwx','default:user:helios-suivi:r-x','default:group::rwx','default:mask::rwx','default:other::---'):need(line in acl,'ACL absente: '+line)
 cmd('runuser','-u','helios-suivi','--','cat',WWW+'/index.html')
 need(cmd('runuser','-u','helios-suivi','--','test','-w',WWW)=='','www non inscriptible')
 cmd('runuser','-u','zabbix','--','stat',WWW+'/etat.json')
 denied('runuser','-u','zabbix','--','ls',WWW)
 need(os.stat(WWW+'/index.html').st_uid==5104,'index non cree par lea')
def e3():
 p='/usr/local/sbin/helios-suivi-publish.sh';s=os.stat(p)
 need(s.st_uid==0 and not s.st_mode&0o022,'Script publication modifiable')
 text=open(p).read()
 for marker in ('set -Eeuo pipefail','flock -n','trap cleanup EXIT','helios-suivi-publish','mv -fT'):need(marker in text,'Publication: '+marker+' absent')
 d=json.load(open(WWW+'/etat.json'))
 need(set(('genere','hote','derniere_mesure','charge_1min','mem_dispo_ko','mesures'))<=set(d),'JSON incomplet')
 need(0<=time.time()-os.stat(WWW+'/etat.json').st_mtime<300,'etat.json perime')
 need(isinstance(d['mesures'],int) and d['mesures']>0,'Nombre mesures invalide')
def e4():
 u='helios-suivi.service';active(u,'helios-suivi-publish.timer');enabled(u,'helios-suivi-publish.timer')
 for key,value in {'User':'helios-suivi','MemoryMax':'134217728','CPUQuotaPerSecUSec':'500ms','ProtectSystem':'strict','ReadWritePaths':''}.items():need(prop(u,key)==value,key+' incorrect')
 need('helios-suivi.service' in cmd('systemctl','list-dependencies','helios.target','--plain','--no-pager'),'Non rattache a helios.target')
 need(prop(u,'Restart') in ('always','on-failure'),'Pas de redemarrage')
 for path in ('/','/etat.json'):need(cmd('curl','-sS','--max-time','4','-o','/dev/null','-w','%{http_code}','http://127.0.0.1:8080'+path)=='200','HTTP '+path)
 score=cmd('systemd-analyze','security','--no-pager',u)
 m=re.search(r'Overall exposure level.*?:\s*([0-9.]+)',score);need(m and float(m[1])<=4,'Score de durcissement')
 need(prop('helios-suivi-publish.service','User')=='helios-suivi','Identite publication')
 need(prop('helios-suivi-publish.service','ReadWritePaths')==WWW,'Ecriture publication non bornee')
 need('OnUnitActiveUSec=2min' in prop('helios-suivi-publish.timer','TimersMonotonic'),'Periodicite publication')
def e5():
 cmd('visudo','-c');p='/etc/sudoers.d/92-helios-suivi';s=os.stat(p)
 need(s.st_uid==0 and s.st_gid==0 and stat.S_IMODE(s.st_mode)==0o440,'Mode sudoers')
 text=open(p).read();need('*' not in text and 'NOPASSWD' not in text,'Sudo joker/NOPASSWD')
 allowed=[['/usr/bin/systemctl','restart','helios-suivi.service'],['/usr/bin/systemctl','status','helios-suivi.service','--no-pager'],['/usr/bin/systemctl','start','helios-suivi-publish.service'],['/usr/bin/journalctl','-u','helios-suivi.service','-n','100','--no-pager'],['/usr/bin/journalctl','-u','helios-suivi-publish.service','-n','100','--no-pager']]
 for a in allowed:cmd('sudo','-l','-U','lea',*a)
 for a in (['/usr/bin/systemctl','restart','sshd'],allowed[3]+['--vacuum-time=1s'],allowed[0]+['sshd']):denied('sudo','-l','-U','lea',*a)
 need('NOPASSWD' not in cmd('sudo','-l','-U','lea'),'Delegation sans mot de passe')
def e6():
 active('firewalld');need(cmd('firewall-cmd','--get-default-zone')=='drop','Zone par defaut')
 for mode in ([],['--permanent']):
  text=cmd('firewall-cmd',*mode,'--list-all-zones')
  zones={}
  for line in text.splitlines():
   if line and not line[0].isspace():z=line.split()[0];zones[z]=[]
   elif line.strip():zones[z].append(line.strip())
  need('internal' in zones,'Zone internal absente')
  for z,lines in zones.items():
   ports=next((x.split(':',1)[1].split() for x in lines if x.startswith('ports:')),[])
   need(('8080/tcp' in ports)==(z=='internal'),'8080 dans '+z+' '+str(mode))
   if z!='internal':need(not any('8080' in x for x in lines),'Regle 8080 dans '+z)
def e7():
 conf=cmd('/usr/sbin/sshd','-T').splitlines()
 for line in ('port 2242','permitrootlogin no','passwordauthentication no','allowgroups ssh-admins'):need(line in conf,'SSH regression '+line)
 active('helios-watch-auth.timer','helios-collect.service','helios-archive.timer')
 need(os.path.isdir('/var/log/journal') and bool(glob.glob('/var/log/journal/*/*.journal')),'Journaux non persistants')
 need(cmd('getenforce')=='Enforcing','SELinux non Enforcing')
def e8():
 active('zabbix-agent2','sysstat','sysstat-collect.timer');enabled('zabbix-agent2','sysstat','sysstat-collect.timer')
 need('Server=127.0.0.1' in open('/etc/zabbix/zabbix_agent2.conf').read().splitlines(),'Server agent incorrect')
 need(cmd('zabbix_get','-s','127.0.0.1','-k','helios.suivi.http')=='200','Sonde HTTP')
 age=cmd('zabbix_get','-s','127.0.0.1','-k','helios.suivi.age');need(age.isdigit() and int(age)<300,'Sonde age: '+age)
def e9():
 s=os.stat('/srv/helios/archives');need(s.st_uid==pwd.getpwnam('helios').pw_uid and s.st_gid==grp.getgrnam('helios').gr_gid and stat.S_IMODE(s.st_mode)==0o750,'Repertoire archives')
 files=sorted(glob.glob('/srv/helios/archives/suivi/suivi-????????-??????.tar.gz'))
 need(1<=len(files)<=7,'Sauvegarde absente ou retention incorrecte')
 for p in files:
  with open(p+'.sha256') as f:parts=f.read().split()
  need(len(parts)==2 and parts[1]==os.path.basename(p),'Fichier empreinte incorrect')
  with open(p,'rb') as f:actual=hashlib.sha256(f.read()).hexdigest()
  need(parts[0]==actual,'Empreinte invalide: '+p)
 with tarfile.open(files[-1]) as t:
  names=set(t.getnames())
  for n in ('srv/helios/suivi/www/index.html','etc/sudoers.d/92-helios-suivi','etc/zabbix/zabbix_agent2.d/helios-suivi.conf','usr/local/sbin/helios-suivi-publish.sh','usr/local/sbin/helios-suivi-backup.sh','etc/systemd/system/helios-suivi.service','etc/systemd/system/helios-suivi-publish.service','etc/systemd/system/helios-suivi-publish.timer','etc/systemd/system/helios-suivi-backup.service','etc/systemd/system/helios-suivi-backup.timer'):need(n in names,'Archive incomplete: '+n)
 active('helios-suivi-backup.timer');enabled('helios-suivi-backup.timer')
 need(prop('helios-suivi-backup.timer','Persistent')=='yes','Rattrapage sauvegarde absent')
 need('03:15:00' in prop('helios-suivi-backup.timer','TimersCalendar'),'Heure sauvegarde incorrecte')
total=0
for n,fn in enumerate((e1,e2,e3,e4,e5,e6,e7,e8,e9),1):
 try:fn();print('[OK] E'+str(n));total+=1
 except Exception as e:print('[KO] E'+str(n)+' : '+str(e))
print('Bilan : '+str(total)+'/9')
raise SystemExit(0 if total==9 else 1)
PY
