alter table public.profiles
    add column if not exists comrade_code text;

update public.profiles
   set comrade_code = upper(substr(encode(digest(user_id::text, 'sha256'), 'hex'), 1, 5))
 where comrade_code is null;

alter table public.profiles
    drop constraint if exists profiles_comrade_code_not_blank;

alter table public.profiles
    add constraint profiles_comrade_code_not_blank
    check (comrade_code is null or length(trim(comrade_code)) >= 5);

create unique index if not exists profiles_comrade_code_unique_idx
    on public.profiles (upper(comrade_code))
    where comrade_code is not null;

create table if not exists public.user_comrades (
    user_id uuid not null references public.profiles(user_id) on delete cascade,
    comrade_user_id uuid not null references public.profiles(user_id) on delete cascade,
    created_at timestamptz not null default now(),
    primary key (user_id, comrade_user_id),
    constraint user_comrades_not_self_check check (user_id <> comrade_user_id)
);

create index if not exists user_comrades_comrade_idx
    on public.user_comrades (comrade_user_id);

alter table public.user_comrades enable row level security;

grant select, insert, delete on public.user_comrades to authenticated;

drop policy if exists "users can see their comrades" on public.user_comrades;
create policy "users can see their comrades"
    on public.user_comrades
    for select
    to authenticated
    using (auth.uid() = user_id);

drop policy if exists "users can add their comrades" on public.user_comrades;
create policy "users can add their comrades"
    on public.user_comrades
    for insert
    to authenticated
    with check (auth.uid() = user_id);

drop policy if exists "users can remove their comrades" on public.user_comrades;
create policy "users can remove their comrades"
    on public.user_comrades
    for delete
    to authenticated
    using (auth.uid() = user_id);
