# 8genz

Twee sites, elk een eigen Cloudflare Worker. Een wijziging op `main` gaat automatisch live.

| Map | Wat | Live op |
|---|---|---|
| `site/` | Publieke site | 8genz.com + www.8genz.com |
| `members/` | Members-area (login via Supabase) | members.8genz.com |

## Waar pas je wat aan

- **Site:** `site/public/index.html`. Alle cijfers en links staan in het `CONFIG`-blok onderaan in het script.
- **Members-area:** `members/public/index.html`. Ook daar één `CONFIG`-blok bovenin.
- **Database:** `members/schema.sql` (al uitgevoerd in Supabase, niet opnieuw draaien).
- **Beheer zonder code:** zie `members/SETUP.md`.

## Afspraken

- Elk bestand blijft één HTML-bestand. Het logo zit er inline in.
- Plannamen **Start** en **Unlimited** en de route `#apply` worden door beide sites gebruikt. Pas je ze aan, doe het op beide plekken.
- Geen geheime sleutels in deze repo. De Supabase **anon**-key in de members-area mag; **service_role**- en Resend-keys nooit.
- Test mobiel op 390px breed, zonder horizontaal scrollen.
