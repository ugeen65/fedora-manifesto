#!/usr/bin/env bash
#
# confronta.sh — Confronta due snapshot generati da snapshot.sh e produce
#                un report delle differenze in una cartella "diff-report".
#
# USO:
#   ./confronta.sh <cartella-snapshot-PULITO> <cartella-snapshot-CONFIGURATO> [cartella-output]
#
# ESEMPIO:
#   ./confronta.sh ~/fedora-manifesto/snapshots/vm-pulita-2026-08-28_1200 \
#                  ~/fedora-manifesto/snapshots/sistemaA-2026-08-28_1230
#
# Il primo argomento è SEMPRE il sistema "pulito" (baseline / riferimento),
# il secondo è il sistema "configurato" da cui vogliamo estrarre cosa manca
# al primo per diventare uguale.

set -uo pipefail

PULITO="${1:?Indica la cartella dello snapshot del sistema PULITO}"
CONFIG="${2:?Indica la cartella dello snapshot del sistema CONFIGURATO}"
OUT="${3:-$HOME/fedora-manifesto/diff-report-$(date +%Y-%m-%d_%H%M)}"

for dir in "$PULITO" "$CONFIG"; do
    if [[ ! -d "$dir" ]]; then
        echo "Errore: la cartella '$dir' non esiste." >&2
        exit 1
    fi
done

mkdir -p "$OUT"
echo "==> Confronto in corso."
echo "    Pulito:      $PULITO"
echo "    Configurato: $CONFIG"
echo "    Report in:   $OUT"

# Piccola utility: righe presenti SOLO nel file di destra (configurato)
# rispetto al file di sinistra (pulito). Ordina prima, per sicurezza.
solo_in_configurato() {
    local file_pulito="$1"
    local file_config="$2"
    comm -13 <(sort -u "$file_pulito" 2>/dev/null) <(sort -u "$file_config" 2>/dev/null)
}

# -----------------------------------------------------------------------------
# 1. Pacchetti RPM da installare (presenti nel configurato, assenti nel pulito)
# -----------------------------------------------------------------------------
solo_in_configurato "$PULITO/packages-rpm.txt" "$CONFIG/packages-rpm.txt" \
    > "$OUT/packages-to-install.txt"

# -----------------------------------------------------------------------------
# 2. Flatpak da installare
# -----------------------------------------------------------------------------
solo_in_configurato "$PULITO/flatpaks.txt" "$CONFIG/flatpaks.txt" \
    > "$OUT/flatpaks-to-install.txt"

# -----------------------------------------------------------------------------
# 3. Repository extra (RPM Fusion, COPR...) presenti solo nel configurato
# -----------------------------------------------------------------------------
mkdir -p "$OUT/repos-to-add"
if [[ -d "$CONFIG/repos" ]]; then
    for f in "$CONFIG/repos"/*.repo; do
        [[ -e "$f" ]] || continue
        base="$(basename "$f")"
        if [[ ! -f "$PULITO/repos/$base" ]]; then
            cp "$f" "$OUT/repos-to-add/"
        fi
    done
fi

# -----------------------------------------------------------------------------
# 4. Servizi systemd da abilitare (sistema e utente)
# -----------------------------------------------------------------------------
solo_in_configurato "$PULITO/systemd-enabled-system.txt" "$CONFIG/systemd-enabled-system.txt" \
    > "$OUT/systemd-services-to-enable-system.txt"

solo_in_configurato "$PULITO/systemd-enabled-user.txt" "$CONFIG/systemd-enabled-user.txt" \
    > "$OUT/systemd-services-to-enable-user.txt"

# -----------------------------------------------------------------------------
# 5. Cartelle di configurazione nuove/diverse (elenco, non contenuto)
#    Serve solo a dirti QUALI cartelle guardare per una copia manuale/mirata,
#    non a copiarle automaticamente (potrebbero contenere cache pesanti).
# -----------------------------------------------------------------------------
solo_in_configurato "$PULITO/home-dotfiles-list.txt" "$CONFIG/home-dotfiles-list.txt" \
    > "$OUT/new-home-dotfiles.txt"

solo_in_configurato "$PULITO/config-dirs-list.txt" "$CONFIG/config-dirs-list.txt" \
    > "$OUT/new-config-dirs.txt"

solo_in_configurato "$PULITO/local-share-dirs-list.txt" "$CONFIG/local-share-dirs-list.txt" \
    > "$OUT/new-local-share-dirs.txt"

# -----------------------------------------------------------------------------
# 6. Differenza dconf (impostazioni GNOME/desktop)
#    Qui usiamo un vero diff testuale perché il dump è strutturato a blocchi,
#    non una semplice lista: serve leggerlo come diff, non come "righe nuove".
# -----------------------------------------------------------------------------
if [[ -f "$PULITO/dconf-dump.txt" && -f "$CONFIG/dconf-dump.txt" ]]; then
    diff -u "$PULITO/dconf-dump.txt" "$CONFIG/dconf-dump.txt" > "$OUT/dconf-diff.txt"
fi

# -----------------------------------------------------------------------------
# 7. Crontab: mostra il crontab del configurato per revisione manuale
#    (di solito breve, ha senso leggerlo per intero piuttosto che diffarlo)
# -----------------------------------------------------------------------------
cp "$CONFIG/crontab-user.txt" "$OUT/crontab-user-configurato.txt" 2>/dev/null

# -----------------------------------------------------------------------------
# Riepilogo a schermo
# -----------------------------------------------------------------------------
echo ""
echo "==> Report generato in: $OUT"
echo ""
echo "Riepilogo rapido:"
printf "  Pacchetti da installare:      %s\n" "$(wc -l < "$OUT/packages-to-install.txt")"
printf "  Flatpak da installare:        %s\n" "$(wc -l < "$OUT/flatpaks-to-install.txt")"
printf "  Repo da aggiungere:           %s\n" "$(find "$OUT/repos-to-add" -type f | wc -l)"
printf "  Servizi sistema da abilitare: %s\n" "$(wc -l < "$OUT/systemd-services-to-enable-system.txt")"
printf "  Servizi utente da abilitare:  %s\n" "$(wc -l < "$OUT/systemd-services-to-enable-user.txt")"
printf "  Nuove cartelle in ~/.config:  %s\n" "$(wc -l < "$OUT/new-config-dirs.txt")"
echo ""
echo "Rivedi i file uno per uno prima di usarli per costruire lo script di ripristino."
