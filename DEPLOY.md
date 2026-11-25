# Deploy auf spv-crm

Ziel ist der bestehende Server `37.27.9.176` (hel1, Ubuntu 24.04). Dort laufen Twenty CRM und das Oldorff-Portal. Dieses Stack kommt daneben. Es wird nichts davon neu gestartet, umkonfiguriert oder gelöscht.

Ein Hetzner-Webhosting-Paket (PHP, kein Docker, kein dauerhafter Prozess) kann diese Software nicht ausführen.

## Vorher

1. Snapshot des Servers in der Hetzner-Konsole. Das Skript startet nicht ohne `SPV_SNAPSHOT_CONFIRMED=yes`.
2. Image hier oder in CI bauen, nicht auf dem Server: `ops/build-and-push.sh`.
3. Registry-Tag in `SPV_BOOKING_IMAGE`. Ohne Registry: `docker save` / `docker load`. Auch das baut nicht auf dem Server.
4. DNS für `book.scalepoint-ventures.com` erst schalten, wenn du es willst. Die Zone liegt bei Hetzner DNS (`ns1.your-server.de`). Ein A-Record auf `37.27.9.176`.

## Was du noch eintragen musst

Lege auf dem Server `deploy/.env` an. Keine dieser Werte gehören ins Git.

- `SPV_BOOKING_IMAGE`
- `POSTGRES_PASSWORD`
- `SECRET_KEY_BASE` (`openssl rand -base64 64`)
- `DATA_ENCRYPTION_KEY` (`openssl rand -base64 48`)
- `SPV_OWNER_PASSWORD` (mindestens 12 Zeichen). `NEUTRAL_OWNER_PASSWORD` nur, wenn `SEED_NEUTRAL_TENANT=true`
- SMTP für den neutralen Absender: `SMTP_HOST`, `SMTP_PORT`, `SMTP_USERNAME`, `SMTP_PASSWORD`
- `SPV_SENDER_EMAIL` / `SPV_SENDER_NAME` (Vorschlag `booking@scalepoint-ventures.com` / `ScalePoint Ventures`)
- `NEUTRAL_SENDER_EMAIL` / `NEUTRAL_SENDER_NAME` (eigene Adresse, nicht die ScalePoint-Adresse)
- `SOURCE_OFFER_URL` sobald das Repository öffentlich ist
- Google OAuth, erst wenn die App existiert:
  - Client-ID, Secret, und ein State-Secret in den Variablen, die die Anwendung dafür schon hat (`GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`)
  - Scopes: `openid`, `email`, `https://www.googleapis.com/auth/calendar`, `https://www.googleapis.com/auth/meetings.space.created`
  - Redirects: `https://book.scalepoint-ventures.com/auth/google/callback`, `/auth/google/calendar/callback`, `/auth/google/video/callback`
  - Testmodus mit Markus als Testnutzer funktioniert, Tokens laufen nach 7 Tagen ab. Die Produktiv-Freigabe des Kalender-Scopes ist ein eigener Antrag bei Google.
- Zwei Kalender nach dem OAuth-Connect: `markus@scalepoint-ventures.com` zum Eintragen, `markus.froehlich@nenya.io` nur zur Konfliktprüfung.

Der Instanz-Absender (`EMAIL_FROM_*`, `DEFAULT_BRAND_KEY=scalepoint`) ist ScalePoint Ventures, `booking@scalepoint-ventures.com`. Systemmails, auch Passwort-Reset und Verifikation, gehen damit als ScalePoint Booking raus.

## Start

```sh
export SPV_SNAPSHOT_CONFIRMED=yes
ops/deploy-spv-crm.sh
```

Das Skript schreibt vorher `docker ps`, Volumes, `df` und `free` nach `/var/backups/`. Es nutzt nur `docker compose -p spv-booking`. Caddy bekommt eine Import-Zeile zwischen `# BEGIN spv-booking` und `# END spv-booking`, dann `caddy validate` und `caddy reload`. Kein `caddy restart`. Schlägt die Prüfung fehl, wird die Caddyfile zurückgesetzt.

Die Anwendung lauscht nur auf `127.0.0.1:4473`. Postgres ist nicht veröffentlicht. Eigenes Netz `spv-booking_net`, eigenes Volume `spv-booking_pg`.

Speicher: App 720 MB, Postgres 256 MB, zusammen unter 1 GB. Upstream empfiehlt 1–2 GB für die Anwendung allein. Das Limit schützt CRM: unter Druck wird zuerst dieser Stack beendet. Ein eigener Server mit 2 vCPU und 4 GB ist die dauerhafte Lösung, sobald die CX-Linie lieferbar ist.

## Nach dem Start

Die Seite zeigt erst Zeiten, wenn ein Kalender verbunden ist. Lokal übernimmt das der Demo-Kalender (`SPV_DEMO_CALENDAR=true`). In Produktion bleibt er aus.

Der Ort heißt in der Demo „Google Meet“, ist aber ein eigener Ort ohne OAuth. Nach dem echten Connect den Ort auf die Google-Meet-Integration umstellen. Ohne diese Integration schlägt eine Video-Buchung fehl.

## Backup und Update

```sh
ops/backup-booking.sh
ops/update.sh
```

`update.sh` zieht nur das Image und startet neu. Es löscht kein Volume.

## Rückbau

```sh
ops/rollback-caddy.sh
```

Nimmt die Site aus Caddy und lädt neu. Container stoppen zusätzlich mit `SPV_STOP_STACK=yes`. Volumes bleiben.

## Marken

`deploy/brands/scalepoint.json` ist die produktive Marke und der Standard. `deploy/brands/neutral.json` ist die Vorlage BookDesk24 (`booking@bookdesk24.com`). Sie steht auf `enabled: false`. Die Domain ist nicht gekauft. Aktivierung, DNS und SMTP stehen in `docs/plans/bookdesk24.md`. `SEED_NEUTRAL_TENANT` bleibt in der Produktion `false`.

Eine schon eingereihte Mail an `host@scheduler24.io` oder `host@meetdesk24.com` wird nicht mehr zugestellt. Wer die wartenden Jobs abbrechen will, tut das erst nach Freigabe und löscht dabei keine Benutzer:

```sh
CONFIRM_SUPPRESS_SEED_MAIL=yes mix run -e 'Tymeslot.Emails.SeedMailSuppress.run()'
```
