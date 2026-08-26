# PEXEK CRM deployment

PEXEK CRM is a full Frappe application. It needs a database, Redis, background
workers, a websocket service, and a frontend proxy. It cannot be deployed as a
static website on GitHub Pages, Vercel, or Netlify.

## Production route

Every push to `main` builds a versioned container and publishes it to:

```text
ghcr.io/selqaous-maker/pexek-crm:latest
```

Use a Linux VPS with Docker, a domain or subdomain whose DNS points to the VPS,
and ports 80 and 443 open. The official Frappe easy-install route is:

```bash
wget https://frappe.io/easy-install.py

python3 ./easy-install.py deploy \
  --project=pexek_crm \
  --email=YOUR_EMAIL \
  --image=ghcr.io/selqaous-maker/pexek-crm \
  --version=latest \
  --app=crm \
  --sitename=crm.pexek.com
```

Replace `YOUR_EMAIL` and `crm.pexek.com` before running the command. If the
container package is private, authenticate the server first with `docker login
ghcr.io`, or change the package visibility to public in GitHub Packages.

After the first login:

1. Change the Administrator password.
2. Open **Settings > Custom Branding** and upload the final PEXEK logo/favicon.
3. Configure an outgoing email account before inviting teammates.
4. Open **Settings > Invite Users** and add each teammate as Admin, Manager, or
   Sales User.
5. Create an encrypted off-server backup schedule before adding production data.

## Local development

The compose file in `docker/` is only for development:

```bash
cd docker
cp .env.example .env
docker compose up -d
docker compose logs -f frappe
```

Then open `http://crm.localhost:8000/crm`. Change the passwords in `.env` before
starting the stack. Production should use the official Frappe production stack,
not this development compose file.

## Updating production

The image workflow publishes an immutable tag for every commit as well as
`latest`. After pulling a new image, run the Frappe migrator/`bench migrate`
before serving traffic. Keep the previous commit tag available for rollback and
restore the matching database backup if a migration must be reversed.
