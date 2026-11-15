# Changelog

Tutte le modifiche rilevanti di Dillo sono annotate in questo file.

Il formato segue [Keep a Changelog](https://keepachangelog.com/it/1.1.0/)
e il progetto adotta il [Versionamento Semantico](https://semver.org/lang/it/).

## [Non ancora rilasciato]

### Modificato
- Il tasto di dettatura si può usare ancora per scrivere: se insieme a ⌥ premi un altro tasto (⌥ò per @, ⌥à per #…),
  la dettatura viene annullata senza suoni né indicatore. Anche i tocchi più brevi di un quarto di secondo vengono ignorati.
- In modalità «premi per avviare e fermare» la dettatura parte al rilascio del tasto, così le combinazioni non la attivano.
- Il motore audio viene riusato tra una dettatura e l'altra finché il microfono non cambia: l'avvio è più rapido.
- L'elenco dei microfoni si aggiorna da solo quando colleghi o scolleghi un dispositivo.
- Panoramica e Dizionario non ricalcolano più le statistiche sull'intera cronologia a ogni aggiornamento.
- Il dizionario viene compilato una sola volta e ricompilato solo quando cambia.
- Il codice adotta l'isolamento predefinito sul main actor di Swift 6.2; la CI usa le versioni più recenti delle azioni GitHub.

### Corretto
- Nelle Impostazioni non si poteva scegliere un microfono diverso da quello predefinito: le voci del menu apparivano disattivate.
- Dall'elenco dei microfoni sparisce il dispositivo interno «CADefaultDeviceAggregate», che non è un microfono vero.
- Lettura dei callback audio protetta da un lock: niente più accessi concorrenti tra il thread audio e l'interfaccia.

## [1.1.0] — 2026-11-14

Prima versione pubblica, come anteprima: il DMG non è ancora notarizzato da Apple.

### Aggiunto
- Dillo diventa open source con licenza MIT.
- Guida per contribuire, codice di condotta, policy di sicurezza, modelli per issue e pull request.
- Integrazione continua su GitHub Actions: build, test e controllo dei warning su ogni pull request.
- Firma configurabile tramite `Config/Signing.local.xcconfig`, per compilare con il proprio account Apple.
- Barra laterale espandibile con le etichette delle pagine; si compatta da sola nelle finestre strette.
- Menu **Vai** con ⌘1, ⌘2, ⌘3 per passare tra Panoramica, Cronologia e Dizionario; ⌃⌘S per la barra laterale.
- Calendario dell'attività sull'intero anno (gennaio–dicembre), con selettore dell'anno e dettaglio del giorno.

### Modificato
- Impostazioni ridisegnate: sezioni nella barra laterale (Generale, Dettatura, Modello, Permessi, Dati e privacy,
  Informazioni) e righe con valore attuale e pulsante «Cambia».
- Guida al primo avvio ridisegnata: titolo grande, illustrazione con il tasto, passi con etichette,
  note su privacy e permessi, pulsante principale ben visibile e «Configura più tardi».
- Controllo di dettatura più chiaro (tasto disegnato, timer e livello durante la registrazione).
- Campi di testo e pulsanti con uno stile proprio e coerente; contenuto centrato sugli schermi grandi.
- Voce «Guida» nella barra laterale.
- Il pulsante della barra laterale si trova accanto ai pulsanti della finestra, come nelle app di sistema.
- Panoramica e Dizionario ridisegnati; le varianti del dizionario vengono ripulite da duplicati e voci vuote.
- Il logo nella barra laterale è disegnato in vettoriale, così è sempre aggiornato e nitido.
- Gli screenshot dimostrativi non mostrano più il nome dell'utente né gli avvisi sui permessi.
- La versione di FluidAudio è fissata (0.18.3) per build riproducibili; il progetto Xcode generato non è più versionato.

### Corretto
- La conversione dell'audio è compatibile con la concorrenza stretta delle SDK più recenti.
- Il suggerimento di scorrimento del calendario non copre più le celle.

## [1.0.0] — 2026-11-14

Prima versione (non distribuita).

### Aggiunto
- Dettatura push-to-talk in qualsiasi app, con scorciatoia globale configurabile e annullamento con Esc.
- Due motori on-device: Apple Speech (streaming, predefinito) e Parakeet v3 (25 lingue europee).
- Anteprima dal vivo nell'indicatore flottante, con comparsa morbida parola per parola.
- Dizionario personale con suggerimenti al riconoscimento e correzioni automatiche.
- Cronologia ricercabile, con copia ed esportazione in Markdown e CSV.
- Panoramica con parole al minuto, app più usate, giorni consecutivi e calendario dell'attività.
- Scelta del microfono, inclusi i dispositivi virtuali, e avviso di microfono muto.
- Proposta di cambio lingua quando detti in un'altra lingua.
- Pettirosso animato nella barra dei menu e guida introduttiva al primo avvio.
- Impostazioni per conservazione, esportazione ed eliminazione dei dati.

[Non ancora rilasciato]: https://github.com/Sferralove/dillo/compare/v1.1.0...HEAD
[1.1.0]: https://github.com/Sferralove/dillo/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/Sferralove/dillo/releases/tag/v1.0.0
