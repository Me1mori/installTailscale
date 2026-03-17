#!/bin/bash
# ══════════════════════════════════════════════════════════════════════════════
#  Instalador de Tailscale — compatible con todas las distros Linux
#  Uso: bash instalar_tailscale.sh
# ══════════════════════════════════════════════════════════════════════════════

set -e

# ── Colores ────────────────────────────────────────────────────────────────────
R='\033[0;31m'
G='\033[0;32m'
Y='\033[0;33m'
C='\033[0;36m'
W='\033[1;37m'
D='\033[2;37m'
NC='\033[0m'

# ── Banner ─────────────────────────────────────────────────────────────────────
clear
echo
echo -e "${W}  ╔══════════════════════════════════════════════╗${NC}"
echo -e "${W}  ║       ${C}🔒 Instalador de Tailscale${W}             ║${NC}"
echo -e "${W}  ╚══════════════════════════════════════════════╝${NC}"
echo

# ── Verificar que no sea root directo ─────────────────────────────────────────
if [ "$EUID" -eq 0 ]; then
    echo -e "  ${R}✗${NC} No ejecutes este script como root directamente."
    echo -e "    Usa: ${C}bash instalar_tailscale.sh${NC}"
    echo
    exit 1
fi

# ── Pedir contraseña sudo al inicio (una sola vez) ────────────────────────────
echo -e "  ${Y}▸${NC} Se necesitan permisos de administrador para instalar."
echo
sudo -v
# Mantener sudo activo durante todo el script
( while true; do sudo -v; sleep 50; done ) &
SUDO_PID=$!
trap "kill $SUDO_PID 2>/dev/null" EXIT

echo -e "  ${G}✓${NC} Permisos obtenidos."
echo

# ── Detectar distro ────────────────────────────────────────────────────────────
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO_ID="${ID}"
        DISTRO_ID_LIKE="${ID_LIKE:-}"
        DISTRO_NAME="${PRETTY_NAME:-$NAME}"
    elif [ -f /etc/redhat-release ]; then
        DISTRO_ID="rhel"
        DISTRO_NAME=$(cat /etc/redhat-release)
    elif [ -f /etc/debian_version ]; then
        DISTRO_ID="debian"
        DISTRO_NAME="Debian"
    else
        DISTRO_ID="unknown"
        DISTRO_NAME="Desconocida"
    fi
}

detect_distro

echo -e "  ${D}┌─ Sistema detectado ────────────────────────────┐${NC}"
echo -e "  ${D}│${NC}  ${W}Distro  ${NC}  ${C}${DISTRO_NAME}${NC}"
echo -e "  ${D}│${NC}  ${W}Kernel  ${NC}  ${D}$(uname -r)${NC}"
echo -e "  ${D}│${NC}  ${W}Arq.    ${NC}  ${D}$(uname -m)${NC}"
echo -e "  ${D}└────────────────────────────────────────────────┘${NC}"
echo

# ── Verificar si ya está instalado ────────────────────────────────────────────
if command -v tailscale &>/dev/null; then
    TS_VERSION=$(tailscale version 2>/dev/null | head -1)
    echo -e "  ${Y}⚠${NC}  Tailscale ya está instalado: ${C}${TS_VERSION}${NC}"
    echo -e "  ${D}    Continuando para asegurar que el servicio esté activo...${NC}"
    echo
    ALREADY_INSTALLED=true
else
    ALREADY_INSTALLED=false
fi

# ── Instalar según distro ──────────────────────────────────────────────────────
install_tailscale() {
    local distro="$1"
    local like="$2"

    # Función auxiliar para verificar si es de familia X
    is_family() {
        echo "$distro $like" | grep -qi "$1"
    }

    echo -e "  ${Y}▸${NC} Instalando Tailscale..."
    echo

    # ── Arch Linux y derivados (Manjaro, EndeavourOS, Garuda, etc.) ────────────
    if is_family "arch"; then
        if command -v pacman &>/dev/null; then
            sudo pacman -Sy --noconfirm tailscale
        fi

    # ── Debian / Ubuntu / Mint / Pop!_OS / Raspbian / Kali / MX Linux ─────────
    elif is_family "debian" || is_family "ubuntu" || is_family "raspbian"; then
        sudo apt-get update -qq
        sudo apt-get install -y curl
        curl -fsSL https://pkgs.tailscale.com/stable/debian/$(. /etc/os-release && echo "$VERSION_CODENAME").gpg \
            | sudo gpg --dearmor -o /usr/share/keyrings/tailscale-archive-keyring.gpg 2>/dev/null \
            || true
        # Método universal como fallback
        curl -fsSL https://tailscale.com/install.sh | sudo sh

    # ── Fedora ─────────────────────────────────────────────────────────────────
    elif is_family "fedora"; then
        sudo dnf install -y tailscale 2>/dev/null \
            || curl -fsSL https://tailscale.com/install.sh | sudo sh

    # ── RHEL / CentOS / Rocky / AlmaLinux / Oracle Linux ──────────────────────
    elif is_family "rhel" || is_family "centos" || is_family "rocky" || is_family "almalinux"; then
        sudo yum install -y yum-utils 2>/dev/null || true
        sudo yum-config-manager --add-repo https://pkgs.tailscale.com/stable/rhel/$(rpm -E %{rhel})/tailscale.repo 2>/dev/null \
            || curl -fsSL https://tailscale.com/install.sh | sudo sh
        sudo yum install -y tailscale 2>/dev/null \
            || curl -fsSL https://tailscale.com/install.sh | sudo sh

    # ── openSUSE / SLES ────────────────────────────────────────────────────────
    elif is_family "opensuse" || is_family "suse"; then
        sudo zypper install -y tailscale 2>/dev/null \
            || curl -fsSL https://tailscale.com/install.sh | sudo sh

    # ── Alpine Linux ───────────────────────────────────────────────────────────
    elif is_family "alpine"; then
        sudo apk add --no-cache tailscale

    # ── Gentoo ─────────────────────────────────────────────────────────────────
    elif is_family "gentoo"; then
        sudo emerge --ask=n net-vpn/tailscale

    # ── NixOS ──────────────────────────────────────────────────────────────────
    elif is_family "nixos"; then
        echo -e "  ${Y}⚠${NC}  NixOS detectado."
        echo -e "     Agrega a tu ${C}configuration.nix${NC}:"
        echo -e "     ${D}services.tailscale.enable = true;${NC}"
        echo
        exit 0

    # ── Fallback universal (script oficial de Tailscale) ──────────────────────
    else
        echo -e "  ${D}    Usando instalador universal de Tailscale...${NC}"
        curl -fsSL https://tailscale.com/install.sh | sudo sh
    fi
}

