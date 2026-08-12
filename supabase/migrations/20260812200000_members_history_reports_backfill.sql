begin;

-- =========================================================
-- THE UNLEASH TRIBE
-- MEMBERS + HISTORY + REPORTING + BACKFILL
-- =========================================================


-- Keep repository defaults aligned with production timezone.

update public.app_settings
set
    community_timezone = 'Africa/Lagos',
    accountability_open_time = '10:00',
    accountability_close_time = '06:00',
    updated_at = now()
where id = true;


-- =========================================================
-- MEMBER STATUS HISTORY
--
-- Needed so historical accountability reports know
-- whether someone was actually active on a past date.
-- =========================================================

create table if not exists public.profile_status_history (

    id bigint generated always as identity
        primary key,

    user_id uuid not null
        references auth.users(id)
        on delete cascade,

    status public.account_status
        not null,

    effective_at timestamptz
        not null
        default now(),

    changed_by uuid
        references auth.users(id)
        on delete set null,

    reason text,

    created_at timestamptz
        not null
        default now()

);


create index if not exists
profile_status_history_user_effective_idx
on public.profile_status_history (
    user_id,
    effective_at desc,
    id desc
);


alter table public.profile_status_history
enable row level security;


drop policy if exists
profile_status_history_admin_select
on public.profile_status_history;


create policy profile_status_history_admin_select
on public.profile_status_history
for select
to authenticated
using (
    (select private.is_admin())
);


revoke all
on table public.profile_status_history
from anon, authenticated;


grant select
on table public.profile_status_history
to authenticated;


grant all
on table public.profile_status_history
to service_role;


grant usage, select
on sequence public.profile_status_history_id_seq
to service_role;


-- Baseline the users that already exist.

insert into public.profile_status_history (
    user_id,
    status,
    effective_at,
    changed_by,
    reason
)

select
    profile.id,
    profile.status,
    coalesce(
        profile.approved_at,
        profile.created_at
    ),
    profile.approved_by,
    'Initial status baseline'

from public.profiles as profile

where not exists (

    select 1

    from public.profile_status_history as history

    where history.user_id =
        profile.id

);


-- =========================================================
-- AUTH PROFILE CREATION
-- Also records initial status.
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

    status_effective_at timestamptz :=
        now();

    status_changed_by uuid;

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
            split_part(
                new.email,
                '@',
                1
            );

    end if;


    if length(trim(profile_name)) = 0 then

        profile_name :=
            'Member';

    end if;


    select *
    into request_record

    from public.access_requests

    where lower(email) =
        lower(new.email)

      and status =
        'approved'::public.access_request_status

    order by
        reviewed_at desc nulls last

    limit 1;


    if found then

        initial_status :=
            'active'::public.account_status;

        status_effective_at :=
            coalesce(
                request_record.reviewed_at,
                now()
            );

        status_changed_by :=
            request_record.reviewed_by;

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
            when initial_status =
                'active'::public.account_status
            then status_changed_by
            else null
        end,
        case
            when initial_status =
                'active'::public.account_status
            then status_effective_at
            else null
        end
    )
    on conflict (id)
    do nothing;


    if not exists (

        select 1

        from public.profile_status_history

        where user_id =
            new.id

    ) then

        insert into public.profile_status_history (
            user_id,
            status,
            effective_at,
            changed_by,
            reason
        )
        values (
            new.id,
            initial_status,
            status_effective_at,
            status_changed_by,
            'Auth account created'
        );

    end if;


    if initial_status =
        'active'::public.account_status
    then

        update public.access_requests

        set user_id =
            new.id

        where id =
            request_record.id;

    end if;


    return new;

end;

$$;


