#!/usr/bin/env bash
#
# fedora-manifesto-etc-snapshot.sh — Copia i file/cartelle di /etc rilevanti
# per il manifesto Fedora, in una destinazione FISSA e non parametrizzabile.
#
# Questo script è pensato per essere eseguibile via sudo con NOPASSWD, ma
# SOLO in questa forma esatta (nessun argomento accettato), per limitare
# il rischio: un utente non può passare percorsi arbitrari da leggere o
# scrivere, perché sia la sorgente che la destinazione sono determinate
# automaticamente qui (tramite $SUDO_USER, impostata da sudo stesso).
#
# Va installato in /usr/local/sbin/, di proprietà di root, permessi 755,
# NON scrivibile dall'utente normale.
#
# Esempio di riga da aggiungere in /etc/sudoers.d/ (con visudo):
#   tuoutente ALL=(root) NOPASSWD: /usr/local/sbin/fedora-manifesto-etc-snapshot.sh

set -uo pipefail

if [[ -z "${SUDO_USER:-}" ]]; then
    echo "Errore: questo script va lanciato tramite sudo (manca \$SUDO_USER)." >&2
    exit 1
fi

DEST="/home/$SUDO_USER/fedora-manifesto/manifest/etc-tracked"

mkdir -p "$DEST/NetworkManager-system-connections"
mkdir -p "$DEST/modprobe.d"
mkdir -p "$DEST/sysctl.d"

rm -f "$DEST"/NetworkManager-system-connections/*.* 2>/dev/null
rm -f "$DEST"/modprobe.d/*.* 2>/dev/null
rm -f "$DEST"/sysctl.d/*.* 2>/dev/null

cp -a /etc/NetworkManager/system-connections/. "$DEST/NetworkManager-system-connections/" 2>/dev/null
cp -a /etc/modprobe.d/. "$DEST/modprobe.d/" 2>/dev/null
cp -a /etc/sysctl.d/. "$DEST/sysctl.d/" 2>/dev/null
cp -a /etc/samba/smb.conf "$DEST/smb.conf" 2>/dev/null

# Rendi leggibili i file copiati dall'utente normale (altrimenti restano
# root-only come gli originali, e git/l'utente non potrebbe leggerli)
chown -R "$SUDO_USER:$SUDO_USER" "$DEST"
chmod -R u+rwX,go-rwx "$DEST"

exit 0
