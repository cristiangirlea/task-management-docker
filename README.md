# task-management-docker

Development stack for the task management app: one `docker compose up` brings up
the Laravel API, the Next.js frontend, PostgreSQL, Redis and an nginx front door.

```
                     ┌──────────────────────────────┐
  browser ─────────► │  nginx  (host :8080 → :80)   │
                     └───────┬──────────────┬───────┘
          /api/*, /mcp, /up  │              │  everything else
                             ▼              ▼
                ┌────────────────┐   ┌────────────────────┐
                │ app            │   │ web                │
                │ Laravel 13     │   │ Next.js 15 dev     │
                │ php-fpm :9000  │   │ server :3000       │
                └───┬────────┬───┘   └────────────────────┘
                    ▼        ▼
            ┌──────────┐ ┌────────┐
            │ postgres │ │ redis  │
            │ 16       │ │ 7      │
            └──────────┘ └────────┘
```

The browser only ever talks to nginx, so the Next.js app calls the API on the
same origin (`http://localhost:8080/api`) with Sanctum bearer tokens and CORS
never gets in the way. Only nginx publishes a host port.

## Prerequisites

- Docker Engine 24+ with the Compose v2 plugin (`docker compose`, not
  `docker-compose`). Docker Desktop is fine.
- The three repos cloned **side by side** under the same parent directory:

```
some-folder/
├── task-management-app/          https://github.com/cristiangirlea/task-management-app
├── task-management-next-react/   https://github.com/cristiangirlea/task-management-next-react
└── task-management-docker/       this repo
```

The paths are configurable (`LARAVEL_CONTEXT`, `NEXT_CONTEXT` in `.env`), but the
defaults assume exactly this layout. Both app repos are bind-mounted into their
containers, so edits on the host are picked up live.

## Quick start

```sh
cd task-management-docker
cp .env.example .env

# 1. Generate the Laravel application key and paste it into .env as APP_KEY=...
#    (the first run installs Composer dependencies into ../task-management-app/vendor)
docker compose run --rm --no-deps app php artisan key:generate --show

# 2. Build the images and start everything
docker compose up --build
```

On start the Laravel container clears its caches, runs `php artisan migrate --force`,
seeds demo data when `SEED_DATABASE=true` (the default in `.env.example`) and then
starts php-fpm. The Next.js container runs `npm run dev`.

| What | URL |
| --- | --- |
| App (Next.js) | http://localhost:8080 |
| API (Laravel) | http://localhost:8080/api |
| MCP endpoint | http://localhost:8080/mcp |
| Laravel health check | http://localhost:8080/up |

Demo login when `SEED_DATABASE=true`: **demo@example.com** / **password**.

Change `NGINX_PORT` in `.env` if 8080 is taken; `APP_URL` and `CORS_ALLOWED_ORIGINS`
must be updated to match.

## Common commands

```sh
docker compose up -d                       # start in the background
docker compose logs -f app                 # Laravel logs (LOG_CHANNEL=stderr)
docker compose logs -f web                 # Next.js dev server output
docker compose exec app php artisan migrate
docker compose exec app php artisan migrate:fresh --seed
docker compose exec app php artisan tinker
docker compose exec app php artisan test   # uses in-memory SQLite (.env.testing)
docker compose exec app composer install   # after pulling a composer.lock change
docker compose exec web npm install        # after pulling a package-lock.json change
docker compose exec postgres psql -U task_management task_management
docker compose exec redis redis-cli               # authenticates via REDISCLI_AUTH
docker compose build app                   # rebuild an image (Dockerfile changes)
docker compose down                        # stop; keeps database and redis data
docker compose down -v                     # stop and wipe database and redis data
```

## How it fits together

- **`.env`** is used twice: docker compose interpolates it, and the `app` service
  gets the whole file as its environment (`env_file`). All Laravel settings for
  the stack (`DB_*`, `REDIS_*`, `APP_KEY`, ...) live here, not in the Laravel repo's
  own `.env`. Laravel gives real environment variables precedence, so a stray
  `.env` in `../task-management-app` does not override these.
- **`app`** is built from `.docker/laravel/Dockerfile` with the Laravel repo as
  build context. The image contains a `composer install --no-dev` copy of the app
  and its `CMD` runs the repo's own `entrypoint.sh`. In this dev stack the repo is
  bind-mounted over `/var/www/html`, which hides the image's `vendor/`, so
  `.docker/laravel/docker-entrypoint.sh` (mounted and set as `entrypoint`) runs
  `composer install` when `vendor/` is missing and then execs the normal command.
- **`web`** is built from `.docker/next/Dockerfile`. The repo is bind-mounted
  over `/usr/src/app` while `node_modules` stays in an anonymous volume seeded
  from the image, so a host without `node_modules` (or with macOS/Windows
  binaries in it) does not matter. `WATCHPACK_POLLING=true` keeps hot reload
  working across the mount. `NEXT_PUBLIC_API_URL` is set by compose to
  `http://localhost:${NGINX_PORT}/api`.
- **`nginx`** (`.docker/nginx/default.conf`) sends `/api/*`, `/mcp`, `/mcp/*` and
  `/up` to php-fpm (`app:9000`, always through `public/index.php`) and proxies
  everything else, including the HMR websocket, to `web:3000`.
- **Dockerfile paths.** Compose resolves `dockerfile:` relative to the build
  context (the app repo), so the Dockerfiles in this repo are referenced as
  `${STACK_DIR}/.docker/<service>/Dockerfile`. `STACK_DIR` defaults to
  `../task-management-docker`; change it in `.env` if this repo lives under
  another name. The `Dockerfile.dockerignore` files next to each Dockerfile are
  what BuildKit applies to the app repo during the build.

## Troubleshooting

- **`vendor/` or `node_modules` owned by root (Linux).** The first start installs
  dependencies from inside the containers. If that bothers you, install them on
  the host instead (`composer install`, `npm ci`) before `docker compose up`.
- **Laravel "Permission denied" writing to `storage/`** (Linux hosts): php-fpm
  workers run as `www-data` inside the container while the bind-mounted files
  belong to your user. With `LOG_CHANNEL=stderr`, Redis cache and array sessions
  nothing normally needs writing there; if something does, run
  `chmod -R a+rwX storage bootstrap/cache` in the Laravel repo.
- **nginx exits with "host not found in upstream"**: `app` or `web` failed to
  start; check `docker compose logs app web`.
- **Changed `composer.json` / `package.json`**: run the `exec ... install` commands
  above, or `docker compose up --build` to rebuild the images.

## Production

`docker-compose.prod.yml` is a separate, production stack: Caddy with automatic HTTPS in
place of nginx, the published images from GHCR instead of bind-mounted source, Postgres,
Redis and a nightly off-site backup job. It runs on one small server (about $13/month).
[docs/production.md](docs/production.md) is the runbook: server setup, configuration
(`.env.prod.example`, `backup.env.example`), Stripe and email, backups and restore drills,
updates (the **Deploy** workflow) and a local rehearsal.

```bash
cp .env.prod.example .env.prod   # fill it in
bin/prod up -d --build           # docker compose -f docker-compose.prod.yml --env-file .env.prod ...
```
