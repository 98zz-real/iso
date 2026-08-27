#!/bin/bash
# install.sh — Richtet alles für den Remote-OS-Installer-Stick ein:
# System-Abhängigkeiten, boot-client-Testbuild, Buildroot-Checkout + Overlay.
#
# Erwartet, dass unter BASE_DIR bereits liegen:
#   roi/                 (das entpackte Projekt-ZIP)
#   buildroot-overlay/    (das entpackte Overlay-ZIP)
#
# Nutzung:
#   chmod +x install.sh
#   ./install.sh

set -euo pipefail

BASE_DIR="/opt/bootsoftware"
ROI_DIR="${BASE_DIR}/roi"
OVERLAY_DIR="${BASE_DIR}/buildroot-overlay"
BUILDROOT_DIR="${BASE_DIR}/buildroot"

log() { echo -e "\n>>> $*"; }
err() { echo -e "\n!!! $*" >&2; }

# ---------------------------------------------------------------------------
# 0) Vorbedingungen prüfen
# ---------------------------------------------------------------------------
if [ "$(id -u)" -eq 0 ]; then
	err "Bitte NICHT als root ausführen, sondern als normaler User mit sudo-Rechten."
	exit 1
fi

if [ ! -d "$ROI_DIR" ] || [ ! -d "$OVERLAY_DIR" ]; then
	err "Erwarte ${ROI_DIR} und ${OVERLAY_DIR} — bitte erst beide ZIPs dorthin entpacken."
	exit 1
fi

# ---------------------------------------------------------------------------
# 1) System-Abhängigkeiten installieren
# ---------------------------------------------------------------------------
log "Installiere System-Abhängigkeiten (apt, brauche sudo-Passwort)..."
sudo apt update
sudo apt install -y \
	pkg-config \
	libfontconfig1-dev \
	libudev-dev \
	libinput-dev \
	libxkbcommon-dev \
	libdrm-dev \
	libseat-dev \
	libgbm-dev \
	build-essential \
	git \
	libncurses-dev \
	bc \
	bison \
	flex \
	libssl-dev \
	cpio \
	unzip \
	rsync \
	genimage \
	curl

# ---------------------------------------------------------------------------
# 2) Rust-Toolchain sicherstellen
# ---------------------------------------------------------------------------
if command -v cargo >/dev/null 2>&1; then
	log "Rust/Cargo bereits vorhanden ($(cargo --version)), überspringe rustup."
else
	log "Installiere Rust via rustup..."
	curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
	# shellcheck disable=SC1091
	source "$HOME/.cargo/env"
fi

# ---------------------------------------------------------------------------
# 3) boot-client Testbuild
# ---------------------------------------------------------------------------
log "Baue boot-client (Testbuild, cargo build --release)..."
(
	cd "${ROI_DIR}/boot-client" || (cd "${ROI_DIR}"/*/boot-client 2>/dev/null || {
		err "Konnte boot-client-Verzeichnis unter ${ROI_DIR} nicht finden."
		exit 1
	})
	cargo build --release
)

# ---------------------------------------------------------------------------
# 4) Buildroot klonen (falls noch nicht vorhanden)
# ---------------------------------------------------------------------------
if [ -d "$BUILDROOT_DIR" ]; then
	log "Buildroot-Checkout existiert bereits unter ${BUILDROOT_DIR}, überspringe Klonen."
else
	log "Klone Buildroot nach ${BUILDROOT_DIR}..."
	git clone https://github.com/buildroot/buildroot.git "$BUILDROOT_DIR"
fi

# ---------------------------------------------------------------------------
# 5) Platzhalter-Pfad im Kernel-Config-Fragment automatisch ersetzen
# ---------------------------------------------------------------------------
EFISTUB_CFG="${OVERLAY_DIR}/board/bootclient/linux-efistub.config"
if [ -f "$EFISTUB_CFG" ]; then
	log "Setze Buildroot-Pfad in linux-efistub.config..."
	sed -i "s|<ABSOLUTER-PFAD-ZU-BUILDROOT>|${BUILDROOT_DIR}|g" "$EFISTUB_CFG"
else
	err "Warnung: ${EFISTUB_CFG} nicht gefunden — Platzhalter musst du manuell setzen."
fi

# ---------------------------------------------------------------------------
# 6) Fertig — letzter Schritt ist manuell (Kernel-Treiber sind hardwarespezifisch)
# ---------------------------------------------------------------------------
log "Setup fertig."
echo ""
echo "Alles Automatisierbare ist erledigt. Zwei Schritte bleiben MANUELL, weil"
echo "sie von deiner Ziel-Hardware (GPU-Modell) abhängen und nicht pauschal"
echo "automatisiert werden können:"
echo ""
echo "  cd ${BUILDROOT_DIR}"
echo "  make BR2_EXTERNAL=${OVERLAY_DIR} menuconfig"
echo ""
echo "    Dort einstellen:"
echo "      - Target options -> Target Architecture: x86_64"
echo "      - Target packages -> boot-client aktivieren"
echo "      - Kernel-Menü -> General setup -> Initramfs source file(s):"
echo "        ${BUILDROOT_DIR}/output/target"
echo "      - Kernel-Menü -> EFI stub support aktivieren"
echo "      - Kernel-Menü -> passenden KMS-Treiber für deine Ziel-GPU"
echo "        aktivieren (i915 = Intel, amdgpu = AMD, nouveau = Nvidia)"
echo ""
echo "  Danach:"
echo "  make BR2_EXTERNAL=${OVERLAY_DIR}"
echo ""
echo "  (dauert 30-90 Minuten, Ergebnis: ${BUILDROOT_DIR}/output/images/bootclient.img)"
