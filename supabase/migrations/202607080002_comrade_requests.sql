create table if not exists public.user_comrade_requests (
    requester_user_id uuid not null references public.profiles(user_id) on delete cascade,
    addressee_user_id uuid not null references public.profiles(user_id) on delete cascade,
    created_at timestamptz not null default now(),
    primary key (requester_user_id, addressee_user_id),
    constraint user_comrade_requests_not_self_check
        check (requester_user_id <> addressee_user_id)
);

create index if not exists user_comrade_requests_addressee_idx
    on public.user_comrade_requests (addressee_user_id, created_at desc);

alter table public.user_comrade_requests enable row level security;

grant select, insert, update, delete on public.user_comrade_requests to authenticated;

drop policy if exists "users can see their comrade requests" on public.user_comrade_requests;
create policy "users can see their comrade requests"
    on public.user_comrade_requests
    for select
    to authenticated
    using (requester_user_id = auth.uid() or addressee_user_id = auth.uid());

drop policy if exists "users can send comrade requests" on public.user_comrade_requests;
create policy "users can send comrade requests"
    on public.user_comrade_requests
    for insert
    to authenticated
    with check (requester_user_id = auth.uid());

drop policy if exists "users can update their sent comrade requests" on public.user_comrade_requests;
create policy "users can update their sent comrade requests"
    on public.user_comrade_requests
    for update
    to authenticated
    using (requester_user_id = auth.uid())
    with check (requester_user_id = auth.uid());

drop policy if exists "users can delete their comrade requests" on public.user_comrade_requests;
create policy "users can delete their comrade requests"
    on public.user_comrade_requests
    for delete
    to authenticated
    using (requester_user_id = auth.uid() or addressee_user_id = auth.uid());
