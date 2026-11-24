# BookDesk24

Stand 24. November 2026. Das ist ein Plan, keine Schaltung. Die Domain `bookdesk24.com` ist nicht gekauft. Es wird hier nichts deployt, nichts auf dem Server geändert und keine Domain oder kein Abo bestellt.

BookDesk24 ersetzt MeetDesk24 als Name der neutralen Standalone-Vorlage. Scheduler 24 und MeetDesk24 bleiben nur als gesperrte Alt-Adressen, damit keine Mail mehr dorthin geht.

## Was der Code jetzt tut

Die Vorlage liegt in `priv/brands/neutral.json` und `deploy/brands/neutral.json`.

| Feld | Wert |
| --- | --- |
| `key` | `neutral` |
| `enabled` | `false` |
| `default` | `false` |
| `house_brand` | `false` |
| `name` / `product_label` / `sender_name` / `footer` | BookDesk24 |
| `sender_email` | `booking@bookdesk24.com` |
| `owner_email` / `notify_email` | `host@bookdesk24.com` |
| `hosts` | `book.bookdesk24.com` |
| `username` | `studio` |

Der Mandant ist deaktiviert. `Brands.all/0` lädt ihn nicht, der Seed legt keinen Benutzer an, und die Seite `studio` existiert dadurch nicht. Die produktive Instanz bleibt ScalePoint Booking: `DEFAULT_BRAND_KEY=scalepoint`, Absender ScalePoint Ventures, `booking@scalepoint-ventures.com`.

`SEED_NEUTRAL_TENANT` steht in `deploy/compose.yml` auf `false`. In der lokalen Compose bleibt es `true`, wirkt aber nicht, solange `enabled` falsch ist.

## Absender

Solange der Mandant aus ist, verschickt nichts als BookDesk24.

Nach der Aktivierung:

- `NEUTRAL_SENDER_EMAIL=booking@bookdesk24.com`
- `NEUTRAL_SENDER_NAME=BookDesk24`
- `NEUTRAL_BRAND_NAME=BookDesk24`
- `NEUTRAL_FOOTER=BookDesk24`

Das sind die Env-Schlüssel, die die JSON-Datei schon nennt (`sender_email_env` und so weiter). Die Instanz-Absender `EMAIL_FROM_*` bleiben ScalePoint. BookDesk24 gilt nur für Empfänger dieses Mandanten.

Postfach `booking@bookdesk24.com` erst anlegen, wenn die Domain gekauft und die DNS-Einträge unten live sind. Vorher würde jede Mail bouncen.

## Nach dem Domainkauf

Reihenfolge. Nichts davon ist schon erledigt.

1. Domain `bookdesk24.com` kaufen. Erst danach die folgenden Namen anlegen.
2. DNS, Zone beim Registrar oder bei Hetzner DNS:
   - `book.bookdesk24.com` A auf die IP des Booking-Servers, wenn dieser Mandant dort laufen soll
   - MX auf den SMTP-Anbieter, der `booking@` und `host@` empfängt
   - SPF als TXT auf der Apex-Domain, passend zum Anbieter
   - DKIM als CNAMEs, die der Anbieter nennt
   - DMARC als TXT `_dmarc.bookdesk24.com`, am Anfang `p=none`, später verschärfen
3. HTTPS: den Host `book.bookdesk24.com` in den Reverse Proxy aufnehmen und ein Zertifikat ausstellen lassen. Der App-Container bleibt auf dem Loopback-Port. Kein zweiter öffentlicher Postgres-Port.
4. SMTP: Host, Port, Benutzer und Passwort als `SMTP_*` nur in der Env-Datei auf dem Server, nicht im Git. Absenderadresse muss zum SPF/DKIM-Namen passen.
5. Postfächer `booking@bookdesk24.com` und `host@bookdesk24.com` anlegen. `host@` ist der Besitzer der Buchungsseite, `booking@` ist der Absender.

## Umbenennung im Code

Erledigt in diesem Branch, der Mandant bleibt aus:

- Name, Absender, Host und Besitzer in beiden JSON-Dateien
- Wortmarke `priv/static/images/brand/neutral-mark.svg` und `neutral-mark.png`
- Voreinstellungen in `deploy/compose.yml` und `deploy/compose.local.yml`
- Tests, die den alten Namen MeetDesk24 erwartet haben

Nicht anfassen, bis die Checkliste unten durch ist: `enabled` nicht auf `true` setzen, `SEED_NEUTRAL_TENANT` in der Produktion nicht einschalten.

## Aktivierung

Erst wenn Domain, DNS, Zertifikat, Postfächer und SPF/DKIM stehen.

1. `enabled` in der gemounteten `neutral.json` auf `true`.
2. `NEUTRAL_OWNER_PASSWORD` setzen, mindestens 12 Zeichen.
3. `SEED_NEUTRAL_TENANT=true` nur für den Boot, der den Benutzer `host@bookdesk24.com` anlegen soll. Danach kann es wieder aus, der Benutzer bleibt.
4. `NEUTRAL_SENDER_EMAIL` und `NEUTRAL_SENDER_NAME` wie oben.
5. Einmal starten und prüfen, dass die Seite unter `book.bookdesk24.com` die BookDesk24-Vorlage zeigt und keine ScalePoint-Namen.
6. Eine Testmail an eine echte Adresse schicken, nicht an `host@scheduler24.io` oder `host@meetdesk24.com`.

Der Seed verschickt keine Verifikationsmail. Der Besitzer wird als verifiziert markiert. Eine „Verify your email“ an diese Adresse ist ein Fehler.

## Mail an Seed- und Demo-Adressen

Drei Sperren, alle im Code, keine davon löscht Daten:

- Provisioning (`via: :provisioning`) stellt keine Verifikationsmail ein.
- Ein Verifikationsjob für ein Konto mit `verified_at` wird verworfen.
- `Tymeslot.Emails.SeedRecipients` unterdrückt jede Mail an `scheduler24.io`, `meetdesk24.com` und an Besitzer, Notify und Absender eines deaktivierten Mandanten. Der Job endet als zugestellt-unterdrückt und wird nicht erneut versucht.

Wartende Jobs in Oban bleiben liegen, bis jemand das abbricht. Das Skript löscht keine Benutzer und keine Job-Zeilen. Es setzt passende E-Mail-Jobs nur auf `cancelled`, und nur mit der Variable:

```sh
CONFIRM_SUPPRESS_SEED_MAIL=yes mix run -e 'Tymeslot.Emails.SeedMailSuppress.run()'
```

Auf einem Release dasselbe mit `bin/tymeslot eval`. Nicht beim Boot, nicht in einer Migration, nicht ohne Freigabe.
