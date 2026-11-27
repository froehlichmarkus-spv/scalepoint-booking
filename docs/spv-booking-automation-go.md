# BookDesk24: automatic plan chain, GO package

One GO from Markus runs this file top to bottom. Executor: Outreach OS Lead (or the Booking head). Every step has a check; a failed check means section 7 (rollback), then report.

Chain: signup -> 14-day Pro trial -> trial mail -> access -> checkout -> dunning d0/d3/d6 -> restricted (Free) -> reactivation -> cancel at period end. No manual step once this is done.

Server: `spv-crm` 37.27.9.176, compose project `spv-booking` in `/opt/spv-booking/deploy`. SSH: `ssh -o BatchMode=yes -i ~/.ssh/spv_crm root@37.27.9.176`.
Never print, echo, cat or log a secret value. Check names only (`grep -c '^NAME=.' .env`).

## 0. What is live before GO (checked 2026-11-27)

| Part | State |
| --- | --- |
| Booking image | `spv-booking:e6b8a755` (main e6b8a755), `PLANS_ENABLED=true`, billing client `BillingClient.HTTP`, healthy |
| Signup hook | `UserRegisteredHook` runs in the same transaction as signup: local 14-day Pro trial, then `POST /v1/accounts {trial:true}` to billing |
| Billing push | billing `MODULE_BOOKING_WEBHOOK_URL=https://book.scalepoint-ventures.com/webhooks/growth-os-billing`; Booking verifies `X-GOS-Signature` (HMAC-SHA256, 5 min) with `GROWTH_OS_BILLING_WEBHOOK_SECRET`. Probe 2026-11-27: wrong key 400, billing key accepted. No booking push has happened yet (0 booking accounts at billing). |
| Resync | Oban cron every 6 h pulls `GET /v1/entitlements` for trials, past-due and ended periods |
| Access | Pro while `trialing` (trial not over), `active`, or `past_due` inside `grace_until`; else Free (1 event type, 1 calendar, Pro features off, extra event types paused, not deleted) |
| Booking mails | `SEND_EMAILS=true`, Resend, From `BookDesk24 <noreply@scalepoint-ventures.com>`, Reply-To `support@scalepoint-ventures.com`. Booking sends account and booking mails only, no plan mails |
| Billing mails | billing sends trial_ending, subscription_started, payment_failed_d0/d3/d6, read_only, payment_recovered, cancel_scheduled, subscription_ended. `trial_started` exists only in the local billing copy, not deployed |
| Billing mode | `ALLOW_LIVE_MODE=false`, `MAIL_ALLOW_REAL_RECIPIENTS=false`, `MAIL_TEST_RECIPIENT` is a Resend sink, so billing mails in test mode do not reach a person today |

## 1. Preconditions (billing side, done by the billing owner before GO)

| ID | Change on growth-os-billing | Why |
| --- | --- | --- |
| B1 | Deploy the billing build that contains the `trial_started` mail | Welcome mail at trial start. Booking sends no welcome mail, so there is no duplicate |
| B2 | Keep `MODULE_BOOKING_WELCOME_URL=https://book.scalepoint-ventures.com/welcome` and `MODULE_BOOKING_TRIAL_ENABLED` unset or `true` | Trial mail button opens the dashboard (needs this PR) |
| B3 | For the test run only: `MAIL_TEST_RECIPIENT=markus@scalepoint-ventures.com` | In test mode billing sends every mail to this address as `markus+<kind>@…`; today it goes to a sink |
| B4 | For the test run only: `ALLOW_TEST_CLOCK_API=true`; back to `false` after section 6 | Fast-forward trial end and dunning with Stripe test clocks, and `POST /internal/tick` |
| B5 | Not part of this GO: live keys, `ALLOW_LIVE_MODE=true`, `MAIL_ALLOW_REAL_RECIPIENTS=true` | Real money and real customer mails need their own GO |

Check after B1–B4 (names and flags only):

```sh
ssh -o BatchMode=yes -i ~/.ssh/spv_crm root@37.27.9.176 '
grep -c "trial_started" /opt/growth-os-billing/app/service.py
grep -E "^(ALLOW_LIVE_MODE|ALLOW_TEST_CLOCK_API|MAIL_ALLOW_REAL_RECIPIENTS)=" /opt/growth-os-billing/.env
grep -E "^MAIL_TEST_RECIPIENT=markus@scalepoint-ventures.com$" -c /opt/growth-os-billing/.env
curl -fsS https://billing.scalepoint-ventures.com/healthz'
```

