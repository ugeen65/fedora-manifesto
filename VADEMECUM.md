# Vademecum — Sistema di gestione configurazione Fedora 44

## A cosa serve questo progetto

Quando installi Fedora da zero, il sistema "pulito" non ha nessuna delle tue
app, impostazioni, configurazioni di rete o personalizzazioni. Ricostruire
tutto a mano dopo una reinstallazione (o su un PC nuovo) è lento e si
dimenticano sempre dei pezzi.

Questo progetto tiene traccia automaticamente di **tutto ciò che rende il tuo
sistema diverso da un'installazione pulita**: pacchetti installati, app
Flatpak, repository di terze parti, impostazioni desktop, servizi attivi,
alcune configurazioni di rete. Lo fa in modo continuo, senza che tu debba
ricordarti di fare nulla nella maggior parte dei casi.

In caso di reinstallazione, questi dati permettono di sapere esattamente
cosa reinstallare e riconfigurare — invece di andare a memoria.

---

## I componenti del sistema

Tutto vive nella cartella `~/fedora-manifesto/`.

| File / cartella | A cosa serve |
|---|---|
| `manifest/` | Lo stato **attuale** del sistema: pacchetti, repo, impostazioni, ecc. Viene sovrascritto ad ogni aggiornamento. |
| `.git/` | Lo storico di **com'è cambiato** il manifesto nel tempo, un commit per ogni modifica. |
| `aggiorna-manifesto.sh` | Lo script che rilegge lo stato del sistema, aggiorna `manifest/` e fa il commit git. È il cuore del sistema. |
| `snapshot.sh` | Cattura **una tantum** lo stato di un sistema in una cartella a sé, usato per confronti puntuali (es. VM pulita vs sistema reale). |
| `confronta.sh` | Confronta due snapshot e genera un report delle differenze (`diff-report-.../`). |
| `backup-manifesto.sh` | Crea un archivio `.tar.gz` di tutta la cartella `fedora-manifesto` (script + manifesto + storico git), con rotazione automatica degli ultimi 10 backup. |
| `/usr/local/sbin/fedora-manifesto-etc-snapshot.sh` | Script di proprietà di root che copia alcuni file sensibili di `/etc` (connessioni di rete, moduli kernel, samba) nel manifesto. Eseguibile senza password grazie a una regola dedicata in `/etc/sudoers.d/fedora-manifesto`. |

---

## Come si aggiorna il manifesto: tre modi

### 1. Automaticamente, quando installi qualcosa (il modo normale)

Invece dei comandi normali, usa questi wrapper (funzioni definite in `~/.bashrc`):

```bash
dnfi install nome-pacchetto
dnfi remove nome-pacchetto
dnfi upgrade
dnfi update
dnfi autoremove
dnfi reinstall nome-pacchetto
dnfi downgrade nome-pacchetto
dnfi distro-sync
dnfi group install "nome gruppo"
dnfi swap pacchetto-vecchio pacchetto-nuovo

flatpaki install nome-app
flatpaki uninstall nome-app
flatpaki update
```

`dnfi` copre ormai tutti i sottocomandi dnf che modificano lo stato del
sistema. Comandi di sola lettura (`search`, `info`, `list`, ecc.) funzionano
normalmente ma **non** aggiornano il manifesto, giustamente.

Fanno esattamente la stessa cosa del comando originale, ma se l'operazione
va a buon fine aggiornano subito il manifesto e fanno un commit git con un
messaggio tipo `dnfi: install firefox`.

### 2. Automaticamente, una volta a settimana (rete di sicurezza)

Un timer di sistema (`systemctl --user list-timers`) lancia
`aggiorna-manifesto.sh` ogni lunedì mattina, così vengono comunque catturati
i cambiamenti fatti senza passare dai wrapper — per esempio un'app Flatpak
installata dal Software Center grafico.

### 3. Manualmente, quando vuoi

```bash
esegui-aggiorna-manifesto "un messaggio a piacere per il commit"
```

Utile se vuoi forzare un aggiornamento subito, senza aspettare il lunedì.

---

## Alias utili da ricordare

| Comando | Cosa fa |
|---|---|
| `dnfi install pacchetto` | Installa un pacchetto RPM e aggiorna il manifesto |
| `flatpaki install app` | Installa un Flatpak e aggiorna il manifesto |
| `esegui-aggiorna-manifesto "msg"` | Forza un aggiornamento manuale del manifesto |
| `edita-aggiorna-manifesto` | Apre lo script principale per modificarlo |
| `backup-manifesto` | Crea un backup `.tar.gz` di tutto il progetto |
| `mb` | Apre il tuo `.bashrc` per modificarlo |

