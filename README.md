[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/new/template/falkordb-3?utm_medium=integration&utm_source=button&utm_campaign=falkordb)

# FalkorDB on Railway

A Railway template for [FalkorDB](https://github.com/FalkorDB/FalkorDB), the graph database for GraphRAG and knowledge graphs (Cypher queries over a Redis-protocol server), with the FalkorDB Browser web UI in the same service.

## What it deploys

One service, built from this repo's [`Dockerfile`](Dockerfile), which pins the official image by version **and** digest:

| Item | Value |
|---|---|
| Image | `falkordb/falkordb:6.0.4@sha256:bef8acb1d8ed9ff8d2ea251767e75c6c05cfa759f7c6bc7e1c122f27d0ea4d7f` (FalkorDB 6.0.4, Redis 8.10.2, FalkorDB Browser 2.7.3) |
| Public HTTPS domain | FalkorDB Browser on port 3000 (needs the database password to log in) |
| TCP proxy | Redis protocol on port 6379, for clients outside Railway |
| Private network | `FALKORDB_PRIVATE_URL` for apps in the same project |
| Volume | `/var/lib/falkordb/data`: RDB snapshots, the append-only file and the Browser's API tokens |
| Health check | `/api/auth/providers` |

[`start.sh`](start.sh) is a small wrapper around the image's own `run.sh`. It refuses to start without `FALKORDB_PASSWORD`, sets `--requirepass`, turns on AOF persistence (`--appendonly yes --appendfsync everysec`) on top of the default RDB snapshots, keeps the Browser's API-token store on the volume, and hands a fresh Railway volume to the unprivileged `falkordb` user so the server doesn't run as root. The Browser login form is prefilled with the local server (`localhost:6379`, user `default`) and never signs in on its own (`FALKORDB_AUTO_CONNECT=false`).

## Variables

The template fills in everything; the deploy page asks for nothing.

| Variable | Default | Why |
|---|---|---|
| `FALKORDB_PASSWORD` | `${{secret(32,…)}}` (letters and digits) | Password of the `default` user, required by the server and the Browser login. |
| `AUTH_SECRET` | `${{secret(64,"0123456789abcdef")}}` | Signs Browser sessions; kept across redeploys so you stay logged in. |
| `ENCRYPTION_KEY` | `${{secret(64,"0123456789abcdef")}}` | Encrypts credentials of the Browser's API tokens; must stay the same. |
| `NEXTAUTH_URL` | `https://${{RAILWAY_PUBLIC_DOMAIN}}` | Public URL of the Browser (login redirects). Change it if you add a custom domain. |
| `PORT` | `3000` | Port of the Browser behind the public domain. |
| `FALKORDB_PRIVATE_URL` | `redis://default:…@${{RAILWAY_PRIVATE_DOMAIN}}:6379` | Connection URL for other services: reference it as `${{FalkorDB.FALKORDB_PRIVATE_URL}}`. |
| `FALKORDB_PUBLIC_URL` | `redis://default:…@${{RAILWAY_TCP_PROXY_DOMAIN}}:${{RAILWAY_TCP_PROXY_PORT}}` | Connection URL from outside Railway, through the TCP proxy. |

Optional: `FALKORDB_ARGS` (module settings, default `MAX_QUEUED_QUERIES 25 TIMEOUT 1000 RESULTSET_SIZE 10000`, see [configuration](https://docs.falkordb.com/getting-started/configuration.html)) and `REDIS_ARGS` (extra `redis-server` flags, added after the template's own).

The password may only use letters, digits and `. _ ~ -`, because it goes on the command line and into URLs.

## After deploy

1. Open the service's public domain, enter the value of `FALKORDB_PASSWORD` (host and user are prefilled) and run a query, for example `CREATE (:Person {name:'Ada'})-[:KNOWS]->(:Person {name:'Bob'})`.
2. From another Railway service, add the variable `FALKORDB_URL=${{FalkorDB.FALKORDB_PRIVATE_URL}}` and connect with a FalkorDB client, e.g. `FalkorDB.from_url(os.environ["FALKORDB_URL"])` in Python.
3. From your machine: `redis-cli -u "$FALKORDB_PUBLIC_URL" GRAPH.QUERY g "MATCH (n) RETURN count(n)"`. Remove the TCP proxy in the service settings if you don't need outside access.

## Updates

The service builds from this repo's `main` branch. When we bump the pinned FalkorDB version, Railway shows an "update available" notice on your project, and you choose when to apply it. Read [CHANGELOG.md](CHANGELOG.md) first: breaking changes are listed at the top of each entry. Your data stays on the volume across updates and redeploys.

FalkorDB major versions can change the on-disk format (a 6.x server can't open a 4.x volume without a migration), so a major bump here is always marked as breaking, with the migration steps.

## Local test

```sh
FALKORDB_PASSWORD=$(openssl rand -hex 16) docker compose -f local-test/compose.yml up --build
```

Then open http://localhost:3000.

## License

This wrapper is MIT. FalkorDB is licensed under the [Server Side Public License v1](https://github.com/FalkorDB/FalkorDB/blob/master/LICENSE); the FalkorDB Browser under its own [license](https://github.com/FalkorDB/falkordb-browser).
