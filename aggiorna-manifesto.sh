#!/usr/bin/env bash
#
# aggiorna-manifesto.sh — Rigenera il manifesto attivo dello stato del sistema
#                          e ne registra la versione con un commit git.
#
# A differenza di snapshot.sh (che crea una nuova cartella con timestamp ogni
# volta), questo script SOVRASCRIVE sempre gli stessi file dentro manifest/,
# lasciando a git il compito di tracciare lo storico tramite i commit.
#
# USO:
#   ./aggiorna-manifesto.sh ["messaggio di commit opzionale"]
#
# Pensato per essere richiamato sia da un wrapper attorno a "dnf install"
# (per aggiornare subito il manifesto ad ogni installazione consapevole) sia
# da un timer periodico (systemd, cron) come rete di sicurezza.

set -uo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST_DIR="$REPO_DIR/manifest"
MSG="${1:-Aggiornamento automatico manifesto: $(date -Iseconds)}"

# -----------------------------------------------------------------------------
# 0. Verifica che git sia installato; se manca, prova a installarlo da solo.
#    Serve un'eccezione sudoers dedicata (vedi sudoers.d/fedora-manifesto.example)
#    per poterlo fare senza password anche quando lo script gira da un timer,
#    senza un utente davanti alla tastiera.
# -----------------------------------------------------------------------------
if ! command -v git >/dev/null 2>&1; then
    echo "==> git non risulta installato, tento l'installazione automatica..."
    sudo -n dnf install -y git 2>/dev/null

    if ! command -v git >/dev/null 2>&1; then
        echo "==> ERRORE: git non è installato e non è stato possibile installarlo automaticamente." >&2
        echo "    Installalo manualmente con: sudo dnf install git" >&2
        exit 1
    fi
    echo "==> git installato correttamente."
fi

mkdir -p "$MANIFEST_DIR"

# -----------------------------------------------------------------------------
# 1. Pacchetti RPM installati
# -----------------------------------------------------------------------------
rpm -qa --qf '%{NAME}\n' | sort -u > "$MANIFEST_DIR/packages-rpm.txt"

# -----------------------------------------------------------------------------
# 2. Gruppi pacchetto installati
# -----------------------------------------------------------------------------
dnf group list --installed 2>/dev/null | sed '1,3d' | sort -u > "$MANIFEST_DIR/package-groups.txt"

# -----------------------------------------------------------------------------
# 3. App Flatpak installate
# -----------------------------------------------------------------------------
if command -v flatpak >/dev/null 2>&1; then
    flatpak list --app --columns=application 2>/dev/null | sort -u > "$MANIFEST_DIR/flatpaks.txt"
else
    echo "(flatpak non installato)" > "$MANIFEST_DIR/flatpaks.txt"
fi

