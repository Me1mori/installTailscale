#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
#  instalar_tailscale.sh — Instalador de Tailscale para todas las distros Linux
#  Uso: bash instalar_tailscale.sh
# ══════════════════════════════════════════════════════════════════════════════

set -e

# ── Colores ───────────────────────────────────────────────────────────────────
R='\033[0;31m'  G='\033[0;32m'  Y='\033[0;33m'
C='\033[0;36m'  W='\033[1;37m'  D='\033[2;37m'  NC='\033[0m'

ok()   { echo -e "  ${G}✔${NC}  $*"; }
err()  { echo -e "  ${R}✗${NC}  $*"; }
info() { echo -e "  ${Y}▸${NC}  $*"; }
dim()  { echo -e "  ${D}$*${NC}"; }

# ── Banner ────────────────────────────────────────────────────────────────────
clear
echo
echo -e "${W}  ╔══════════════════════════════════════════════╗${NC}"
echo -e "${W}  ║       ${C}🔒 Instalador de Tailscale${W}             ║${NC}"
echo -e "${W}  ╚══════════════════════════════════════════════╝${NC}"
echo

# ── Verificar que no sea root directo ────────────────────────────────────────
if [ "$EUID" -eq 0 ]; then
    err "No ejecutes este script como root directamente."
    echo -e "    Usa: ${C}bash instalar_tailscale.sh${NC}"
    exit 1
fi

# ── Pedir sudo una sola vez y mantenerlo vivo ─────────────────────────────────
info "Se necesitan permisos de administrador."
echo
sudo -v
( while true; do sudo -v; sleep 50; done ) &
SUDO_PID=$!
trap "kill $SUDO_PID 2>/dev/null; exit" EXIT INT TERM

ok "Permisos obtenidos."
echo

# ── Detectar distro ───────────────────────────────────────────────────────────
if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO_ID="${ID}"
    DISTRO_ID_LIKE="${ID_LIKE:-}"
    DISTRO_NAME="${PRETTY_NAME:-$NAME}"
elif [ -f /etc/redhat-release ]; then
    DISTRO_ID="rhel"; DISTRO_NAME=$(cat /etc/redhat-release)
elif [ -f /etc/debian_version ]; then
    DISTRO_ID="debian"; DISTRO_NAME="Debian"
else
    DISTRO_ID="unknown"; DISTRO_NAME="Desconocida"
fi

echo -e "  ${D}┌─ Sistema ──────────────────────────────────────┐${NC}"
echo -e "  ${D}│${NC}  ${W}Distro${NC}   ${C}${DISTRO_NAME}${NC}"
echo -e "  ${D}│${NC}  ${W}Kernel${NC}   ${D}$(uname -r)${NC}"
echo -e "  ${D}│${NC}  ${W}Arq.  ${NC}   ${D}$(uname -m)${NC}"
echo -e "  ${D}└────────────────────────────────────────────────┘${NC}"
echo

# ── Verificar si ya está instalado ───────────────────────────────────────────
ALREADY_INSTALLED=false
if command -v tailscale &>/dev/null; then
    TS_VER=$(tailscale version 2>/dev/null | head -1)
    echo -e "  ${Y}⚠${NC}  Tailscale ya instalado: ${C}${TS_VER}${NC}"
    dim "Asegurando que el servicio esté activo…"
    echo
    ALREADY_INSTALLED=true
fi

# ── Función: abrir navegador ──────────────────────────────────────────────────
open_browser() {
    local url="$1"
    local opened=false

    # Lista de métodos en orden de preferencia
    for cmd in xdg-open firefox chromium chromium-browser google-chrome \
               brave-browser opera sensible-browser; do
        if command -v "$cmd" &>/dev/null; then
            "$cmd" "$url" &>/dev/null &
            disown
            opened=true
            break
        fi
    done

    # macOS
    if ! $opened && command -v open &>/dev/null; then
        open "$url" &>/dev/null &
        disown
        opened=true
    fi

    if ! $opened; then
        echo
        echo -e "  ${Y}No se detectó navegador.${NC} Abre manualmente:"
        echo -e "  ${C}${url}${NC}"
        echo
    fi
}