-- =========================================================
-- ACCESS REQUEST REVIEW
-- Records activation status history.
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

    actor_id uuid :=
        (select auth.uid());

    request_record
        public.access_requests%rowtype;

    target_user_id uuid;

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

    where id =
        p_request_id

    for update;


    if not found then

        raise exception
            'Access request not found.';

    end if;


    if request_record.status <>
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

    where id =
        p_request_id;


    if p_decision = 'approved' then

        update public.profiles

        set
            status =
                'active'::public.account_status,

            approved_by =
                actor_id,

            approved_at =
                coalesce(
                    approved_at,
                    now()
                )

        where lower(email) =
            lower(request_record.email)

        returning id
        into target_user_id;


        if target_user_id is not null then

            insert into public.profile_status_history (
                user_id,
                status,
                effective_at,
                changed_by,
                reason
            )
            values (
                target_user_id,
                'active'::public.account_status,
                now(),
                actor_id,
                'Membership request approved'
            );

        end if;

    end if;


    insert into public.admin_audit_log (
        actor_user_id,
        target_user_id,
        action,
        details
    )
    values (
        actor_id,
        target_user_id,
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
-- ENABLE / DISABLE MEMBER
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

    actor_id uuid :=
        (select auth.uid());

    previous_status
        public.account_status;

    new_status
        public.account_status;

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


    new_status :=
        p_status::public.account_status;


    if
        p_user_id = actor_id
        and new_status <>
            'active'::public.account_status
    then

        raise exception
            'Administrators cannot disable their own account.';

    end if;


    select status
    into previous_status

    from public.profiles

    where id =
        p_user_id

    for update;


    if not found then

        raise exception
            'User profile not found.';

    end if;


    if previous_status =
        new_status
    then

        return;

    end if;


    update public.profiles

    set
        status =
            new_status,

        approved_by =
            case
                when new_status =
                    'active'::public.account_status
                then coalesce(
                    approved_by,
                    actor_id
                )
                else approved_by
            end,

        approved_at =
            case
                when new_status =
                    'active'::public.account_status
                then coalesce(
                    approved_at,
                    now()
                )
                else approved_at
            end

    where id =
        p_user_id;


    insert into public.profile_status_history (
        user_id,
        status,
        effective_at,
        changed_by,
        reason
    )
    values (
        p_user_id,
        new_status,
        now(),
        actor_id,
        'Administrator changed member status'
    );


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
            new_status
        )
    );

end;

$$;


-- =========================================================
-- ACCOUNTABILITY WINDOW END
-- =========================================================

create or replace function private.accountability_window_end(
    p_date date
)
returns timestamptz
language plpgsql
stable
security definer
set search_path = ''
as $$

declare

    timezone_name text;

    open_time time;

    close_time time;

    local_end timestamp;

begin

    select
        community_timezone,
        accountability_open_time,
        accountability_close_time

    into
        timezone_name,
        open_time,
        close_time

    from public.app_settings

    where id = true;


    if close_time < open_time then

        local_end :=
            (p_date + 1)
            + close_time;

    else

        local_end :=
            p_date
            + close_time;

    end if;


    return
        local_end
        at time zone timezone_name;

end;

$$;


-- =========================================================
-- ACCOUNT STATUS AT HISTORICAL TIME
-- =========================================================

create or replace function private.account_status_at(

    p_user_id uuid,

    p_at timestamptz

)
returns public.account_status
language sql
stable
security definer
set search_path = ''
as $$

    select history.status

    from public.profile_status_history
        as history

    where history.user_id =
        p_user_id

      and history.effective_at <=
        p_at

    order by
        history.effective_at desc,
        history.id desc

    limit 1;

$$;


-- =========================================================
-- COMPLETED PARENT COUNT
-- =========================================================

create or replace function private.completed_category_count(

    p_user_id uuid,

    p_date date

)
returns integer
language sql
stable
security definer
set search_path = ''
as $$

    select count(*)::integer

    from public.growth_areas as area

    where area.is_active = true

      and area.is_required = true

      and (
          area.starts_on is null
          or area.starts_on <= p_date
      )

      and (
          area.ends_on is null
          or area.ends_on >= p_date
      )

      and private.is_category_complete(
          p_user_id,
          area.id,
          p_date
      );

$$;


