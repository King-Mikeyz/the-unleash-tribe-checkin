begin;

-- =========================================================
-- THE UNLEASH TRIBE
-- INITIAL PLATFORM DATABASE FOUNDATION
-- =========================================================


-- =========================================================
-- PRIVATE SCHEMA
-- Security helper functions live outside the exposed
-- public schema.
-- =========================================================

create schema if not exists private;

revoke all on schema private from public;


-- =========================================================
-- ENUM TYPES
-- =========================================================

create type public.app_role as enum (
    'member',
    'admin'
);

create type public.account_status as enum (
    'pending',
    'active',
    'disabled'
);

create type public.access_request_status as enum (
    'pending',
    'approved',
    'rejected'
);

create type public.checkin_source as enum (
    'member',
    'admin_backfill'
);


-- =========================================================
-- PROFILES
--
-- Application profile associated with Supabase auth.users.
-- Roles and account state live here.
-- =========================================================

create table public.profiles (

    id uuid primary key
        references auth.users(id)
        on delete cascade,

    email text not null,

    full_name text not null,

    role public.app_role
        not null
        default 'member',

    status public.account_status
        not null
        default 'pending',

    approved_by uuid
        references auth.users(id)
        on delete set null,

    approved_at timestamptz,

    created_at timestamptz
        not null
        default now(),

    updated_at timestamptz
        not null
        default now(),

    constraint profiles_email_not_blank
        check (length(trim(email)) > 3),

    constraint profiles_name_not_blank
        check (length(trim(full_name)) > 0)
);


create unique index profiles_email_unique_idx
on public.profiles (lower(email));


create index profiles_role_status_idx
on public.profiles (role, status);


-- =========================================================
-- ACCESS REQUESTS
-- =========================================================

create table public.access_requests (

    id uuid primary key
        default gen_random_uuid(),

    full_name text not null,

    email text not null,

    message text,

    status public.access_request_status
        not null
        default 'pending',

    reviewed_by uuid
        references auth.users(id)
        on delete set null,

    reviewed_at timestamptz,

    rejection_reason text,

    user_id uuid
        references auth.users(id)
        on delete set null,

    created_at timestamptz
        not null
        default now(),

    updated_at timestamptz
        not null
        default now(),

    constraint access_requests_name_not_blank
        check (length(trim(full_name)) > 0),

    constraint access_requests_email_not_blank
        check (length(trim(email)) > 3)
);


-- Prevent the same email from creating multiple active
-- requests while one is pending or approved.
create unique index access_requests_open_email_unique_idx
on public.access_requests (lower(email))
where status in ('pending', 'approved');


create index access_requests_status_created_idx
on public.access_requests (status, created_at desc);


-- =========================================================
-- APPLICATION SETTINGS
--
-- Singleton row. UTC is safe initially.
-- We can change the community timezone later.
-- =========================================================

create table public.app_settings (

    id boolean primary key
        default true,

    community_timezone text
        not null
        default 'UTC',

    updated_by uuid
        references auth.users(id)
        on delete set null,

    updated_at timestamptz
        not null
        default now(),

    constraint app_settings_single_row
        check (id = true)
);


insert into public.app_settings (
    id,
    community_timezone
)
values (
    true,
    'UTC'
);


-- =========================================================
-- SEVEN GROWTH AREAS
-- =========================================================

create table public.growth_areas (

    id smallint primary key,

    slug text not null unique,

    name text not null,

    sort_order smallint not null unique,

    is_active boolean
        not null
        default true,

    created_at timestamptz
        not null
        default now()
);


insert into public.growth_areas (
    id,
    slug,
    name,
    sort_order
)
values

    (
        1,
        'fellowship-with-the-holy-spirit',
        'Fellowship with the Holy Spirit',
        1
    ),

    (
        2,
        'scripture',
        'Scripture',
        2
    ),

    (
        3,
        'monthly-goal-progress',
        'Monthly Goal Progress',
        3
    ),

    (
        4,
        'financial-living',
        'Financial Living',
        4
    ),

    (
        5,
        'health-and-wellness',
        'Health & Wellness',
        5
    ),

    (
        6,
        'personal-growth',
        'Personal Growth',
        6
    ),

    (
        7,
        'holy-spirit-journaling',
        'Holy Spirit Journaling',
        7
    );


