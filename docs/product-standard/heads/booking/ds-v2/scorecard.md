# BookDesk24 · Scorecard (DS v2, Runde nach der Barrierefreiheit)

Stand: 26. Nov 2026. Branch `feat/bookdesk24-ds-v2`. Live-Shots in `after/`. Ziel ist 9. Was darunter liegt, steht so da.

Verify und der Secret-Scan liefen nach `a47d8b1` nicht mehr, weil der Pull Request mit `qa/bookdesk24-saas-ready` in den Gettext-Dateien kollidiert. GitHub baut dann keinen Merge-Commit und startet `pull_request`-Workflows nicht. `pull_request_target` (dco-check) läuft weiter. Dieselbe Prüfung hängt zusätzlich an `push` für diesen Branch, ohne eine Prüfung zu streichen.

| Kriterium | Score | Warum |
|---|---|---|
| 1 Visual | 8 | Übersicht, Termine, Verfügbarkeit, Termintypen, Integrationen, Profil und Tarif sind bei 1440 geschossen. Der Kalender-Button ist wieder ein Umriss-Symbol auf dem Primärbutton. Die Wortmarke bricht in der Sidebar weiter („BookDesk24“ / „by“). |
| 2 Consistency | 8 | Tarifkarten und Skeletons nutzen `--gos-space-*`, `--gos-radius-*`, `--gos-line`, `--gos-surface`. Hex in den vier gemeldeten CSS-Dateien bleibt ein DS-Request. Grüne und rote Aktionsbuttons auf der Terminliste sind nicht auf eine Stufe gezogen. |
| 3 Usability | 8 | Leere Terminliste verlinkt „Termintyp anlegen“. Termintypen, Kalender und Abwesenheit hatten schon einen nächsten Schritt. Abrechnung sagt im Formular, was zu tun ist, wenn Billing fehlt. Nicht jedes Formular ist neu auf Inline-Validierung geprüft. |
| 4 Accessibility | 9 | Unverändert aus der vorigen Runde: axe serious/critical 0 auf Auth, Übersicht und öffentlicher Buchung, 1440 und 390. Der Kalender-Button ist ein Icon mit `fill: none` und Strich in der Buttonfarbe, kein schwarzes Quadrat. |
| 5 States | 8 | Slot-Zustände und die echte Bestätigung bleiben. Die Terminliste lädt als drei Skeleton-Zeilen statt als Spinner. Andere Dashboard-Seiten liefern die Daten im ersten HTML. |
| 6 Microcopy | 8 | Der Vertrauenssatz auf der Buchungsseite ist du und nennt Verschieben, Absagen und die Zeitzone. Begriffe Termin und Buchung bleiben. Nicht jeder Satz ist neu. |
| 7 Mobile | 8 | Buchung und Bestätigung bei 390. Termine, Verfügbarkeit und Tarif zusätzlich bei 390. Integrationen, Termintypen und Profil in dieser Runde nur bei 1440. |
| 8 Perceived performance | 8 | Slot-Wahl ist sofort markiert. Die einzige Spinner-Karte der Terminliste ist ein Skeleton mit fester Höhe. Slack-Kanäle und kleine Button-Spinner während einer Aktion bleiben. |
| 9 Polish | 8 | Bestätigung ist eine Spalte, Kalender-Icon ist ein Strich, Tarifseite nutzt die Flächentokens. Die Sidebar-Wortmarke und der Integrations-Hinweis oben auf jeder Dashboard-Seite sind nicht neu gesetzt. |
| 10 Trust | 9 | Öffentliche Buchung zeigt Gastgeber, Zeitzone, den Satz zum Verschieben und Absagen, und die Legal-Links (Impressum, Datenschutz, Nutzungsbedingungen, Auftragsverarbeitung). |
| 11 Emails | 8 | Bestätigung, Verschieben, Absage, Erinnerung und Passwort-Reset haben eigene Akzente und einen eigenen Streifen. Passwort-Reset hat den Button und keine Terminkarte. Der Fließtext ist weiter der bisherige Text, kein eigenes Satzbild pro Mail. Klartext-Zwillinge bleiben in den Templates. |

## Verbleibende `sie` / `ihr` / `ihnen`

Kein Treffer ist die formelle Anrede. Die fünf grossgeschriebenen `Sie` sind Satzanfang für eine Sache („Sie bleibt veröffentlicht“, die Seite; „Sie bleiben in deinem Kalender“, die Buchungen). Der Rest ist:

- `sie` = sie/es (die Integration, die Buchung, die Umfrage, die Adresse)
- `ihr` = ihr/dessen (der Termin der Unterhaltung, „was ihr am besten passt“, „Gib ihr einen Namen“, „ihr Stripe-Konto“)
- `ihnen` = ihnen (den Gästen, den Termintypen)
- `dein-nutzername` ersetzt den alten Platzhalter `ihr-name`

`mix gettext.extract --merge` ist gelaufen. msgids sind unverändert. Platzhalter `%{…}` sind stehen geblieben.
