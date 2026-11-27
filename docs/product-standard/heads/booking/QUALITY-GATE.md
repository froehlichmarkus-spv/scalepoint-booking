# BookDesk24 · quality gate (DS v2.8 imagery + v2.9 auth)

Stand: 27 Nov 2026. Branch `feat/bookdesk24-ds-v2`. Draft PR #7. Not merged.

## Imagery R1–R7 (`/bookdesk24`)

| Rule | Result | Evidence |
|---|---|---|
| R1 Emotional hero | Pass | `imagery-before-1440.png`, `imagery-before-390.png`. Confirmation card and free-slots card on the hero photo. |
| R2 Aurora | Pass | `.aur.aur-booking` amber, teal, violet. |
| R3 Three generated photos | Pass | `booking-hero.jpg`, `booking-section-evening.jpg`, `booking-cta.jpg`. Each has the caption pill. |
| R4 One dark band | Pass | Navy band, then a separate dark photo CTA. |
| R5 Rhythm | Pass | Light hero, mood, one dark band, light fact, dark CTA. |
| R6 Motion | Pass | `data-gos-reveal` only below the fold. Hero cards use `.gos-float`. `data-gos-count` is only the real default fee `0%`. Reduced motion is the static path in `gos-motion.js`. |
| R7 Retina | Pass | File ÷ shown CSS width, 1440 and 390, all ≥ 2. Hero 2560/495 and 2560/369. Mood 2304/594 and 2304/358. CTA 2560/574 and 2560/358. |

Overflow 0 at 1440 and 390. No console errors on those loads. Before-scroll image weight is the hero only, 379 KB (limit 600 KB). Caption ink `#33435A` on solid white is the AA pair from the kit (10.3:1) at both drift extremes, because the pill is opaque.

## Product scorecard

| # | Criterion | Score |
|---|---|---|
| 1 | Visual | 9 |
| 2 | Consistency | 9 |
| 3 | Usability | 9 |
| 4 | Accessibility | 9 |
| 5 | States | 9 |
| 6 | Microcopy | 9 |
| 7 | Mobile | 9 |
| 8 | Perceived performance | 9 |
| 9 | Polish | 9 |
| 10 | Trust | 9 |
| 11 | Emails | 9 |

Auth token lifetimes stay in `lib/tymeslot/auth/account_tokens.ex`: reset 60 minutes, verification 30 minutes, magic link 15 minutes. Mail templates were not edited.
