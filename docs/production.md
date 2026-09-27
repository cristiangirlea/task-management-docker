# Running Task Board in production

One small server runs everything with Docker Compose: Caddy (HTTPS), the Laravel API
(php-fpm), the Next.js app, Postgres, Redis and a backup job. The app images are built
by the app repos' `release.yml` workflows and pulled from GitHub Container Registry;
this repo holds only the stack definition.

```
internet ──> caddy :443 (Let's Encrypt)
               ├── /api/*, /mcp, /up ──> app   ghcr.io/cristiangirlea/task-management-api
               └── everything else  ──> web   ghcr.io/cristiangirlea/task-management-web
             app ──> postgres, redis            backup ──> nightly pg_dump ──> B2 / R2
```

## What it costs

| Item | Monthly |
| --- | --- |
| Server: DigitalOcean Basic, 1 vCPU / 2 GB (Hetzner CX23, 2 vCPU / 4 GB, is ≈ €5.49 when orderable) | $12 |
| Domain name | ≈ $1 |
| Email: Resend free tier (3,000 emails/month) | $0 |
| Off-site backups: Backblaze B2 or Cloudflare R2 free tier (10 GB) | $0 |
| Stripe: 2.9% + 30¢ per successful card charge (US cards) | per sale |
| **Total fixed cost** | **≈ $13/month** |

A paying workspace has at least four members (the free plan covers three), so at $8 per
member one customer covers the server. Upgrade the server when memory runs short
(`docker stats`): the next size up is about $24.

## 1. Before you start

You need:

- a domain, and access to its DNS;
- a [Resend](https://resend.com) account with the domain verified (it gives you the SPF
  and DKIM records to add), and an API key;
