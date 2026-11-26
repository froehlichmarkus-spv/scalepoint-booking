# BookDesk24 — Gate 2: SaaS-Ready, White-Label und User Journey

**Datum:** 26. November 2026
**Branch:** `qa/bookdesk24-saas-ready` gegen `main` (PR #1 und #2 sind gemergt)
**Umgebung:** lokal, `http://127.0.0.1:4000`, Seeds, Stripe nicht angefasst, kein Deploy
**Screenshots:** `/opt/cursor/artifacts/` (01 bis 27)

`automatic_tax` in Stripe ist absichtlich unverändert. Es gibt keinen Live-Server-Eingriff und keine Secrets im Code.

## Ergebnis

| Bereich | Score | Ziel | Status |
|---|---:|---:|---|
| SaaS-Ready | **6 / 10** | ≥ 9 | nicht erreicht |
| 100 % White-Label | **7 / 10** | ≥ 9 | nicht erreicht |
| User Journey lokal | **7 / 10** | ≥ 9 | nicht erreicht |

Lokal laufen Registrierung, Verifizierung, Login, Passwort-Reset, Buchung, Absage und Verschieben. Der 14-Tage-Pro-Trial startet ohne Karte. Der Stripe-Checkout selbst geht nicht, weil `growth-os-billing` fehlt. Die Live-URL, Stripe Tax, das öffentliche Repo und der Google-OAuth-Consent bleiben offen. Das sind Entscheidungen für dich, Markus.

`mix credo --strict` ist auf diesem Branch grün. Die gezielten Auth-, Passwort-, Webhook- und Plan-Tests sind grün. Die volle `mix test`-Suite (CI, etwa 45 Minuten) ist hier nicht noch einmal komplett gelaufen.

## Area 1 — SaaS-Ready: 6 / 10

| ID | Score | Ergebnis | Beleg |
|---|---:|---|---|
| SR-1 | 5 | Lokal `GET /healthcheck` = 200. Live `book.scalepoint-ventures.com` war im Lead-Bericht 502. Hier kein Deploy, also keine neue Live-Prüfung. | lokaler Server |
| SR-2 | 8 | Plan-Seite zeigt Pro monatlich 5 €, jährlich 50 € (2 Monate frei), Trial bis 2026-12-10, kein Setup-Fee. Das trifft `docs/plans/plans-and-gating.md`. Die Terms-Schedules liegen nicht in diesem Repo. | `13-plan.png` |
| SR-3 | 4 | `automatic_tax` ist auf Anweisung nicht geändert. Die Payment Links aus dem Lead-Bericht bleiben mit Tax aus. Die UI sagt: „Prices are net. VAT IDs for reverse charge are collected by billing. No Stripe Tax.“ | `13-plan.png` |
| SR-4 | 5 | „Manage billing“ ruft `growth-os-billing`. Der Dienst fehlt, die App antwortet „Billing is unavailable.“ Der Webhook-Handler `/webhooks/growth-os-billing` ist im Code. Portal-Metadaten `bpc_1UfQwu…` sind nicht gesetzt. | `14-checkout.png` |
| SR-5 | 8 | Free/Pro-Limits, Pause statt Löschen und 7 Tage Past-due stehen im Plan-Code aus PR #2 und in `test/tymeslot/plans/plans_test.exs`. Ein Live-Downgrade ist nicht gelaufen. | Plan-Tests |
| SR-6 | 6 | Lokale Mails kommen von `ScalePoint Ventures <booking@scalepoint-ventures.com>`. SPF/DKIM/DMARC und `SEND_EMAILS` in Produktion sind nicht geprüft. | `03-mailbox.png` |
| SR-7 | 8 | Signup verlangt die Zustimmung zu Terms und Privacy (`/growthos/legal/terms` und `/privacy`). Daten hängen am User. Der Satz „Join ScalePoint Ventures“ ist kein Verbraucher-Pitch, aber auch kein explizites „nur für Unternehmen“. | `01-signup.png` |
| SR-8 | 5 | `/source` antwortet und nennt AGPLv3. Das Repo `froehlichmarkus-spv/scalepoint-booking` ist privat. Ohne öffentliche URL ist die Pflicht nicht erfüllt. | `21-source.png` |

## Area 2 — White-Label: 7 / 10

| ID | Score | Ergebnis | Beleg |
|---|---:|---|---|
| WL-1 | 8 | Signup, Plan, Buchung und 404 zeigen BookDesk24 und ScalePoint. Gettext ersetzt den Upstream-Namen zur Laufzeit durch den Markennamen (`TymeslotWeb.Gettext.ProductScrub`). CSS-Klassen `tymeslot-*` bleiben im HTML. | `01-signup.png`, `15-booking-home.png` |
| WL-2 | 7 | Absender ist ScalePoint Ventures. Das Inline-Logo heißt jetzt `bookdesk24-logo.png`. Links in der lokalen Mail zeigen auf `localhost:4000`, in Produktion auf `PHX_HOST`. | Mailbox, `mjml_email.ex` |
| WL-3 | 5 | Nur localhost. Kein DNS- oder CNAME-Eingriff. | — |
| WL-4 | 4 | Google-Consent bleibt laut Lead-Bericht im Testing-Modus. Keine Console-Credentials, nichts geändert. | Lead-Bericht |
| WL-5 | 8 | Seitentitel der Auth-Seiten: `ScalePoint Growth OS · Booking`. Buchungstitel: `Schedule with Markus Fröhlich · BookDesk24`. Manifest unter `/site.webmanifest`, Favicon aus der Brand. | Signup-HTML, `20-404.png` |
| WL-6 | 8 | 404 ist markiert: Titel `Page not found · BookDesk24`, Text „Go to BookDesk24“, `support@scalepoint-ventures.com`. 500-Template liegt daneben und ist nicht extra ausgelöst. In Dev mit `DEBUG_ERRORS=true` siehst du stattdessen die Phoenix-Debugseite. | `20-404.png` |
| WL-7 | 5 | Stripe-Konto, Produkttexte und Portal-Links sind nicht angefasst. Vendor-Namen in Stripe-Beschreibungen aus dem Lead-Bericht können noch da sein. | — |
| WL-8 | 6 | Keine neuen Hilfe-Seiten. Die In-App-Texte der Auth- und Plan-Fläche sind auf BookDesk24 gezogen. Ein vollständiger Help-Audit fehlt. | — |
| WL-9 | 8 | Ausgehende Webhooks senden `X-BookDesk24-*` und `User-Agent: BookDesk24-Webhooks/1.0`. Alte Token-Header werden beim Redirect weiter entfernt. Doku: `docs/qa/WEBHOOK-HEADERS.md`. | Header-Tests |

„the scheduler“ ist aus der 404 und den Katalogen raus. Der Button heißt „Go to BookDesk24“, auf Deutsch „Weiter zu %{product}“.

## Area 3 — User Journey: 7 / 10

Lokal mit Seeds, `PLANS_ENABLED=true`, Mailbox unter `/dev/mailbox`.

| ID | Score | Ergebnis | Beleg |
|---|---:|---|---|
| UJ-1 | 9 | Signup mit E-Mail, Passwort und Terms-Checkbox. Konto wird angelegt. | `01-signup.png`, `02-signup-result.png` |
| UJ-2 | 9 | Mail „Verify your email address“ von ScalePoint Ventures. GET auf den Link lässt den Button stehen (kein Prefetch-Verbrauch). Klick auf „Verify email address“ loggt ein und öffnet das Onboarding. | `03-mailbox.png`, `05-verify-confirm.png`, `06-after-verify.png` |
| UJ-3 | 8 | Login mit dem neuen Passwort landet im Dashboard („Login successful.“). Falsches Passwort ist in diesem Lauf nicht noch einmal geklickt; die bestehende Auth-Suite prüft das. | `08-after-login.png` |
| UJ-4 | 9 | Reset-Mail, Formular mit den Regeln „mindestens 8 Zeichen“ und „höchstens 72 Byte“. Das neue Passwort loggt ein, der alte Link ist danach ungültig. | `11-reset-form.png`, `12-reset-done.png` |
| UJ-5 | 6 | 14-Tage-Trial ohne Karte (Pro trial until 2026-12-10). Preise 5 € / 50 €. Der Checkout-Button sagt „Billing is unavailable“, weil der Billing-Dienst fehlt. Kein Stripe-Test-Payment. | `13-plan.png`, `14-checkout.png` |
| UJ-6 | 8 | Nach der Verifizierung startet der Wizard bei „Your link“, Schritt 1 von 5. | `08-after-login.png` |
| UJ-7 | 5 | „Manage billing“ ist da und endet in derselben Meldung wie der Checkout. Rechnungen, Karte, Kündigung zum Periodenende gehen erst mit dem Billing-Dienst. | `14-checkout.png` |
| UJ-8 | 5 | Export und Löschung sind in diesem Lauf nicht geklickt. Die Upstream-Routen dafür sind im Code, hier nicht end-to-end belegt. | — |
| UJ-9 | 7 | Signup und Buchungsseite verlinken `https://scalepoint-ventures.com/growthos/legal/terms`, `/privacy`, `/notice`, `/dpa`. Ob diese URLs live 200 liefern, hängt am Marketing-Hub (im Lead-Bericht noch 404). | `15-booking-home.png` |

Buchung, Absage, Verschieben:

- Buchung Introductory Conversation, 27. November 2026, 09:00 UTC, bestätigt. Danach über den Mail-Link abgesagt. Die Seite sagt „Meeting Cancelled“.
- Zweite Buchung 10:00 UTC, bestätigt. Verschieben auf 10:30 UTC. Danke-Seite: „See you on Friday 27 November 2026 instead“, Uhrzeit 10:30 AM. In der Datenbank steht `confirmed` und `2026-11-27 10:30:00`.
- Belege: `19-confirmed` im Log, `24-cancel.png`, `25-cancelled.png`, `23-rescheduled.png`.

## Was am Code geändert ist

- Passwort: mindestens 8 Zeichen, höchstens 72 Byte (bcrypt liest nicht weiter), Ablehnung bekannter geleakter Passwörter über eine lokale Liste plus Have-I-Been-Pwned-Range-API (k-Anonymity, nur die ersten fünf Zeichen des SHA-1). Fällt die API aus, gilt nur die lokale Liste, das Signup blockiert nicht. Keine Kompositionsregeln. Tests nutzen die Offline-Liste und rufen das Netz nicht.
- Webhook-Header `X-BookDesk24-*`. `X-Tymeslot-*`, `X-the scheduler-*` und `X-the-scheduler-*` werden beim Redirect weiterhin als Token-Header gestrichen und nicht mehr gesendet.
- Gettext scrubbt den Upstream-Namen in übersetzten Strings. Interne Modulnamen `Tymeslot.*` bleiben.
- Legal-Defaults außerhalb der Tests: `/growthos/legal/terms`, `/privacy`, `/notice`, `/dpa`. Signup-Checkbox ist an, `ENFORCE_LEGAL_AGREEMENTS=false` schaltet sie aus. Provisioning (Seed) verlangt die Checkbox nicht.
- Deutsche Plan-Texte und die neuen Strings sind informell „du“. Der geerbte Katalog ist weiter überwiegend „Sie“.
- `mix credo --strict`: Plan-Seite liegt in `<.dashboard_page>`, der Plan-Hinweis ist als Banner ausgenommen.

## Was du entscheiden musst

1. **Live-Container.** `book.scalepoint-ventures.com` bleibt 502, bis du den Deploy freigibst. Dieser PR deployed nicht.
2. **Stripe Tax.** `automatic_tax` und `tax_id_collection` auf den Booking-Payment-Links sind auf deine Anweisung nicht angefasst. Ohne das bleibt SR-3 unter 9. Die App-Kopie sagt bewusst „No Stripe Tax“ und verweist auf Reverse Charge im Billing.
3. **`growth-os-billing`.** Checkout, Portal und das Entitlement-Webhook brauchen den Dienst. Ohne ihn gibt es keinen Stripe-Testkauf und kein Self-Service-Kündigen.
4. **AGPLv3.** Das Repo muss öffentlich sein, und `SOURCE_OFFER_URL` muss auf diese URL zeigen, bevor Gäste `/source` sinnvoll nutzen.
5. **Google OAuth.** Consent raus aus Testing, Name BookDesk24, Links auf `/growthos/legal/*`.
6. **Deutsch „du“ im Restkatalog.** Neu und in `plans.po` ist „du“. Tausende geerbte Sätze bleiben „Sie“. Ein mechanischer Umbau wäre fehleranfällig und kollidiert mit PR #5.
7. **Mail-Domain.** `booking@scalepoint-ventures.com` ist der Absender. SPF, DKIM und DMARC sind hier nicht geprüft.
8. **CSS-Präfix `tymeslot-*`.** Sichtbarer Text ist umgestellt. Klassennamen im HTML tragen den alten Namen weiter. Ein Rename trifft fast jedes Template und PR #5.
9. **Domain `bookdesk24.com`.** Die neutrale Brand ist weiter deaktiviert, bis die Domain da ist.
10. **Ob der Signup-Satz „nur für Unternehmen“ heißen soll.** Die Terms-Checkbox ist da, ein eigener B2B-Satz nicht.
