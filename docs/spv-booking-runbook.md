# spv-booking: main ziehen, starten, prüfen, zurück

Der Checkout auf dem Server ist `/opt/spv-booking`. Compose und die Marken liegen in `/opt/spv-booking/deploy`. Das Compose-Projekt heißt `spv-booking`. Die Anwendung hört nur auf `127.0.0.1:4473`. Postgres ist nicht veröffentlicht. Secrets stehen nur in `/opt/spv-booking/deploy/.env`. Die Vorlage ohne echte Werte ist `deploy/env.example`.

Es wird kein Volume gelöscht.

## main ziehen und Container neu starten

```sh
cd /opt/spv-booking
git fetch origin main
git checkout main
git pull --ff-only origin main

cd /opt/spv-booking/deploy
docker compose -p spv-booking -f compose.yml pull
docker compose -p spv-booking -f compose.yml up -d --no-build
```

`git pull` holt Compose und die Markendateien. Der laufende Code kommt aus `SPV_BOOKING_IMAGE`. Auf dem Server wird nicht gebaut.

## Migrationen

Der Container führt beim Start aus:

```sh
bin/tymeslot eval 'Tymeslot.Release.migrate()'
```

Das passiert, bevor der Server zuhört. Ein zweites Mal ist ungefährlich:

```sh
cd /opt/spv-booking/deploy
docker compose -p spv-booking -f compose.yml exec -T app bin/tymeslot eval 'Tymeslot.Release.migrate()'
```

## Healthcheck

Compose prüft im Container `GET /healthcheck` auf Port 4000. Von der Maschine aus:

```sh
curl -fsS http://127.0.0.1:4473/healthcheck
```

Eine Antwort `200` heißt, die Anwendung und die Datenbank antworten. Bei einem Fehler hier nicht weiter deployen.

## Rollback

Die Site aus Caddy nehmen, ohne die Datenbank zu löschen:

```sh
cd /opt/spv-booking
ops/rollback-caddy.sh
```

Container zusätzlich stoppen, Volumes behalten:

```sh
SPV_STOP_STACK=yes ops/rollback-caddy.sh
```

Ein älteres Image wieder einsetzen: `SPV_BOOKING_IMAGE` in `deploy/.env` auf den vorherigen Tag setzen, dann `docker compose -p spv-booking -f compose.yml up -d --no-build` aus `/opt/spv-booking/deploy`.
