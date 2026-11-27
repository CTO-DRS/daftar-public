-- Daftar sync layer. Isolated schema; touches nothing else in the project.
create schema if not exists daftar;

create table if not exists daftar.records (
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  entity text not null check (entity in ('customer','item','invoice','payment','doc')),
  id text not null,
  data jsonb not null,
  deleted boolean not null default false,
  updated_at timestamptz not null default now(),
  primary key (user_id, entity, id)
);
create index if not exists records_pull on daftar.records (user_id, updated_at);

create or replace function daftar.touch() returns trigger language plpgsql as $$
begin
  -- server clock is the sync cursor; client clock only breaks ties via data->>'u'
  new.updated_at := clock_timestamp();
  new.user_id := coalesce(new.user_id, auth.uid());
  return new;
end $$;
drop trigger if exists records_touch on daftar.records;
create trigger records_touch before insert or update on daftar.records
  for each row execute function daftar.touch();

alter table daftar.records enable row level security;
drop policy if exists own_records on daftar.records;
create policy own_records on daftar.records for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- shared invoice links with view tracking
create table if not exists daftar.shares (
  token text primary key default encode(gen_random_bytes(12),'hex'),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  invoice_id text not null,
  snapshot jsonb not null,
  views int not null default 0,
  first_viewed_at timestamptz,
  last_viewed_at timestamptz,
  created_at timestamptz not null default now()
);
alter table daftar.shares enable row level security;
drop policy if exists own_shares on daftar.shares;
create policy own_shares on daftar.shares for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- public read by unguessable token; counts the view
create or replace function daftar.open_share(p_token text) returns jsonb
language plpgsql security definer set search_path = daftar, public as $$
declare s jsonb;
begin
  update daftar.shares set views = views + 1,
    first_viewed_at = coalesce(first_viewed_at, now()), last_viewed_at = now()
  where token = p_token returning snapshot into s;
  return s;
end $$;
revoke all on function daftar.open_share(text) from public;
grant execute on function daftar.open_share(text) to anon, authenticated;

grant usage on schema daftar to authenticated, anon;
grant select, insert, update, delete on daftar.records, daftar.shares to authenticated;

create unique index if not exists shares_one_per_invoice on daftar.shares (user_id, invoice_id);

-- v0.1.35: price tiers sync as entity 'tiers'
alter table daftar.records drop constraint if exists records_entity_check;
alter table daftar.records add constraint records_entity_check
  check (entity in ('customer','item','invoice','payment','doc','tiers'));

-- v0.1.37: client-side encrypted backups (server only ever sees ciphertext)
create table if not exists daftar.backups (
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  slot text not null check (slot in ('latest','previous')),
  data text not null,
  size int not null,
  created_at timestamptz not null default now(),
  primary key (user_id, slot)
);
alter table daftar.backups enable row level security;
drop policy if exists own_backups on daftar.backups;
create policy own_backups on daftar.backups for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
grant select, insert, update, delete on daftar.backups to authenticated;
