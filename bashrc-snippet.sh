# bashrc-snippet.sh
#
# Aggiungi queste funzioni al tuo ~/.bashrc per far sì che le installazioni
# "consapevoli" tramite dnf/flatpak aggiornino subito il manifesto.
#
# Percorso atteso: ~/fedora-manifesto/aggiorna-manifesto.sh
# Modifica il percorso qui sotto se hai clonato il repository altrove.

dnfi() {
    sudo dnf "$@"
    local status=$?
    case "$1" in
        install|remove|upgrade|update|autoremove|reinstall|downgrade|distro-sync|group|groupinstall|groupremove|groupupdate|swap)
            if [[ $status -eq 0 ]]; then
                local pacchetti="${*:2}"
                ~/fedora-manifesto/aggiorna-manifesto.sh "dnfi: $1 $pacchetti"
            fi
            ;;
    esac
    return $status
}

flatpaki() {
    flatpak "$@"
    local status=$?
    if [[ $status -eq 0 ]] && [[ "$1" == "install" || "$1" == "uninstall" || "$1" == "update" ]]; then
        local pacchetti="${*:2}"
        ~/fedora-manifesto/aggiorna-manifesto.sh "flatpaki: $1 $pacchetti"
    fi
    return $status
}

# Comodo per forzare un aggiornamento manuale del manifesto quando serve:
alias esegui-aggiorna-manifesto='~/fedora-manifesto/aggiorna-manifesto.sh'
