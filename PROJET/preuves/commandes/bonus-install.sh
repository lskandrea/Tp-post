set -euo pipefail
export LC_ALL=C
echo '=== INSTALLATION BONUS ZABBIX ==='
dnf install -y mariadb-server zabbix-server-mysql zabbix-web-mysql zabbix-apache-conf zabbix-sql-scripts zabbix-selinux-policy
systemctl enable --now mariadb
python3 - <<'PY'
import secrets,json,pathlib,os,subprocess
p=pathlib.Path('/root/.helios-zabbix.json')
if not p.exists():
 data={'db_password':secrets.token_hex(24),'admin_password':secrets.token_urlsafe(24)}
 fd=os.open(str(p),os.O_WRONLY|os.O_CREAT|os.O_EXCL,0o600)
 with os.fdopen(fd,'w') as f:json.dump(data,f)
d=json.loads(p.read_text());pw=d['db_password']
sql="CREATE DATABASE IF NOT EXISTS zabbix CHARACTER SET utf8mb4 COLLATE utf8mb4_bin; CREATE USER IF NOT EXISTS 'zabbix'@'localhost' IDENTIFIED BY '"+pw+"'; GRANT ALL PRIVILEGES ON zabbix.* TO 'zabbix'@'localhost'; SET GLOBAL log_bin_trust_function_creators=1;"
subprocess.run(['mariadb'],input=sql,text=True,check=True)
conf=pathlib.Path('/etc/zabbix/zabbix_server.conf')
lines=conf.read_text().splitlines()
for key,value in [('DBPassword',pw),('ListenIP','127.0.0.1'),('CacheSize','32M')]:
 lines=[l for l in lines if not l.startswith(key+'=')];lines.append(key+'='+value)
conf.write_text('\n'.join(lines)+'\n')
web=pathlib.Path('/etc/zabbix/web/zabbix.conf.php')
web.write_text("<?php\n$DB['TYPE']='MYSQL';\n$DB['SERVER']='localhost';\n$DB['PORT']='0';\n$DB['DATABASE']='zabbix';\n$DB['USER']='zabbix';\n$DB['PASSWORD']='"+pw+"';\n$DB['SCHEMA']='';\n$ZBX_SERVER='127.0.0.1';\n$ZBX_SERVER_PORT='10051';\n$ZBX_SERVER_NAME='Helios - suivi des tournees';\n$IMAGE_FORMAT_DEFAULT=IMAGE_FORMAT_PNG;\n")
os.chmod(str(web),0o640)
import shutil;shutil.chown(str(web),user='apache',group='apache')
PY
tables=$(mariadb -N -e "SELECT count(*) FROM information_schema.tables WHERE table_schema='zabbix' AND table_name='users'")
if test "$tables" -eq 0; then zcat /usr/share/zabbix-sql-scripts/mysql/server.sql.gz | mariadb --default-character-set=utf8mb4 zabbix; fi
mariadb -e 'SET GLOBAL log_bin_trust_function_creators=0;'
python3 - <<'PY'
import pathlib,re
p=pathlib.Path('/etc/httpd/conf/httpd.conf');t=p.read_text()
t=re.sub(r'^Listen\s+.*$', 'Listen 127.0.0.1:80\nListen 192.168.56.10:80',t,flags=re.M)
p.write_text(t)
p=pathlib.Path('/etc/php-fpm.d/zabbix.conf');t=p.read_text()
t=re.sub(r'^;?\s*php_value\[date.timezone\].*$', 'php_value[date.timezone] = Europe/Paris',t,flags=re.M)
p.write_text(t)
PY
setsebool -P httpd_can_connect_zabbix on
setsebool -P httpd_can_network_connect_db on
restorecon -Rv /etc/zabbix/web
apachectl configtest
systemctl enable --now zabbix-server httpd php-fpm
firewall-cmd --zone=work --add-service=http
firewall-cmd --permanent --zone=work --add-service=http
echo '=== ETAT DES SERVICES ==='
systemctl is-active mariadb zabbix-server httpd php-fpm
systemctl is-enabled mariadb zabbix-server httpd php-fpm
curl --max-time 10 -s -o /dev/null -w 'Frontend HTTP = %{http_code}\n' http://127.0.0.1/zabbix/index.php
ss -lnt | grep -E ':80 |:10051 '
getenforce
