# BookDesk24 · Inventar (DS v2, Schritt 1)

Stand: 26. Nov 2026. Branch `feat/bookdesk24-ds-v2`, aufgesetzt auf `qa/bookdesk24-saas-ready` (PR #6, `f42621e`) und damit auf `main` (`d019ced`).

Runde 5 auf `feat/bookdesk24-product-ux` (`a2c588a`) ist committet und gepusht. Nichts lag uncommitted. Dieser Branch merged PR #5 nicht: PR #5 zieht Inter, DM Serif und Teal mit, und seine `.po`-Änderungen schneiden sich mit PR #6. Verhalten, das nur auf PR #5 liegt (Zeitzonen-Fallback Europe/Berlin, Slot-Bottom-Sheet, eine Navy-Aktion pro Terminkarte, Skeletons), wird gegen DS v2 neu gebaut, nicht zurückgemergt.

Quellen: `HEADS-BRIEF-V2.md` (Common part und Brief BookDesk24), `MIGRATION.md` §1, `PRODUCT-UX-STANDARD.md` v2, `CONTENT.md` §5.

## Abgrenzung zu PR #6

PR #6 ist offen und ändert White-Label-Texte in diesen Katalogen (alle Sprachen, nicht nur Deutsch): `auth`, `booking`, `common`, `dashboard_automation`, `errors`, `errors_input`, `plans`.

Schritt 1 fasst keine `.po`-Datei an. Die du-Umstellung (~1 453 Treffer, siehe unten) startet erst, wenn PR #6 nicht mehr an denselben Dateien schreibt.

## Was der Code heute ist

| Thema | Ist-Stand auf diesem Branch | DS v2 |
|---|---|---|
| Tokens | Kein `data-m`. 219 Hex-Werte in `assets/css`. Klasse `gos-powered-by` existiert, `gos.css` ist nicht importiert. | `tokens.phoenix.css` + `gos.css`, `data-m="booking"`, keine Hex-Werte im Modulcode |
| Schrift | Inter, DM Serif Display, Fraunces, IBM Plex in `priv/static/fonts/` | Geist + Geist Mono, nur Geist preloaden |
| Icons | 1 001 `hero-`-Treffer in `lib` und `assets` | Lucide-Sprite `priv/static/images/sprite.svg` |
| Primärfarbe | Navy aus dem Polish-Zweig ist hier nicht der einzige Akzent | Navy bleibt Primär. Amber `#F2A40E` nur als Modulfläche, Text in Amber immer Ink `#835000`, Charts `#C27C00` |
| Register | `priv/gettext/GLOSSARY.de.md` §1: „Formal Sie everywhere. Never du.“ | du, `CONTENT.md` §5. Rechtstexte bleiben im eigenen Register |
| Sie/Ihr/Ihnen | 1 453 `msgstr` mit Sie, Ihr oder Ihnen in 64 deutschen `.po`-Dateien; 65 Dateien enthalten das Wort irgendwo | Brief nennt ~1 576 in 66 Dateien. Ziel: 0 in UI-Strings |
| „Powered by“ | `TymeslotWeb.Branding.PoweredBy`: Badge nur auf Free, Pro ohne Badge | bleibt so |
| Öffentliche Buchung | Themes Quill, Rhythm, Paper, Folio. Kein Slot-Bestätigungs-Sheet unter 640 px (das lag nur auf PR #5) | DS-Typo und -Farbe, Bottom Sheet, sticky „Buchung bestätigen“ |
| Auth-Login | `dgettext("auth", "Log in to Tymeslot")` steht noch als msgid. Laufzeit-Brand kommt aus Gettext | kein Upstream-Name |

## Routen

Eigener Fork. Interne Modulnamen `Tymeslot.*` bleiben.

### Auth (`AuthLive`)

| Route | Zustand | Gegen §4 |
|---|---|---|
| `/auth/login` | `:login` | da. Kein Magic-Link, kein „Forgot password?“-Beweis in diesem Inventar nachgemessen. OAuth nur für vom Admin eingeschaltete Provider (`SocialAuthButtons`), keine toten Buttons |
| `/auth/signup` | `:signup` | da. Split-Layout und Navy-Proof-Panel fehlen |
| `/auth/verify-email` | `:verify_email` | da. 6-Stellen-Code plus Link ist nicht der aktuelle Screen |
| `/auth/reset-password` | `:reset_password` | da |
| `/auth/reset-password-sent` | `:reset_password_sent` | da. Cooldown 60/120 s nicht geprüft |
| `/auth/reset-password/:token` | `:reset_password_form` | da |
| `/auth/complete-registration` | `:complete_registration` | Zusatz, nicht in §4 |
| `/auth/password-reset-success` | `:password_reset_success` | da, als Success |
| Token ungültig | `:invalid_token` | teilweise `expired.html` |

Fehlt gegen §4: Magic Link, OAuth-Fehler-Alert, abgelaufener Link als eigene Seite mit vorausgefüllter Adresse, Account-Lock mit Countdown, 2FA, Session-expired-Modal über der aktuellen Seite, Invite-Accept („Lena hat dich eingeladen“), Toast „Du bist abgemeldet“.

Passwort (`password_validator.ex`): mindestens 8, höchstens 72 Byte (bcrypt schneidet danach ab), geleakte Passwörter abgelehnt, keine Komposition. Der Standard sagt Maximum 128. Das ist offen, siehe Fragen im Bericht.

### Onboarding

`/onboarding`, `/onboarding/:step`. Muster `patterns/onboarding.html` ist noch nicht übernommen.

### Dashboard

| Route | Inhalt |
|---|---|
| `/dashboard`, `/dashboard/calendar` | Kalender |
| `/dashboard/overview` | Überblick |
| `/dashboard/meetings` | Termine |
| `/dashboard/meeting-settings` | Termintypen |
| `/dashboard/availability` | Verfügbarkeit |
| `/dashboard/locations`, `/languages` | Orte, Sprachen |
| `/dashboard/integrations`, `/calendar-integration`, `/video-integration` | Kalender und Video |
| `/dashboard/payments` | Zahlungen |
| `/dashboard/embed` | Einbetten |
| `/dashboard/automation` | Webhooks |
| `/dashboard/polls` | Umfragen |
| `/dashboard/analytics` | Auswertung |
| `/dashboard/pages`, `/pages/customize/:theme_id` | Auftritt |
| `/dashboard/account` | Konto |
| `/dashboard/plan` | Tarif |
| `/dashboard/settings` | Einstellungen |

Pflicht-Zustände je Liste (Skeleton, Empty, No results, Error mit Retry, Permission, Success): nicht vollständig. Leere Termine und leere Termintypen existieren im Code, sind auf diesem Branch nicht die DS-Muster. Kein `phx-loading`-Skeleton nach `gos.css`.

### Öffentliche Buchung

`/:username`, `/:username/:slug`, Danke, Absagen, Verschieben, Serie, Umfrage, `/verify-booking/:token`, `/meeting-request/:token`. Priorität im Brief.

### Admin und System

`/admin`. Fehlerseiten über den Phoenix-Error-Render, nicht `patterns/404|500|403|maintenance`.

## Mails

53 Template-Module unter `lib/tymeslot/emails/templates/`. Rahmen ist MJML (`MjmlEmail`), nicht `design-system/email/base.html`. Plain-Text-Helfer (`TextBodyHelper`) existieren; ein DS-Zwilling pro Mail fehlt.

Zuerst diese 12, jeweils mit Plain-Text-Zwilling:

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

Danach die übrigen ~41.

## Vorher-Shots

Live auf diesem Branch, Chrome, `TZ=Europe/Berlin`. Ablage nur unter `/opt/cursor/artifacts/ds-v2/before/`, nicht im Repo. 62 Dateien.

UI, 1440 und 390: `auth-login`, `auth-signup`, `booking-public`, `booking-slots`, `dash-overview`, `dash-meetings`, `dash-plan`.

Signup zeigt noch „Sie“, einen türkisen Primärbutton und „Bei ScalePoint Ventures registrieren“. Die öffentliche Buchung von Nordlicht ist Folio mit dem gesetzten Buchungstext (du), nicht mit dem Katalog.

Mails, alle 12, 600 und 375, hell und dunkel: `mail-<name>-<breite>-<light|dark>.png`. Der heutige MJML-Rahmen. Die Bestätigung trägt oben noch die Marke „Tymeslot“ und „Möchten Sie Änderungen vornehmen?“. Dark-Shots folgen `prefers-color-scheme`; der alte Rahmen tauscht die Fläche dabei kaum.
