# BookDesk24 · Scorecard (DS v2.5)

Stand: 26. Nov 2026, nach dem Merge von `qa/bookdesk24-saas-ready` (`ad5b9e5`). Branch `feat/bookdesk24-ds-v2`. Live-Shots in `after/`. Ziel ist 9.

Belege dieser Runde: `after/auth-login-1440.png` und `after/auth-login-390.png` (oben, ohne leeres „Oder fortfahren mit“), `after/dash-plan-1440.png` („Du nutzt Pro“), `after/booking-trust-1440.png` und `after/booking-trust-390.png` (Monogramm LH), `after/mail-confirmation.png` (BookDesk24, du, Fakten, Legal). Die wählbaren Cover und Hintergrund-Presets sind generierte Verläufe, keine Pixabay-Fotos.

DS v2.5.0 tokens are in `assets/css/tokens.phoenix.css`. The four CSS files that carried raw hex now use those tokens, including `--gos-overlay-hover` and `--gos-gradient-hue`. The icon map includes the answered Lucide rows, and the wrong stretch mappings are corrected.

Verify und der Secret-Scan liefen nach `a47d8b1` nicht mehr, weil der Pull Request mit `qa/bookdesk24-saas-ready` in den Gettext-Dateien kollidiert. GitHub baut dann keinen Merge-Commit und startet `pull_request`-Workflows nicht. `pull_request_target` (dco-check) läuft weiter. Dieselbe Prüfung hängt zusätzlich an `push` für diesen Branch, ohne eine Prüfung zu streichen.

| Kriterium | Score | Warum |
|---|---|---|
| 1 Visual | 9 | Geist, Navy und Amber-Ink. Wortmarke bricht nicht mehr. Kalender-Button ist ein Strich-Icon. Tarif und Shell nutzen die v2.5-Flächen. |
| 2 Consistency | 9 | Die vier gemeldeten CSS-Dateien lesen `--gos-*`. `brand-tokens.css` behält die Hell-Werte von v2.5 nur als Fallback, weil der Scheduling-Check ein nacktes `var()` ohne Definition ablehnt. Die alten Werte `#469189`, `#3a7872` und `#65758b` sind weg. Hero-Namen aus der Antwort zeigen Lucide, nicht mehr `i-info`. |
| 3 Usability | 9 | Leere Listen haben einen nächsten Schritt. Buchung validiert inline. Zerstören läuft über das Modal mit Fokusfalle. Billing sagt, was zu tun ist. |
| 4 Accessibility | 9 | axe serious/critical 0 auf Auth, Übersicht und Buchung, 1440 und 390. Geschlossene Schublade ist `inert` und `aria-hidden`, Escape schliesst, Tab bleibt in der offenen Schublade. Touch-Ziele sind 44px unter 640px. |
| 5 States | 9 | Skeleton, leer, Fehler mit erneut versuchen, Bestätigung, gesperrte Abrechnung. Daten, die schon im ersten HTML stehen, brauchen keinen zweiten Ladezustand. |
| 6 Microcopy | 9 | du, Termin, Buchung, Verfügbarkeit. Fehler nennen den Vorfall und den nächsten Schritt. Die kaputten Verben aus der du-Umstellung, die noch sichtbar waren, sind korrigiert. |
| 7 Mobile | 9 | Auth ist unter 640px oben ausgerichtet. Buchung, Bestätigung, Termine, Verfügbarkeit und Tarif sind bei 390 geschossen. Ziele sind mindestens 44px. |
| 8 Perceived performance | 9 | Slot-Wahl markiert sofort. Slot-Liste und Terminliste laden als Skeleton mit fester Höhe, nicht als alleiniger Spinner. |
| 9 Polish | 9 | Eine Button-Stufe: Gefahr nutzt `--gos-on-danger` und `--gos-danger-hover`, Erfolg `--gos-on-success`. Karten und Abstände aus den Tokens. |
| 10 Trust | 9 | Gastgeber, Zeitzone, Verschieben/Absagen, Legal-Links. Der Seed hängt kein persönliches Foto mehr an. |
| 11 Emails | 9 | Bestätigung, neue Zeit, Absage, Erinnerung und Passwort haben je ein eigenes Band. Links und Karten bleiben im MJML-Körper, der Klartext-Zwilling in der Vorlage. |

## Verbleibende `sie` / `ihr` / `ihnen`

Kein Treffer ist die formelle Anrede. Die fünf grossgeschriebenen `Sie` sind Satzanfang für eine Sache („Sie bleibt veröffentlicht“, die Seite; „Sie bleiben in deinem Kalender“, die Buchungen). Der Rest ist:

- `sie` = sie/es (die Integration, die Buchung, die Umfrage, die Adresse)
- `ihr` = ihr/dessen (der Termin der Unterhaltung, „was ihr am besten passt“, „Gib ihr einen Namen“, „ihr Stripe-Konto“)
- `ihnen` = ihnen (den Gästen, den Termintypen)
- `dein-nutzername` ersetzt den alten Platzhalter `ihr-name`

`mix gettext.extract --merge` ist gelaufen. msgids sind unverändert. Platzhalter `%{…}` sind stehen geblieben.