Expected: `trial_started` count ≥ 1, `ALLOW_LIVE_MODE=false`, `ALLOW_TEST_CLOCK_API=true`, `MAIL_ALLOW_REAL_RECIPIENTS=false`, recipient count 1, healthz `"livemode":false`.

## 2. Merge

PR #10 (`feat/bookdesk24-automation-chain`) into `main`, merge commit, keep the branch, only when Verify, Secret scan and Licensing are green. GitHub may require the async merge endpoint:

```sh
R=froehlichmarkus-spv/scalepoint-booking
gh pr view 10 -R $R --json headRefOid,mergeable,statusCheckRollup
gh pr ready 10 -R $R
gh api -X PUT repos/$R/pulls/10/merge-async -f merge_method=merge -f merge_action=direct_merge -f sha=<head sha>
```

What the PR changes: checkout success URL is `/welcome?checkout=success`; bare `/welcome` (trial mail button) opens `/dashboard`; optional `GROWTH_OS_BILLING_TEST_CLOCK`; `PLANS_COMPED_EMAILS` in compose and env example; chain contract test `test/tymeslot_web/controllers/growth_os_billing_chain_test.exs`.

## 3. Build and deploy (build on the box, never on the server)

```sh
cd /workspace/deploy-src/scalepoint-booking && git fetch -q origin && git checkout -q main && git reset -q --hard origin/main
SHA=$(git rev-parse --short=8 HEAD)
sudo docker build -f Dockerfile.docker --target release-slim -t spv-booking:local -t spv-booking:$SHA .

ssh -o BatchMode=yes -i ~/.ssh/spv_crm root@37.27.9.176 '
cd /opt/spv-booking/deploy
OLD=$(docker inspect --format "{{.Image}}" spv-booking-app)
docker tag "$OLD" spv-booking:prev-e6b8a755
TS=$(date +%Y%m%d-%H%M); cp -p .env .env.bak-$TS; cp -p compose.yml compose.yml.bak-$TS; echo $TS'

sudo docker save spv-booking:local spv-booking:$SHA | gzip -1 | ssh -o BatchMode=yes -i ~/.ssh/spv_crm root@37.27.9.176 'gunzip | docker load'
```

## 4. Env and compose on the server

Exact lines. Values come from the named source, never from chat.

`/opt/spv-booking/deploy/.env` (add or set):

```
PLANS_COMPED_EMAILS=<owner login addresses that must always have Pro, comma-separated; list confirmed by Markus>
GROWTH_OS_BILLING_TEST_CLOCK=true    # test run only; set to false in step 6.9
```

Unchanged and required (check names only): `GROWTH_OS_BILLING_URL` (`https://billing.scalepoint-ventures.com`), `GROWTH_OS_BILLING_API_KEY` (= billing `MODULE_BOOKING_API_KEY`), `GROWTH_OS_BILLING_WEBHOOK_SECRET` (= billing `MODULE_BOOKING_WEBHOOK_SECRET`), `PLANS_ENABLED=true`, `SEND_EMAILS=true`, `RESEND_API_KEY` (box secret), `MAIL_FROM`, `MAIL_REPLY_TO`.

`/opt/spv-booking/deploy/compose.yml`, app `environment`, after `GROWTH_OS_BILLING_WEBHOOK_SECRET` (leave `PHX_HOST` on line 41 and everything else):

```
      PLANS_COMPED_EMAILS: ${PLANS_COMPED_EMAILS:-}
      GROWTH_OS_BILLING_TEST_CLOCK: ${GROWTH_OS_BILLING_TEST_CLOCK:-false}
```

Apply without printing values:

