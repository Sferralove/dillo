# Sicurezza

## Versioni supportate

| Versione | Supportata |
|---|---|
| 1.x | ✅ |

## Segnalare una vulnerabilità

**Non aprire una issue pubblica.** Usa la segnalazione privata di GitHub:
[Security → Report a vulnerability](https://github.com/Sferralove/dillo/security/advisories/new).

Includi, se puoi: versione di Dillo e di macOS, descrizione del problema, passi per riprodurlo e impatto potenziale.
Riceverai una risposta entro pochi giorni. Una volta corretto il problema, la segnalazione sarà resa pubblica
riconoscendo il tuo contributo, se lo desideri.

## Modello di sicurezza

Dillo gestisce dati sensibili (la tua voce e ciò che detti), per questo:

- **Audio solo in memoria**: non viene mai scritto su disco né inviato in rete.
- **Trascrizione on-device**: Apple Speech e Parakeet girano localmente.
- **Rete**: usata solo per scaricare i modelli (macOS per Apple Speech, Hugging Face per Parakeet).
- **Dati locali**: cronologia e dizionario in `~/Library/Application Support/Dillo/`, leggibili solo dal tuo utente.
- **Permessi**: Microfono (dettatura) e Accessibilità (scorciatoia globale e incolla). Senza sandbox, perché il
  Mac App Store non consente di inviare eventi da tastiera ad altre app; le build ufficiali sono firmate
  Developer ID, con hardened runtime, e notarizzate da Apple.
- **Appunti**: per incollare, il testo passa per un istante negli appunti, che poi vengono ripristinati al contenuto precedente.