# ── Función: instalar según distro ────────────────────────────────────────────
is_family() { echo "$DISTRO_ID $DISTRO_ID_LIKE" | grep -qi "$1"; }

install_tailscale() {
    info "Instalando Tailscale…"
    echo

    if is_family "arch"; then
        sudo pacman -Sy --noconfirm tailscale

    elif is_family "debian" || is_family "ubuntu" || is_family "raspbian"; then
        curl -fsSL https://tailscale.com/install.sh | sudo sh

    elif is_family "fedora"; then
        sudo dnf install -y tailscale 2>/dev/null \
            || curl -fsSL https://tailscale.com/install.sh | sudo sh

    elif is_family "rhel" || is_family "centos" || is_family "rocky" || is_family "almalinux"; then
        curl -fsSL https://tailscale.com/install.sh | sudo sh

    elif is_family "opensuse" || is_family "suse"; then
        sudo zypper install -y tailscale 2>/dev/null \
            || curl -fsSL https://tailscale.com/install.sh | sudo sh

    elif is_family "alpine"; then
        sudo apk add --no-cache tailscale

    elif is_family "gentoo"; then
        sudo emerge --ask=n net-vpn/tailscale

    elif is_family "nixos"; then
        echo -e "  ${Y}NixOS detectado.${NC} Agrega a tu ${C}configuration.nix${NC}:"
        echo -e "  ${D}services.tailscale.enable = true;${NC}"
        exit 0

    else
        dim "Usando instalador universal de Tailscale…"
        curl -fsSL https://tailscale.com/install.sh | sudo sh
    fi
}

if ! $ALREADY_INSTALLED; then
    install_tailscale
fi

# ── Verificar instalación ────────────────────────────────────────────────────
if ! command -v tailscale &>/dev/null; then
    echo
    err "Tailscale no se pudo instalar."
    echo -e "    Intenta manualmente: ${C}curl -fsSL https://tailscale.com/install.sh | sh${NC}"
    exit 1
fi
ok "Tailscale instalado: $(tailscale version 2>/dev/null | head -1)"
echo

# ── Activar servicio ─────────────────────────────────────────────────────────
info "Activando servicio tailscaled…"

if command -v systemctl &>/dev/null; then
    sudo systemctl enable tailscaled --now 2>/dev/null \
        || sudo systemctl enable tailscale  --now 2>/dev/null \
        || true
elif command -v rc-service &>/dev/null; then
    sudo rc-update add tailscale default 2>/dev/null || true
    sudo rc-service tailscale start 2>/dev/null || true
elif command -v sv &>/dev/null; then
    sudo ln -sf /etc/sv/tailscaled /var/service/ 2>/dev/null || true
    sudo sv start tailscaled 2>/dev/null || true
fi

# Esperar a que el daemon arranque
for i in $(seq 1 8); do
    tailscale status &>/dev/null && break
    sleep 1
done

ok "Servicio activo."
echo

# ── CAPTURAR URL DE LOGIN ─────────────────────────────────────────────────────
# El truco: tailscale up --reset bloquea ESPERANDO el login.
# Hay que ejecutarlo en segundo plano y capturar su stderr/stdout
# donde imprime la URL antes de bloquearse.

info "Iniciando autenticación…"
echo

# Archivo temporal para capturar la URL
URL_FILE=$(mktemp /tmp/tailscale-url.XXXXXX)
LOGIN_URL=""

# Lanzar tailscale up en background, redirigiendo output al archivo
sudo tailscale up --reset --accept-routes 2>&1 | tee "$URL_FILE" &
TS_PID=$!

