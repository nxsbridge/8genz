-- =====================================================================
-- 8genz Members-area — database schema for Supabase
-- Run this once: Supabase dashboard → SQL Editor → New query → paste → Run
-- =====================================================================
-- How access works:
--   * Everyone who signs up gets tier 'free'.
--   * You make someone a member by setting profiles.tier = 'member'
--     (Table Editor → profiles). That's the only switch.
--   * Free users see titles + teasers of member content, never the content
--     itself. This is enforced in the database, not just in the page.
-- =====================================================================


-- ---------- 1. Profiles (one row per user) ---------------------------
create table if not exists public.profiles (
  id          uuid primary key references auth.users(id) on delete cascade,
  email       text,
  full_name   text,
  company     text,
  tier        text not null default 'free' check (tier in ('free','member')),
  plan        text not null default 'none' check (plan in ('none','start','unlimited')),
  -- none = no account yet, start = Start plan, unlimited = Unlimited plan
  created_at  timestamptz not null default now()
);

alter table public.profiles enable row level security;

drop policy if exists "read own profile" on public.profiles;
create policy "read own profile" on public.profiles
  for select using (auth.uid() = id);
-- No update policy on purpose: tier and plan are only changed by you.

-- Create a profile automatically when someone signs up
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, email, full_name, company)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data->>'full_name', ''),
    coalesce(new.raw_user_meta_data->>'company', '')
  );
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Helper: is the current user a member?
create or replace function public.is_member()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.profiles where id = auth.uid() and tier = 'member');
$$;


-- ---------- 2. Partners ----------------------------------------------
create table if not exists public.partners (
  id          bigint generated always as identity primary key,
  category    text not null check (category in ('Finance','Growth','Operations')),
  name        text not null,
  service     text not null,          -- one line: what they do (visible to all)
  description text,                   -- members only
  perk        text,                   -- members only, e.g. "15% off first 3 months"
  tier        text not null default 'member' check (tier in ('free','member')),
  sort        int  not null default 100,
  active      boolean not null default true
);
alter table public.partners enable row level security;
-- No select policy: the page reads partners only through list_partners() below.


-- ---------- 3. Resources (profile structures, SOPs, templates) --------
create table if not exists public.resources (
  id          bigint generated always as identity primary key,
  category    text not null,          -- e.g. 'Profile structures', 'SOPs', 'Templates'
  title       text not null,
  teaser      text,                   -- visible to all
  url         text,                   -- members only (Google Doc, Notion, PDF, Loom…)
  tier        text not null default 'member' check (tier in ('free','member')),
  sort        int  not null default 100,
  active      boolean not null default true
);
alter table public.resources enable row level security;


-- ---------- 4. Coaching sessions --------------------------------------
create table if not exists public.sessions (
  id          bigint generated always as identity primary key,
  title       text not null,
  starts_at   timestamptz,            -- null = recording only
  join_url    text,                   -- members only
  replay_url  text,                   -- members only
  tier        text not null default 'member' check (tier in ('free','member')),
  active      boolean not null default true
);
alter table public.sessions enable row level security;


-- ---------- 5. Intro requests (members ask you for a partner intro) ---
create table if not exists public.intro_requests (
  id          bigint generated always as identity primary key,
  user_id     uuid not null references auth.users(id) on delete cascade default auth.uid(),
  partner_id  bigint not null references public.partners(id) on delete cascade,
  message     text,
  status      text not null default 'new' check (status in ('new','introduced','closed')),
  created_at  timestamptz not null default now()
);
alter table public.intro_requests enable row level security;

drop policy if exists "members request intros" on public.intro_requests;
create policy "members request intros" on public.intro_requests
  for insert with check (auth.uid() = user_id and public.is_member());

drop policy if exists "read own intros" on public.intro_requests;
create policy "read own intros" on public.intro_requests
  for select using (auth.uid() = user_id);


-- ---------- 6. Read functions with gating built in -------------------
-- Free users get the row but with the member-only fields blanked out.

create or replace function public.list_partners()
returns table (id bigint, category text, name text, service text,
               description text, perk text, locked boolean)
language sql stable security definer set search_path = public as $$
  select p.id, p.category,
         case when p.tier = 'free' or public.is_member() then p.name else 'Partner in ' || lower(p.category) end,
         p.service,
         case when p.tier = 'free' or public.is_member() then p.description end,
         case when p.tier = 'free' or public.is_member() then p.perk end,
         not (p.tier = 'free' or public.is_member())
  from public.partners p
  where p.active and auth.uid() is not null
  order by p.category, p.sort, p.id;
$$;

