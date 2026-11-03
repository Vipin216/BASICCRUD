#!/bin/bash
# Launch-template user data for a public HTTPS Git repository on Amazon Linux 2023.
# Fill in these values in the launch-template editor. Never commit edited secrets.
set -Eeuo pipefail
exec > >(tee -a /var/log/notesapp-bootstrap.log | logger -t notesapp-bootstrap -s 2>/dev/console) 2>&1

APP_REPOSITORY_URL="https://github.com/Vipin216/BASICCRUD.git"
APP_GIT_REF="main"
DJANGO_SECRET_KEY="kg0u-eZOcGUnzFOJnVhVxvxi-8J-uS9Rsi1gZFXfFP4TO59T8HvAk4oG6H0FHEBy1RQ"
DJANGO_ALLOWED_HOSTS="cloud-alb-1068983986.ap-south-1.elb.amazonaws.com"
DB_NAME="postgres"
DB_USER="postgres"
DB_PASSWORD="12345678"
DB_HOST="database-1.cz8kgioai4z3.ap-south-1.rds.amazonaws.com"
DB_PORT="5432"
DB_SSLMODE="verify-full"
DB_SSLROOTCERT="/etc/ssl/certs/rds-global-bundle.pem"
APP_DIR="/opt/notesapp"
APP_USER="notesapp"

if [[ "$DJANGO_SECRET_KEY" == REPLACE_* || "$DB_PASSWORD" == REPLACE_* ]]; then
  echo "Fill in the Django secret and database password before using this user data."
  exit 1
fi

dnf install -y git python3.11 python3.11-pip curl
curl --fail --silent --show-error \
  https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem \
  --output /etc/ssl/certs/rds-global-bundle.pem
chmod 644 /etc/ssl/certs/rds-global-bundle.pem
id "$APP_USER" >/dev/null 2>&1 || useradd --system --home-dir "$APP_DIR" --shell /sbin/nologin "$APP_USER"
install -d -o "$APP_USER" -g "$APP_USER" "$APP_DIR"

runuser -u "$APP_USER" -- git clone --depth 1 --branch "$APP_GIT_REF" "$APP_REPOSITORY_URL" "$APP_DIR"
runuser -u "$APP_USER" -- python3.11 -m venv "$APP_DIR/.venv"
runuser -u "$APP_USER" -- "$APP_DIR/.venv/bin/python" -m pip install --upgrade pip
runuser -u "$APP_USER" -- "$APP_DIR/.venv/bin/pip" install -r "$APP_DIR/requirements.txt"

# Keep runtime settings in a root-owned file rather than in the application code.
umask 077
{
  printf 'DJANGO_DEBUG=0\n'
  printf 'DJANGO_SECRET_KEY=%s\n' "$DJANGO_SECRET_KEY"
  printf 'DJANGO_ALLOWED_HOSTS=%s\n' "$DJANGO_ALLOWED_HOSTS"
  printf 'DB_NAME=%s\n' "$DB_NAME"
  printf 'DB_USER=%s\n' "$DB_USER"
  printf 'DB_PASSWORD=%s\n' "$DB_PASSWORD"
  printf 'DB_HOST=%s\n' "$DB_HOST"
  printf 'DB_PORT=%s\n' "$DB_PORT"
  printf 'PGSSLMODE=%s\n' "$DB_SSLMODE"
  printf 'PGSSLROOTCERT=%s\n' "$DB_SSLROOTCERT"
} > /etc/notesapp.env
chown root:"$APP_USER" /etc/notesapp.env
chmod 640 /etc/notesapp.env

runuser -u "$APP_USER" -- bash -c \
  'set -a; . /etc/notesapp.env; set +a; /opt/notesapp/.venv/bin/python /opt/notesapp/manage.py check && /opt/notesapp/.venv/bin/python /opt/notesapp/manage.py collectstatic --noinput'

cat > /etc/systemd/system/notesapp.service <<'UNIT'
[Unit]
Description=NoteSpace Django application
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
User=notesapp
Group=notesapp
WorkingDirectory=/opt/notesapp
EnvironmentFile=/etc/notesapp.env
ExecStart=/opt/notesapp/.venv/bin/gunicorn --bind 0.0.0.0:8000 --workers 3 notes_project.wsgi:application
Restart=on-failure
RestartSec=5
PrivateTmp=true

[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload
systemctl enable --now notesapp.service
