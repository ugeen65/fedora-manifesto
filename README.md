# fedora-manifesto

Un piccolo toolkit di script bash per tenere traccia automaticamente di
tutto ciò che rende la tua installazione Fedora diversa da una pulita:
pacchetti RPM, app Flatpak, repository di terze parti, impostazioni
desktop (dconf), servizi systemd, alcune configurazioni di rete, e il tuo
`.bashrc`.

L'obiettivo: se un giorno reinstalli Fedora (o passi a un PC nuovo), sai
esattamente cosa reinstallare e riconfigurare, invece di andare a memoria.

Vedi [VADEMECUM.md](VADEMECUM.md) per la spiegazione completa di come
funziona e come usarlo.

## Componenti

| File | A cosa serve |
|---|---|
| `aggiorna-manifesto.sh` | Rilegge lo stato del sistema, aggiorna `manifest/`, fa un commit git |
| `snapshot.sh` | Cattura una tantum lo stato di un sistema, per confronti puntuali |
| `confronta.sh` | Confronta due snapshot e genera un report delle differenze |
| `ripristina.sh` | Legge il manifesto e prova a portare un sistema pulito allo stesso stato |
| `backup-manifesto.sh` | Crea un backup `.tar.gz` di tutto il progetto, con rotazione |
| `fedora-manifesto-etc-snapshot.sh` | Script root-owned per tracciare in sicurezza alcuni file sensibili di `/etc` |
| `bashrc-snippet.sh` | Wrapper `dnfi`/`flatpaki` da aggiungere al tuo `.bashrc` |
| `sudoers-fedora-manifesto.example` | Esempio di regola sudoers per l'esecuzione sicura senza password |
| `mc-menu-personalizzato` | Voci extra per Midnight Commander: cifra/decifra con 7z (AES-256) |

## Avvio rapido

```bash
git clone <url-di-questo-repo> ~/fedora-manifesto
cd ~/fedora-manifesto
chmod +x *.sh

# Primo aggiornamento del manifesto
./aggiorna-manifesto.sh "Primo manifesto"

# Aggiungi i wrapper dnfi/flatpaki al tuo .bashrc
cat bashrc-snippet.sh >> ~/.bashrc
source ~/.bashrc
```

Per il tracciamento sicuro di `/etc` (connessioni di rete, moduli kernel,
samba), segui le istruzioni dentro `sudoers-fedora-manifesto.example`.

## ⚠️ Attenzione: dati sensibili

Le connessioni NetworkManager tracciate da `fedora-manifesto-etc-snapshot.sh`
possono contenere **password Wi-Fi/VPN in chiaro**. Se sincronizzi il tuo
manifesto (la cartella `manifest/`, che va tenuta **separata** da questo
repository di script) su un servizio cloud o un repository condiviso,
cifra quel file prima — vedi la sezione dedicata nel vademecum per usare
7z con password come alternativa più semplice di GPG.

## Licenza

GNU General Public License v3.0 — vedi [LICENSE](LICENSE).

## Nota sullo sviluppo

Questo progetto è stato sviluppato con l'assistenza di un assistente IA
(Claude, Anthropic), ma ogni componente è stato progettato, testato e
rivisto manualmente: incluso un vero ciclo di test end-to-end su una VM
clonata (installazione pacchetti, Flatpak, impostazioni desktop, bashrc),
con bug reali scoperti e corretti nel processo (gestione chiavi GPG dei
repository, conflitti tra pacchetti, comportamento dei menu di Midnight
Commander). Il codice è compreso e mantenuto attivamente, non generato e
pubblicato senza revisione.
