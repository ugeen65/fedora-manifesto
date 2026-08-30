#!/usr/bin/env bash
#
# snapshot.sh — Raccoglie lo stato di un sistema Fedora in una cartella di output.
#
# USO:
#   ./snapshot.sh <nome-macchina> [cartella-output-base]
#
# ESEMPI:
#   ./snapshot.sh sistemaA              # crea ./snapshots/sistemaA-2026-08-28_1200/
#   ./snapshot.sh vm-pulita ~/manifesto # crea ~/manifesto/vm-pulita-2026-08-28_1200/
#
# Lo stesso script va lanciato SENZA MODIFICHE sia sul Sistema A (già configurato)
# sia sulla VM pulita, così i due snapshot sono direttamente confrontabili.

set -uo pipefail

NOME="${1:?Devi indicare un nome per questo snapshot, es: sistemaA oppure vm-pulita}"
BASE_OUT="${2:-$HOME/fedora-manifesto/snapshots}"
TIMESTAMP="$(date +%Y-%m-%d_%H%M)"
OUT="${BASE_OUT}/${NOME}-${TIMESTAMP}"

mkdir -p "$OUT"

echo "==> Snapshot '$NOME' in corso, output in: $OUT"

# -----------------------------------------------------------------------------
# 1. Pacchetti RPM installati (nome + versione, ordinati per confronto pulito)
# -----------------------------------------------------------------------------
echo "  - Pacchetti RPM..."
rpm -qa --qf '%{NAME}\n' | sort -u > "$OUT/packages-rpm.txt"

# -----------------------------------------------------------------------------
# 2. Gruppi/Environment installati (utile per capire "Xfce Desktop" vs "GNOME")
# -----------------------------------------------------------------------------
echo "  - Gruppi pacchetti (dnf group list installed)..."
dnf group list --installed 2>/dev/null | sed '1,3d' | sort -u > "$OUT/package-groups.txt"

# -----------------------------------------------------------------------------
# 3. App Flatpak installate
# -----------------------------------------------------------------------------
echo "  - Flatpak..."
if command -v flatpak >/dev/null 2>&1; then
    flatpak list --app --columns=application 2>/dev/null | sort -u > "$OUT/flatpaks.txt"
else
    echo "(flatpak non installato su questo sistema)" > "$OUT/flatpaks.txt"
fi

# -----------------------------------------------------------------------------
# 4. Repository di terze parti (RPM Fusion, COPR, ecc.)
# -----------------------------------------------------------------------------
echo "  - Repository..."
mkdir -p "$OUT/repos"
cp -a /etc/yum.repos.d/. "$OUT/repos/" 2>/dev/null

if command -v dnf >/dev/null 2>&1; then
    dnf repolist --all 2>/dev/null > "$OUT/repolist.txt"
fi

# -----------------------------------------------------------------------------
# 5. Impostazioni GNOME/dconf (utile anche se poi passi a Xfce/niri,
#    perché GDM/login e alcune app GTK usano comunque dconf)
# -----------------------------------------------------------------------------
echo "  - dconf..."
if command -v dconf >/dev/null 2>&1; then
    dconf dump / > "$OUT/dconf-dump.txt"
fi

# -----------------------------------------------------------------------------
# 6. Servizi systemd abilitati (di sistema e utente)
# -----------------------------------------------------------------------------
echo "  - Servizi systemd..."
systemctl list-unit-files --state=enabled --no-legend 2>/dev/null \
    | awk '{print $1}' | sort -u > "$OUT/systemd-enabled-system.txt"

systemctl --user list-unit-files --state=enabled --no-legend 2>/dev/null \
    | awk '{print $1}' | sort -u > "$OUT/systemd-enabled-user.txt"

# -----------------------------------------------------------------------------
# 7. Crontab utente e timer systemd utente
# -----------------------------------------------------------------------------
echo "  - Crontab..."
crontab -l > "$OUT/crontab-user.txt" 2>/dev/null || echo "(nessun crontab utente)" > "$OUT/crontab-user.txt"

mkdir -p "$OUT/systemd-user-units"
cp -a "$HOME/.config/systemd/user/." "$OUT/systemd-user-units/" 2>/dev/null

# -----------------------------------------------------------------------------
# 8. Elenco dotfile e cartelle di configurazione nella home
#    (elenchiamo i NOMI, non copiamo tutto il contenuto: eviteremo di portarci
#    dietro cache pesanti o dati sensibili non necessari in questa fase)
# -----------------------------------------------------------------------------
echo "  - Elenco dotfile in home..."
find "$HOME" -maxdepth 1 -name '.*' -printf '%f\n' 2>/dev/null | sort > "$OUT/home-dotfiles-list.txt"

echo "  - Elenco cartelle in ~/.config..."
find "$HOME/.config" -maxdepth 1 -mindepth 1 -printf '%f\n' 2>/dev/null | sort > "$OUT/config-dirs-list.txt"

echo "  - Elenco cartelle in ~/.local/share..."
find "$HOME/.local/share" -maxdepth 1 -mindepth 1 -printf '%f\n' 2>/dev/null | sort > "$OUT/local-share-dirs-list.txt"

# -----------------------------------------------------------------------------
# 9. Metadati dello snapshot
# -----------------------------------------------------------------------------
{
    echo "nome=$NOME"
    echo "data=$(date -Iseconds)"
    echo "hostname=$(hostname)"
    echo "fedora_release=$(rpm -E %fedora 2>/dev/null || echo sconosciuto)"
} > "$OUT/meta.txt"

echo "==> Fatto. Snapshot salvato in: $OUT"
echo "    Copia questa cartella dove vuoi confrontarla con l'altro snapshot."
