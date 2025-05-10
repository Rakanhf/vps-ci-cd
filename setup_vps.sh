#!/usr/bin/env bash
# setup_vps.sh — run as root on Ubuntu 20.04+
set -euo pipefail

DEPLOY_USER=${1:-deployer}
REPO_DIR=${2:-/home/$DEPLOY_USER/app}
KEY_COMMENT=${3:-actions@$(hostname)}
KEY_NAME="actions-to-vps"
KEY_PATH="/home/$DEPLOY_USER/.ssh/$KEY_NAME"

echo "→ 1. Create deploy user [$DEPLOY_USER] if it doesn't exist"
if ! id -u "$DEPLOY_USER" &>/dev/null; then
  adduser --disabled-password --gecos "" "$DEPLOY_USER"
fi

echo "→ 2. Add $DEPLOY_USER to sudo and docker groups"
usermod -aG sudo,docker "$DEPLOY_USER"

echo "→ 3. Install & configure OpenSSH + UFW"
apt update
apt install -y openssh-server ufw
# disable root & password auth, enable key auth
sed -i 's/^#PermitRootLogin .*/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/^#PasswordAuthentication .*/PasswordAuthentication no/' /etc/ssh/sshd_config
systemctl reload ssh
ufw allow OpenSSH
ufw allow 80,443/tcp
ufw --force enable

echo "→ 4. Install Docker & Compose plugin"
curl -fsSL https://get.docker.com | sh
apt install -y docker-compose-plugin

echo "→ 5. Prepare .ssh for $DEPLOY_USER"
sudo -u "$DEPLOY_USER" mkdir -p "/home/$DEPLOY_USER/.ssh"
sudo -u "$DEPLOY_USER" chmod 700 "/home/$DEPLOY_USER/.ssh"

echo "→ 6. Generate Actions→VPS SSH keypair"
sudo -u "$DEPLOY_USER" ssh-keygen -t ed25519 \
  -C "$KEY_COMMENT" \
  -f "$KEY_PATH" -N "" \
  >/dev/null

echo
echo "===== COPY THIS PRIVATE KEY INTO GITHUB SECRET 'VPS_SSH_KEY' ====="
cat "$KEY_PATH"
echo "===== END PRIVATE KEY ====="
echo

echo "→ 7. Authorize Actions key for $DEPLOY_USER"
cat "${KEY_PATH}.pub" >> "/home/$DEPLOY_USER/.ssh/authorized_keys"
chown "$DEPLOY_USER:$DEPLOY_USER" "/home/$DEPLOY_USER/.ssh/authorized_keys"
chmod 600 "/home/$DEPLOY_USER/.ssh/authorized_keys"

echo "→ 8. Create application directory $REPO_DIR"
mkdir -p "$REPO_DIR"
chown -R "$DEPLOY_USER:$DEPLOY_USER" "$REPO_DIR"

echo
echo "✅  Provisioning complete!"
echo "Your application dir is: $REPO_DIR"
echo "You can now add the above private key to GitHub Secrets (VPS_SSH_KEY),"
echo "set VPS_HOST, VPS_USER=$DEPLOY_USER and REMOTE_APP_PATH=$REPO_DIR,"
echo "and run your GitHub Actions deploy."
