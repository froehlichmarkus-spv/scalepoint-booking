# BookDesk24 · Scorecard (DS v2, Barrierefreiheit und Buchung)

Stand: 26. Nov 2026. Branch `feat/bookdesk24-ds-v2`. Live-Shots in `after/`. Ziel ist 9. Was darunter liegt, steht so da.

axe-core, nur serious und critical, nach den Kontrast-Fixes: Auth, Übersicht und `/nordlicht/intro` bei 1440 und 390 jeweils 0. Eine echte Buchung (Mara Köhler, 30. November, 12:00) liegt auf der Bestätigungsseite. Die Bestätigungsmail ist in HTML und als Klartext geschossen.

| Kriterium | Score | Warum |
|---|---|---|
| 1 Visual | 8 | Auth zweispaltig, Übersicht mit navy Banner, Buchung und Bestätigung in Folio/Geist. Der Kalender-Button auf der Bestätigung zeigt ein schwarzes Quadrat statt des Kalender-Symbols. |
| 2 Consistency | 7 | Kontrast und die Bestätigungskarte nutzen vorhandene Tokens (`--gos-text-2`, `--gos-text-3`, `--gos-booking-ink`, `--gos-success-ink`). Abstände der Bestätigung kommen aus `--space-*` und `--folio-column`. Hex in den vier gemeldeten CSS-Dateien bleibt ein DS-Request. |
| 3 Usability | 8 | Login bis Fehler, Buchung von Tag über Slot und Formular bis „Termin bestätigt“. Google/Microsoft nur, wenn ein Admin den Provider einschaltet. |
| 4 Accessibility | 9 | axe serious/critical 0 auf Auth, Shell/Übersicht und öffentlicher Buchung, 1440 und 390. Amber-Text am Wortmarkenzeichen ist `--gos-booking-ink`. Fokusring aus Folio, Fehler mit `role="alert"`, Slot-Status für Screenreader. Tab erreicht Tag und Slot (native Buttons). `prefers-reduced-motion` setzt Animation und Transition auf 0,01 ms. |
| 5 States | 8 | Skeleton, leere Zeiten, Fehler mit „Erneut versuchen“, und die Bestätigung nach einer echten Buchung, 1440 und 390. |
| 6 Microcopy | 8 | du, „Termin“ in Bestätigung und Mail. Ein holpriger Imperativ („Hake ab, was du nicht benötigen“) ist korrigiert. Die 179 `sie`/`ihr`/`ihnen` sind weiter keine Anrede. Nicht jeder Satz im Produkt ist neu gefasst. |
| 7 Mobile | 8 | Auth, Übersicht, Buchung und Bestätigung bei 390. |
| 8 Perceived performance | 7 | Die Slot-Liste lädt als Skeleton und markiert die gewählte Zeit sofort (`slot-list__slot--selected`), bevor die Antwort da ist. Andere Datenflächen der Übersicht haben weiter kein Skeleton. |
| 9 Polish | 7 | Die Bestätigung ist eine lesbare Spalte (640 px) statt der überlagerten Karte. Die Mail-Karte hat eine Amber-Ink-Kante. Offen: schwarzes Quadrat im Kalender-Button, Logo-Zeile „BookDesk24 / by“. |
| 10 Trust | 8 | Navy als Primärbutton, Passwortregel sichtbar, Legal-Links auf `/growthos/legal/*`, Bestätigung nennt Gastgeber, Zeit und Ort. |
| 11 Emails | 8 | `DsMail` setzt Termintyp, Dauer, Ort und Beschreibung in eine Tabelle (Ink `#835000`, weil Mail keine CSS-Variablen trägt). Klartext-Zwilling bleibt im Template und ist geschossen. Nicht jede der 12 Mails hat ein eigenes Layout, alle laufen durch denselben Rahmen. |

## Verbleibende `sie` / `ihr` / `ihnen`

Kein Treffer ist die formelle Anrede. Die fünf grossgeschriebenen `Sie` sind Satzanfang für eine Sache („Sie bleibt veröffentlicht“, die Seite; „Sie bleiben in deinem Kalender“, die Buchungen). Der Rest ist:

- `sie` = sie/es (die Integration, die Buchung, die Umfrage, die Adresse)
- `ihr` = ihr/dessen (der Termin der Unterhaltung, „was ihr am besten passt“, „Gib ihr einen Namen“, „ihr Stripe-Konto“)
- `ihnen` = ihnen (den Gästen, den Termintypen)
- `dein-nutzername` ersetzt den alten Platzhalter `ihr-name`

`mix gettext.extract --merge` ist gelaufen. msgids sind unverändert. Platzhalter `%{…}` sind stehen geblieben.