-- =========================================================
-- CHECKLIST ITEM DEFINITIONS
--
-- Exact tasks will be inserted after we confirm the full
-- checklist requirements.
--
-- response_type:
-- boolean = checkbox
-- text    = written answer/journal response
-- number  = numeric progress/value
-- =========================================================

create table public.checklist_items (

    id uuid primary key
        default gen_random_uuid(),

    growth_area_id smallint not null
        references public.growth_areas(id)
        on delete restrict,

    label text not null,

    response_type text
        not null
        default 'boolean',

    is_required boolean
        not null
        default false,

    sort_order smallint
        not null,

    is_active boolean
        not null
        default true,

    created_at timestamptz
        not null
        default now(),

    updated_at timestamptz
        not null
        default now(),

    constraint checklist_items_label_not_blank
        check (length(trim(label)) > 0),

    constraint checklist_items_response_type_check
        check (
            response_type in (
                'boolean',
                'text',
                'number'
            )
        ),

    constraint checklist_items_sort_order_positive
        check (sort_order > 0),

    constraint checklist_items_area_sort_unique
        unique (
            growth_area_id,
            sort_order
        )
);


create index checklist_items_growth_area_idx
on public.checklist_items (
    growth_area_id,
    sort_order
);


-- =========================================================
-- DAILY CHECK-INS
--
-- One check-in per member per community date.
--
-- Members create today's check-in.
-- Admins may create historical/backfilled check-ins.
-- =========================================================

create table public.daily_checkins (

    id uuid primary key
        default gen_random_uuid(),

    user_id uuid not null
        references auth.users(id)
        on delete cascade,

    checkin_date date not null,

    notes text,

    source public.checkin_source
        not null
        default 'member',

    created_by uuid
        references auth.users(id)
        on delete set null,

    created_at timestamptz
        not null
        default now(),

    updated_at timestamptz
        not null
        default now(),

    constraint daily_checkins_user_date_unique
        unique (
            user_id,
            checkin_date
        ),

    constraint daily_checkins_member_creator_check
        check (
            source <> 'member'
            or created_by = user_id
        )
);


create index daily_checkins_date_idx
on public.daily_checkins (
    checkin_date desc
);


create index daily_checkins_user_date_idx
on public.daily_checkins (
    user_id,
    checkin_date desc
);


-- =========================================================
-- CHECK-IN RESPONSES
-- =========================================================

create table public.checkin_responses (

    id uuid primary key
        default gen_random_uuid(),

    checkin_id uuid not null
        references public.daily_checkins(id)
        on delete cascade,

    checklist_item_id uuid not null
        references public.checklist_items(id)
        on delete restrict,

    boolean_value boolean,

    text_value text,

    numeric_value numeric,

    created_at timestamptz
        not null
        default now(),

    updated_at timestamptz
        not null
        default now(),

    constraint checkin_responses_unique_item
        unique (
            checkin_id,
            checklist_item_id
        )
);


create index checkin_responses_checkin_idx
on public.checkin_responses (
    checkin_id
);


-- =========================================================
-- ADMIN AUDIT LOG
--
-- Records security-sensitive administrative operations.
-- Application users will never directly INSERT here.
-- =========================================================

create table public.admin_audit_log (

    id bigint generated always as identity
        primary key,

    actor_user_id uuid
        references auth.users(id)
        on delete set null,

    target_user_id uuid
        references auth.users(id)
        on delete set null,

    action text not null,

    details jsonb
        not null
        default '{}'::jsonb,

    created_at timestamptz
        not null
        default now(),

    constraint admin_audit_log_action_not_blank
        check (length(trim(action)) > 0)
);


create index admin_audit_log_created_idx
on public.admin_audit_log (
    created_at desc
);


create index admin_audit_log_actor_idx
on public.admin_audit_log (
    actor_user_id,
    created_at desc
);


create index admin_audit_log_target_idx
on public.admin_audit_log (
    target_user_id,
    created_at desc
);


-- =========================================================
-- SECURITY HELPER FUNCTIONS
-- =========================================================


-- ---------------------------------------------------------
-- Is the current authenticated user an ACTIVE admin?
-- ---------------------------------------------------------

create or replace function private.is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$

    select exists (

        select 1

        from public.profiles

        where id = (select auth.uid())

          and role = 'admin'::public.app_role

          and status = 'active'::public.account_status

    );

$$;


-- ---------------------------------------------------------
-- Is the current authenticated user active?
-- ---------------------------------------------------------

