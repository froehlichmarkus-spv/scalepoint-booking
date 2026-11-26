# BookDesk24 · Scorecard Schritt 2 (DS v2)

Stand: 26. Nov 2026. Branch `feat/bookdesk24-ds-v2`. Live-Shots in `after/`. Ziel ist 9. Was darunter liegt, steht so da.

| Kriterium | Score | Warum |
|---|---|---|
| 1 Visual | 6 | Shell und Auth nutzen Geist, Navy und `data-m="booking"`. Die Übersicht behält den alten Verlaufsbanner und die alte Kartenanordnung. Auth ist eine Karte auf hellem Grund, nicht das Split-Layout mit Proof-Panel. |
| 2 Consistency | 5 | Tokens und `gos.css` sind eingebunden. Hex bleibt in den Theme-CSS und in `tokens.phoenix.css` (Kopie, nicht von Hand geändert). Die meisten `hero-`-Icons ausserhalb von Shell und Auth sind noch da. Inter und DM Serif liegen weiter in `priv/static/fonts`. |
| 3 Usability | 8 | Login, Signup, Passwort vergessen, Link gesendet, Verifizieren, Erfolg und der Login-Fehler sind erreichbar. Google/Microsoft nur, wenn ein Admin den Provider einschaltet. |
| 4 Accessibility | 7 | Skip-Link, Fokus-Ring aus dem DS, lesbare Sidebar nach dem Kontrast-Fix. Kein neuer axe-Lauf in diesem Schritt. |
| 5 States | 5 | Login-Fehler und Passwort-Erfolg sind geschossen. Skeleton, Empty, Permission, Magic Link, Lock mit Countdown und Session-expired-Modal fehlen. Magic Link gibt es im Stack nicht. |
| 6 Microcopy | 7 | Kein formelles `Sie`/`Ihr`/`Ihnen` mehr als Anrede. 179 Treffer von `rg -i "\b(sie|ihr|ihnen)\b"` bleiben, alle dritte Person oder Platzhalter, Liste unten. Einzelne Imperative sind holprig („Hake ab“). |
| 7 Mobile | 7 | Shots bei 390 für Shell und die Auth-Zustände. Das Bottom-Sheet der Buchungsseite ist dieser Schritt nicht. |
| 8 Perceived performance | 7 | In diesem Schritt nicht neu gemessen. |
| 9 Polish | 6 | Logo-Zeile bricht („BookDesk24“ / „by“), Verlaufsbanner, alte Karten. |
| 10 Trust | 8 | Navy als Primärbutton, Passwortregel 8 Zeichen und 72 Byte sichtbar, Legal-Links auf `/growthos/legal/*`. |
| 11 Emails | 4 | Die 12 Prioritäts-Mails liegen noch auf dem MJML-Rahmen, nicht auf `email/base.html`. |

## Verbleibende `sie` / `ihr` / `ihnen`

Kein Treffer ist die formelle Anrede. Die fünf grossgeschriebenen `Sie` sind Satzanfang für eine Sache („Sie bleibt veröffentlicht“, die Seite; „Sie bleiben in deinem Kalender“, die Buchungen). Der Rest ist:

- `sie` = sie/es (die Integration, die Buchung, die Umfrage, die Adresse)
- `ihr` = ihr/dessen (der Termin der Unterhaltung, „was ihr am besten passt“, „Gib ihr einen Namen“, „ihr Stripe-Konto“)
- `ihnen` = ihnen (den Gästen, den Termintypen)
- `dein-nutzername` ersetzt den alten Platzhalter `ihr-name`

`mix gettext.extract --merge` ist gelaufen. msgids sind unverändert. Platzhalter `%{…}` sind stehen geblieben.