```sh
ssh -o BatchMode=yes -i ~/.ssh/spv_crm root@37.27.9.176 'cd /opt/spv-booking/deploy && python3 - <<"PY"
from pathlib import Path
c = Path("compose.yml"); t = c.read_text()
a = "      GROWTH_OS_BILLING_WEBHOOK_SECRET: ${GROWTH_OS_BILLING_WEBHOOK_SECRET:-}\n"
if "PLANS_COMPED_EMAILS" not in t:
    assert t.count(a) == 1
    t = t.replace(a, a + "      PLANS_COMPED_EMAILS: ${PLANS_COMPED_EMAILS:-}\n      GROWTH_OS_BILLING_TEST_CLOCK: ${GROWTH_OS_BILLING_TEST_CLOCK:-false}\n")
    c.write_text(t)
PY
for n in PLANS_COMPED_EMAILS GROWTH_OS_BILLING_TEST_CLOCK GROWTH_OS_BILLING_URL GROWTH_OS_BILLING_API_KEY GROWTH_OS_BILLING_WEBHOOK_SECRET PLANS_ENABLED SEND_EMAILS RESEND_API_KEY; do echo "$n $(grep -c "^$n=." .env)"; done
sed -n 41p compose.yml
docker compose -p spv-booking -f compose.yml config -q && echo compose_ok'
```

Set the two `.env` lines with an editor or a `set_line` script like the billing switch in `docs/spv-booking-runbook.md`; each name must count 1.

## 5. Start and health

```sh
ssh -o BatchMode=yes -i ~/.ssh/spv_crm root@37.27.9.176 '
cd /opt/spv-booking/deploy
docker compose -p spv-booking -f compose.yml up -d --no-build --pull never --force-recreate app
sleep 60
curl -fsS http://127.0.0.1:4473/healthcheck; echo
for u in "" /bookdesk24 /auth/login /auth/signup; do curl -s -o /dev/null -w "$u %{http_code}\n" https://book.scalepoint-ventures.com$u; done
curl -fsS https://billing.scalepoint-ventures.com/healthz; echo
docker inspect --format "restarts={{.RestartCount}} {{.State.Status}}" spv-booking-app
docker exec spv-booking-app bin/tymeslot rpc "c = Application.get_env(:tymeslot, :billing_client); IO.inspect({c, c.health()}); IO.inspect(Keyword.take(Application.get_env(:tymeslot, Tymeslot.Mailer), [:adapter])); IO.inspect(Application.get_env(:tymeslot, :plans)[:billing_test_clock], label: :test_clock)"
docker logs spv-booking-app 2>&1 | grep -ciE "\"severity\":\"error\"|\*\* \(|crash"
docker ps --format "{{.Names}} {{.Status}}" | grep -E "billing|connect|booking"; free -m | head -2'
```

Pass: healthcheck 200, `/` 302, `/bookdesk24` 200, `/auth/login` 200, `/auth/signup` 200, billing `livemode:false`, 0 restarts, `{Tymeslot.Plans.BillingClient.HTTP, :ok}`, adapter `Swoosh.Adapters.Resend`, `test_clock: true`, error count 0, billing and connect healthy.

## 6. End-to-end run (Stripe TEST mode only, mails only to markus@scalepoint-ventures.com)

Test accounts use plus addresses that land in Markus's inbox: `markus+boo-e2e1@scalepoint-ventures.com` (full chain) and `markus+boo-e2e2@scalepoint-ventures.com` (trial ends unpaid). Passwords: generated, kept in the vault, never in chat or files. Cards: Stripe test cards only, 4242 4242 4242 4242 and 4000 0000 0000 0341.

Read a test account's plan on the server (no secrets):

```sh
ssh -o BatchMode=yes -i ~/.ssh/spv_crm root@37.27.9.176 'docker exec spv-booking-app bin/tymeslot rpc "
email = \"markus+boo-e2e1@scalepoint-ventures.com\"
u = Tymeslot.Repo.get_by(Tymeslot.Auth.UserSchema, email: email)
e = Tymeslot.Plans.get_entitlement(u.id)
IO.inspect(%{plan: Tymeslot.Plans.effective_plan(u.id), status: e && e.status, version: e && e.source_version, trial_ends_at: e && e.trial_ends_at, grace_until: e && e.grace_until, cancel_at_period_end: e && e.cancel_at_period_end})"'
```

Advance a test clock (billing owner, Stripe test key from the billing server env, never printed), then let billing process:

