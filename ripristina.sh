#!/usr/bin/env bash
#
# ripristina.sh — Legge il manifesto (manifest/) e prova a portare un
# sistema Fedora pulito allo stesso stato descritto nel manifesto:
# installa i pacchetti mancanti, i flatpak mancanti, aggiunge i
# repository mancanti, riabilita i servizi mancanti.
#
# USO (da lanciare DENTRO la VM/sistema da ripristinare, con la cartella
# del manifesto raggiungibile, es. via cartella condivisa):
#
#   ./ripristina.sh /percorso/al/manifest
#
# Lo script è pensato per essere eseguito passo dopo passo, con conferma,
# non alla cieca: mostra sempre COSA sta per fare prima di farlo.

set -uo pipefail

MANIFEST_DIR="${1:?Indica il percorso della cartella manifest da cui ripristinare}"

if [[ ! -d "$MANIFEST_DIR" ]]; then
    echo "Errore: la cartella '$MANIFEST_DIR' non esiste." >&2
    exit 1
fi

echo "==========================================================="
echo "  RIPRISTINO SISTEMA DA MANIFESTO"
echo "  Sorgente: $MANIFEST_DIR"
echo "==========================================================="
echo

# -----------------------------------------------------------------------------
# 1. Repository di terze parti (van fatti PRIMA dei pacchetti, altrimenti
#    dnf non troverebbe i pacchetti che vengono da quei repo)
# -----------------------------------------------------------------------------
if [[ -d "$MANIFEST_DIR/repos" ]]; then
    echo "--- Repository da aggiungere ---"
    for f in "$MANIFEST_DIR"/repos/*.repo; do
        [[ -e "$f" ]] || continue
        base="$(basename "$f")"
        dest="/etc/yum.repos.d/$base"
        if [[ -f "$dest" ]]; then
            echo "  [già presente] $base"
        else
            echo "  [da aggiungere] $base"
        fi
    done
    echo
    read -p "Copiare i repository mancanti in /etc/yum.repos.d/? [y/N] " RISP
    if [[ "$RISP" == "y" || "$RISP" == "Y" ]]; then
        for f in "$MANIFEST_DIR"/repos/*.repo; do
            [[ -e "$f" ]] || continue
            base="$(basename "$f")"
            dest="/etc/yum.repos.d/$base"
            if [[ ! -f "$dest" ]]; then
                sudo cp "$f" "$dest"
                echo "  copiato: $base"
            fi
        done
        sudo dnf makecache
    fi
    echo
fi

# -----------------------------------------------------------------------------
# 2. Pacchetti RPM mancanti
# -----------------------------------------------------------------------------
if [[ -f "$MANIFEST_DIR/packages-rpm.txt" ]]; then
    echo "--- Calcolo pacchetti RPM mancanti ---"
    PACCHETTI_ATTUALI=$(rpm -qa --qf '%{NAME}\n' | sort -u)
    PACCHETTI_MANCANTI=$(comm -13 <(echo "$PACCHETTI_ATTUALI") <(sort -u "$MANIFEST_DIR/packages-rpm.txt"))
    NUM_MANCANTI=$(echo "$PACCHETTI_MANCANTI" | grep -c .)

    echo "  Pacchetti mancanti trovati: $NUM_MANCANTI"
    echo

    if [[ "$NUM_MANCANTI" -gt 0 ]]; then
        echo "$PACCHETTI_MANCANTI" > /tmp/pacchetti-da-installare.txt
        echo "  Elenco salvato in: /tmp/pacchetti-da-installare.txt"

        # -------------------------------------------------------------------
        # 2b. Pacchetti "*-release" (es. rpmfusion-free-release): questi
        #     pacchetti portano con sé le chiavi GPG dei rispettivi
        #     repository. Se li installiamo insieme a tutto il resto, dnf
        #     si rifiuta di verificarli perché la chiave non esiste ancora
        #     (problema dell'uovo e della gallina). Vanno quindi installati
        #     PRIMA, singolarmente, con --nogpgcheck.
        # -------------------------------------------------------------------
        PACCHETTI_RELEASE=$(grep -- '-release$' /tmp/pacchetti-da-installare.txt || true)
        if [[ -n "$PACCHETTI_RELEASE" ]]; then
            echo
            echo "  Trovati pacchetti *-release (portano le chiavi GPG dei repo):"
            echo "$PACCHETTI_RELEASE" | sed 's/^/    /'
            read -p "  Installarli ora per primi, senza verifica GPG (necessario)? [y/N] " RISP_REL
            if [[ "$RISP_REL" == "y" || "$RISP_REL" == "Y" ]]; then
                sudo dnf install -y --nogpgcheck $PACCHETTI_RELEASE
            fi
        fi

        echo
        read -p "Installare ora tutti gli altri pacchetti con dnf? [y/N] " RISP
        if [[ "$RISP" == "y" || "$RISP" == "Y" ]]; then
            if ! sudo dnf install -y --skip-unavailable $(cat /tmp/pacchetti-da-installare.txt); then
                echo
                echo "  ATTENZIONE: l'installazione è fallita, probabilmente per un"
                echo "  CONFLITTO DI FILE tra due pacchetti simili (es. dizionari"
                echo "  hunspell-en vs hunspell-en-XX, o pacchetti equivalenti)."
                echo "  Leggi il messaggio di dnf qui sopra: di solito indica quale"
                echo "  pacchetto rimuovere con 'sudo dnf remove -y nome-pacchetto'"
                echo "  prima di rilanciare questo script."
            fi
        fi
    fi
    echo
fi

# -----------------------------------------------------------------------------
# 3. Flatpak mancanti
# -----------------------------------------------------------------------------
if [[ -f "$MANIFEST_DIR/flatpaks.txt" ]] && command -v flatpak >/dev/null 2>&1; then
    echo "--- Calcolo Flatpak mancanti ---"
    FLATPAK_ATTUALI=$(flatpak list --app --columns=application 2>/dev/null | sort -u)
    FLATPAK_MANCANTI=$(comm -13 <(echo "$FLATPAK_ATTUALI") <(sort -u "$MANIFEST_DIR/flatpaks.txt"))
    NUM_MANCANTI_FP=$(echo "$FLATPAK_MANCANTI" | grep -c .)

    echo "  Flatpak mancanti trovati: $NUM_MANCANTI_FP"
    if [[ "$NUM_MANCANTI_FP" -gt 0 ]]; then
        echo "$FLATPAK_MANCANTI"
        echo
        read -p "Installare ora questi Flatpak (da flathub)? [y/N] " RISP
        if [[ "$RISP" == "y" || "$RISP" == "Y" ]]; then
            for app in $FLATPAK_MANCANTI; do
                flatpak install -y flathub "$app"
            done
        fi
    fi
    echo
fi

# -----------------------------------------------------------------------------
# 4. Servizi systemd da riabilitare (mostrati solo, non abilitati alla cieca:
#    abilitare un servizio senza sapere perché era attivo può essere rischioso)
# -----------------------------------------------------------------------------
if [[ -f "$MANIFEST_DIR/systemd-enabled-system.txt" ]]; then
    echo "--- Servizi di sistema mancanti (solo elenco, da valutare a mano) ---"
    SERVIZI_ATTUALI=$(systemctl list-unit-files --state=enabled --no-legend 2>/dev/null | awk '{print $1}' | sort -u)
    SERVIZI_MANCANTI=$(comm -13 <(echo "$SERVIZI_ATTUALI") <(sort -u "$MANIFEST_DIR/systemd-enabled-system.txt"))
    echo "$SERVIZI_MANCANTI"
    echo "  (per abilitarne uno: sudo systemctl enable --now nome-servizio)"
    echo
fi

# -----------------------------------------------------------------------------
# 5. Impostazioni desktop (dconf): sfondo, temi, scorciatoie, tutto quanto.
#    A differenza delle altre sezioni, qui applichiamo l'INTERO dump, non un
#    confronto differenziale: dconf load è pensato per essere idempotente
#    (puoi applicarlo più volte senza danni) e coprire tutto in un colpo solo
#    è più semplice ed efficace che tentare un confronto voce per voce.
# -----------------------------------------------------------------------------
if [[ -f "$MANIFEST_DIR/dconf-dump.txt" ]] && command -v dconf >/dev/null 2>&1; then
    echo "--- Impostazioni desktop (dconf: sfondo, temi, scorciatoie, ecc.) ---"
    read -p "Applicare ORA tutte le impostazioni dconf salvate? [y/N] " RISP
    if [[ "$RISP" == "y" || "$RISP" == "Y" ]]; then
        dconf load / < "$MANIFEST_DIR/dconf-dump.txt"
        echo "  Impostazioni dconf applicate. Potrebbe servire un logout/login"
        echo "  perché tutti i cambiamenti (es. sfondo) siano visibili subito."
    fi
    echo
fi

# -----------------------------------------------------------------------------
# 6. Alias e funzioni bash (.bashrc): non sovrascriviamo mai automaticamente,
#    dato che il .bashrc della VM/sistema nuovo potrebbe avere righe di
#    sistema diverse. Mostriamo solo un diff e lasciamo decidere all'utente.
# -----------------------------------------------------------------------------
if [[ -f "$MANIFEST_DIR/bashrc" ]]; then
    echo "--- Confronto .bashrc salvato vs .bashrc attuale ---"
    if diff -q "$MANIFEST_DIR/bashrc" "$HOME/.bashrc" >/dev/null 2>&1; then
        echo "  Nessuna differenza, il .bashrc è già identico."
    else
        echo "  Il .bashrc salvato è diverso da quello attuale."
        read -p "  Sostituire il .bashrc attuale con quello salvato? [y/N] " RISP
        if [[ "$RISP" == "y" || "$RISP" == "Y" ]]; then
            cp "$HOME/.bashrc" "$HOME/.bashrc.prima-del-ripristino"
            cp "$MANIFEST_DIR/bashrc" "$HOME/.bashrc"
            echo "  Fatto. Backup del vecchio .bashrc salvato come"
            echo "  ~/.bashrc.prima-del-ripristino"
            echo "  Lancia 'source ~/.bashrc' per applicarlo subito."
        fi
    fi
    echo
fi

echo "==========================================================="
echo "  RIPRISTINO GUIDATO COMPLETATO"
echo "  Ricorda di controllare manualmente:"
echo "  - dconf-dump.txt (impostazioni desktop)"
echo "  - etc-tracked/ (connessioni di rete, samba, moduli kernel)"
echo "  - config-dirs-list.txt (cartelle di configurazione da valutare)"
echo
echo "  Casi noti che possono restare 'mancanti' legittimamente:"
echo "  - Pacchetti installati da .rpm scaricato a mano (non da repo):"
echo "    vanno reinstallati manualmente scaricando di nuovo il file .rpm."
echo "  - Conflitti tra pacchetti simili (es. dizionari hunspell-en vs"
echo "    varianti regionali): risolvi rimuovendo il pacchetto generico"
echo "    in conflitto, poi rilancia questo script."
echo "==========================================================="
