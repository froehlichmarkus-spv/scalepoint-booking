# Umzug auf einen eigenen Server

Der Stack auf spv-crm ist absichtlich klein und abgeschlossen, damit er später umziehen kann, ohne CRM anzufassen.

## Ablauf

1. Snapshot beider Server.
2. Auf spv-crm nur die Booking-Datenbank sichern:

```sh
ops/backup-booking.sh /var/backups/spv-booking-move.dump
```

Das ist `pg_dump` im Container `spv-booking-postgres`. Die CRM-Datenbank wird nicht gelesen.

3. Image auf dem neuen Server laden (`docker pull` oder `docker load`). Dieselbe `deploy/compose.yml`, dieselben Env-Dateien, dasselbe `deploy/brands/`.
4. Stack starten, noch ohne DNS:

```sh
docker compose -p spv-booking -f deploy/compose.yml up -d
```

5. Dump einspielen:

```sh
docker exec -i spv-booking-postgres pg_restore -U booking -d booking --clean --if-exists < /var/backups/spv-booking-move.dump
```

6. Prüfen: `https://<neue-ip>` mit einem Host-Header, dann die beiden Buchungsseiten.
7. DNS-A-Record von `book.scalepoint-ventures.com` auf die neue Adresse legen. Den neutralen Host, sobald der Name feststeht, ebenfalls.
8. Auf spv-crm: `ops/rollback-caddy.sh` und danach `SPV_STOP_STACK=yes`. Volume erst löschen, wenn der neue Server eine Buchung geschrieben und eine Mail zugestellt hat.

Google OAuth Redirect-URLs bleiben gleich, solange der Hostname gleich bleibt. SMTP-Zugänge bleiben gleich.

Uploads (Porträt) liegen im Volume `spv-booking_uploads` unter `/app/data`. Das Volume mit kopieren, sonst fehlt das Foto:

```sh
docker run --rm -v spv-booking_uploads:/from alpine tar -C /from -czf - . > uploads.tgz
```

Auf dem neuen Server das Archiv in das neue Volume entpacken.
