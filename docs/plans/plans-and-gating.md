# BookDesk24: Pläne, Gating und Design-Tokens

Stand: 25.11.2026. Umgesetzt im Fork `froehlichmarkus-spv/scalepoint-booking`
auf `feat/bookdesk24-plans-gating`. Kein Deploy, kein Merge, keine Secrets.

Die Spec wurde gegen Upstream `fe1a106` geschrieben. Die Andockpunkte
existieren im Fork, die Zeilennummern weichen ab. Interne Modulnamen
`Tymeslot.*` bleiben.

## Entscheidungen

| Thema | Entscheidung |
|---|---|
| Pläne | Phase 1 ist Free und Pro. Team (Round-Robin, eigene Domain, Mails von der Kundendomain) ist Phase 2 und nicht gebaut. |
| Billing | Die App speichert nur den Plan. Stripe-Subscriptions laufen in `growth-os-billing` (Supabase Free). Webhooks der Subscription gehen nur dorthin, nie an `/webhooks/stripe`. |
| Preise | `booking_pro_monthly` 5 €, `booking_pro_yearly` 50 €. Netto, keine Stripe Tax. USt-ID und Reverse Charge macht Billing. Lookup Keys, keine Secret Keys. |
| Referenz-Preis-IDs | `price_1UfQtxGjbro3yjKYyoBIHw1G`, `price_1UfQu1Gjbro3yjKY3fJVSUbm`. Team-Preise und `bpc_1UfQwuGjbro3yjKYN0lO7drN` sind nur Referenz und werden von der App nicht aufgerufen. |
| Trial | 14 Tage, lokal sofort, ohne Karte. |
| Free-Kalender | Ein Kalender, jeder Provider inklusive Google. Meet, Zoom und Teams sind Pro. |
| Free sonst | Keine Gruppen, Polls, Serien, Zahlungen, Webhooks, Slack, Telegram, Erinnerungen, weiteren Buchungsseiten. Fragen und Analytics an. Bestätigung und Storno bleiben an. |
| Downgrade | Pausiert, löscht nie. Überzählige Event-Typen sind nicht öffentlich buchbar. Bestehende Kalender bleiben für die Konfliktprüfung aktiv. |
| Badge | Free: fest „Powered by BookDesk24“, nicht abschaltbar. Pro: kein Badge. |
| White-Label | Pro: eigenes Logo und eigene Akzentfarbe nur auf der Buchungsseite. Die Akzentfarbe überschreibt dort `--spv-teal`, `--spv-teal-strong` und `--spv-teal-light`. |
| Namen | `product_name` BookDesk24, `byline` by ScalePoint, `suite_name` ScalePoint Ventures Growth OS, `module_name` Booking, Seitentitel Admin/Login/Dashboard: ScalePoint Growth OS · Booking. Mandanten überschreiben die Felder in der Brand-JSON oder per ENV. |
| Design | `brand/tokens.css` ist die gemeinsame Token-Datei mit dem Growth-OS-CRM. Cards weiß, Radius 8px, dezente Border. Teal für CTAs und aktive Zustände. DM Serif Display nur für Headlines, Inter für die UI. |
| Connect | `AccountCurrency.charges_enabled_for_user?/1`. `PAYMENT_APPLICATION_FEE_BP` nicht setzen. |
| DATABASE_URL | Sonderzeichen im Passwort sind PR #1. Hier nicht erneut geändert. |

## Was die App tut

`PLANS_ENABLED=true` setzt in `config/runtime.exs` den Access Checker, den
Subscription Manager (nur für das Badge), die Dashboard-Hooks, den
Registrierungs- und Lösch-Hook, die Oban-Queue `plans` und den Resync alle
sechs Stunden. Ohne das Flag bleibt das Upstream-Verhalten.

Lokal liegt der Status in `plan_entitlements`. `source_version` verwirft
verspätete Events. `plan_webhook_deliveries` macht die Push-ID idempotent.
Signatur: `X-GOS-Signature: v1=<hex(HMAC_SHA256(secret, timestamp ++ "." ++ body))>`,
Toleranz fünf Minuten, `Plug.Crypto.secure_compare/2`.

Mengenlimits hängen in `MeetingTypes.create_meeting_type/2` und
`Calendar.Management.insert_integration/1`, jeweils mit `SELECT … FOR UPDATE`
auf `users`. Reconnect schreibt die bestehende Zeile und zählt nicht als neu.

## Akzeptanz

- Free kann keinen zweiten Event-Typ anlegen, auch nicht per Duplizieren oder parallel.
- Free kann keinen zweiten Kalender verbinden. Reconnect des vorhandenen Kalenders bleibt möglich.
- Free: Gruppe, Preis, Reminder, Meet/Zoom/Teams, Webhook/Slack/Telegram, Poll, Serie und zusätzliche Buchungsseite werden serverseitig abgelehnt.
- Badge „Powered by BookDesk24“ auf den Themes, im Embed und in der `.ics`-Beschreibung bei Free. Pro ohne Badge.
- Pro-Logo und Pro-Akzent nur auf der Buchungsseite. Free zeigt das hochgeladene Logo nicht.
- Downgrade löscht nichts. Überzählige Event-Typen sind nicht buchbar. Bestehende Buchungen bleiben.
- Webhook-Replay und eine ältere `source_version` ändern den gespeicherten Plan nicht.
- `PLANS_ENABLED` ungesetzt lässt den Default-Checker und damit Self-Hosting unverändert.
- `brand/tokens.css` enthält die Growth-OS-Variablen unverändert.

## Offene Punkte

- growth-os-billing (Checkout, Portal, Stripe-Webhooks, Outbox) ist ein eigenes Repo und hier nicht enthalten.
- Live-Preise und Produkte werden nicht angelegt.
- Team-Plan, eigene Domain und Absender auf der Kundendomain sind Phase 2.
