# VPS Provisioning & CI/CD Deployment

This guide walks you through:

1. Provisioning a fresh Hetzner (Ubuntu) VPS  
2. Generating an SSH key for GitHub Actions → VPS  
3. Installing Docker & Docker Compose  
4. Creating your app directory  
5. Wiring up GitHub Actions to deploy via SSH and Docker Compose  

---

## 1. Run the provisioning script

_On your VPS as `root`:_

```bash
# Upload the script (either via scp or direct paste):
cat > /root/setup_vps.sh <<'EOF'
$(sed 's/^/    /' <<EOF
$script_content
EOF
)
EOF

chmod +x /root/setup_vps.sh
/root/setup_vps.sh
```

- At the end it will **print** a new private key.  
- **Copy** everything between the `COPY THIS PRIVATE KEY` markers.

---

## 2. Add GitHub Secrets

Go to **YourRepo → Settings → Secrets and Variables → Actions** and add:

- `VPS_HOST` = your VPS IP or hostname  
- `VPS_USER` = the deploy user (default: `deployer`)  
- `VPS_SSH_KEY` = *paste the private key* from step 1  
- `VPS_SSH_PASSPHRASE` = leave blank (we generated with no passphrase)  
- `REMOTE_APP_PATH` = `/home/deployer/{APP-DIR}`  

---

## 3. Verify access

From your local machine:

```bash
ssh -i actions-to-vps deployer@your.vps.ip docker compose version
```

You should see Docker Compose’s version output without a password prompt.

---

## 4. Prepare your project on the VPS

Your GitHub Actions will SSH into `$REMOTE_APP_PATH` and deploy files.  
You don’t need to `git clone` on the VPS.

Ensure that your workflow copies:

- `docker-compose.local.yml`  
- `docker-compose.prod.yml`  
- `Dockerfile`  
- `app/` (your code)  
- `Caddyfile` and `Caddyfile.local`  
- `config/.env.prod` or `.env.local`  

into `$REMOTE_APP_PATH`.

---

## 5. GitHub Actions snippet

Key job in your `.github/workflows/main.yml`:

```yaml
vps-deploy:
  if: github.ref == 'refs/heads/vps-test'
  name: 🚀 Deploy to VPS Test Environment
  runs-on: ubuntu-latest
  steps:
    - name: 🚚 Checkout code
      uses: actions/checkout@v3

    - name: 📁 Copy entire repo to VPS via SFTP
      uses: appleboy/scp-action@v0.1.0
      with:
        host: ${{ secrets.VPS_HOST }}
        username: ${{ secrets.VPS_USER }}
        key: ${{ secrets.VPS_SSH_KEY }}
        passphrase: ${{ secrets.VPS_SSH_PASSPHRASE }}
        port: 22
        source: "."                    # <-- copy everything
        target: ${{ secrets.REMOTE_APP_PATH }}
        recursive: true

    - name: 🔑 SSH & rebuild on VPS
      uses: appleboy/ssh-action@master
      with:
        host: ${{ secrets.VPS_HOST }}
        username: ${{ secrets.VPS_USER }}
        key: ${{ secrets.VPS_SSH_KEY }}
        passphrase: ${{ secrets.VPS_SSH_PASSPHRASE }}
        port: 22
        script: |
          set -e
          cd ${{ secrets.REMOTE_APP_PATH }}
          echo "⏳ Pulling latest images & rebuilding with prod compose…"
          docker compose -f docker-compose.prod.yml pull
          docker compose -f docker-compose.prod.yml up -d --build
```

---

## 6. Next steps

- Push to your `vps-test` branch → watch the CI deploy automatically.  
- Merge to `main` (or `staging`) to trigger other environments.  
- Enjoy zero-downtime, GitHub-driven deployments!

  Note :
  SSH into the vps using `ssh root@<VPS-IP>` and use the password set for the vps
