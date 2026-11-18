# RLH University container standup

**Status:** queued
**Created:** 2026-11-18
**Source:** Cloudy-Work kickoff
**Do not start this ahead of the current PBS / reboot work.**

## Objective

Stand up a blue-green pair for The RLH University and create its database on the shared Postgres VIP. Do not choose or publish a public domain.

## App

- Repo: https://github.com/heybearc/rlh-university
- Local: `~/Projects/rlh-university`
- MCP app id: `rlh-university`
- Canonical path: `/opt/rlh-university`
- Port: 3001
- PM2: `rlh-university-blue` and `rlh-university-green`
- Subnet: `10.92.3.0/24` / `vmbr0923` only
- Use `ansible/playbooks/deploy-bluegreen-app.yml` and a new `group_vars` file. Do not clone the HHV or mail playbooks.

## Database

Shared Postgres RW VIP `10.92.3.23` (`postgres.cloudigan.net`).

- Database: `rlh_university`
- User: `rlh_university`
- Password stays on the containers. Do not commit it.

The Prisma schema in the app repo has no models yet. Creating the empty database and role is enough.

## Leave unset

- External domain, DNS, and NPM host. The app briefing has not chosen a name.
- Container IDs and addresses until this standup assigns them. Then report those values for the Cloudy-Work APP-MAP entry.

## After the containers exist

1. Register `rlh-university` in the homelab blue-green MCP `APPS` map with the PM2 names above.
2. Put the CT IDs and IPs into Cloudy-Work `_cloudy-ops/context/APP-MAP.md`. Leave the domain blank.
3. Secrets stay in each container's `/opt/rlh-university/.env`.

## Acceptance

- [ ] Blue and green containers exist on `10.92.3.0/24`
- [ ] Each runs the repo on port 3001 under the PM2 names above
- [ ] Database `rlh_university` and user `rlh_university` exist on `10.92.3.23`
- [ ] No public DNS name was created
- [ ] APP-MAP has the real CT IDs and IPs, and the domain line is still "not chosen"