create or replace function public.list_resources()
returns table (id bigint, category text, title text, teaser text, url text, locked boolean)
language sql stable security definer set search_path = public as $$
  select r.id, r.category, r.title, r.teaser,
         case when r.tier = 'free' or public.is_member() then r.url end,
         not (r.tier = 'free' or public.is_member())
  from public.resources r
  where r.active and auth.uid() is not null
  order by r.category, r.sort, r.id;
$$;

create or replace function public.list_sessions()
returns table (id bigint, title text, starts_at timestamptz,
               join_url text, replay_url text, locked boolean)
language sql stable security definer set search_path = public as $$
  select s.id, s.title, s.starts_at,
         case when s.tier = 'free' or public.is_member() then s.join_url end,
         case when s.tier = 'free' or public.is_member() then s.replay_url end,
         not (s.tier = 'free' or public.is_member())
  from public.sessions s
  where s.active and auth.uid() is not null
  order by s.starts_at desc nulls last;
$$;

revoke all on function public.list_partners()  from public, anon;
revoke all on function public.list_resources() from public, anon;
revoke all on function public.list_sessions()  from public, anon;
grant execute on function public.list_partners()  to authenticated;
grant execute on function public.list_resources() to authenticated;
grant execute on function public.list_sessions()  to authenticated;


-- ---------- 7. Example content (replace in Table Editor) -------------
-- Partner names are placeholders: fill in real partners once they agree.
insert into public.partners (category, name, service, description, perk, tier, sort) values
 ('Finance',    'E-com accountant (TBC)',      'Bookkeeping and VAT/OSS for cross-border stores', 'Specialised in EU e-commerce: OSS returns, multi-currency, quarterly reporting.', 'Free intake + member rate', 'member', 10),
 ('Finance',    'Payments partner (TBC)',      'Business account built for ad top-ups',           'Fast international transfers for ad spend, without high bank fees.',             'Fee-free first transfer',   'member', 20),
 ('Finance',    'Legal partner (TBC)',         'Terms, privacy and trademark registration',       'Standard store T&Cs, GDPR-proof privacy policy, EU trademark filing.',           'Fixed member pricing',      'member', 30),
 ('Growth',     'Creative studio (TBC)',       'UGC and ad creatives that convert',               'Hook-driven UGC, statics and video ads built for Meta.',                         '10% off first order',       'member', 10),
 ('Growth',     'Email & SMS agency (TBC)',    'Klaviyo flows and campaigns',                     'Welcome, abandoned cart and post-purchase flows set up in 2 weeks.',             'Free flow audit',           'member', 20),
 ('Growth',     'Shopify & CRO dev (TBC)',     'Store speed and conversion rate',                 'Theme fixes, landing pages and A/B tests.',                                      'Free CRO audit',            'member', 30),
 ('Operations', 'Nexus Bridge Sourcing',       'Product sourcing from vetted suppliers in China', 'Supplier search, samples, QC and shipping coordination.',                         'Priority sourcing request', 'free',   10),
 ('Operations', 'EU fulfilment / 3PL (TBC)',   'Warehousing and fast EU delivery',                'Store stock in the EU, 1–3 day delivery across Europe.',                         'Reduced onboarding fee',    'member', 20),
 ('Operations', 'Customer support team (TBC)', 'Outsourced inbox and chat support',               'Multilingual support team working in your helpdesk.',                            'First week free',           'member', 30);

insert into public.resources (category, title, teaser, url, tier, sort) values
 ('Profile structures', 'Business Manager setup that survives reviews', 'The exact BM, page and pixel structure we use for every client.', 'https://example.com/bm-structure', 'member', 10),
 ('Profile structures', 'Pixel protection checklist',                  'How to keep your pixel data when an account gets restricted.',   'https://example.com/pixel',        'member', 20),
 ('Profile structures', 'Whitelisted vs. regular ad accounts',         'What the difference is and when it matters for you.',            'https://example.com/whitelisted',  'free',   5),
 ('SOPs',               'Top-up in under 24 hours',                    'Step by step: how to top up your account and what we need.',     'https://example.com/top-up',       'member', 10),
 ('SOPs',               'What to do when an account gets banned',      'The replacement process, start to finish.',                      'https://example.com/ban',          'member', 20),
 ('Templates',          'Scaling plan: from Start to Unlimited',       'When to switch plans, and how to raise spend without killing the account.', 'https://example.com/scaling', 'member', 10);

insert into public.sessions (title, starts_at, join_url, replay_url, tier) values
 ('Monthly group call: scaling past €1,000/day', now() + interval '10 days', 'https://calendly.com/your-link', null, 'member'),
 ('Intro session: how whitelisted accounts work', null, null, 'https://example.com/replay-intro', 'free'),
 ('Group call replay: creative testing framework', null, null, 'https://example.com/replay-creatives', 'member');
