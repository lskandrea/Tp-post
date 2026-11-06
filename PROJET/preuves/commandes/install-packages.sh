set -euo pipefail
rpm -q zabbix-release || rpm -Uvh https://repo.zabbix.com/zabbix/7.0/rocky/9/x86_64/zabbix-release-latest-7.0.el9.noarch.rpm
if test -f /etc/yum.repos.d/epel.repo; then
 python3 - <<'PY'
import configparser
p='/etc/yum.repos.d/epel.repo'
c=configparser.ConfigParser(interpolation=None); c.read(p)
for s in c.sections():
 old=c.get(s,'excludepkgs',fallback='')
 if 'zabbix*' not in old:c.set(s,'excludepkgs',(old+' zabbix*').strip())
with open(p,'w') as f:c.write(f)
PY
fi
dnf install -y zabbix-agent2 zabbix-get sysstat acl policycoreutils-python-utils
systemctl enable --now zabbix-agent2 sysstat sysstat-collect.timer
rpm -q zabbix-agent2 zabbix-get sysstat
getent passwd zabbix
