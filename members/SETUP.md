# 8genz Members-area — live zetten

Drie bestanden:

- **index.html**: de members-area. Werkt meteen in demo-modus (nep-data, geen login).
- **schema.sql**: de database, plak je één keer in Supabase.
- **SETUP.md**: dit stappenplan.

```
 1. Supabase-project ──► 2. Database plakken ──► 3. Login instellen ──► 4. Sleutels in CONFIG ──► 5. Online zetten
    (5 min)                 (1 min)                 (3 min)                 (1 min)                    (5 min)
```

---

## 1. Supabase-project aanmaken

1. Ga naar **supabase.com** → *Start your project* → log in met GitHub of e-mail.
2. *New project*:
   - Name: `8genz-members`
   - Database password: genereer er één en **bewaar hem** in je wachtwoordmanager.
   - Region: **West EU (Ireland)** of **Central EU (Frankfurt)**, dan blijft de data in de EU (AVG).
3. Wacht ± 2 minuten tot het project klaar is.

## 2. Database plakken

1. Links in het menu: **SQL Editor** → *New query*.
2. Open `schema.sql`, kopieer alles, plak het erin en klik **Run**.
3. Je ziet "Success". Check onder **Table Editor**: je ziet nu `profiles`, `partners`, `resources`, `sessions` en `intro_requests`, met voorbeelddata.

## 3. Login instellen

1. **Authentication → Sign In / Providers → Email**: staat standaard aan. Laat **Confirm email** aan (nepaccounts blijven dan buiten).
2. **Authentication → URL Configuration**:
   - Site URL: het adres waar de members-area komt, bijv. `https://members.8genz.com`
   - Redirect URLs: voeg hetzelfde adres toe.
   Zonder deze stap werken de bevestigingsmail en de "wachtwoord vergeten"-link niet.
3. **Belangrijk vóór je live gaat:** Supabase verstuurt standaard maar een paar mails per uur. Koppel een eigen mailadres via **Authentication → Emails → SMTP Settings** (bijv. met Resend, gratis tot 3.000 mails per maand). Zo komen de mails ook van `@8genz.com`.

## 4. Sleutels in de CONFIG zetten

1. Kopieer in Supabase:
   - **Project URL** (Project Settings → **Data API**) → in `index.html` bij `supabaseUrl`
   - **anon public** key (Project Settings → **API Keys**, tabblad *Legacy API keys*) → bij `supabaseAnonKey`. Zie je alleen een *publishable key* (`sb_publishable_…`), gebruik die.
2. Pas in hetzelfde CONFIG-blok je links aan: `mainSiteUrl`, `upgradeUrl`, `supportEmail`, `onboardingCallUrl`.

> De **anon**-sleutel mag in de pagina staan; de database schermt zelf af wie wat ziet.
> Zet de **service_role**-sleutel **nooit** in de pagina. Die geeft toegang tot alles.

## 5. Online zetten

Cloudflare Pages, net als je hoofdsite:

1. Cloudflare → **Workers & Pages → Create → Pages → Upload assets**.
2. Upload een map met alleen `index.html` erin. Naam: `8genz-members`.
3. **Custom domains** → `members.8genz.com`.
4. Zet in de CONFIG van je hoofdsite `membersUrl` op dat adres. Dan verschijnt de knop **Log in** vanzelf.

---

## Dagelijks gebruik (zonder code)

Alles via **Table Editor** in Supabase:

```
 Iemand meldt zich aan ──► staat in "profiles" als free
                              │
          klant tekent ──────►│ tier: free → member      (dubbelklik op de cel)
                              │ plan: start / unlimited   (welk pakket hij heeft)
                              ▼
                        ziet direct alles
```

| Wat | Waar | Hoe |
|---|---|---|
| Iemand member maken | `profiles` | `tier` op `member` zetten |
| Pakket instellen | `profiles` | `plan`: `start` of `unlimited` (`none` = nog geen account) |
| Partner toevoegen | `partners` | *Insert row*. `tier`: `free` = iedereen ziet hem, `member` = alleen klanten |
| Partner verbergen | `partners` | `active` uitzetten |
| Resource toevoegen | `resources` | Titel, teaser, link (Google Doc, Notion, Loom…) |
| Call inplannen | `sessions` | `starts_at` + `join_url`. Na de call: `replay_url` invullen |
| Intro-aanvragen zien | `intro_requests` | `status` op `introduced` zetten als je ze hebt gekoppeld |

**Tip:** zet in Supabase onder **Database → Webhooks** (of later via Zapier/Make) een melding op nieuwe rijen in `intro_requests` en `profiles`. Dan krijg je een seintje bij elke intro-aanvraag en elke nieuwe aanmelding: dat zijn je warmste leads.

---

## Wat getest is

- Gratis gebruiker ziet bij afgeschermde content alleen titel en teaser; links, perks en partnernamen komen niet eens binnen in de browser.
- Gratis gebruiker kan zichzelf niet upgraden en geen intro aanvragen (geblokkeerd in de database).
- Niet-ingelogde bezoekers krijgen niets.
- Inloggen, registreren, uitloggen, wachtwoord vergeten en de resetlink werken; de sessie blijft bewaard na herladen.
- Mobiel: geen horizontaal scrollen, navigatie onderin.

Getest tegen een lokale Postgres en een nagebootste Supabase. De echte Supabase-koppeling testen we samen zodra je project staat.
