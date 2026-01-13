#!/bin/sh

# Container init
MARKER_FILE="/var/www/moodledata/container-init"
MOODLE_ROOT="/var/www/html"
MOODLE_ARCHIVE="/tmp/moodle.tgz"

if [ -f "$MARKER_FILE" ] && [ -f "$MOODLE_ROOT/config.php" ]; then
  echo "=========="
  echo " S T A R T"
  echo "=========="

  echo "update moodle config.php"
  echo "-> moodle host: $MOODLE_HOST"
  echo "-> moodle port: $MOODLE_PORT"
  config_file="$MOODLE_ROOT/config.php"
  sed -i "s/\(\$CFG->wwwroot\s*=\s*'\)[^']*';/\1http:\/\/$MOODLE_HOST:$MOODLE_PORT';/" "$config_file"
  envsubst '\$MOODLE_HOST \$MOODLE_PORT' </etc/nginx/conf.d/moodle.template >/etc/nginx/conf.d/default.conf

  exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
fi

if [ -f "$MARKER_FILE" ] && [ ! -f "$MOODLE_ROOT/config.php" ]; then
  echo "Marker exists but Moodle config is missing. Re-initializing."
  rm -f "$MARKER_FILE"
fi

echo "==========================="
echo " I N I T  C O N T A I N E R"
echo "==========================="

if [ ! -f "$MOODLE_ARCHIVE" ]; then
  echo "ERROR: Moodle archive missing at $MOODLE_ARCHIVE. Rebuild the image." >&2
  exit 1
fi

/usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf &

# Datenbank- und Benutzerinformationen
DB_NAME="moodle"
DB_USER="moodle_user"
DB_PASSWORD="12345"

# Warte auf die Verfügbarkeit der Datenbank
until mysqladmin ping -u nobody; do
  echo "Warte auf die Verfügbarkeit der Datenbank..."
  sleep 5
done

# SQL-Befehle für die Datenbank-Initialisierung
SQL_COMMAND="CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASSWORD';
             CREATE DATABASE IF NOT EXISTS $DB_NAME;
             GRANT ALL PRIVILEGES ON moodle.* TO '$DB_USER'@'%' IDENTIFIED BY '$DB_PASSWORD';
             FLUSH PRIVILEGES;"

# Führe die SQL-Befehle aus
echo "$SQL_COMMAND" | mysql -u nobody

echo "Unpack moodle.tgz"
tar -zxvf "$MOODLE_ARCHIVE" -C /tmp >/dev/null 2>&1
rm "$MOODLE_ARCHIVE"
mv /tmp/moodle/* "$MOODLE_ROOT"

php "$MOODLE_ROOT/admin/cli/install.php" \
  --lang=de \
  --wwwroot="http://$MOODLE_HOST:$MOODLE_PORT" \
  --dataroot=/var/www/moodledata \
  --dbtype=mariadb \
  --dbhost=127.0.0.1 \
  --dbname="$DB_NAME" \
  --dbuser="$DB_USER" \
  --dbpass="$DB_PASSWORD" \
  --fullname=Moodle \
  --shortname=moodle \
  --adminuser=admin \
  --adminpass=12345 \
  --non-interactive \
  --agree-license

echo "update moodle config.php"
echo "-> moodle host: $MOODLE_HOST"
echo "-> moodle port: $MOODLE_PORT"
config_file="$MOODLE_ROOT/config.php"
sed -i "s/\(\$CFG->wwwroot\s*=\s*'\)[^']*';/\1http:\/\/$MOODLE_HOST:$MOODLE_PORT';/" "$config_file"
envsubst </etc/nginx/conf.d/moodle.template >/etc/nginx/conf.d/default.conf
touch "$MARKER_FILE"

echo "================="
echo " I N I T  D O N E"
echo "================="

echo "RESTARTING NOW!"
