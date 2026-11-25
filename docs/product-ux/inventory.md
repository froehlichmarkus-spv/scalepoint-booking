# BookDesk24 Inventar (verifiziert am Code)

Quelle: Fork `froehlichmarkus-spv/scalepoint-booking`, Branch `feat/bookdesk24-product-ux` auf `feat/bookdesk24-polish`.
Geprüft gegen `lib/tymeslot_web/router.ex`, `lib/tymeslot_web/live/**`, `lib/tymeslot/emails/templates/**` und `priv/gettext/de/**`.

Alles hier ist **eigener Code** (Fork). Keine Vendor-UI und keine Vendor-Mails. Interne Modulnamen `Tymeslot.*` bleiben.

## Auth

| Route | Live-Action | Stand |
|---|---|---|
| `/auth/login` | `:login` | eigener Code |
| `/auth/signup` | `:signup` | eigener Code |
| `/auth/verify-email` | `:verify_email` | eigener Code |
| `/auth/reset-password` | `:reset_password` | eigener Code |
| `/auth/reset-password-sent` | `:reset_password_sent` | eigener Code |
| `/auth/reset-password/:token` | `:reset_password_form` | eigener Code |
| `/auth/complete-registration` | `:complete_registration` | eigener Code |
| `/auth/password-reset-success` | `:password_reset_success` | eigener Code |

Passwort: mindestens 8 Zeichen, lokale Blocklist (häufig/kompromittiert), kein Teil des E-Mail-Namens, keine Kompositionsregeln. Anzeige-Toggle mit `aria-pressed`, Live-Checkliste, Stärke-Hinweis, Feststelltaste.

## Onboarding

`/onboarding`, `/onboarding/:step` — Profil, Kalender, Termin, Theme, fertig (`OnboardingLive`).

## Dashboard

| Route | Inhalt |
|---|---|
| `/dashboard`, `/dashboard/calendar` | Kalender |
| `/dashboard/overview` | Überblick |
| `/dashboard/meetings` | Buchungen |
| `/dashboard/meeting-settings` | Termintypen, leerer Zustand vorhanden |
| `/dashboard/availability` | Verfügbarkeit |
| `/dashboard/integrations`, `/calendar-integration`, `/video-integration` | Kalender und Video |
| `/dashboard/payments` | Stripe Connect |
| `/dashboard/embed` | Einbettung |
| `/dashboard/automation` | Webhooks |
| `/dashboard/polls` | Umfragen |
| `/dashboard/analytics` | Auswertung |
| `/dashboard/pages`, `/pages/customize/:theme_id` | Auftritt |
| `/dashboard/account` | Konto, Gefahrenzone, Löschen |
| `/dashboard/plan` | Plan, Pro-Testphase, Rückfall auf Free, Stripe-Portal |
| `/dashboard/settings`, `/locations`, `/languages` | Einstellungen |

Shell: helle Sidebar, eine Navy-Primäraktion, Karten mit Linie und leichter Elevation, Seitentitel in DM Serif.

## Öffentliche Buchung

Themes Quill (Default), Rhythm, Paper, Folio. Routen über `Themes.Core.Dispatcher`:

- `/:username`, `/:username/:slug`, `/:username/:slug/book`
- Danke: `/:username/thank-you`, `/:username/:page/thank-you`
- Absagen und Verschieben: `/:username/meeting/:meeting_uid/cancel|reschedule`
- Serie: `/:username/series/:series_uid`
- Umfrage: `/:username/poll/:token`
- `BookingVerificationLive` `/verify-booking/:token`
- `MeetingRequestLive` `/meeting-request/:token`

Mobil: die Bestätigung sitzt in `.booking-confirm-sheet` (unter 640 px ein Bottom-Sheet, Button über die Breite). Quill, Rhythm und Folio sagen „Confirm booking“ / „Buchung bestätigen“.

## Admin und System

`/admin` Authentication, Settings, Email, General, Users. Fehlerseiten über den Phoenix-Error-Render.

## Billing

`PlanComponent`: aktueller Plan, Preise netto, Portal, Vergleich Free/Pro.
Neu: Karte **Pro-Testphase** (Tage, was am Ende passiert) und **Wieder bei Free**, wenn der Status `canceled`, `unpaid` oder `incomplete_expired` ist und der Plan Free ist.
`PlanNoticeComponent`: Zahlung überfällig, Testphase endet in 3 Tagen, Free-Limits.

## Mails

53 Template-Module unter `lib/tymeslot/emails/templates/`. Absendername der House-Brand: **ScalePoint Growth OS**. Rahmen (`Frame`, `Layouts`, `Buttons`): Navy-CTA, Serif-Überschrift, helle Fläche `#F5F7F9`, Dark-Palette, Footer mit ScalePoint Ventures Oy, Business ID und Links auf `/growthos/legal/terms|privacy|notice`.

Priorität 12, alle über diesen Rahmen:

1. `appointment_confirmation`
2. `appointment_reminder`
3. `appointment_rescheduled`
4. `appointment_cancellation`
5. `calendar_invitation`
6. `email_verification`
7. `password_reset`
8. `account_invitation`
9. `integration_reauth_required`
10. `calendar_sync_error`
11. `booking_payment_refunded`
12. `account_deletion_notice`

Weitere Gruppen: Polls (8), Serie (5), Reschedule-Anfragen (5), Buchungsanfragen (4), E-Mail-Wechsel (3), Integrationen, Admin-Alerts, Zahlung.

## Deutsch

Verbindlich ist das informelle **du** (Entscheidung Markus, geht dem Standard-„Sie“ vor). Die bestehenden du-Sätze in `onboarding_wizard.po` („hier kannst du dir einen Termin…“) sind unverändert. Übrige Anreden in `priv/gettext/de` sind auf du umgestellt.

## Lücken

| # | Lücke | Umgang | Wirkung |
|---|---|---|---|
| 1 | Kein gesetzter Demo-Workspace in dieser Umgebung | Vorher/Nachher sind Renderings der ausgelieferten Tokens und Flächen (Auth, Dashboard, Slots, Mail), nicht ein gebootetes LiveView mit Seed | Shots |
| 2 | Nicht jede Dashboard-Tabelle wird unter 640 px zur Kartenliste | Öffentliche Buchung hat das Sheet und den sticky Button; Plan-Tabelle bleibt Tabelle | Mobile |
| 3 | bcrypt liest 72 Byte | Obergrenze bleibt 72 Byte, nicht 128 | Passwort |
| 4 | Magic-Link/2FA/Session-Modal sind nicht als eigene Screens da, wo der Stack sie nicht hat | Login, Reset, Verify, abgelaufener Token sind da | States |