# -----------------------------------------------------------------------------
# 4. Repository di terze parti
# -----------------------------------------------------------------------------
mkdir -p "$MANIFEST_DIR/repos"
rm -f "$MANIFEST_DIR"/repos/*.repo 2>/dev/null
cp -a /etc/yum.repos.d/*.repo "$MANIFEST_DIR/repos/" 2>/dev/null
dnf repolist --all 2>/dev/null > "$MANIFEST_DIR/repolist.txt"

# -----------------------------------------------------------------------------
# 5. Impostazioni dconf (sfondo, temi, scorciatoie, ecc.)
# -----------------------------------------------------------------------------
if command -v dconf >/dev/null 2>&1; then
    dconf dump / > "$MANIFEST_DIR/dconf-dump.txt"
fi

# -----------------------------------------------------------------------------
# 6. Servizi systemd abilitati
# -----------------------------------------------------------------------------
systemctl list-unit-files --state=enabled --no-legend 2>/dev/null \
    | awk '{print $1}' | sort -u > "$MANIFEST_DIR/systemd-enabled-system.txt"

systemctl --user list-unit-files --state=enabled --no-legend 2>/dev/null \
    | awk '{print $1}' | sort -u > "$MANIFEST_DIR/systemd-enabled-user.txt"

# -----------------------------------------------------------------------------
# 7. Crontab e timer utente
# -----------------------------------------------------------------------------
crontab -l > "$MANIFEST_DIR/crontab-user.txt" 2>/dev/null || echo "(nessun crontab utente)" > "$MANIFEST_DIR/crontab-user.txt"

mkdir -p "$MANIFEST_DIR/systemd-user-units"
rm -f "$MANIFEST_DIR"/systemd-user-units/*.* 2>/dev/null
cp -a "$HOME/.config/systemd/user/." "$MANIFEST_DIR/systemd-user-units/" 2>/dev/null

# -----------------------------------------------------------------------------
# 8. Elenco dotfile e cartelle di configurazione (solo i nomi, non il
#    contenuto: evita di catturare cache pesanti o dati sensibili non
#    esplicitamente gestiti altrove)
# -----------------------------------------------------------------------------
find "$HOME" -maxdepth 1 -name '.*' -printf '%f\n' 2>/dev/null | sort > "$MANIFEST_DIR/home-dotfiles-list.txt"
find "$HOME/.config" -maxdepth 1 -mindepth 1 -printf '%f\n' 2>/dev/null | sort > "$MANIFEST_DIR/config-dirs-list.txt"
find "$HOME/.local/share" -maxdepth 1 -mindepth 1 -printf '%f\n' 2>/dev/null | sort > "$MANIFEST_DIR/local-share-dirs-list.txt"

# -----------------------------------------------------------------------------
# 8b. Copia completa di .bashrc (alias, funzioni, prompt personalizzato, ecc.)
# -----------------------------------------------------------------------------
cp "$HOME/.bashrc" "$MANIFEST_DIR/bashrc" 2>/dev/null

# -----------------------------------------------------------------------------
# 9. Configurazioni mirate di /etc (whitelist di cartelle/file rilevanti:
#    connessioni di rete, moduli kernel, samba). Delegato a uno script
#    root-owned dedicato (vedi fedora-manifesto-etc-snapshot.sh), eseguibile
#    via sudo NOPASSWD ma solo in questa forma esatta, senza parametri: questo
#    evita di dare sudo generico su cp con percorsi arbitrari.
#
#    ATTENZIONE: il file delle connessioni NetworkManager può contenere
#    password Wi-Fi/VPN IN CHIARO. Valuta se cifrarle (es. con GPG o con lo
#    script 7z incluso in mc-menu-esempio) prima di sincronizzare il
#    manifesto su un repository condiviso o un cloud.
#
#    Se sudo non è disponibile in modalità non-interattiva (es. prima
#    esecuzione manuale senza aver configurato sudoers), questa sezione viene
#    saltata senza bloccare il resto dell'aggiornamento.
# -----------------------------------------------------------------------------
sudo -n /usr/local/sbin/fedora-manifesto-etc-snapshot.sh 2>/dev/null

# -----------------------------------------------------------------------------
# 10. Metadati
# -----------------------------------------------------------------------------
{
    echo "ultimo_aggiornamento=$(date -Iseconds)"
    echo "hostname=$(hostname)"
    echo "fedora_release=$(rpm -E %fedora 2>/dev/null || echo sconosciuto)"
} > "$MANIFEST_DIR/meta.txt"

# -----------------------------------------------------------------------------
# 11. Commit su git, solo se ci sono cambiamenti reali
# -----------------------------------------------------------------------------
cd "$REPO_DIR" || exit 1

git add manifest/

if git diff --cached --quiet; then
    echo "==> Nessuna modifica rilevata rispetto all'ultimo manifesto. Nessun commit."
else
    git commit -q -m "$MSG"
    echo "==> Manifesto aggiornato e committato: $MSG"
fi
