# Exsinov — Infraestrutura de Produção

Stack: **Digital Ocean Droplet** → **Ubuntu 22.04** → **Nginx** → **Cloudflare Tunnel** → **exsinov.com**

```
Usuário
   │ HTTPS
   ▼
Cloudflare Edge  (SSL/TLS, DDoS, Cache)
   │ Tunnel criptografado
   ▼
cloudflared daemon  (rodando no Droplet)
   │ HTTP
   ▼
Nginx  localhost:80
   │
   ▼
/var/www/exsinov  ← build gerado a partir de github.com/murilogillbert/exsinov
```

### Fluxo de deploy

```
[Você] git push → github.com/murilogillbert/exsinov
                         │
                         ▼
             [Web Console do Droplet]
             bash update.sh
             → git pull exsinov
             → npm build
             → copia dist/ para /var/www/exsinov
             → nginx reload
```

---

## Seção 1 — Criar o Droplet no Digital Ocean

### Passo 1 — Criar conta / login
Acesse [cloud.digitalocean.com](https://cloud.digitalocean.com).

### Passo 2 — Criar novo Droplet
1. **Create → Droplets**
2. Região: **São Paulo (sao1)**
3. Imagem: **Ubuntu 22.04 LTS (x64)**
4. Plano: **Basic · Regular · 1 GB RAM · 1 vCPU · 25 GB SSD · $6/mês**

### Passo 3 — Autenticação por Senha
1. Em **Authentication** selecione **Password**
2. Defina uma senha forte (guarde bem — usada em todo acesso)
3. Em **Hostname**: `exsinov-prod`
4. Clique em **Create Droplet**
5. Anote o **IP público**: `206.81.11.63`

---

## Seção 2 — Setup inicial (via Web Console)

No painel do Digital Ocean, clique em **Console** (ícone de terminal no droplet).

### Passo 1 — Clonar este repositório no servidor

```bash
cd /root
git clone https://github.com/murilogillbert/exsinov-prod.git
cd exsinov-prod
```

### Passo 2 — Rodar o setup

```bash
bash setup.sh
```

O script faz automaticamente:
- ✅ Atualiza o sistema
- ✅ Instala Nginx, Node.js 20, Git, UFW, Fail2ban, cloudflared
- ✅ Clona `github.com/murilogillbert/exsinov`
- ✅ Roda `npm ci && npm run build`
- ✅ Copia o `dist/` para `/var/www/exsinov/`
- ✅ Configura e inicia o Nginx
- ✅ Instala o cloudflared

---

## Seção 3 — Configurar o Cloudflare Tunnel (via Web Console)

> **Pré-requisito:** `exsinov.com` com nameservers apontando para o Cloudflare.
> Em [dash.cloudflare.com](https://dash.cloudflare.com) → Add a domain → siga o fluxo → troque os nameservers no seu registrador.

### Passo 1 — Autenticar

```bash
cloudflared tunnel login
```
Copie a URL que aparecer → abra no navegador → selecione `exsinov.com` → autorize.

### Passo 2 — Criar o Tunnel

```bash
cloudflared tunnel create exsinov
```
Anote o **TUNNEL_ID** (UUID longo exibido na saída).

### Passo 3 — Editar o config.yml

```bash
nano /root/exsinov-prod/cloudflared/config.yml
```

Substitua `TUNNEL_ID` (2 ocorrências) pelo UUID real. Exemplo:
```yaml
tunnel: a1b2c3d4-e5f6-7890-abcd-ef1234567890
credentials-file: /root/.cloudflared/a1b2c3d4-e5f6-7890-abcd-ef1234567890.json
```
Salve: `Ctrl+O` → `Enter` → `Ctrl+X`

```bash
cp /root/exsinov-prod/cloudflared/config.yml /root/.cloudflared/config.yml
```

### Passo 4 — Criar registros DNS

```bash
cloudflared tunnel route dns exsinov exsinov.com
cloudflared tunnel route dns exsinov www.exsinov.com
```

### Passo 5 — Ativar como serviço

```bash
cloudflared service install
systemctl enable cloudflared
systemctl start cloudflared
systemctl status cloudflared
# → Active: active (running) ✅
```

---

## Seção 4 — Verificar

```bash
# Nginx respondendo localmente?
curl -I http://localhost
# → HTTP/1.1 200 OK ✅

# Tunnel ativo?
systemctl status cloudflared

# Logs do tunnel
journalctl -u cloudflared -f
```

Abra **https://exsinov.com** no navegador → site carregando com cadeado 🔒

---

## Seção 5 — Deploy de atualizações

Sempre que fizer push no `exsinov`, rode no **web console**:

```bash
cd /root/exsinov-prod && bash update.sh
```

O `update.sh` faz:
1. `git pull` no repositório `exsinov`
2. `npm ci && npm run build`
3. Copia o novo `dist/` para `/var/www/exsinov/`
4. `nginx reload`

---

## Estrutura dos repositórios

```
github.com/murilogillbert/exsinov        ← código-fonte (React + TS)
github.com/murilogillbert/exsinov-prod   ← infraestrutura (este repo)
```

```
exsinov-prod/
├── README.md               ← Este guia
├── setup.sh                ← Setup inicial (rodar 1× no droplet)
├── update.sh               ← Redeploy após git push no exsinov
├── nginx/
│   └── exsinov.conf        ← Configuração do Nginx
└── cloudflared/
    └── config.yml          ← Configuração do Cloudflare Tunnel
```

---

## Comandos úteis no servidor

```bash
# Atualizar o site após push
cd /root/exsinov-prod && bash update.sh

# Status dos serviços
systemctl status nginx
systemctl status cloudflared

# Logs
tail -f /var/log/nginx/exsinov.access.log
journalctl -u cloudflared -f

# Reiniciar serviços
systemctl restart nginx
systemctl restart cloudflared

# Ver arquivos publicados
ls -la /var/www/exsinov/
```

---

## Arquitetura de segurança

| Camada | Proteção |
|---|---|
| Cloudflare | DDoS, WAF, SSL/TLS automático |
| UFW | Somente porta 22 aberta ao mundo |
| Fail2ban | Bloqueia IPs com tentativas SSH repetidas |
| Tunnel | Servidor não expõe 80/443 publicamente |
| Nginx | Headers de segurança (X-Frame, nosniff, etc.) |