create or replace function private.is_active_member()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$

    select exists (

        select 1

        from public.profiles

        where id = (select auth.uid())

          and status = 'active'::public.account_status

    );

$$;


-- ---------------------------------------------------------
-- Determine the current community date.
-- ---------------------------------------------------------

create or replace function private.community_today()
returns date
language sql
stable
security definer
set search_path = ''
as $$

    select (

        now()
        at time zone coalesce(

            (
                select community_timezone
                from public.app_settings
                where id = true
            ),

            'UTC'

        )

    )::date;

$$;


-- =========================================================
-- UPDATED_AT TRIGGER
-- =========================================================

create or replace function private.set_updated_at()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$

begin

    new.updated_at = now();

    return new;

end;

$$;


create trigger profiles_set_updated_at
before update on public.profiles
for each row
execute function private.set_updated_at();


create trigger access_requests_set_updated_at
before update on public.access_requests
for each row
execute function private.set_updated_at();


create trigger app_settings_set_updated_at
before update on public.app_settings
for each row
execute function private.set_updated_at();


create trigger checklist_items_set_updated_at
before update on public.checklist_items
for each row
execute function private.set_updated_at();


create trigger daily_checkins_set_updated_at
before update on public.daily_checkins
for each row
execute function private.set_updated_at();


create trigger checkin_responses_set_updated_at
before update on public.checkin_responses
for each row
execute function private.set_updated_at();


-- =========================================================
-- TIMEZONE VALIDATION
-- =========================================================

create or replace function private.validate_community_timezone()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$

begin

    if not exists (

        select 1

        from pg_catalog.pg_timezone_names

        where name = new.community_timezone

    ) then

        raise exception
            'Invalid timezone: %',
            new.community_timezone;

    end if;

    return new;

end;

$$;


create trigger app_settings_validate_timezone
before insert or update of community_timezone
on public.app_settings
for each row
execute function private.validate_community_timezone();


-- =========================================================
-- LAST ACTIVE ADMIN PROTECTION
--
-- The application must never reach zero active admins.
--
-- Advisory transaction lock prevents two admins from being
-- removed concurrently and accidentally bypassing the count.
-- =========================================================

create or replace function private.prevent_last_active_admin_loss()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$

declare

    remaining_active_admins integer;

begin

    if tg_op = 'DELETE' then

        if
            old.role = 'admin'::public.app_role
            and
            old.status = 'active'::public.account_status
        then

            perform pg_catalog.pg_advisory_xact_lock(
                784221091
            );

            select count(*)
            into remaining_active_admins
            from public.profiles
            where id <> old.id
              and role = 'admin'::public.app_role
              and status = 'active'::public.account_status;

            if remaining_active_admins = 0 then

                raise exception
                    'Cannot remove the last active administrator.';

            end if;

        end if;

        return old;

    end if;


    if
        old.role = 'admin'::public.app_role
        and
        old.status = 'active'::public.account_status
        and
        not (
            new.role = 'admin'::public.app_role
            and
            new.status = 'active'::public.account_status
        )
    then

        perform pg_catalog.pg_advisory_xact_lock(
            784221091
        );

        select count(*)
        into remaining_active_admins
        from public.profiles
        where id <> old.id
          and role = 'admin'::public.app_role
          and status = 'active'::public.account_status;

        if remaining_active_admins = 0 then

            raise exception
                'Cannot remove, disable, or demote the last active administrator.';

        end if;

    end if;

    return new;

end;

$$;


create trigger profiles_protect_last_admin_update
before update of role, status
on public.profiles
for each row
execute function private.prevent_last_active_admin_loss();


create trigger profiles_protect_last_admin_delete
before delete
on public.profiles
for each row
execute function private.prevent_last_active_admin_loss();


-- =========================================================
-- CHECK-IN RESPONSE VALIDATION
--
-- Prevents boolean tasks from receiving text values,
-- text tasks from receiving numeric values, etc.
-- =========================================================

create or replace function private.validate_checkin_response()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$

declare

    item_response_type text;

