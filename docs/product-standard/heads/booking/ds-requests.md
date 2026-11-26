# DS requests · BookDesk24

Tokens and sprite symbols that the module needs and the Design System does not ship. No local token was invented for these.

## Sprite

These `hero-` names render as `i-info` until the sprite has a closer symbol:

- arrow-trending-up
- arrows-pointing-in / arrows-pointing-out
- arrows-right-left
- at-symbol
- beaker
- book-open
- bug-ant
- card
- computer-desktop
- cube
- document-text
- ellipsis-horizontal
- face-smile
- gift
- hand-raised
- hashtag
- heart
- identification
- light-bulb
- list-bullet
- paint-brush
- paper-airplane
- pause
- photo
- play
- puzzle-piece
- queue-list
- rectangle-stack
- rocket-launch
- signal
- squares-2x2
- swatch
- tag
- ticket
- view-columns
- window
- wrench-screwdriver

## Colour

Hex remains in these files because no existing `--gos-*` token is the same colour. They should move into `tokens.json` rather than a local alias:

- `assets/css/components/calendar-editing.css`
- `assets/css/components/background-motion.css`
- `assets/css/components/theme-customization.css`
- `assets/css/scheduling/shared/brand-tokens.css` (the v1 bridge palette)
- `assets/css/gos.css` line for `.gos-auth-art .proof .gos-icon` (`#0E9488`). Overridden in `ds-apply.css` with `--gos-teal-ink`.

## Type

Booking-theme font ids (`inter`, `classic`, `editorial`) still name the Inter and Fraunces files in `fonts.css`, because `FontPreload` and its test couple the stack name to those file paths. The app shell, the bridge and Folio headings use Geist.