- a [Stripe](https://stripe.com) account. Start in **test mode**: create a product
  "Team" with a **recurring, monthly, per-unit** price (e.g. $8.00). Note the price ID
  (`price_…`) and the test API keys;
- a Backblaze B2 bucket plus an application key limited to it (or a Cloudflare R2
  bucket and an S3 API token).

## 2. Publish the images

Merge the app repos into `master`: each one's `release.yml` publishes its image to GHCR
(`latest` plus a `sha-<commit>` tag). You can also run it by hand from the Actions tab.
The packages are private by default: either make them public (GitHub → your profile →
Packages → package settings), or log the server in with a personal access token that has
`read:packages` (step 4).

## 3. Create the server

1. Create an Ubuntu 24.04 server (DigitalOcean: Basic droplet, Regular, $12/month, 2 GB).
   Add your SSH key when creating it.
2. Point an `A` record for your domain (e.g. `tasks.example.com`) at its IP address.
   Caddy needs this to resolve before the first start, to obtain the certificate.
3. Install Docker and create a deploy user:

   ```bash
   ssh root@<server-ip>
   curl -fsSL https://get.docker.com | sh
   adduser --disabled-password --gecos "" deploy
   usermod -aG docker deploy
   mkdir -p /home/deploy/.ssh && cp ~/.ssh/authorized_keys /home/deploy/.ssh/
   chown -R deploy:deploy /home/deploy/.ssh
   ufw allow OpenSSH && ufw allow 80 && ufw allow 443 && ufw --force enable
   ```

   Docker publishes ports past ufw's rules, which is why only Caddy publishes any:
   Postgres, Redis and php-fpm are reachable only inside the compose network.

## 4. Configure the stack

```bash
ssh deploy@<server-ip>
git clone https://github.com/cristiangirlea/task-management-docker.git
cd task-management-docker
cp .env.prod.example .env.prod && chmod 600 .env.prod
cp backup.env.example backup.env && chmod 600 backup.env
```

Fill in every `CHANGE_ME` in both files. Generate secrets with:

```bash
echo "base64:$(openssl rand -base64 32)"   # APP_KEY
openssl rand -hex 24                        # DB_PASSWORD, REDIS_PASSWORD
```

Leave `STRIPE_WEBHOOK_SECRET` empty until step 6. If the GHCR packages are private:
`echo <token> | docker login ghcr.io -u <github-user> --password-stdin`.

## 5. Start it

```bash
bin/prod up -d --build      # --build: the small backup image is built here
bin/prod logs -f app        # watch the migrations run, then php-fpm start
bin/prod ps                 # every service "healthy" / "running"
curl -fsS https://tasks.example.com/up
```

`bin/prod` is `docker compose -f docker-compose.prod.yml --env-file .env.prod`, so every
compose command works through it (`bin/prod logs web`, `bin/prod exec app php artisan
about`, ...). The app container runs pending migrations every time it starts; it never
seeds. Register at `https://tasks.example.com/register` to create the first workspace.

## 6. Connect Stripe

1. Create the webhook endpoint with the events Cashier handles:

   ```bash
   bin/prod exec app php artisan cashier:webhook --url=https://tasks.example.com/api/stripe/webhook
   ```

   (or in the Stripe dashboard: Developers → Webhooks → add endpoint, events
   `customer.subscription.created/updated/deleted`, `customer.updated/deleted`,
   `payment_method.automatically_updated`, `invoice.payment_action_required`,
   `invoice.payment_succeeded`).
2. Copy the endpoint's signing secret (`whsec_…`) into `STRIPE_WEBHOOK_SECRET` in
   `.env.prod`, then `bin/prod up -d` to restart the app with it. Until it is set the
   webhook is switched off (the app warns about it in `bin/prod logs app`) and upgrades
   never take effect.
3. In the Stripe dashboard, enable the **customer portal** (Settings → Billing → Customer
   portal) and allow customers to update payment methods, view invoices and cancel.

## 7. Smoke test

1. Register, then invite someone: the email should arrive from your domain.
2. Invite two more people: the fourth person is refused with "The Free plan includes up
   to 3 members".
3. Settings → **Upgrade to Team** → pay with the test card `4242 4242 4242 4242` (any
   future date, any CVC). You return to Settings and the plan switches to Team within a
   few seconds (that is the webhook arriving).
4. **Manage billing** opens the Stripe portal. Cancel there: Settings shows "Ends <date>",
   and the workspace keeps Team until then.
5. In Stripe → Webhooks → your endpoint, every delivery shows `200`.

When that all works, repeat step 6 with **live** keys and a live price, and put them in
`.env.prod`.

## 8. Backups

The `backup` service dumps the database every night at 03:15 UTC (`BACKUP_SCHEDULE`),
keeps the last 7 dumps on the server and copies each one to `BACKUP_REMOTE`, where dumps
older than 14 days are deleted.

```bash
bin/prod exec backup backup.sh      # take one now, and check the upload works
bin/prod exec backup restore.sh     # list local and off-site dumps
bin/prod logs backup                # the nightly runs
```

**Do a restore drill once, now**, into a scratch database, so you know the backups are
good:

```bash
bin/prod exec backup sh -c 'createdb restore_drill && RESTORE_DATABASE=restore_drill restore.sh <dump-name>'
bin/prod exec postgres psql -U task_management -d restore_drill -c 'select count(*) from users'
bin/prod exec backup dropdb restore_drill
```

**Restoring for real** (e.g. after losing the server: create a new one, repeat steps 3–5
with the same `.env.prod` and `backup.env`, then):

```bash
bin/prod stop app                              # nothing writes while restoring
bin/prod exec backup restore.sh <dump-name>    # downloads it from BACKUP_REMOTE if needed
bin/prod start app
```

Also keep a copy of `.env.prod` somewhere safe (a password manager): without `APP_KEY`
and the Stripe settings a restored database is of little use.

## 9. Updating

Merging to `master` in an app repo publishes a new `latest` image. To roll it out, run
the **Deploy** workflow in this repo (Actions → Deploy → Run workflow), or on the server:

```bash
cd task-management-docker && git pull && bin/prod pull && bin/prod up -d --build
```

To pin or roll back, set `API_TAG` / `WEB_TAG` in `.env.prod` to a `sha-<commit>` tag
(or give it to the Deploy workflow) and `bin/prod up -d`. Migrations only move forward,
so roll back the database from a backup if a migration has to be undone.

The Deploy workflow needs these repository secrets: `DEPLOY_HOST`, `DEPLOY_USER`
(`deploy`), `DEPLOY_SSH_KEY` (a key pair made for it; its public half goes in the deploy
user's `authorized_keys`), `DEPLOY_KNOWN_HOSTS` (`ssh-keyscan <server-ip>`),
`DEPLOY_PATH` (`/home/deploy/task-management-docker`) and `SITE_DOMAIN`.

## 10. Rehearse on your own machine

With Docker running locally, the same stack works on `localhost` (Caddy then uses its own
local certificate authority, so the browser warns once):

```bash
cp .env.prod.example .env.prod
# SITE_DOMAIN=localhost, APP_URL/FRONTEND_URL/CORS_ALLOWED_ORIGINS=https://localhost,
# APP_KEY and passwords as above, MAIL_MAILER=log, Stripe test keys.
bin/prod up -d --build
open https://localhost
```

## Troubleshooting

- **The certificate is not issued**: DNS does not point at the server yet, or ports 80/443
  are closed. `bin/prod logs caddy` says which.
- **`app` never becomes healthy**: `bin/prod logs app`. Usually a missing or wrong
  `DB_*`/`APP_KEY` value; config is cached at start, so restart after editing `.env.prod`.
- **Emails do not arrive**: the Resend domain is not verified, or `MAIL_FROM_ADDRESS` is
  not on it. Resend's dashboard lists every attempt.
- **Upgrades stay on Free**: `STRIPE_WEBHOOK_SECRET` is missing or wrong; Stripe's webhook
  page shows the failed deliveries and their responses (403 means a wrong secret).
- **Out of memory**: `docker stats`. Lower `pm.max_children` in the API image, or move up a
  server size.