begin

    select response_type
    into item_response_type
    from public.checklist_items
    where id = new.checklist_item_id;

    if not found then

        raise exception
            'Checklist item does not exist.';

    end if;


    if item_response_type = 'boolean' then

        if
            new.boolean_value is null
            or new.text_value is not null
            or new.numeric_value is not null
        then

            raise exception
                'Boolean checklist item requires only boolean_value.';

        end if;


    elsif item_response_type = 'text' then

        if
            new.text_value is null
            or new.boolean_value is not null
            or new.numeric_value is not null
        then

            raise exception
                'Text checklist item requires only text_value.';

        end if;


    elsif item_response_type = 'number' then

        if
            new.numeric_value is null
            or new.boolean_value is not null
            or new.text_value is not null
        then

            raise exception
                'Numeric checklist item requires only numeric_value.';

        end if;


    else

        raise exception
            'Unsupported checklist response type.';

    end if;

    return new;

end;

$$;


create trigger checkin_responses_validate
before insert or update
on public.checkin_responses
for each row
execute function private.validate_checkin_response();


-- =========================================================
-- AUTH USER -> PROFILE SYNCHRONIZATION
-- =========================================================

create or replace function private.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$

declare

    request_record public.access_requests%rowtype;

    profile_name text;

    initial_status public.account_status :=
        'pending'::public.account_status;

begin

    if new.email is null then

        raise exception
            'The Unleash Tribe requires an email-based account.';

    end if;


    profile_name :=
        nullif(
            trim(
                coalesce(
                    new.raw_user_meta_data ->> 'full_name',
                    ''
                )
            ),
            ''
        );


    if profile_name is null then

        profile_name :=
            split_part(new.email, '@', 1);

    end if;


    if length(trim(profile_name)) = 0 then

        profile_name := 'Member';

    end if;


    select *
    into request_record
    from public.access_requests
    where lower(email) = lower(new.email)
      and status = 'approved'::public.access_request_status
    order by reviewed_at desc nulls last
    limit 1;


    if found then

        initial_status :=
            'active'::public.account_status;

    end if;


    insert into public.profiles (

        id,
        email,
        full_name,
        role,
        status,
        approved_by,
        approved_at

    )
    values (

        new.id,
        lower(new.email),
        profile_name,
        'member'::public.app_role,
        initial_status,

        case
            when initial_status = 'active'
            then request_record.reviewed_by
            else null
        end,

        case
            when initial_status = 'active'
            then coalesce(
                request_record.reviewed_at,
                now()
            )
            else null
        end

    )
    on conflict (id)
    do nothing;


    if initial_status = 'active' then

        update public.access_requests

        set user_id = new.id

        where id = request_record.id;

    end if;


    return new;

end;

$$;


create trigger auth_user_create_profile
after insert
on auth.users
for each row
execute function private.handle_new_auth_user();


-- Keep profile email synchronized if Supabase Auth email changes.

create or replace function private.handle_auth_user_email_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$

begin

    if
        new.email is distinct from old.email
        and new.email is not null
    then

        update public.profiles

        set email = lower(new.email)

        where id = new.id;

    end if;

    return new;

end;

$$;


create trigger auth_user_sync_profile_email
after update of email
on auth.users
for each row
execute function private.handle_auth_user_email_change();


-- =========================================================
-- BACKFILL PROFILES FOR ANY PRE-EXISTING AUTH USERS
-- =========================================================

insert into public.profiles (

    id,
    email,
    full_name,
    role,
    status

)
select

    users.id,

    lower(users.email),

    case

        when length(
            trim(
                coalesce(
                    users.raw_user_meta_data ->> 'full_name',
                    ''
                )
            )
        ) > 0

        then trim(
            users.raw_user_meta_data ->> 'full_name'
        )

        when length(
            trim(
                split_part(users.email, '@', 1)
            )
        ) > 0

        then split_part(users.email, '@', 1)

        else 'Member'

    end,

    'member'::public.app_role,

    'pending'::public.account_status

from auth.users as users

where users.email is not null

on conflict (id)
do nothing;


-- =========================================================
-- ADMIN RPC: REVIEW ACCESS REQUEST
-- =========================================================

create or replace function public.admin_review_access_request(

    p_request_id uuid,

    p_decision text,

    p_rejection_reason text default null

)
returns void
language plpgsql
security definer
set search_path = ''
as $$

declare

    actor_id uuid := (select auth.uid());

    request_record public.access_requests%rowtype;

