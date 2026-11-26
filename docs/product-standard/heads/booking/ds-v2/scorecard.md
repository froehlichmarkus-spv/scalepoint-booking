# BookDesk24 · Scorecard Schritt 2 (DS v2)

Stand: 26. Nov 2026. Branch `feat/bookdesk24-ds-v2`. Live-Shots in `after/`. Ziel ist 9. Was darunter liegt, steht so da.

| Kriterium | Score | Warum |
|---|---|---|
| 1 Visual | 8 | Auth ist zweispaltig. Die Übersicht hat einen navy Banner mit Amber-Kante statt des Verlaufs. Die Buchungsseite ist Folio in Geist. |
| 2 Consistency | 6 | Jedes `hero-`-Icon rendert das Lucide-Sprite. Namen ohne Symbol stehen in `ds-requests.md` und fallen auf `i-info`. Die App-Schrift und Folio-Überschriften sind Geist. Theme-Schrift-IDs und Hex ausserhalb der Token-Dateien sind noch offen, ebenfalls in `ds-requests.md`. |
| 3 Usability | 8 | Login, Signup, Passwort vergessen, Link gesendet, Verifizieren, Erfolg und der Login-Fehler sind erreichbar. Google/Microsoft nur, wenn ein Admin den Provider einschaltet. |
| 4 Accessibility | 7 | Skip-Link, Fokus-Ring aus dem DS, lesbare Sidebar nach dem Kontrast-Fix. Kein neuer axe-Lauf in diesem Schritt. |
| 5 States | 8 | Auth-Zustände und die Buchungsseite (Skeleton, keine Zeiten, Fehler mit „Erneut versuchen“) sind geschossen. Die Bestätigungsseite existiert als Live-Schritt, ist in diesem Lauf nicht neu gebucht. |
| 6 Microcopy | 7 | 179 Treffer bleiben: 175 `sie`, 5 `ihr`, 3 `ihnen`, plus fünf grossgeschriebene `Sie` am Satzanfang für eine Sache („Sie bleibt“). Keine formelle Anrede. Einzelne Imperative sind holprig. |
| 7 Mobile | 8 | Buchung, Auth und Übersicht sind bei 390 geschossen. |
| 8 Perceived performance | 7 | In diesem Schritt nicht neu gemessen. |
| 9 Polish | 6 | Logo-Zeile bricht („BookDesk24“ / „by“), Verlaufsbanner, alte Karten. |
| 10 Trust | 8 | Navy als Primärbutton, Passwortregel 8 Zeichen und 72 Byte sichtbar, Legal-Links auf `/growthos/legal/*`. |
| 11 Emails | 7 | HTML der Transaktionsmails kommt aus `DsMail` (DS-Rahmen, Klartext-Zwilling bleibt in den Templates). Der Inhalt ist der bisherige Text, nicht jede Karte neu gesetzt. |

## Verbleibende `sie` / `ihr` / `ihnen`

Kein Treffer ist die formelle Anrede. Die fünf grossgeschriebenen `Sie` sind Satzanfang für eine Sache („Sie bleibt veröffentlicht“, die Seite; „Sie bleiben in deinem Kalender“, die Buchungen). Der Rest ist:

- `sie` = sie/es (die Integration, die Buchung, die Umfrage, die Adresse)
- `ihr` = ihr/dessen (der Termin der Unterhaltung, „was ihr am besten passt“, „Gib ihr einen Namen“, „ihr Stripe-Konto“)
- `ihnen` = ihnen (den Gästen, den Termintypen)
- `dein-nutzername` ersetzt den alten Platzhalter `ihr-name`

`mix gettext.extract --merge` ist gelaufen. msgids sind unverändert. Platzhalter `%{…}` sind stehen geblieben.
