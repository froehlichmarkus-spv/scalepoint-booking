# Scorecard · BookDesk24 mail on Growth OS base v3

Measured on the rendered booking set (confirmation guest and host, reminder, reschedule, cancellation, password reset, verify email, payment refund), German and English. A 9 means that check was run, not assumed. Nothing was sent.

| # | Criterion | Score | Evidence |
|---|---|---|---|
| 1 | Header / Polar Light | **9** | Light and dark header PNGs are the booking CID pair (`header-booking-light@2x.png`, `header-booking-dark@2x.png`), shown at 600×144. Light and dark shots show the ridge, the aurora edge, and the Growth OS · BookDesk24 pill. |
| 2 | Hierarchy and typography | **9** | Eyebrow, one `h1` at 27/34, body at 16/26. One arrow button (`Meeting beitreten` / `Join meeting`). Reschedule and cancel stay text links. The old meeting-details table is no longer repeated above the slot card. |
| 3 | Tangibility (product card) | **9** | Slot card on confirmation, reminder, reschedule, and cancellation (date, time with the recipient's zone, status chip, with / duration / location). Invoice card on the payment-refund mail. |
| 4 | Footer readability and links | **9.5** | Reason line, company line, underlined Datenschutz/Impressum or Privacy/Legal notice. Terms stay hidden. Footer ink `#4A5566` on `#F4F7FB` and link `#0B6E66` on white are in `MailPolicy.contrast_pairs/0` and clear 4.5:1. |
| 5 | Links only to our live hosts | **9.5** | Shell links are `book.scalepoint-ventures.com`, `scalepoint-ventures.com`, and `mailto:support@scalepoint-ventures.com`. A video room is the one exception: the address is the button `href` only. The visible label is `Meeting beitreten` or `Join meeting`. The confirmation HTML does not print the room address as copy. Plain text puts the same label on its own line and the URL under it, because a text part has no href. |
| 6 | Dark mode | **9** | `@media (prefers-color-scheme: dark)` and `[data-ogsc]` / `[data-ogsb]` are in the base. Chrome DevTools `Emulation.setEmulatedMedia` with `prefers-color-scheme: dark` made `matchMedia` true and the shell card compute to `rgb(19, 29, 47)`. The dark shots show the dark header, dark shell, dark slot card, and light footer type. MJML callout panels keep their light fills so their ink stays readable. |
| 7 | Outlook desktop robustness | **9** | Outlook the application was not opened. The rendered confirmation was checked instead, and it has what Outlook needs for the critical layout: `role="presentation"` tables, `bgcolor` on the page, card, header, and button, an `<!--[if mso]>` header path that shows the light PNG, the dark PNG inside `<!--[if !mso]>`, a `v:roundrect` button (`height:48px`, `fillcolor="#111E32"`, Segoe UI / Arial) for the join control, longhand `font-family`, and no `display:flex` or `position:fixed` in the shell. `mail_policy_test.exs` asserts those markers on a rendered shell. |
| 8 | Accessibility | **9** | `lang` on the document, `role="article"`, one `h1`, alt text on both header images, join control at 48px. All 13 pairs in `MailPolicy.contrast_pairs/0` clear 4.5:1 (`mail_policy_test.exs`). axe was not run, so this stays 9 rather than the upstream 9.5. |
| 9 | Mobile 390 | **9** | All 16 renders (8 mails × de/en) at a 390px viewport had `scrollWidth` equal to `clientWidth` (390). No horizontal overflow. The 390px shots are next to this note. |
| 10 | Plain text, preheader, EN/DE (du) | **9.5** | Each template has a text part. The German shell and the account copy use du (`Antworte einfach`, `melde dich`, `Meeting beitreten`, `Speichern und anmelden`). `lang` follows the recipient. Auth lifetimes are the token's own seconds (`AccountTokens.ttl_seconds/1`): verification 30 minutes, reset 60 minutes, magic link 15 minutes, worded as "It works once, for …" / "Er funktioniert einmal und … lang." |
| 11 | Weight / clipping | **9** | The German confirmation HTML is 28,740 bytes. Gmail clips at 102 KB. The two CID headers are 79,881 and 73,793 bytes. |
| 12 | Suite consistency | **9.5** | One booking base, `priv/email/booking/base.{de,en}.{html,txt}.eex`, filled by the same shell for every booking mail. |
| 13 | No vendor names, no fake customers | **10** | `Tymeslot.Emails.VendorNameTest` renders the booking and account mails in German and English, HTML and text, and fails if any of these appear: Tymeslot, SalesBlink, FUTUREBLINK, HeyLeads, ScreamX, IPRoyal, TypeSafe AI, ElevenLabs, Twenty. The names are gone from the templates and the catalogs, not stripped at send time. Internal module names stay in the code. |

**Overall: 9.2.** Every criterion is at least 9.

## Previews

Eight mails, German and English, light and dark, 600 px and 390 px. Files live next to this note: `{mail}-{de|en}-{light|dark}-{600|390}.png`.

Dark shots were taken with Chrome's `prefers-color-scheme: dark` emulation, not by pasting the dark rules into the page.

The German confirmation a person can open, with the CID references still in the markup, is `confirmation-guest-de.html` in this directory. Its header images are `priv/static/images/email/header-booking-light@2x.png` (`header-booking-light@booking.scalepoint`) and `header-booking-dark@2x.png` (`header-booking-dark@booking.scalepoint`).

## Checks

`mix test test/tymeslot/emails/vendor_name_test.exs test/tymeslot/emails/shared/mail_policy_test.exs` covers the forbidden names, the Outlook markers, the link allow-list, and contrast. Nothing in those tests sends mail.