begin

    if
        actor_id is null
        or not private.is_admin()
    then

        raise exception
            'Administrator access required.';

    end if;


    if p_decision not in (
        'approved',
        'rejected'
    ) then

        raise exception
            'Decision must be approved or rejected.';

    end if;


    select *
    into request_record
    from public.access_requests
    where id = p_request_id
    for update;


    if not found then

        raise exception
            'Access request not found.';

    end if;


    if
        request_record.status <>
        'pending'::public.access_request_status
    then

        raise exception
            'This access request has already been reviewed.';

    end if;


    update public.access_requests

    set

        status =
            p_decision::public.access_request_status,

        reviewed_by =
            actor_id,

        reviewed_at =
            now(),

        rejection_reason =
            case

                when p_decision = 'rejected'
                then nullif(
                    trim(
                        coalesce(
                            p_rejection_reason,
                            ''
                        )
                    ),
                    ''
                )

                else null

            end

    where id = p_request_id;


    if p_decision = 'approved' then

        update public.profiles

        set

            status =
                'active'::public.account_status,

            approved_by =
                actor_id,

            approved_at =
                now()

        where lower(email) =
            lower(request_record.email);

    end if;


    insert into public.admin_audit_log (

        actor_user_id,
        target_user_id,
        action,
        details

    )
    values (

        actor_id,

        (
            select id
            from public.profiles
            where lower(email) =
                lower(request_record.email)
            limit 1
        ),

        case

            when p_decision = 'approved'
            then 'access_request_approved'

            else 'access_request_rejected'

        end,

        jsonb_build_object(

            'request_id',
            p_request_id,

            'email',
            request_record.email

        )

    );

end;

$$;


-- =========================================================
-- ADMIN RPC: PROMOTE / DEMOTE USER
-- =========================================================

create or replace function public.admin_set_user_role(

    p_user_id uuid,

    p_role text

)
returns void
language plpgsql
security definer
set search_path = ''
as $$

declare

    actor_id uuid := (select auth.uid());

    previous_role public.app_role;

    target_status public.account_status;

begin

    if
        actor_id is null
        or not private.is_admin()
    then

        raise exception
            'Administrator access required.';

    end if;


    if p_role not in (
        'member',
        'admin'
    ) then

        raise exception
            'Role must be member or admin.';

    end if;


    if
        p_user_id = actor_id
        and p_role <> 'admin'
    then

        raise exception
            'Administrators cannot demote themselves.';

    end if;


    select
        role,
        status

    into
        previous_role,
        target_status

    from public.profiles

    where id = p_user_id

    for update;


    if not found then

        raise exception
            'User profile not found.';

    end if;


    if
        p_role = 'admin'
        and target_status <>
            'active'::public.account_status
    then

        raise exception
            'Only active members can be promoted to administrator.';

    end if;


    update public.profiles

    set role =
        p_role::public.app_role

    where id = p_user_id;


    insert into public.admin_audit_log (

        actor_user_id,
        target_user_id,
        action,
        details

    )
    values (

        actor_id,
        p_user_id,
        'user_role_changed',

        jsonb_build_object(

            'previous_role',
            previous_role,

            'new_role',
            p_role

        )

    );

end;

$$;


-- =========================================================
-- ADMIN RPC: ENABLE / DISABLE USER
-- =========================================================

create or replace function public.admin_set_user_status(

    p_user_id uuid,

    p_status text

)
returns void
language plpgsql
security definer
set search_path = ''
as $$

declare

    actor_id uuid := (select auth.uid());

    previous_status public.account_status;

begin

    if
        actor_id is null
        or not private.is_admin()
    then

        raise exception
            'Administrator access required.';

    end if;


    if p_status not in (
        'pending',
        'active',
        'disabled'
    ) then

        raise exception
            'Invalid account status.';

    end if;


    if
        p_user_id = actor_id
        and p_status <> 'active'
    then

        raise exception
            'Administrators cannot disable their own account.';

    end if;


    select status
    into previous_status

    from public.profiles

    where id = p_user_id

    for update;


    if not found then

        raise exception
            'User profile not found.';

    end if;


    update public.profiles

    set

        status =
            p_status::public.account_status,

        approved_by =
            case

                when p_status = 'active'
                then coalesce(
                    approved_by,
                    actor_id
                )

                else approved_by

            end,

        approved_at =
            case

                when p_status = 'active'
                then coalesce(
                    approved_at,
                    now()
                )

                else approved_at

            end

    where id = p_user_id;


    insert into public.admin_audit_log (

        actor_user_id,
        target_user_id,
        action,
        details

    )
    values (

        actor_id,
        p_user_id,
        'user_status_changed',

        jsonb_build_object(

            'previous_status',
            previous_status,

            'new_status',
            p_status

        )

    );

end;

$$;


