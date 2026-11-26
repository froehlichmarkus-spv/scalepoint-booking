# Scorecard · BookDesk24 mail on Growth OS base v3

Baseline: the booking shell before this change (DS v2 stamp on MJML). Scores are what was measured here. A 9 means it was checked, not assumed.

| # | Criterion | Before | After | Evidence |
|---|---|---|---|---|
| 1 | Header / Polar Light | 6: small logo, no aurora | **9** | `header-booking-{light,dark}@2x.png` as CID. Light and dark shots show the ridge, aurora edge and Growth OS · BookDesk24 pill. |
| 2 | Hierarchy | 7 | **8.5** | Eyebrow, one H1, 16/26 body, navy CTA. The older meeting block still sits above the slot card, so the page is busier than a v3 sample. |
| 3 | Tangibility | 6 | **8.5** | Slot card on confirmation, reminder, reschedule and cancellation. Invoice card on the payment-refund preview. |
| 4 | Footer | 7 | **9** | Reason line, company line, underlined Datenschutz/Impressum or Privacy/Legal notice. Terms stay hidden (`TERMS_LIVE` is false). |
| 5 | Links on our hosts | 6 | **8** | `MailPolicyTest` checks the shell and the booking set when every app link is on `book.scalepoint-ventures.com`. A video room URL in the body is still the provider address. Billing CTA uses the signed `/portal` only when that URL is passed in. |
| 6 | Dark mode | 7 | **8.5** | `prefers-color-scheme` and `[data-ogsc]` rules are in the base. Dark PNGs force those rules so the header swap is visible. Not checked in Gmail or Apple Mail. |
| 7 | Outlook desktop | 8 | **8.5** | VML button, ghost tables and `bgcolor` come from the v3 base. No Outlook client on this machine. |
| 8 | Accessibility | 7 | **8.5** | `MailPolicy.contrast_pairs/0` clears 4.5:1 in `mail_policy_test.exs` (lowest pair in that list is above the floor). No axe run. |
| 9 | Mobile 390 | 7 | **8.5** | 390 px shots for every mail below. Overflow was not measured with a layout engine. |
| 10 | Plain text, EN/DE (du) | 7 | **8.5** | DE shell uses du ("Antworte einfach", "Kopier diesen Link"). EN shell is the English base. Text bodies keep their own copy; the v3 footer is appended on send. |
| 11 | Weight | 8 | **9** | A confirmation HTML file is well under 102 KB. Two header PNGs ride as CID. |
| 12 | Suite consistency | 6 | **9** | Layout is `priv/email/booking/base.{de,en}.{html,txt}.eex`, copied from `modules/booking`. |
| 13 | No vendor names | 6 | **8.5** | `MailPolicy.scrub_vendors/1` strips the forbidden names from HTML. URLs are left intact. Some plain-text bodies still contain the old product name until send-time scrub. |

**Overall: 8.6.** Dark-mode clients, Outlook, and axe were not run. External video-room links in the message body are the open link item.

## Previews

Eight mails, German and English, light and dark, 600 px and 390 px. Files live next to this note: `{mail}-{de|en}-{light|dark}-{600|390}.png`.

Mails: confirmation-guest, confirmation-host, reminder, reschedule, cancellation, password-reset, verify-email, payment-refund.

## Checks

`mix test test/tymeslot/emails/shared/mail_policy_test.exs` covers links, the vendor list, and contrast. Nothing in that test sends mail. `SEND_EMAILS` defaults to false, which selects the logger adapter.
