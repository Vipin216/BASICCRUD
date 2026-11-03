#!/bin/bash
# Launch-template user data for a public HTTPS Git repository on Amazon Linux 2023.
# Set the repository, immutable release tag, and SSM parameter name below.
set -Eeuo pipefail
exec > >(tee -a /var/log/notesapp-bootstrap.log | logger -t notesapp-bootstrap -s 2>/dev/console) 2>&1

APP_REPOSITORY_URL="REPLACE_WITH_PUBLIC_GIT_URL"
APP_GIT_REF="REPLACE_WITH_RELEASE_TAG"
RUNTIME_ENV_PARAMETER="REPLACE_WITH_SSM_SECURESTRING_NAME"
APP_DIR="/opt/notesapp"
APP_USER="notesapp"

if [[ "$APP_REPOSITORY_URL" == REPLACE_* || "$APP_GIT_REF" == REPLACE_* || "$RUNTIME_ENV_PARAMETER" == REPLACE_* ]]; then
  echo "Edit the repository URL, release ref, and SSM parameter name before using this user data."
  exit 1
fi

dnf install -y git python3.11 python3.11-pip awscli-2 curl
id "$APP_USER" >/dev/null 2>&1 || useradd --system --home-dir "$APP_DIR" --shell /sbin/nologin "$APP_USER"
install -d -o "$APP_USER" -g "$APP_USER" "$APP_DIR"

runuser -u "$APP_USER" -- git clone --depth 1 --branch "$APP_GIT_REF" "$APP_REPOSITORY_URL" "$APP_DIR"
runuser -u "$APP_USER" -- python3.11 -m venv "$APP_DIR/.venv"
runuser -u "$APP_USER" -- "$APP_DIR/.venv/bin/python" -m pip install --upgrade pip
runuser -u "$APP_USER" -- "$APP_DIR/.venv/bin/pip" install -r "$APP_DIR/requirements.txt"

# Find the instance Region without embedding it in user data.
IMDS_TOKEN="$(curl --fail --silent --show-error -X PUT \
  -H 'X-aws-ec2-metadata-token-ttl-seconds: 60' \
  http://169.254.169.254/latest/api/token)"
AWS_REGION="$(curl --fail --silent --show-error \
  -H "X-aws-ec2-metadata-token: $IMDS_TOKEN" \
  http://169.254.169.254/latest/meta-data/placement/region)"

# The SecureString value is a systemd EnvironmentFile with DJANGO_SECRET_KEY,
# DJANGO_DEBUG=0, DJANGO_ALLOWED_HOSTS, and DB_NAME/USER/PASSWORD/HOST/PORT.
umask 077
aws ssm get-parameter \
  --region "$AWS_REGION" \
  --name "$RUNTIME_ENV_PARAMETER" \
  --with-decryption \
  --query 'Parameter.Value' \
  --output text > /etc/notesapp.env
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