-- =========================================================
-- ROW LEVEL SECURITY
-- =========================================================

alter table public.profiles
enable row level security;

alter table public.access_requests
enable row level security;

alter table public.app_settings
enable row level security;

alter table public.growth_areas
enable row level security;

alter table public.checklist_items
enable row level security;

alter table public.daily_checkins
enable row level security;

alter table public.checkin_responses
enable row level security;

alter table public.admin_audit_log
enable row level security;


-- =========================================================
-- PROFILES POLICIES
-- =========================================================

create policy profiles_select_own_or_admin
on public.profiles
for select
to authenticated
using (

    id = (select auth.uid())

    or

    (select private.is_admin())

);


create policy profiles_update_own_or_admin
on public.profiles
for update
to authenticated
using (

    id = (select auth.uid())

    or

    (select private.is_admin())

)
with check (

    id = (select auth.uid())

    or

    (select private.is_admin())

);


-- =========================================================
-- ACCESS REQUEST POLICIES
-- =========================================================

create policy access_requests_public_insert
on public.access_requests
for insert
to anon, authenticated
with check (

    status =
        'pending'::public.access_request_status

    and reviewed_by is null

    and reviewed_at is null

    and user_id is null

);


create policy access_requests_admin_select
on public.access_requests
for select
to authenticated
using (

    (select private.is_admin())

);


-- =========================================================
-- APP SETTINGS POLICIES
-- =========================================================

create policy app_settings_authenticated_select
on public.app_settings
for select
to authenticated
using (true);


create policy app_settings_admin_update
on public.app_settings
for update
to authenticated
using (

    (select private.is_admin())

)
with check (

    (select private.is_admin())

);


-- =========================================================
-- GROWTH AREA POLICIES
-- =========================================================

create policy growth_areas_authenticated_select
on public.growth_areas
for select
to authenticated
using (

    is_active = true

    or

    (select private.is_admin())

);


-- =========================================================
-- CHECKLIST ITEM POLICIES
-- =========================================================

create policy checklist_items_authenticated_select
on public.checklist_items
for select
to authenticated
using (

    is_active = true

    or

    (select private.is_admin())

);


-- =========================================================
-- DAILY CHECK-IN POLICIES
-- =========================================================

create policy daily_checkins_select
on public.daily_checkins
for select
to authenticated
using (

    (select private.is_admin())

    or

    (
        (select private.is_active_member())

        and

        user_id = (select auth.uid())
    )

);


create policy daily_checkins_member_insert
on public.daily_checkins
for insert
to authenticated
with check (

    (select private.is_active_member())

    and

    user_id = (select auth.uid())

    and

    created_by = (select auth.uid())

    and

    source =
        'member'::public.checkin_source

    and

    checkin_date =
        (select private.community_today())

);


create policy daily_checkins_admin_insert
on public.daily_checkins
for insert
to authenticated
with check (

    (select private.is_admin())

    and

    created_by = (select auth.uid())

    and

    source =
        'admin_backfill'::public.checkin_source

);


create policy daily_checkins_member_update
on public.daily_checkins
for update
to authenticated
using (

    (select private.is_active_member())

    and

    user_id = (select auth.uid())

    and

    source =
        'member'::public.checkin_source

    and

    checkin_date =
        (select private.community_today())

)
with check (

    (select private.is_active_member())

    and

    user_id = (select auth.uid())

    and

    source =
        'member'::public.checkin_source

    and

    checkin_date =
        (select private.community_today())

);


create policy daily_checkins_admin_update
on public.daily_checkins
for update
to authenticated
using (

    (select private.is_admin())

)
with check (

    (select private.is_admin())

);


-- =========================================================
-- CHECK-IN RESPONSE POLICIES
-- =========================================================

create policy checkin_responses_select
on public.checkin_responses
for select
to authenticated
using (

    (select private.is_admin())

    or

    (
        (select private.is_active_member())

        and

        exists (

            select 1

            from public.daily_checkins

            where daily_checkins.id =
                checkin_responses.checkin_id

              and daily_checkins.user_id =
                (select auth.uid())

        )
    )

);


create policy checkin_responses_member_insert
on public.checkin_responses
for insert
to authenticated
with check (

    (select private.is_active_member())

    and

    exists (

        select 1

        from public.daily_checkins

        where daily_checkins.id =
            checkin_responses.checkin_id

          and daily_checkins.user_id =
            (select auth.uid())

          and daily_checkins.source =
            'member'::public.checkin_source

          and daily_checkins.checkin_date =
            (select private.community_today())

    )

);


