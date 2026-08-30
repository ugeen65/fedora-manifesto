#!/usr/bin/env bash
#
# backup-manifesto.sh — Crea un backup compresso (.tar.gz) dell'intera
# cartella ~/fedora-manifesto: script, manifesto attivo, storico git incluso.
#
# USO:
#   backup-manifesto.sh [cartella-destinazione]
#
# Se non specifichi una cartella, va di default in ~/Backup/fedora-manifesto/
#
# RIPRISTINO (in caso di reinstallazione o rottura del sistema):
#   tar xzf fedora-manifesto-AAAA-MM-GG_HHMM.tar.gz -C ~/
#
# Questo ricrea ~/fedora-manifesto con tutto lo storico git intatto: puoi
# subito lanciare "git log" dentro per vedere tutta la cronologia salvata.

set -uo pipefail

SRC="$HOME/fedora-manifesto"
DEST_DIR="${1:-$HOME/Backup/fedora-manifesto}"
TIMESTAMP="$(date +%Y-%m-%d_%H%M)"
ARCHIVIO="$DEST_DIR/fedora-manifesto-${TIMESTAMP}.tar.gz"

if [[ ! -d "$SRC" ]]; then
    echo "Errore: la cartella $SRC non esiste, nulla da salvare." >&2
    exit 1
fi

mkdir -p "$DEST_DIR"

echo "==> Backup di $SRC in corso..."
tar czf "$ARCHIVIO" -C "$HOME" fedora-manifesto

if [[ $? -eq 0 ]]; then
    DIMENSIONE="$(du -h "$ARCHIVIO" | cut -f1)"
    echo "==> Backup completato: $ARCHIVIO ($DIMENSIONE)"
else
    echo "Errore durante la creazione del backup." >&2
    exit 1
fi

# -----------------------------------------------------------------------------
# Pulizia automatica: tieni solo gli ultimi 10 backup, elimina i più vecchi
# (evita di riempire il disco nel tempo con backup giornalieri/settimanali)
# -----------------------------------------------------------------------------
NUM_BACKUP=10
cd "$DEST_DIR" || exit 0
ls -1t fedora-manifesto-*.tar.gz 2>/dev/null | tail -n +$((NUM_BACKUP + 1)) | while read -r vecchio; do
    echo "==> Rimuovo backup vecchio: $vecchio"
    rm -f "$vecchio"
done

echo "==> Backup disponibili in $DEST_DIR:"
ls -lh "$DEST_DIR"/fedora-manifesto-*.tar.gz 2>/dev/null
