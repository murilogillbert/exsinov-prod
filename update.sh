#!/usr/bin/env bash
# =============================================================================
# update.sh — Redeploy sem reinstalar tudo
# Rode no servidor via web console sempre que fizer push no repositório exsinov
#
#   cd /root/exsinov-prod && bash update.sh
# =============================================================================
set -euo pipefail

APP_DIR="/root/exsinov"
WEBROOT="/var/www/exsinov"

echo ""
echo "════════════════════════════════════"
echo "  Exsinov — Update / Redeploy"
echo "════════════════════════════════════"
echo ""

# ── 1. Pull do repositório ───────────────────────────────────────────────────
echo "▶ [1/4] Atualizando código..."
cd "$APP_DIR"
git pull --rebase origin main
echo "   ✓ $(git log -1 --pretty='%h %s')"

# ── 2. Dependências (só instala se package.json mudou) ───────────────────────
echo "▶ [2/4] Verificando dependências..."
npm ci --silent
echo "   ✓ Dependências ok"

# ── 3. Build de produção ─────────────────────────────────────────────────────
echo "▶ [3/4] Gerando build..."
npm run build
echo "   ✓ Build gerado"

# ── 4. Publicar e recarregar Nginx ───────────────────────────────────────────
echo "▶ [4/4] Publicando e recarregando Nginx..."
rm -rf "${WEBROOT:?}/"*
cp -r "$APP_DIR/dist/." "$WEBROOT/"
chown -R www-data:www-data "$WEBROOT"
nginx -t && systemctl reload nginx
echo "   ✓ Nginx recarregado"

echo ""
echo "════════════════════════════════════"
echo "  ✅ Site atualizado!"
echo "  🌐 https://exsinov.com"
echo "  📦 $(git -C "$APP_DIR" log -1 --pretty='Commit: %h — %s')"
echo "════════════════════════════════════"
echo ""
