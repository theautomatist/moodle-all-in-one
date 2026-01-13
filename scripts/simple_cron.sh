#!/bin/sh
sleep 60
echo "Run cron.php"
/usr/bin/php /var/www/html/admin/cli/cron.php >/usr/nobody/simple_cron.log
