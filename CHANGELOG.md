# Changelog

Tutte le modifiche rilevanti di Dillo sono annotate in questo file.

Il formato segue [Keep a Changelog](https://keepachangelog.com/it/1.1.0/)
e il progetto adotta il [Versionamento Semantico](https://semver.org/lang/it/).

## [Non ancora rilasciato]

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

## [1.0.0] — 2026-11-14

Prima versione.

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

[Non ancora rilasciato]: https://github.com/Sferralove/dillo/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/Sferralove/dillo/releases/tag/v1.0.0
