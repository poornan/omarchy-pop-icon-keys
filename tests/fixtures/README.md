# Test fixtures

One folder per profile (`profiles/<slug>.json`), each with three `solaar show
"<keyboard>"` outputs the status tests feed to `bin/logitech-keys-status`:

| File | Keyboard state |
|---|---|
| `routed.txt` | Every mapped key diverted, both saved and live |
| `dropped.txt` | Saved settings divert the keys, the keyboard reports them Regular (after sleep or reconnect) |
| `not-setup.txt` | Some mapped keys not diverted in the saved settings (setup needed), some dropped |

Serial numbers and unit ids are masked as `00000000`.

- **`pop-icon-keys/`** — recorded from a real POP Icon Keys with Solaar 1.1.20
  (Bolt receiver, Linux OS mode). `not-setup.txt`: Show Desktop and Dictation
  not saved; MultiPlatform Search, Emoji and Screen Capture dropped.
- **`mx-keys-mac/`** — **synthetic**. Written by hand in Solaar 1.1.20's
  format, using the key names in Solaar's key table and the model id Solaar
  saved for a real MX Keys for Mac. Not recorded from the keyboard; replace
  with recorded output once someone tests it. `not-setup.txt`: Screen
  Capture/Print Screen not saved; Screen Lock and Calculator dropped.