if [ "$ALREADY_INSTALLED" = false ]; then
    install_tailscale "$DISTRO_ID" "$DISTRO_ID_LIKE"
fi

# ── Verificar instalación ──────────────────────────────────────────────────────
if ! command -v tailscale &>/dev/null; then
    echo
    echo -e "  ${R}✗${NC} Error: Tailscale no se pudo instalar."
    echo -e "    Intenta manualmente: ${C}curl -fsSL https://tailscale.com/install.sh | sh${NC}"
    echo
    exit 1
fi

echo -e "  ${G}✓${NC} Tailscale instalado correctamente."
echo

# ── Activar y arrancar el servicio ────────────────────────────────────────────
echo -e "  ${Y}▸${NC} Activando servicio..."

# systemd (mayoría de distros modernas)
if command -v systemctl &>/dev/null; then
    sudo systemctl enable tailscaled --now 2>/dev/null \
        || sudo systemctl enable tailscale --now 2>/dev/null \
        || true

# OpenRC (Alpine, Gentoo, algunos Artix)
elif command -v rc-service &>/dev/null; then
    sudo rc-update add tailscale default
    sudo rc-service tailscale start

# runit (Void Linux, algunos Artix)
elif command -v sv &>/dev/null; then
    sudo ln -sf /etc/sv/tailscaled /var/service/ 2>/dev/null || true
    sudo sv start tailscaled 2>/dev/null || true
fi

# Esperar a que el daemon esté listo
sleep 2

# Verificar que el daemon corre
if ! tailscale status &>/dev/null; then
    # Intentar arrancar manualmente
    sudo tailscaled &>/dev/null &
    sleep 2
fi

echo -e "  ${G}✓${NC} Servicio activo."
echo

# ── Resumen antes de abrir navegador ──────────────────────────────────────────
echo -e "  ${D}┌─ Instalación completada ───────────────────────┐${NC}"
echo -e "  ${D}│${NC}  ${W}Versión  ${NC}  ${C}$(tailscale version 2>/dev/null | head -1)${NC}"
echo -e "  ${D}│${NC}  ${W}Servicio ${NC}  ${G}● activo${NC}"
echo -e "  ${D}└────────────────────────────────────────────────┘${NC}"
echo
echo -e "  ${Y}▸${NC} Abriendo navegador para iniciar sesión en Tailscale..."
echo -e "  ${D}    Inicia sesión con la cuenta compartida.${NC}"
echo

# ── Iniciar Tailscale y abrir URL de login en el navegador ────────────────────
# Obtener URL de autenticación
AUTH_URL=$(sudo tailscale up --reset 2>&1 | grep -o 'https://login.tailscale.com[^ ]*' | head -1)

if [ -z "$AUTH_URL" ]; then
    # Intentar con timeout si el primero no devuelve URL
    AUTH_URL=$(timeout 10 sudo tailscale up 2>&1 | grep -o 'https://[^ ]*' | head -1 || true)
fi

# Abrir navegador
open_browser() {
    local url="$1"
    if [ -z "$url" ]; then
        url="https://login.tailscale.com"
    fi

    # Intentar distintos navegadores/métodos
    if command -v xdg-open &>/dev/null; then
        xdg-open "$url" &>/dev/null &
    elif command -v firefox &>/dev/null; then
        firefox "$url" &>/dev/null &
    elif command -v chromium &>/dev/null; then
        chromium "$url" &>/dev/null &
    elif command -v google-chrome &>/dev/null; then
        google-chrome "$url" &>/dev/null &
    elif command -v brave &>/dev/null; then
        brave "$url" &>/dev/null &
    else
        echo -e "  ${Y}⚠${NC}  No se detectó navegador. Abre manualmente:"
        echo -e "     ${C}${url}${NC}"
    fi
}

open_browser "$AUTH_URL"

echo
echo -e "  ${G}✓${NC} Listo. Inicia sesión en el navegador con:"
echo -e "     ${C}raspberrymorilannoc@gmail.com${NC}"
echo
echo -e "  ${D}    Una vez conectado puedes acceder a:${NC}"
echo -e "  ${D}│${NC}  ${W}Archivos  ${NC}  ${C}smb://me1mori@100.110.49.10${NC}"
echo -e "  ${D}│${NC}  ${W}Jellyfin  ${NC}  ${C}http://100.110.49.10:8096${NC}"
echo -e "  ${D}│${NC}  ${W}SSH       ${NC}  ${C}ssh me1mori@100.110.49.10${NC}"
echo