# Esperar hasta 20 segundos a que aparezca la URL en el output
echo -ne "  ${D}Esperando URL de login"
for i in $(seq 1 40); do
    echo -ne "."
    sleep 0.5

    # Buscar URL en el output acumulado
    URL=$(grep -o 'https://login\.tailscale\.com[^ "]*' "$URL_FILE" 2>/dev/null | head -1)
    if [ -n "$URL" ]; then
        LOGIN_URL="$URL"
        break
    fi

    # También verificar si ya estaba autenticado (sin necesitar URL)
    if tailscale status 2>/dev/null | grep -q "^100\." 2>/dev/null; then
        echo -e "\n  ${G}✔${NC}  ¡Ya autenticado!"
        LOGIN_URL=""
        break
    fi
done
echo  # nueva línea tras los puntos

rm -f "$URL_FILE"

# ── Mostrar URL y abrir navegador ─────────────────────────────────────────────
if [ -n "$LOGIN_URL" ]; then
    echo
    echo -e "  ${G}✔${NC}  URL de login obtenida:"
    echo
    echo -e "  ${C}${LOGIN_URL}${NC}"
    echo
    info "Abriendo navegador…"
    open_browser "$LOGIN_URL"

    echo
    echo -e "  ${W}Inicia sesión con:${NC}  ${C}raspberrymorilannoc@gmail.com${NC}"
    echo

    # Esperar a que el usuario complete el login (hasta 3 minutos)
    echo -ne "  ${D}Esperando que completes el login"
    for i in $(seq 1 36); do
        echo -ne "."
        sleep 5
        if tailscale status 2>/dev/null | grep -qE "^[0-9]+\." 2>/dev/null; then
            echo
            echo
            ok "¡Login completado!"
            break
        fi
    done
    echo

elif tailscale status 2>/dev/null | grep -q "^100\."; then
    ok "Tailscale ya estaba autenticado."
else
    # Fallback: mostrar instrucciones manuales
    echo
    echo -e "  ${Y}⚠${NC}  No se pudo capturar la URL automáticamente."
    echo
    echo -e "  Ejecuta manualmente y abre la URL que aparezca:"
    echo -e "  ${C}sudo tailscale up${NC}"
    echo
fi

# Matar el proceso tailscale up si sigue corriendo
kill $TS_PID 2>/dev/null || true
wait $TS_PID 2>/dev/null || true

# ── Resultado final ───────────────────────────────────────────────────────────
echo
TS_STATUS=$(tailscale status 2>/dev/null | head -3 || echo "no disponible")
TS_IP=$(tailscale ip -4 2>/dev/null | head -1 || echo "no asignada")

echo -e "  ${D}┌─ Estado final ─────────────────────────────────┐${NC}"
echo -e "  ${D}│${NC}  ${W}Versión ${NC}  ${C}$(tailscale version 2>/dev/null | head -1)${NC}"
if [ -n "$TS_IP" ] && [ "$TS_IP" != "no asignada" ]; then
    echo -e "  ${D}│${NC}  ${W}IP TS   ${NC}  ${G}${TS_IP}${NC}"
    echo -e "  ${D}│${NC}  ${W}Estado  ${NC}  ${G}● conectado${NC}"
else
    echo -e "  ${D}│${NC}  ${W}IP TS   ${NC}  ${Y}pendiente de login${NC}"
fi
echo -e "  ${D}└────────────────────────────────────────────────┘${NC}"
echo

if [ -n "$TS_IP" ] && [ "$TS_IP" != "no asignada" ]; then
    echo -e "  ${G}Una vez conectado puedes acceder a:${NC}"
    echo -e "  ${D}│${NC}  ${W}Archivos  ${NC}  ${C}smb://me1mori@100.110.49.10${NC}"
    echo -e "  ${D}│${NC}  ${W}Jellyfin  ${NC}  ${C}http://100.110.49.10:8096${NC}"
    echo -e "  ${D}│${NC}  ${W}Panel     ${NC}  ${C}http://100.110.49.10:9090${NC}"
    echo -e "  ${D}│${NC}  ${W}SSH       ${NC}  ${C}ssh me1mori@100.110.49.10${NC}"
    echo
fi