-- =========================================================
-- MEMBER HISTORY
-- Includes missed days, not only submitted days.
-- =========================================================

create or replace function private.get_my_checkin_history_impl(
    p_limit integer default 30
)
returns table (

    accountability_date date,

    started boolean,

    completed_categories integer,

    total_categories integer,

    percentage integer,

    status_label text,

    source text,

    last_activity timestamptz

)
language plpgsql
stable
security definer
set search_path = ''
as $$

declare

    actor_id uuid :=
        (select auth.uid());

    anchor_date date;

    joined_date date;

    timezone_name text;

    bounded_limit integer;

begin

    if
        actor_id is null
        or not private.is_active_member()
    then

        raise exception
            'Active member account required.';

    end if;


    bounded_limit :=
        greatest(
            1,
            least(
                coalesce(
                    p_limit,
                    30
                ),
                90
            )
        );


    select community_timezone
    into timezone_name

    from public.app_settings

    where id = true;


    select
        (
            coalesce(
                profile.approved_at,
                profile.created_at
            )
            at time zone timezone_name
        )::date

    into joined_date

    from public.profiles as profile

    where profile.id =
        actor_id;


    anchor_date :=
        coalesce(
            private.current_accountability_date(),
            private.community_local_date() - 1
        );


    return query

    with days as (

        select
            series.day::date
                as history_date

        from generate_series(
            anchor_date::timestamp,
            joined_date::timestamp,
            interval '-1 day'
        ) as series(day)

        where private.required_category_count(
            series.day::date
        ) > 0

        order by series.day desc

        limit bounded_limit

    ),

    metrics as (

        select
            days.history_date,

            exists (

                select 1

                from public.daily_checkins
                    as daily

                where daily.user_id =
                    actor_id

                  and daily.checkin_date =
                    days.history_date

            ) as has_started,

            private.completed_category_count(
                actor_id,
                days.history_date
            ) as completed_count,

            private.required_category_count(
                days.history_date
            ) as total_count,

            private.is_day_complete(
                actor_id,
                days.history_date
            ) as day_complete

        from days

    )

    select

        metrics.history_date,

        metrics.has_started,

        metrics.completed_count,

        metrics.total_count,

        case
            when metrics.total_count = 0
            then 0
            else round(
                metrics.completed_count
                * 100.0
                / metrics.total_count
            )::integer
        end,

        case
            when metrics.day_complete
            then 'done'

            when metrics.has_started
            then 'incomplete'

            else 'not_started'
        end,

        (
            select daily.source::text

            from public.daily_checkins
                as daily

            where daily.user_id =
                actor_id

              and daily.checkin_date =
                metrics.history_date

            limit 1
        ),

        (
            select daily.updated_at

            from public.daily_checkins
                as daily

            where daily.user_id =
                actor_id

              and daily.checkin_date =
                metrics.history_date

            limit 1
        )

    from metrics

    order by
        metrics.history_date desc;

end;

$$;


create or replace function public.get_my_checkin_history(
    p_limit integer default 30
)
returns table (

    accountability_date date,

    started boolean,

    completed_categories integer,

    total_categories integer,

    percentage integer,

    status_label text,

    source text,

    last_activity timestamptz

)
language sql
security invoker
set search_path = ''
as $$

    select *

    from private.get_my_checkin_history_impl(
        p_limit
    );

$$;


-- =========================================================
-- ADMIN ACCOUNTABILITY REPORT
-- =========================================================

create or replace function private.admin_accountability_report_impl(
    p_date date
)
returns table (

    user_id uuid,

    full_name text,

    username text,

    email text,

    role_name text,

    checkin_status text,

    completed_categories integer,

    total_categories integer,

    percentage integer,

    last_activity timestamptz

)
language plpgsql
stable
security definer
set search_path = ''
as $$

declare

    actor_id uuid :=
        (select auth.uid());

    window_end timestamptz;

