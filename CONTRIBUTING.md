# Contribuire a Dillo

Grazie per l'interesse! Dillo è un progetto open source e ogni contributo è benvenuto:
segnalazioni di bug, idee, traduzioni, documentazione e codice.

> **English speakers welcome.** Issues and pull requests in English are fine — the app UI is
> Italian today, but code comments and discussions can be in either language.

## Indice

- [Prima di iniziare](#prima-di-iniziare)
- [Preparare l'ambiente](#preparare-lambiente)
- [Struttura del progetto](#struttura-del-progetto)
- [Flusso di lavoro](#flusso-di-lavoro)
- [Stile del codice](#stile-del-codice)
- [Test](#test)
- [Interfaccia e marchio](#interfaccia-e-marchio)
- [Segnalare bug e proporre idee](#segnalare-bug-e-proporre-idee)

## Prima di iniziare

- Leggi il [Codice di condotta](CODE_OF_CONDUCT.md).
- Per modifiche importanti (un nuovo motore, una nuova pagina, cambi all'architettura) **apri prima una issue**
  per discuterne: eviti di lavorare su qualcosa che non verrebbe accettato.
- Le piccole correzioni (bug evidenti, refusi, documentazione) possono arrivare direttamente come pull request.
- I problemi di sicurezza non vanno nelle issue pubbliche: vedi [SECURITY.md](SECURITY.md).

## Preparare l'ambiente

Requisiti: macOS 26+, Apple Silicon, Xcode 26+, [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
brew install xcodegen
git clone https://github.com/Sferralove/dillo.git
cd dillo
```

### Firma con il tuo account Apple

Il progetto è configurato con il team del manutentore. Per compilare con il tuo:

```bash
cp Config/Signing.local.xcconfig.example Config/Signing.local.xcconfig
# poi apri il file e imposta il tuo DEVELOPMENT_TEAM
```

`Signing.local.xcconfig` è ignorato da git. Basta un account Apple gratuito.

> Perché serve una firma? macOS concede il permesso **Accessibilità** (necessario per la scorciatoia globale
> e per incollare) a una specifica firma. Con una firma stabile il permesso resta valido tra una build e l'altra.

### Compilare ed eseguire

```bash
xcodegen generate
open Dillo.xcodeproj      # ⌘R in Xcode
```

oppure da terminale:

```bash
xcodebuild -project Dillo.xcodeproj -scheme Dillo -configuration Debug -derivedDataPath build build
open build/Build/Products/Debug/Dillo.app
```

Il progetto Xcode è **generato** da [`project.yml`](project.yml) e non è incluso nel repository:
target, impostazioni, Info.plist ed entitlement si cambiano in `project.yml`, poi `xcodegen generate`.

## Struttura del progetto

```
Dillo/
├── App/        Punto d'ingresso, finestre e comandi, pannello Informazioni, snapshot di debug
├── Core/       DictationController, modelli SwiftData, preferenze, dizionario, statistiche, esportazione
├── Engines/    Protocollo SpeechEngine, AppleSpeechEngine, ParakeetEngine
├── Services/   Microfono, scorciatoia globale, incolla, permessi, rilevamento lingua
└── UI/         Finestra principale, indicatore flottante, barra dei menu, impostazioni, guida, marchio
DilloTests/     Test unitari (Swift Testing)
Branding/       Icona e mascotte (sorgenti Affinity/SVG)
Config/         Configurazione della firma
scripts/        Script di rilascio
```

Il cuore è `DictationController` ([Core/DictationController.swift](Dillo/Core/DictationController.swift)): gestisce
gli stati (caricamento → pronto → registrazione → trascrizione) e coordina microfono, motore, dizionario,
cronologia e incolla. I motori implementano `SpeechEngine` ([Engines/SpeechEngine.swift](Dillo/Engines/SpeechEngine.swift)).

### Aggiungere un motore di trascrizione

1. Crea un tipo conforme a `SpeechEngine` in `Dillo/Engines/` (`prepare`, `begin`, `append`, `finish`).
2. Aggiungi un caso a `EngineKind` in [Core/Preferences.swift](Dillo/Core/Preferences.swift) con titolo, sottotitolo e simbolo.
3. Collega il caso in `DictationController.makeEngine`.
4. Il motore deve funzionare **on-device**: Dillo non invia audio a servizi esterni.

## Flusso di lavoro

1. Fai un fork e crea un ramo dal `main`: `fix/descrizione-breve` o `feature/descrizione-breve`.
2. Fai commit piccoli e mirati, con messaggi chiari all'imperativo (`Corregge l'anteprima quando…`, `Add …`).
3. Esegui i test e verifica che la build sia **senza warning**.
4. Se la modifica è visibile all'utente, aggiungi una riga alla sezione *Non ancora rilasciato* di [CHANGELOG.md](CHANGELOG.md).
5. Apri la pull request compilando il modello. Per modifiche all'interfaccia allega screenshot prima/dopo.

La CI su GitHub compila il progetto ed esegue i test su ogni pull request.

## Stile del codice

- **Swift 6** con concorrenza stretta: niente warning, niente `@unchecked Sendable` senza un commento che spieghi perché è sicuro.
- **SwiftUI** per l'interfaccia, `@Observable` per lo stato. AppKit solo dove serve (pannelli, eventi globali, appunti).
- Nomi chiari e commenti che spiegano il *perché*, non il *cosa*. I commenti esistenti sono in italiano: puoi scrivere in italiano o in inglese.
- Testi dell'interfaccia in italiano, tono diretto e cordiale (“Ti ascolto…”, “Concedi…”).
- Niente dipendenze nuove senza discussione: oggi l'unica è FluidAudio.
- Niente telemetria, analytics o chiamate di rete oltre ai download dei modelli.

## Test

```bash
xcodebuild test -project Dillo.xcodeproj -scheme Dillo -derivedDataPath build
```

I test usano **Swift Testing** (`import Testing`, `@Test`, `#expect`) e coprono la logica pura.
Se correggi un bug in quella logica, aggiungi un test che lo riproduce.
Durante i test l'app non avvia scorciatoie, microfono né modelli (`DilloApp.isRunningTests`).

### Screenshot

Per aggiornare le immagini di `docs/screenshots/` (dati di esempio, nessun dato personale):

```bash
build/Build/Products/Debug/Dillo.app/Contents/MacOS/Dillo -demo -snapshot /tmp/dillo-snap
```

## Interfaccia e marchio

- Palette e tipografia sono in [UI/Theme.swift](Dillo/UI/Theme.swift): usa i token (`Theme.coral`, `Typo.display`) invece di colori e font scritti a mano.
- La mascotte è disegnata da [UI/RobinMark.swift](Dillo/UI/RobinMark.swift) a partire da `Branding/Robin.svg`.
- L'icona si rigenera da `Branding/AppIcon-1024.png` con `zsh Branding/make_icon.sh`.
- Rispetta le preferenze di sistema dove possibile (dimensione del testo, riduzione del movimento, VoiceOver).

## Segnalare bug e proporre idee

Usa i modelli di [GitHub Issues](https://github.com/Sferralove/dillo/issues/new/choose). Per un bug indica:
versione di Dillo e di macOS, modello di Mac, motore e lingua in uso, passi per riprodurre, cosa ti aspettavi e cosa è successo.

Grazie! 🐦
