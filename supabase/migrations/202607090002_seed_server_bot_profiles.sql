create table if not exists public.server_bot_profiles (
    user_id uuid primary key references public.profiles(user_id) on delete cascade,
    controller text not null,
    slot integer not null,
    active boolean not null default true,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    constraint server_bot_profiles_controller_check
        check (controller in ('heuristicAI', 'mediumAI', 'neuralAI')),
    constraint server_bot_profiles_slot_check check (slot between 1 and 5),
    constraint server_bot_profiles_controller_slot_unique unique (controller, slot)
);

alter table public.server_bot_profiles enable row level security;
revoke all on public.server_bot_profiles from anon, authenticated, public;

create temporary table kolkhoz_server_bot_seed (
    user_id uuid primary key,
    controller text not null,
    slot integer not null,
    display_name text not null,
    avatar_url text not null
) on commit drop;

insert into kolkhoz_server_bot_seed (
    user_id,
    controller,
    slot,
    display_name,
    avatar_url
)
values
    ('00000000-0000-4000-8000-000000000101'::uuid, 'heuristicAI', 1, 'mossy7', 'worker1'),
    ('00000000-0000-4000-8000-000000000102'::uuid, 'heuristicAI', 2, 'turnip99', 'worker2'),
    ('00000000-0000-4000-8000-000000000103'::uuid, 'heuristicAI', 3, 'crabcake', 'worker3'),
    ('00000000-0000-4000-8000-000000000104'::uuid, 'heuristicAI', 4, 'zimbo', 'worker4'),
    ('00000000-0000-4000-8000-000000000105'::uuid, 'heuristicAI', 5, 'redkip', 'worker1'),
    ('00000000-0000-4000-8000-000000000201'::uuid, 'mediumAI', 1, 'noodle44', 'worker1'),
    ('00000000-0000-4000-8000-000000000202'::uuid, 'mediumAI', 2, 'lilspud', 'worker2'),
    ('00000000-0000-4000-8000-000000000203'::uuid, 'mediumAI', 3, 'wallywest', 'worker3'),
    ('00000000-0000-4000-8000-000000000204'::uuid, 'mediumAI', 4, 'beepboop8', 'worker4'),
    ('00000000-0000-4000-8000-000000000205'::uuid, 'mediumAI', 5, 'grumble', 'worker1'),
    ('00000000-0000-4000-8000-000000000301'::uuid, 'neuralAI', 1, 'toastman', 'worker1'),
    ('00000000-0000-4000-8000-000000000302'::uuid, 'neuralAI', 2, 'juno13', 'worker2'),
    ('00000000-0000-4000-8000-000000000303'::uuid, 'neuralAI', 3, 'bogfrog', 'worker3'),
    ('00000000-0000-4000-8000-000000000304'::uuid, 'neuralAI', 4, 'pickles2', 'worker4'),
    ('00000000-0000-4000-8000-000000000305'::uuid, 'neuralAI', 5, 'dingo77', 'worker1');

insert into auth.users (
    id,
    aud,
    role,
    email,
    email_confirmed_at,
    raw_app_meta_data,
    raw_user_meta_data,
    created_at,
    updated_at,
    is_sso_user,
    is_anonymous
)
select
    user_id,
    'authenticated',
    'authenticated',
    lower(controller || '-' || slot || '@bots.kolkhoz.local'),
    now(),
    jsonb_build_object(
        'provider', 'server-bot',
        'providers', jsonb_build_array('server-bot')
    ),
    jsonb_build_object(
        'server_bot', true,
        'controller', controller,
        'slot', slot
    ),
    now(),
    now(),
    false,
    false
from kolkhoz_server_bot_seed
on conflict (id) do update
    set email = excluded.email,
        raw_app_meta_data = excluded.raw_app_meta_data,
        raw_user_meta_data = excluded.raw_user_meta_data,
        updated_at = now(),
        is_sso_user = false,
        is_anonymous = false;

insert into public.profiles (user_id, display_name, avatar_url)
select user_id, display_name, avatar_url
from kolkhoz_server_bot_seed
on conflict (user_id) do update
    set display_name = excluded.display_name,
        avatar_url = excluded.avatar_url,
        updated_at = now();

insert into public.profile_stats (user_id)
select user_id
from kolkhoz_server_bot_seed
on conflict (user_id) do nothing;

insert into public.server_bot_profiles (
    user_id,
    controller,
    slot,
    active
)
select
    user_id,
    controller,
    slot,
    true
from kolkhoz_server_bot_seed
on conflict (user_id) do update
    set controller = excluded.controller,
        slot = excluded.slot,
        active = excluded.active,
        updated_at = now();