```sh
# on the billing side, test mode only
stripe test_helpers test_clocks advance <clock id from billing orgs.test_clock_id> --frozen-time <unix time>
curl -fsS -X POST https://billing.scalepoint-ventures.com/internal/tick -H "Authorization: Bearer <MODULE_BOOKING_API_KEY from billing env>"
```

| # | Step | Expected |
| --- | --- | --- |
| 6.1 | Sign up `markus+boo-e2e1@…` on `/auth/signup`, open the verify mail | Verify mail from BookDesk24 (Resend); account verified |
| 6.2 | Read plan | `pro`, `trialing`, trial ends in 14 days, version ≥ 1 (billing push arrived) |
| 6.3 | Inbox | One `trial_started` mail from billing (`markus+trial-started@…`); its button opens `/welcome` → `/dashboard`. No second welcome mail from Booking |
| 6.4 | Create a second event type, enable a Pro feature (polls) | Allowed during trial |
| 6.5 | `/dashboard/plan` → Pro monthly → Stripe checkout with 4242 | Back on `/dashboard/plan?checkout=success` ("Activating your plan…"), then `pro`/`active`; `subscription_started` mail |
| 6.6 | Customer portal from the plan page: replace card with 4000 0000 0000 0341; advance clock past `current_period_end`; tick | `payment_failed_d0` mail; plan `pro`, `past_due`, `grace_until` ≈ +7 days; dashboard banner "A payment is past due" |
| 6.7 | Advance +3 d, tick; +6 d, tick; +7 d, tick | `payment_failed_d3`, `payment_failed_d6`, then `read_only` mail; plan `free` (status `past_due`, `grace_until` in the past); extra event type paused, polls off |
| 6.8 | Portal: card 4242, pay the open invoice | `payment_recovered` mail; plan `pro`/`active`; paused event type public again |
| 6.9 | Portal: cancel | `cancel_scheduled` mail; still `pro` with `cancel_at_period_end: true`; advance past period end, tick → `subscription_ended` mail, plan `free` |
| 6.10 | Sign up `markus+boo-e2e2@…`, advance its clock past day 14, tick | `trial_ending` mail before the end; after it plan `free` (`canceled`) |
| 6.11 | Missed push check: stop nothing, run `docker exec spv-booking-app bin/tymeslot rpc "Tymeslot.Plans.Workers.EntitlementResync.perform(%Oban.Job{args: %{}})"` | Returns `:ok`; plans unchanged |

After the run:

1. `.env`: `GROWTH_OS_BILLING_TEST_CLOCK=false`, then `docker compose -p spv-booking -f compose.yml up -d --no-build --pull never --force-recreate app` and the section 5 checks (`test_clock: false`).
2. Billing owner: `ALLOW_TEST_CLOCK_API=false`; `MAIL_TEST_RECIPIENT` back to its sink, or leave on markus@ until live mode.
3. Test accounts stay (they are test-mode only) unless Markus asks to delete them.
4. Record results in `human-tests/booking.md` (BOO-xx) and the scorecard.

## 7. Rollback

Any failed check in sections 3–5, or a crash loop:

```sh
ssh -o BatchMode=yes -i ~/.ssh/spv_crm root@37.27.9.176 '
cd /opt/spv-booking/deploy
TS=<stamp printed in section 3>
cp -p .env.bak-$TS .env; cp -p compose.yml.bak-$TS compose.yml
docker tag spv-booking:prev-e6b8a755 spv-booking:local
docker compose -p spv-booking -f compose.yml up -d --no-build --pull never --force-recreate app
sleep 60; curl -fsS http://127.0.0.1:4473/healthcheck'
```

No migration in this PR, so the database needs no restore. If a plan row is wrong after a failed test, billing's next push or the resync worker overwrites it (newer version wins). Code rollback: revert the merge commit with a PR, never a force push.

## 8. Backup

Daily at 03:15 Europe/Berlin, `/etc/cron.d/growth-os-backup` runs `/opt/growth-os-backup/backup.sh`. It calls this repo's `ops/backup-booking.sh` (`docker exec spv-booking-postgres pg_dump -U booking -d booking -Fc`) and checks the dump with `pg_restore --list`. Output: `/var/backups/growth-os/<date>/booking.dump`, 600, 14 days. Restore: see `docs/spv-booking-runbook.md` and the restore notes in the GO report.