---

## Come consultare lo storico

Dentro `~/fedora-manifesto/`:

```bash
git log --oneline          # elenco di tutti gli aggiornamenti nel tempo
git show HEAD               # cosa è cambiato nell'ultimo aggiornamento
git log -p -- manifest/packages-rpm.txt   # storia dei pacchetti installati nel tempo
```

---

## Cosa viene tracciato di preciso

- **Pacchetti RPM** installati (`manifest/packages-rpm.txt`)
- **Gruppi pacchetto** (es. ambienti desktop) (`manifest/package-groups.txt`)
- **App Flatpak** (`manifest/flatpaks.txt`)
- **Repository di terze parti** (RPM Fusion, COPR, ecc.) (`manifest/repos/`)
- **Impostazioni GNOME/dconf** (`manifest/dconf-dump.txt`)
- **Servizi systemd abilitati**, di sistema e utente
- **Crontab e timer utente**
- **Elenco di dotfile e cartelle** in home, `.config`, `.local/share` (solo
  i *nomi*, non il contenuto)
- **File selezionati di `/etc`**: connessioni NetworkManager (Wi-Fi/VPN),
  `/etc/modprobe.d/`, `/etc/sysctl.d/`, `/etc/samba/smb.conf`

⚠️ Nota: il file delle connessioni NetworkManager contiene le password Wi-Fi
**in chiaro**. È una scelta consapevole per semplicità, accettabile solo
perché il repository git è **esclusivamente locale** e non viene mai
condiviso, pubblicato online o sincronizzato su cloud pubblici.

## Cosa NON viene tracciato

- Il contenuto di `/etc` al di fuori della lista sopra (scelta deliberata,
  per evitare di catturare file macchina-specifici come `machine-id`,
  `fstab` con UUID del disco, certificati locali)
- Il contenuto dei file dentro `.config`/`.local/share` (solo l'elenco dei
  nomi delle cartelle, non i file dentro)

---

## Backup e ripristino

### Fare un backup

```bash
backup-manifesto
```

Crea un archivio in `~/Backup/fedora-manifesto/fedora-manifesto-AAAA-MM-GG_HHMM.tar.gz`.
Vengono mantenuti automaticamente solo gli ultimi 10 backup.

### Ripristinare da un backup

In caso di reinstallazione o rottura del sistema:

```bash
tar xzf /percorso/fedora-manifesto-AAAA-MM-GG_HHMM.tar.gz -C ~/
```

Questo ricrea `~/fedora-manifesto/` con tutto lo storico git intatto.

⚠️ **Importante**: `backup-manifesto` salva solo la cartella `fedora-manifesto`
sul disco locale. Non protegge da un guasto del disco stesso: copia
periodicamente questi archivi anche su una chiavetta USB, un disco esterno,
o uno dei tuoi cloud (hai già rclone configurato per pcloud/mega/ecc.).

---

## Come nasce un confronto completo (es. dopo una reinstallazione)

1. Prepara una VM con Fedora pulita (stessa versione/spin), o usa direttamente
   il sistema appena reinstallato
2. Lancia `snapshot.sh nome-riferimento` sul sistema pulito
3. Copia la cartella dello snapshot sul sistema con cui vuoi confrontare
   (o usa direttamente `manifest/` del vecchio sistema, se disponibile da backup)
4. Lancia `confronta.sh cartella-pulita cartella-configurato`
5. Il report finale (`diff-report-.../`) elenca pacchetti, flatpak, repo e
   servizi da (re)installare per riportare il sistema pulito allo stato
   precedente

---

## Cambio layout tastiera (italiano / inglese)

Alias disponibili in `~/.bashrc` (vedi `bashrc-snippet.sh`):

| Alias | Uso |
|---|---|
| `italiano` | Layout italiano, **sessione grafica** |
| `inglese` | Layout US, **sessione grafica** |
| `italianotty` | Layout italiano, **solo console TTY reale** |
| `inglesetty` | Layout US, **solo console TTY reale** |

**Due contesti diversi, due comandi diversi:**

- `italiano`/`inglese` usano `gsettings` (`org.gnome.desktop.input-sources`)
  e funzionano correttamente nella sessione grafica GNOME/Wayland,
  applicandosi a tutte le app (native Wayland e Xwayland). Il vecchio
  `setxkbmap`, usato da solo, cambia il layout solo a metà (agisce solo
  sul layer X11/Xwayland, non su Wayland nativo).

