#!/bin/bash

set -e

chown -R www-data:www-data /var/www /var/log/php

if [ -d "/var/lib/mysql" ]; then chown -R mysql:mysql /var/lib/mysql/; fi #ensure mysql owns it even if mounted;
if [ -d "/var/log/mysql" ]; then chown -R mysql:mysql /var/log/mysql/; fi #ensure mysql owns it even if mounted;
if [ $(find /var/lib/mysql -maxdepth 0 -type d -empty 2>/dev/null) ]; then 
    echo "###### Initializing MariaDB data dir - it was empty"
    mysql_install_db
    service mysql start
    mysql-secure-init.sh
fi

echo "###### Starting MariaDB"
service mysql start
# workaround https://serverfault.com/a/480890
mysql -u root -e "GRANT ALL PRIVILEGES ON *.* TO 'debian-sys-maint'@'localhost' IDENTIFIED BY '`sed -n '/user *= *debian-sys-main/{n;s/password *= *//;x};${x;p}' /etc/mysql/debian.cnf`';FLUSH PRIVILEGES;"

echo "###### Starting Postfix"
# workaround https://linuxconfig.org/fatal-the-postfix-mail-system-is-already-running-solution
rm -f /var/spool/postfix/pid/master.pid
/usr/sbin/postfix start

echo "###### Start php-fpm"
service php7.1-fpm start

echo "###### Start nginx"
service nginx start

echo "###### Applying config"
cp -n /tmp/config.sh /backup/ || true
/backup/config.sh
