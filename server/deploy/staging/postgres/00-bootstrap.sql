create schema if not exists auth;
create role anon nologin;
create role authenticated nologin;
create table auth.users (
    id uuid primary key,
    aud varchar(255),
    role varchar(255),
    email varchar(255),
    email_confirmed_at timestamptz,
    raw_app_meta_data jsonb,
    raw_user_meta_data jsonb,
    created_at timestamptz,
    updated_at timestamptz,
    is_sso_user boolean default false,
    is_anonymous boolean default false
);
create function auth.uid() returns uuid language sql stable
as $$ select null::uuid $$;
create publication supabase_realtime;
