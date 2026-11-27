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

## Abrechnung einschalten

Die gemeinsame Abrechnung läuft auf `https://billing.scalepoint-ventures.com`. BookDesk24 legt keinen Stripe-Schlüssel ab und ändert `automatic_tax` nicht. Trial-Ende-Mails schickt die Abrechnung. Die alte Vorlage in dieser App bleibt aus, sobald der HTTP-Client aktiv ist.

In `/opt/spv-booking/deploy/.env` stehen nur die Namen. Die geheimen Werte kommen aus `/opt/growth-os-billing/.env` und gehören nicht ins Git und nicht in den Chat.

| Name in BookDesk24 | Wert |
| --- | --- |
| `GROWTH_OS_BILLING_URL` | `https://billing.scalepoint-ventures.com` |
| `GROWTH_OS_BILLING_API_KEY` | `MODULE_BOOKING_API_KEY` aus `/opt/growth-os-billing/.env` |
| `GROWTH_OS_BILLING_WEBHOOK_SECRET` | `MODULE_BOOKING_WEBHOOK_SECRET` aus derselben Datei |
| `PLANS_ENABLED` | `true` |

Auf dem Server, ohne die Werte auszugeben:

```sh
cd /opt/spv-booking/deploy
python3 - <<'PY'
import pathlib
src = pathlib.Path("/opt/growth-os-billing/.env").read_text().splitlines()
wanted = ("MODULE_BOOKING_API_KEY", "MODULE_BOOKING_WEBHOOK_SECRET")
found = {}
for line in src:
    if not line or line.startswith("#") or "=" not in line:
        continue
    name, value = line.split("=", 1)
    if name in wanted:
        found[name] = value.strip().strip('"').strip("'")
missing = [name for name in wanted if not found.get(name)]
if missing:
    raise SystemExit("missing " + ", ".join(missing))
env_path = pathlib.Path("/opt/spv-booking/deploy/.env")
text = env_path.read_text() if env_path.exists() else ""

def set_line(text, name, value):
    lines = text.splitlines()
    out = []
    found_name = False
    for line in lines:
        if line.startswith(name + "="):
            out.append(name + "=" + value)
            found_name = True
        else:
            out.append(line)
    if not found_name:
        if out and out[-1] != "":
            out.append("")
        out.append(name + "=" + value)
    return "\n".join(out) + "\n"

text = set_line(text, "GROWTH_OS_BILLING_URL", "https://billing.scalepoint-ventures.com")
text = set_line(text, "GROWTH_OS_BILLING_API_KEY", found["MODULE_BOOKING_API_KEY"])
text = set_line(text, "GROWTH_OS_BILLING_WEBHOOK_SECRET", found["MODULE_BOOKING_WEBHOOK_SECRET"])
text = set_line(text, "PLANS_ENABLED", "true")
env_path.write_text(text)
print("billing names written; values not printed")
PY
docker compose -p spv-booking -f compose.yml up -d --no-build
curl -fsS https://billing.scalepoint-ventures.com/healthz
curl -fsS http://127.0.0.1:4473/healthcheck
```

Sind URL und API-Key gesetzt, spricht die App mit `Tymeslot.Plans.BillingClient.HTTP`. Der Satz „Die Abrechnung von BookDesk24 ist noch nicht da“ erscheint nur, solange `GET /healthz` auf dem Billing-Host nicht mit 2xx antwortet. Webhooks kommen an `POST /webhooks/growth-os-billing`.

## Transaktionsmail über Resend

Die Anwendung bleibt auf SMTP, solange `RESEND_API_KEY` leer ist. Ein gesetzter Schlüssel in Produktion schaltet auf Resend um, auch wenn `EMAIL_ADAPTER` weiter `smtp` ist. Der Schlüssel darf nur senden. Die Anwendung ruft beim Start keine Domain-API auf.

Absender, wenn `MAIL_FROM` leer ist und Compose den Standard einsetzt: `BookDesk24 <noreply@scalepoint-ventures.com>`. Antworten gehen an `support@scalepoint-ventures.com` (`MAIL_REPLY_TO`). Ein Mandant mit eigenem Absendernamen behält diesen Namen. Die Domain `scalepoint-ventures.com` muss in Resend schon verifiziert sein. Der reine Sendeschlüssel kann das nicht prüfen.

Zustellung ist aus, solange `SEND_EMAILS` nicht `true` ist. Dann schreibt die Anwendung die Mail nur ins Log.

Umschalten auf dem Server:

```sh
# In /opt/spv-booking/deploy/.env eintragen. Den Wert nicht ins Repo schreiben.
# SEND_EMAILS=true
# RESEND_API_KEY=<sending-access key>

cd /opt/spv-booking/deploy
docker compose -p spv-booking -f compose.yml up -d --no-build --force-recreate app
```

SMTP-Variablen können stehen bleiben. Ohne `RESEND_API_KEY` sendet der nächste Start wieder über SMTP. `MAIL_FROM` und `MAIL_REPLY_TO` leer lassen heißt: die in Compose hinterlegten Standards. Wer den bisherigen Absender behalten will, setzt `MAIL_FROM` ausdrücklich.
