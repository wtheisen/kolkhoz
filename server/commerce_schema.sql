create table if not exists server_store_purchases (
    provider text not null,
    original_transaction_id text not null,
    -- Deliberately retained after account deletion so a surrendered purchase
    -- cannot be linked to a newly-created Kolkhoz account.
    user_id uuid not null,
    product_id text not null,
    account_reference text not null,
    active boolean not null default true,
    purchased_at timestamptz,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    primary key (provider, original_transaction_id)
);

create index if not exists server_store_purchases_user_idx
    on server_store_purchases (user_id, active);

create table if not exists server_entitlements (
    user_id uuid not null references public.profiles(user_id) on delete cascade,
    entitlement_id text not null,
    active boolean not null default true,
    source_provider text not null,
    source_transaction_id text not null,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    primary key (user_id, entitlement_id),
    foreign key (source_provider, source_transaction_id)
        references server_store_purchases(provider, original_transaction_id)
        on delete restrict
);
