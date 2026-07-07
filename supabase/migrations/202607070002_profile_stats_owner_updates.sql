grant insert, update on public.profile_stats to authenticated;

drop policy if exists "users can create their profile stats" on public.profile_stats;
create policy "users can create their profile stats"
    on public.profile_stats
    for insert
    to authenticated
    with check (auth.uid() = user_id);

drop policy if exists "users can update their profile stats" on public.profile_stats;
create policy "users can update their profile stats"
    on public.profile_stats
    for update
    to authenticated
    using (auth.uid() = user_id)
    with check (auth.uid() = user_id);