begin

    if
        actor_id is null
        or not private.is_admin()
    then

        raise exception
            'Administrator access required.';

    end if;


    if p_date is null then

        raise exception
            'Accountability date is required.';

    end if;


    window_end :=
        private.accountability_window_end(
            p_date
        );


    return query

    with eligible as (

        select
            profile.id,
            profile.full_name,
            profile.username,
            profile.email,
            profile.role,

            private.account_status_at(
                profile.id,
                window_end
            ) as historical_status

        from public.profiles
            as profile

        where profile.approved_at
            is not null

          and profile.approved_at <=
            window_end

    ),

    metrics as (

        select
            eligible.*,

            exists (

                select 1

                from public.daily_checkins
                    as daily

                where daily.user_id =
                    eligible.id

                  and daily.checkin_date =
                    p_date

            ) as has_started,

            private.completed_category_count(
                eligible.id,
                p_date
            ) as completed_count,

            private.required_category_count(
                p_date
            ) as total_count

        from eligible

        where eligible.historical_status =
            'active'::public.account_status

    )

    select
        metrics.id,

        metrics.full_name,

        metrics.username,

        metrics.email,

        metrics.role::text,

        case

            when
                metrics.total_count > 0

                and metrics.completed_count =
                    metrics.total_count

            then 'done'

            when metrics.has_started
            then 'incomplete'

            else 'not_started'

        end,

        metrics.completed_count,

        metrics.total_count,

        case
            when metrics.total_count = 0
            then 0
            else round(
                metrics.completed_count
                * 100.0
                / metrics.total_count
            )::integer
        end,

        (
            select daily.updated_at

            from public.daily_checkins
                as daily

            where daily.user_id =
                metrics.id

              and daily.checkin_date =
                p_date

            limit 1
        )

    from metrics

    order by
        metrics.full_name;

end;

$$;


create or replace function public.admin_accountability_report(
    p_date date
)
returns table (

    user_id uuid,

    full_name text,

    username text,

    email text,

    role_name text,

    checkin_status text,

    completed_categories integer,

    total_categories integer,

    percentage integer,

    last_activity timestamptz

)
language sql
security invoker
set search_path = ''
as $$

    select *

    from private.admin_accountability_report_impl(
        p_date
    );

$$;


-- =========================================================
-- ADMIN HISTORICAL BACKFILL
-- Creates a past check-in only if no record exists.
-- =========================================================

create or replace function private.admin_backfill_checkin_impl(

    p_user_id uuid,

    p_date date,

    p_completed_task_ids uuid[],

    p_reason text

)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$

declare

    actor_id uuid :=
        (select auth.uid());

    reference_date date;

    window_end timestamptz;

    new_checkin_id uuid;

    completed_ids uuid[] :=
        coalesce(
            p_completed_task_ids,
            array[]::uuid[]
        );

