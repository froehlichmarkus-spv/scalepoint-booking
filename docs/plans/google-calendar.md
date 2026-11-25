# Google-Kalender für ScalePoint Booking

Stand 24. November 2026. Plan für Markus. Es wird nichts bei Google beantragt, nichts deployt und kein OAuth-Client angelegt. Die App liegt im Testing-Modus. Refresh-Tokens halten dort sieben Tage, danach muss neu verbunden werden.

Zwei Google-Konten, zwei Rollen:

| Konto | Rolle |
| --- | --- |
| `markus@scalepoint-ventures.com` | Buchungskalender. Termine werden hier eingetragen. Google Meet hängt an diesem Konto. |
| `markus.froehlich@nenya.io` | Nur Konfliktkalender. Blockt freie Zeiten. Nimmt keine Buchungen an und bekommt kein Meet. |

## Was die Anwendung verlangt

Die Scopes stehen in `Tymeslot.Integrations.Shared.GoogleConfig`:

- `openid`
- `email`
- `https://www.googleapis.com/auth/calendar` für den Kalender, in den geschrieben wird
- `https://www.googleapis.com/auth/meetings.space.created` für Google Meet

`calendar.readonly` reicht nicht. Der Google-Provider lehnt einen reinen Lese-Scope ab, weil Meet und das Eintragen über `events.insert` Schreibrecht brauchen. Ein Kalender, der nur mitgelesen wird, darf danach trotzdem als Konfliktquelle markiert sein. Das ist eine Einstellung pro Kalender, nicht ein zweiter Scope.

Redirects, sobald `book.scalepoint-ventures.com` per HTTPS erreichbar ist:

- `https://book.scalepoint-ventures.com/auth/google/callback`
- `https://book.scalepoint-ventures.com/auth/google/calendar/callback`
- `https://book.scalepoint-ventures.com/auth/google/video/callback`

Variablen, nur in der Env-Datei auf dem Server:

- `GOOGLE_CLIENT_ID`
- `GOOGLE_CLIENT_SECRET`
- `GOOGLE_STATE_SECRET` (`openssl rand -base64 32`)

## Verbinden, sobald die App im Testing-Modus Testnutzer hat

Beide Adressen müssen als Testnutzer im OAuth-Zustimmungsbildschirm stehen. Sonst bricht der Connect nach dem Google-Login ab.

1. Als `markus@scalepoint-ventures.com` im Dashboard unter Kalender Google verbinden und die genannten Scopes bestätigen.
2. In der Verbindung den Kalender dieses Kontos als Buchungsziel wählen. Die Zeile sagt dann „books into …“. Google Meet für die Terminart einschalten, nicht für den Nenya-Kalender.
3. Als `markus.froehlich@nenya.io` eine zweite Google-Verbindung anlegen. Das ist ein anderes Konto, also ein zweiter Consent.
4. Bei dieser Verbindung keinen Kalender als Buchungsziel setzen. Die Kalender, die Zeiten blocken sollen, in der Konfliktprüfung anlassen. Die Oberfläche sagt das mit „checks N of M calendars for conflicts“ und, wenn der Kalender nur gelesen werden kann, „read-only, blocks time but takes no bookings“. Kalender, die ignoriert werden sollen, bleiben in „ignored during conflict checking“.
5. Eine Buchung auf der ScalePoint-Seite anlegen. Sie erscheint im SPV-Kalender, nicht im Nenya-Kalender. Ein belegter Nenya-Slot taucht auf der Buchungsseite nicht als frei auf.

Der Demo-Kalender (`SPV_DEMO_CALENDAR`) bleibt in der Produktion aus. Er ersetzt den Google-Connect nicht.

Tokens im Testing-Modus: nach sieben Tagen ist das Refresh-Token ungültig. Dann beide Verbindungen neu herstellen, bis die Verifizierung unten durch ist. Ein abgelaufenes Token sieht aus wie ein stiller Kalender: keine neuen Termine, keine Konfliktprüfung.

## Weg zur Verifizierung

Ziel ist der Produktivstatus des OAuth-Clients, damit Refresh-Tokens nicht mehr nach sieben Tagen sterben und sich außer den Testnutzern niemand mehr verbinden muss. Markus verbindet sich selbst. Eine öffentliche Nutzerbasis ist dafür nicht nötig, der Consent-Screen schon.

1. In der Google Cloud Console das Projekt öffnen, das die Client-ID enthält. APIs: Google Calendar API und die Meet-API, die `meetings.space.created` trägt, aktivieren.
2. OAuth-Zustimmungsbildschirm:
   - App-Name: ScalePoint Booking
   - Support-E-Mail: `markus@scalepoint-ventures.com`
   - Startseite: `https://book.scalepoint-ventures.com`
   - Datenschutz: eine öffentliche URL auf derselben Domain, zum Beispiel `https://book.scalepoint-ventures.com/privacy`
   - Nutzungsbedingungen, wenn Google sie für den Antrag verlangt, ebenfalls auf dieser Domain
   - Autorisierte Domain: `scalepoint-ventures.com`
   - Scopes genau die vier oben. Keinen breiteren Drive- oder Gmail-Scope dazunehmen. Das macht den Antrag schwerer.
3. Domain verifizieren, bevor der Antrag rausgeht. In der Search Console `scalepoint-ventures.com` als Domain-Property aufnehmen und den TXT-Eintrag setzen, den Google anzeigt. Dieselbe Domain muss in der Cloud Console unter „Authorized domains“ stehen. Die Redirect-Hosts müssen unter dieser Domain liegen.
4. Die App aus „Testing“ zur Verifizierung einreichen. Google zeigt die Scope-Einstufung im Formular. Kalender-Schreibrechte und Meet gelten als sensibel. Ob zusätzlich eine Sicherheitsprüfung (CASA) fällig ist, sagt das Formular. Das nicht raten: die aktuelle Einstufung im Antrag lesen und nur die Scopes behalten, die der Connect wirklich schickt.
5. Bis die Freigabe da ist, im Testing-Modus bleiben und die beiden Adressen als Testnutzer führen. Nach der Freigabe die Verbindungen einmal neu herstellen, damit die neuen Tokens ohne Sieben-Tage-Frist gelten.

Die Datenschutzseite muss erreichbar sein, bevor der Antrag abgeschickt wird. Ein leerer Link ist ein Ablehnungsgrund. Der Text sagt, dass ScalePoint Booking Kalendertermine liest, um Doppelbuchungen zu vermeiden, Termine in den gewählten Kalender schreibt und für Google Meet einen Raum anlegt. Er nennt `markus@scalepoint-ventures.com` als Kontakt.

Nichts davon auf dem Server umsetzen, bevor Markus die Domain, die Datenschutz-URL und den Antrag freigibt.
