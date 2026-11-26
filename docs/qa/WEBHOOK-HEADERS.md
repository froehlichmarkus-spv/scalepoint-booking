# Webhook-Header

Ausgehende Webhooks von BookDesk24 senden nur noch diese Header:

| Header | Inhalt |
|---|---|
| `X-BookDesk24-Token` | gemeinsames Geheimnis des Webhooks |
| `X-BookDesk24-Signature` | `t=<unix>,v1=<hex HMAC-SHA256>` über `timestamp ++ "." ++ body` |
| `X-BookDesk24-Timestamp` | Zeitstempel als ISO-8601 |
| `X-BookDesk24-Delivery-Id` | stabile Zustell-ID, gleich bei jedem Retry |
| `User-Agent` | `BookDesk24-Webhooks/1.0` |

## Alte Namen

Frühere Zustellungen haben `X-Tymeslot-*` geschickt. Kurzzeitig kamen auch
`X-the scheduler-*` und `X-the-scheduler-*` vor. Diese Namen werden nicht
mehr gesendet.

Wenn eine Weiterleitung den Host wechselt, entfernt die App das Token unter
jedem dieser Präfixe (Groß- und Kleinschreibung egal), zusätzlich zu
`Authorization`. So kann ein altes Token nicht zu einer anderen Origin
mitwandern. Signatur, Zeitstempel und Delivery-Id sind keine Geheimnisse und
bleiben auf derselben Anfrage, die sie ohnehin beschreibt.

Empfänger sollen `X-BookDesk24-*` prüfen. Die alten Namen musst du nicht
mehr akzeptieren, es sei denn, du hast noch Zustellungen aus einer älteren
Version im Puffer.
