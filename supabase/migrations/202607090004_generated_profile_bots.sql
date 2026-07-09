alter table public.server_bot_profiles
    drop constraint if exists server_bot_profiles_slot_check;

alter table public.server_bot_profiles
    add constraint server_bot_profiles_slot_check check (slot >= 1);