begin

    if
        actor_id is null
        or not private.is_admin()
    then

        raise exception
            'Administrator access required.';

    end if;


    if p_user_id is null then

        raise exception
            'Member is required.';

    end if;


    if p_date is null then

        raise exception
            'Historical date is required.';

    end if;


    if length(
        trim(
            coalesce(
                p_reason,
                ''
            )
        )
    ) < 5 then

        raise exception
            'A clear reason for the historical entry is required.';

    end if;


    reference_date :=
        coalesce(
            private.current_accountability_date(),
            private.community_local_date()
        );


    if p_date >= reference_date then

        raise exception
            'Historical backfill is only allowed for previous accountability dates.';

    end if;


    window_end :=
        private.accountability_window_end(
            p_date
        );


    if private.account_status_at(
        p_user_id,
        window_end
    ) <>
        'active'::public.account_status
    then

        raise exception
            'The selected user was not an active member for that accountability date.';

    end if;


    if exists (

        select 1

        from public.daily_checkins

        where user_id =
            p_user_id

          and checkin_date =
            p_date

    ) then

        raise exception
            'A check-in already exists for this member and date.';

    end if;


    if exists (

        select 1

        from unnest(
            completed_ids
        ) as selected(task_id)

        where not exists (

            select 1

            from public.checklist_items
                as item

            join public.growth_areas
                as area

              on area.id =
                 item.growth_area_id

            where item.id =
                selected.task_id

              and item.response_type =
                'boolean'

              and item.is_active = true

              and area.is_active = true

              and (
                  item.starts_on is null
                  or item.starts_on <= p_date
              )

              and (
                  item.ends_on is null
                  or item.ends_on >= p_date
              )

              and (
                  area.starts_on is null
                  or area.starts_on <= p_date
              )

              and (
                  area.ends_on is null
                  or area.ends_on >= p_date
              )

        )

    ) then

        raise exception
            'One or more selected tasks were not valid for that accountability date.';

    end if;


    insert into public.daily_checkins (
        user_id,
        checkin_date,
        source,
        created_by
    )
    values (
        p_user_id,
        p_date,
        'admin_backfill'::public.checkin_source,
        actor_id
    )

    returning id
    into new_checkin_id;


    insert into public.checkin_responses (
        checkin_id,
        checklist_item_id,
        boolean_value
    )

    select
        new_checkin_id,
        item.id,

        (
            item.id =
            any(completed_ids)
        )

    from public.checklist_items
        as item

    join public.growth_areas
        as area

      on area.id =
         item.growth_area_id

    where item.response_type =
        'boolean'

      and item.is_active = true

      and area.is_active = true

      and (
          item.starts_on is null
          or item.starts_on <= p_date
      )

      and (
          item.ends_on is null
          or item.ends_on >= p_date
      )

      and (
          area.starts_on is null
          or area.starts_on <= p_date
      )

      and (
          area.ends_on is null
          or area.ends_on >= p_date
      );


    insert into public.admin_audit_log (
        actor_user_id,
        target_user_id,
        action,
        details
    )
    values (
        actor_id,
        p_user_id,
        'historical_checkin_backfilled',
        jsonb_build_object(
            'checkin_id',
            new_checkin_id,
            'accountability_date',
            p_date,
            'reason',
            trim(p_reason),
            'completed_task_ids',
            to_jsonb(completed_ids)
        )
    );


    return new_checkin_id;

end;

$$;


create or replace function public.admin_backfill_checkin(

    p_user_id uuid,

    p_date date,

    p_completed_task_ids uuid[],

    p_reason text

)
returns uuid
language sql
security invoker
set search_path = ''
as $$

    select
        private.admin_backfill_checkin_impl(
            p_user_id,
            p_date,
            p_completed_task_ids,
            p_reason
        );

$$;


-- =========================================================
-- PRIVILEGES
-- =========================================================

revoke execute
on function private.accountability_window_end(date)
from public;

revoke execute
on function private.account_status_at(uuid, timestamptz)
from public;

revoke execute
on function private.completed_category_count(uuid, date)
from public;

revoke execute
on function private.get_my_checkin_history_impl(integer)
from public;

revoke execute
on function private.admin_accountability_report_impl(date)
from public;

revoke execute
on function private.admin_backfill_checkin_impl(
    uuid,
    date,
    uuid[],
    text
)
from public;


grant execute
on function private.get_my_checkin_history_impl(integer)
to authenticated;

grant execute
on function private.admin_accountability_report_impl(date)
to authenticated;

grant execute
on function private.admin_backfill_checkin_impl(
    uuid,
    date,
    uuid[],
    text
)
to authenticated;


revoke execute
on function public.get_my_checkin_history(integer)
from public, anon;

grant execute
on function public.get_my_checkin_history(integer)
to authenticated;


revoke execute
on function public.admin_accountability_report(date)
from public, anon;

grant execute
on function public.admin_accountability_report(date)
to authenticated;


revoke execute
on function public.admin_backfill_checkin(
    uuid,
    date,
    uuid[],
    text
)
from public, anon;

grant execute
on function public.admin_backfill_checkin(
    uuid,
    date,
    uuid[],
    text
)
to authenticated;


commit;