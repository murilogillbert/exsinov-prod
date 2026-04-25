#!/usr/bin/env bash
# =============================================================================
# setup.sh — Exsinov Production Server
# Ubuntu 22.04 LTS | Digital Ocean Droplet
#
# Execute UMA VEZ no servidor via web console:
#   cd /root/exsinov-prod && bash setup.sh
# =============================================================================
set -euo pipefail

WEBROOT="/var/www/exsinov"
NGINX_CONF="/etc/nginx/sites-available/exsinov"
APP_DIR="/root/exsinov"
REPO_URL="https://github.com/murilogillbert/exsinov.git"

echo ""
echo "════════════════════════════════════════"
echo "  Exsinov — Server Setup"
echo "  Ubuntu 22.04 LTS"
echo "════════════════════════════════════════"
echo ""

# ── 1. Atualiza o sistema ────────────────────────────────────────────────────
echo "▶ [1/9] Atualizando sistema..."
apt-get update -qq
apt-get upgrade -y -qq
apt-get install -y -qq \
    curl git unzip ufw fail2ban \
    nginx \
    ca-certificates gnupg lsb-release

# ── 2. Node.js 20 LTS ────────────────────────────────────────────────────────
echo "▶ [2/9] Instalando Node.js 20 LTS..."
curl -fsSL https://deb.nodesource.com/setup_20.x | bash - > /dev/null
apt-get install -y -qq nodejs
echo "   node $(node -v) | npm $(npm -v)"

# ── 3. Firewall (UFW) ────────────────────────────────────────────────────────
echo "▶ [3/9] Configurando firewall..."
ufw default deny incoming  > /dev/null
ufw default allow outgoing > /dev/null
ufw allow 22/tcp           > /dev/null
ufw --force enable         > /dev/null
ufw status

# ── 4. Fail2ban ──────────────────────────────────────────────────────────────
echo "▶ [4/9] Ativando Fail2ban..."
systemctl enable --now fail2ban > /dev/null

# ── 5. Clonar repositório exsinov e fazer build ──────────────────────────────
echo "▶ [5/9] Clonando $REPO_URL..."
if [ -d "$APP_DIR" ]; then
    echo "   Repositório já existe — atualizando..."
    cd "$APP_DIR" && git pull --rebase
else
    git clone "$REPO_URL" "$APP_DIR"
fi

echo "▶ [5/9] Instalando dependências e gerando build..."
cd "$APP_DIR"
npm ci --silent
npm run build
echo "   ✓ Build gerado em $APP_DIR/dist"

# ── 6. Copiar build para o webroot ───────────────────────────────────────────
echo "▶ [6/9] Publicando arquivos em $WEBROOT..."
mkdir -p "$WEBROOT"
cp -r "$APP_DIR/dist/." "$WEBROOT/"
chown -R www-data:www-data "$WEBROOT"
chmod -R 755 "$WEBROOT"

# ── 7. Nginx ─────────────────────────────────────────────────────────────────
echo "▶ [7/9] Configurando Nginx..."
cp "$(dirname "$0")/nginx/exsinov.conf" "$NGINX_CONF"
ln -sf "$NGINX_CONF" /etc/nginx/sites-enabled/exsinov
rm -f /etc/nginx/sites-enabled/default

nginx -t
systemctl enable nginx > /dev/null
systemctl restart nginx
echo "   ✓ Nginx rodando"

# ── 8. Cloudflare Tunnel (cloudflared) ───────────────────────────────────────
echo "▶ [8/9] Instalando cloudflared..."
curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg \
    | gpg --dearmor -o /usr/share/keyrings/cloudflare-main.gpg
echo "deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] \
    https://pkg.cloudflare.com/cloudflared $(lsb_release -cs) main" \
    | tee /etc/apt/sources.list.d/cloudflared.list > /dev/null
apt-get update -qq
apt-get install -y -qq cloudflared
echo "   ✓ $(cloudflared --version)"

# ── 9. Resultado ─────────────────────────────────────────────────────────────
echo ""
echo "════════════════════════════════════════"
echo "  ✅ Setup concluído!"
echo ""
echo "  Nginx servindo:  http://localhost"
echo "  Arquivos em:     $WEBROOT"
echo "  Código fonte:    $APP_DIR"
echo ""
echo "  Próximo passo → configure o Cloudflare Tunnel"
echo "  Siga o README.md — Seção 3"
echo "════════════════════════════════════════"
echo ""