- `italianotty`/`inglesetty` usano `loadkeys` e vanno usati **solo** da
  una vera console virtuale (Ctrl+Alt+F3, F4, ecc.), **mai** da un
  terminale grafico — altrimenti danno errore (`unknown keysym
  'trademark'`), un bug noto di `loadkeys` sotto sessioni X/Wayland.

*Dentro il desktop grafico → `italiano`/`inglese`. Bloccato in console
nera senza grafica → `italianotty`/`inglesetty`.*

---

## Cifratura manuale con 7z (via menu utente di mc)

Per proteggere file sensibili (es. il backup prima di caricarlo su cloud)
senza la complessità di GPG, sono state aggiunte due voci personalizzate al
menu utente di Midnight Commander, salvate in `~/.config/mc/menu` (copia di
backup in `~/fedora-manifesto/mc-menu-personalizzato`).

**Come cifrare una cartella:**

1. Dentro `mc`, **entra fisicamente** nella cartella da comprimere (premi
   Invio sulla cartella, non limitarti a selezionarla — lo script agisce
   sulla cartella del pannello, non sull'elemento evidenziato al suo interno)
2. Premi **F2**, scegli `p - Compress the current subdirectory with
   password (7z, AES-256)`
3. Scrivi il nome del file risultante
4. Scrivi la password (nascosta), poi ripetila per conferma
5. Il file `.7z` cifrato viene creato nella cartella superiore

**Come decifrare:**

1. Seleziona (basta evidenziarlo) il file `.7z`
2. Premi **F2**, scegli `q - Decrypt and extract current .7z file
   (password protected)`
3. Scrivi la password
4. Viene creata una cartella `nomefile_decriptato_AAAA-MM-GG_HHMM`

**Note tecniche:**

- Usa `-mhe=on`: cifra anche i **nomi dei file** dentro l'archivio, non
  solo il contenuto.
- AES-256 è robusto: il punto debole è sempre la password scelta, non
  l'algoritmo. Usare password lunghe (12+ caratteri) e non banali.
- Attenzione ai simboli `%` nei menu di `mc`: vengono pre-processati da
  `mc` stesso prima di essere passati allo script (es. `%d` ha un
  significato speciale). Per usarlo letteralmente (es. dentro
  `date +%Y-%m-%d`), va raddoppiato: `date +%%Y-%%m-%%d`.

---

## Test di ripristino: esperienza reale e casi noti

Questo sistema è stato testato con un vero ciclo end-to-end: VM pulita
clonata, manifesto di un sistema reale trasferito, `ripristina.sh`
lanciato. Risultato tipico: la stragrande maggioranza dei pacchetti si
installa correttamente in automatico, così come i Flatpak, dconf e il
bashrc. Alcuni casi restano "mancanti" per motivi legittimi, elencati
sotto — non sono bug, sono limiti intrinseci di cosa un package manager
può fare da solo.

**Casi noti che restano "mancanti" legittimamente:**

- **Pacchetti installati da file `.rpm` scaricato a mano** (non da un
  repository configurato), es. UpNote: `dnf` non li trova per definizione,
  dato che non sono in nessun repository. Vanno reinstallati manualmente
  riscaricando il file `.rpm` originale.

- **Conflitti di file tra pacchetti simili**, es. `hunspell-en` (dizionario
  inglese generico) vs `hunspell-en-CA`/`hunspell-en-AU` (varianti
  regionali): `dnf` rifiuta l'installazione perché i pacchetti vogliono
  scrivere file negli stessi percorsi. Soluzione: rimuovere il pacchetto
  generico in conflitto (`sudo dnf remove nome-pacchetto`) prima di
  rilanciare l'installazione.

- **Pacchetti `*-release`** (es. `rpmfusion-free-release`): portano con sé
  la chiave GPG del relativo repository. Se il file `.repo` viene copiato
  manualmente (come fa questo sistema) senza passare dal pacchetto
  `-release`, la chiave GPG non esiste ancora e `dnf` si rifiuta di
  verificare persino il pacchetto che dovrebbe installarla.
  `ripristina.sh` gestisce questo caso automaticamente, installando i
  pacchetti `*-release` per primi con `--nogpgcheck`.

---

## Riepilogo in una frase

*"Ogni volta che installo qualcosa con `dnfi` o `flatpaki`, o ogni lunedì,
il sistema si fotografa da solo e salva la foto nella cronologia git — così
non perdo mai traccia di come è fatto il mio sistema."*
