create or replace function public.record_offline_result(won boolean)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
    current_user_id uuid := auth.uid();
begin
    if current_user_id is null then
        raise exception 'not authenticated';
    end if;

    insert into public.profiles (user_id, display_name)
    values (current_user_id, 'Player')
    on conflict (user_id) do nothing;

    insert into public.profile_stats (user_id)
    values (current_user_id)
    on conflict (user_id) do nothing;

    update public.profile_stats
       set games_played = games_played + 1,
           wins_total = wins_total + case when won then 1 else 0 end,
           offline_games = offline_games + 1,
           offline_wins = offline_wins + case when won then 1 else 0 end,
           updated_at = now()
     where user_id = current_user_id;
end;
$$;

grant execute on function public.record_offline_result(boolean) to authenticated;
