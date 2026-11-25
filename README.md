# ScalePoint Booking

Self-hosted booking pages. ScalePoint Ventures is one tenant. Every other booking runs under a separate, neutral brand. Name, logo, colours, sender, and footer are configuration.

The software is a fork of an AGPLv3 scheduler. Module names in the source stay as they were upstream. They do not appear in the product.

## Run it here

```sh
cp deploy/env.local.example .env.local
docker build -f Dockerfile.docker --target release-slim -t spv-booking:local .
docker compose --env-file .env.local -f deploy/compose.local.yml up
```

- ScalePoint page: http://127.0.0.1:4473/markus
- Neutral page: http://127.0.0.1:4473/studio
- Mail catcher: http://127.0.0.1:4474

Passwords are written in the app container at `/tmp/booking-owners.txt`.

## Change a brand

Edit `deploy/brands/<key>.json`, or set the env vars named in that file (`SPV_SENDER_EMAIL`, `NEUTRAL_BRAND_NAME`, and the others). Restart the app. No code change.

Set `BRAND_DB_OVERRIDE=true` only when a row in `tenant_brands` should replace the file.

The neutral tenant must not contain the house name. Mail and the calendar file are checked for that when `SEED_SAMPLE_MAIL=true`.

## Production

See `DEPLOY.md` and `MIGRATE.md`. Do not build the image on the server that already runs the CRM.