create policy checkin_responses_admin_insert
on public.checkin_responses
for insert
to authenticated
with check (

    (select private.is_admin())

);


create policy checkin_responses_member_update
on public.checkin_responses
for update
to authenticated
using (

    (select private.is_active_member())

    and

    exists (

        select 1

        from public.daily_checkins

        where daily_checkins.id =
            checkin_responses.checkin_id

          and daily_checkins.user_id =
            (select auth.uid())

          and daily_checkins.source =
            'member'::public.checkin_source

          and daily_checkins.checkin_date =
            (select private.community_today())

    )

)
with check (

    (select private.is_active_member())

    and

    exists (

        select 1

        from public.daily_checkins

        where daily_checkins.id =
            checkin_responses.checkin_id

          and daily_checkins.user_id =
            (select auth.uid())

          and daily_checkins.source =
            'member'::public.checkin_source

          and daily_checkins.checkin_date =
            (select private.community_today())

    )

);


create policy checkin_responses_admin_update
on public.checkin_responses
for update
to authenticated
using (

    (select private.is_admin())

)
with check (

    (select private.is_admin())

);


-- =========================================================
-- AUDIT LOG POLICY
-- =========================================================

create policy admin_audit_log_admin_select
on public.admin_audit_log
for select
to authenticated
using (

    (select private.is_admin())

);


-- =========================================================
-- TABLE PRIVILEGES
--
-- Explicit permissions reduce the browser attack surface.
-- =========================================================

revoke all
on table public.profiles
from anon, authenticated;

revoke all
on table public.access_requests
from anon, authenticated;

revoke all
on table public.app_settings
from anon, authenticated;

revoke all
on table public.growth_areas
from anon, authenticated;

revoke all
on table public.checklist_items
from anon, authenticated;

revoke all
on table public.daily_checkins
from anon, authenticated;

revoke all
on table public.checkin_responses
from anon, authenticated;

revoke all
on table public.admin_audit_log
from anon, authenticated;


-- Profiles

grant select
on table public.profiles
to authenticated;

grant update (full_name)
on table public.profiles
to authenticated;


-- Access Requests

grant insert (
    full_name,
    email,
    message
)
on table public.access_requests
to anon, authenticated;

grant select
on table public.access_requests
to authenticated;


-- Settings

grant select, update
on table public.app_settings
to authenticated;


-- Growth Framework

grant select
on table public.growth_areas
to authenticated;

grant select
on table public.checklist_items
to authenticated;


-- Check-ins

grant select, insert
on table public.daily_checkins
to authenticated;

grant update (notes)
on table public.daily_checkins
to authenticated;


grant select, insert, update
on table public.checkin_responses
to authenticated;


-- Audit log

grant select
on table public.admin_audit_log
to authenticated;


-- Service role for future trusted Edge Functions.

grant all
on table public.profiles
to service_role;

grant all
on table public.access_requests
to service_role;

grant all
on table public.app_settings
to service_role;

grant all
on table public.growth_areas
to service_role;

grant all
on table public.checklist_items
to service_role;

grant all
on table public.daily_checkins
to service_role;

grant all
on table public.checkin_responses
to service_role;

grant all
on table public.admin_audit_log
to service_role;

grant usage, select
on sequence public.admin_audit_log_id_seq
to service_role;


-- =========================================================
-- FUNCTION PRIVILEGES
-- =========================================================

revoke all
on schema private
from public;

grant usage
on schema private
to authenticated;


revoke execute
on all functions in schema private
from public;


grant execute
on function private.is_admin()
to authenticated;

grant execute
on function private.is_active_member()
to authenticated;

grant execute
on function private.community_today()
to authenticated;


-- Administrative RPCs are authenticated-only.

revoke execute
on function public.admin_review_access_request(
    uuid,
    text,
    text
)
from public, anon;

grant execute
on function public.admin_review_access_request(
    uuid,
    text,
    text
)
to authenticated;


revoke execute
on function public.admin_set_user_role(
    uuid,
    text
)
from public, anon;

grant execute
on function public.admin_set_user_role(
    uuid,
    text
)
to authenticated;


revoke execute
on function public.admin_set_user_status(
    uuid,
    text
)
from public, anon;

grant execute
on function public.admin_set_user_status(
    uuid,
    text
)
to authenticated;


commit;
