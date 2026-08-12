begin;

-- =========================================================
-- THE UNLEASH TRIBE
-- V1 TASK + ACCOUNTABILITY ENGINE
-- =========================================================


-- =========================================================
-- ACCOUNTABILITY WINDOW SETTINGS
-- =========================================================

alter table public.app_settings
add column if not exists accountability_open_time time
not null default '10:00';

alter table public.app_settings
add column if not exists accountability_close_time time
not null default '06:00';


do $$
begin

    if not exists (
        select 1
        from pg_constraint
        where conname = 'app_settings_accountability_times_different'
    ) then

        alter table public.app_settings
        add constraint app_settings_accountability_times_different
        check (
            accountability_open_time <>
            accountability_close_time
        );

    end if;

end
$$;


-- =========================================================
-- GROWTH AREA / PARENT TASK ENHANCEMENTS
-- =========================================================

alter table public.growth_areas
add column if not exists description text;

alter table public.growth_areas
add column if not exists is_required boolean
not null default true;

alter table public.growth_areas
add column if not exists starts_on date;

alter table public.growth_areas
add column if not exists ends_on date;

alter table public.growth_areas
add column if not exists created_by uuid
references auth.users(id)
on delete set null;

alter table public.growth_areas
add column if not exists updated_at timestamptz
not null default now();


do $$
begin

    if not exists (
        select 1
        from pg_constraint
        where conname = 'growth_areas_schedule_check'
    ) then

        alter table public.growth_areas
        add constraint growth_areas_schedule_check
        check (
            ends_on is null
            or starts_on is null
            or ends_on >= starts_on
        );

    end if;

end
$$;


drop trigger if exists growth_areas_set_updated_at
on public.growth_areas;

create trigger growth_areas_set_updated_at
before update
on public.growth_areas
for each row
execute function private.set_updated_at();


-- Automatically generate IDs for future parent tasks.

create sequence if not exists
public.growth_areas_id_seq;


select setval(
    'public.growth_areas_id_seq',
    coalesce(
        (
            select max(id)::bigint
            from public.growth_areas
        ),
        0
    ) + 1,
    false
);


alter sequence public.growth_areas_id_seq
owned by public.growth_areas.id;


alter table public.growth_areas
alter column id
set default nextval(
    'public.growth_areas_id_seq'
);


-- =========================================================
-- CHILD TASK ENHANCEMENTS
-- =========================================================

alter table public.checklist_items
add column if not exists starts_on date;

alter table public.checklist_items
add column if not exists ends_on date;

alter table public.checklist_items
add column if not exists created_by uuid
references auth.users(id)
on delete set null;


do $$
begin

    if not exists (
        select 1
        from pg_constraint
        where conname = 'checklist_items_schedule_check'
    ) then

        alter table public.checklist_items
        add constraint checklist_items_schedule_check
        check (
            ends_on is null
            or starts_on is null
            or ends_on >= starts_on
        );

    end if;

end
$$;


-- =========================================================
-- SEED THE REAL V1 DAILY TASKS
--
-- All explicit child tasks supplied by the tribe are
-- required. "etc" is intentionally NOT hardcoded.
-- Admins can add more tasks from the Task Manager.
-- =========================================================

with task_seed (
    area_slug,
    label,
    sort_order
) as (

    values

    (
        'fellowship-with-the-holy-spirit',
        'Worship',
        1
    ),

    (
        'fellowship-with-the-holy-spirit',
        'Prayer',
        2
    ),

    (
        'fellowship-with-the-holy-spirit',
        'Bible Reading',
        3
    ),

    (
        'fellowship-with-the-holy-spirit',
        'Listen to a Sermon',
        4
    ),

    (
        'scripture',
        'Proverbs Chapter of the Day',
        1
    ),

    (
        'monthly-goal-progress',
        'Work on your monthly goal today',
        1
    ),

    (
        'financial-living',
        'Save',
        1
    ),

    (
        'financial-living',
        'Avoid Debt',
        2
    ),

    (
        'financial-living',
        'Earn',
        3
    ),

    (
        'financial-living',
        'Give',
        4
    ),

    (
        'financial-living',
        'Budget',
        5
    ),

    (
        'financial-living',
        'Stay Within Budget',
        6
    ),

    (
        'health-and-wellness',
        'Exercise',
        1
    ),

    (
        'health-and-wellness',
        'Water',
        2
    ),

    (
        'health-and-wellness',
        'Rest',
        3
    ),

    (
        'health-and-wellness',
        'Avoid Carbonated Drinks',
        4
    ),

    (
        'personal-growth',
        'Learn',
        1
    ),

    (
        'personal-growth',
        'Read',
        2
    ),

    (
        'personal-growth',
        'Listen',
        3
    ),

    (
        'personal-growth',
        'Improve',
        4
    ),

    (
        'holy-spirit-journaling',
        'Write to the Holy Spirit',
        1
    )

)

insert into public.checklist_items (
    growth_area_id,
    label,
    response_type,
    is_required,
    sort_order,
    is_active
)

select
    growth_areas.id,
    task_seed.label,
    'boolean',
    true,
    task_seed.sort_order,
    true

from task_seed

join public.growth_areas
on growth_areas.slug =
task_seed.area_slug

on conflict (
    growth_area_id,
    sort_order
)
do nothing;


update public.growth_areas
set is_required = true
where id between 1 and 7;


-- =========================================================
-- COMMUNITY LOCAL DATE
-- =========================================================

create or replace function private.community_local_date()
returns date
language sql
stable
security definer
set search_path = ''
as $$

    select (
        now()
        at time zone (
            select community_timezone
            from public.app_settings
            where id = true
        )
    )::date;

$$;


-- =========================================================
-- CURRENT ACCOUNTABILITY DATE
--
-- Example:
-- Aug 12 10:00 AM -> Aug 13 06:00 AM
-- belongs to accountability date Aug 12.
--
-- Between 06:00 and 10:00 there is no open check-in.
-- =========================================================

create or replace function private.current_accountability_date()
returns date
language plpgsql
stable
security definer
set search_path = ''
as $$

declare

    local_now timestamp;

    local_date date;

    local_time time;

    open_time time;

    close_time time;

    timezone_name text;

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


    local_now :=
        now()
        at time zone timezone_name;

    local_date :=
        local_now::date;

    local_time :=
        local_now::time;


    -- Overnight accountability window.
    if close_time < open_time then

        if local_time >= open_time then

            return local_date;

        elsif local_time < close_time then

            return local_date - 1;

        else

            return null;

        end if;

    end if;


    -- Same-day window support if leadership
    -- changes the schedule in future.

    if
        local_time >= open_time
        and local_time < close_time
    then

        return local_date;

    end if;


    return null;

end;

$$;


-- Replace the old calendar-day helper.

create or replace function private.community_today()
returns date
language sql
stable
security definer
set search_path = ''
as $$

    select private.current_accountability_date();

$$;


-- =========================================================
-- REQUIRED PARENT COUNT FOR A DATE
-- =========================================================

create or replace function private.required_category_count(
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

      and exists (

          select 1

          from public.checklist_items as item

          where item.growth_area_id = area.id

            and item.is_active = true

            and item.is_required = true

            and (
                item.starts_on is null
                or item.starts_on <= p_date
            )

            and (
                item.ends_on is null
                or item.ends_on >= p_date
            )

      );

$$;


-- =========================================================
-- PARENT COMPLETION
--
-- A parent is complete ONLY when every active REQUIRED
-- child task is complete.
-- =========================================================

create or replace function private.is_category_complete(
    p_user_id uuid,
    p_growth_area_id smallint,
    p_date date
)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$

declare

    required_count integer;

    completed_count integer;

begin

    select count(*)::integer

    into required_count

    from public.checklist_items as item

    where item.growth_area_id =
        p_growth_area_id

      and item.is_active = true

      and item.is_required = true

      and (
          item.starts_on is null
          or item.starts_on <= p_date
      )

      and (
          item.ends_on is null
          or item.ends_on >= p_date
      );


    if required_count = 0 then

        return false;

    end if;


    select count(*)::integer

    into completed_count

    from public.checklist_items as item

    left join public.daily_checkins as checkin

      on checkin.user_id =
         p_user_id

     and checkin.checkin_date =
         p_date

    left join public.checkin_responses as response

      on response.checkin_id =
         checkin.id

     and response.checklist_item_id =
         item.id

    where item.growth_area_id =
        p_growth_area_id

      and item.is_active = true

      and item.is_required = true

      and (
          item.starts_on is null
          or item.starts_on <= p_date
      )

      and (
          item.ends_on is null
          or item.ends_on >= p_date
      )

      and (

          case item.response_type

              when 'boolean'
              then response.boolean_value is true

              when 'text'
              then nullif(
                  trim(response.text_value),
                  ''
              ) is not null

              when 'number'
              then response.numeric_value is not null

              else false

          end

      );


    return
        completed_count =
        required_count;

end;

$$;


-- =========================================================
-- FULL DAY COMPLETION
-- =========================================================

create or replace function private.is_day_complete(
    p_user_id uuid,
    p_date date
)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$

declare

    total_categories integer;

    completed_categories integer;

begin

    total_categories :=
        private.required_category_count(
            p_date
        );


    if total_categories = 0 then

        return false;

    end if;


    select count(*)::integer

    into completed_categories

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


    return
        completed_categories =
        total_categories;

end;

$$;


-- =========================================================
-- CURRENT STREAK
-- =========================================================

create or replace function private.current_streak(
    p_user_id uuid
)
returns integer
language plpgsql
stable
security definer
set search_path = ''
as $$

declare

    timezone_name text;

    joined_date date;

    open_date date;

    cursor_date date;

    local_date date;

    streak integer := 0;

begin

    select community_timezone
    into timezone_name

    from public.app_settings

    where id = true;


    select coalesce(

        (
            profile.approved_at
            at time zone timezone_name
        )::date,

        (
            profile.created_at
            at time zone timezone_name
        )::date

    )

    into joined_date

    from public.profiles as profile

    where profile.id =
        p_user_id;


    if joined_date is null then

        return 0;

    end if;


    open_date :=
        private.current_accountability_date();

    local_date :=
        private.community_local_date();


    -- An open day does not break a streak until it closes.
    -- If today's work is already complete, include it.

    if open_date is not null then

        if private.is_day_complete(
            p_user_id,
            open_date
        ) then

            cursor_date :=
                open_date;

        else

            cursor_date :=
                open_date - 1;

        end if;

    else

        cursor_date :=
            local_date - 1;

    end if;


    while cursor_date >= joined_date loop

        -- Days with no required categories are skipped.
        if
            private.required_category_count(
                cursor_date
            ) = 0
        then

            cursor_date :=
                cursor_date - 1;

            continue;

        end if;


        if private.is_day_complete(
            p_user_id,
            cursor_date
        ) then

            streak :=
                streak + 1;

            cursor_date :=
                cursor_date - 1;

        else

            exit;

        end if;

    end loop;


    return streak;

end;

$$;


-- =========================================================
-- DASHBOARD DATA BUILDER
-- =========================================================

create or replace function private.build_today_checkin_dashboard()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$

declare

    actor_id uuid :=
        (select auth.uid());

    accountability_date date;

    timezone_name text;

    open_time time;

    close_time time;

    total_categories integer := 0;

    completed_categories integer := 0;

    streak_count integer := 0;

    category_data jsonb :=
        '[]'::jsonb;

begin

    if
        actor_id is null
        or not private.is_active_member()
    then

        raise exception
            'Active member account required.';

    end if;


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


    accountability_date :=
        private.current_accountability_date();

    streak_count :=
        private.current_streak(
            actor_id
        );


    if accountability_date is null then

        return jsonb_build_object(

            'is_open',
            false,

            'accountability_date',
            null,

            'timezone',
            timezone_name,

            'open_time',
            to_char(
                open_time,
                'HH24:MI'
            ),

            'close_time',
            to_char(
                close_time,
                'HH24:MI'
            ),

            'completed_categories',
            0,

            'total_categories',
            0,

            'percentage',
            0,

            'streak',
            streak_count,

            'categories',
            '[]'::jsonb

        );

    end if;


    total_categories :=
        private.required_category_count(
            accountability_date
        );


    select count(*)::integer

    into completed_categories

    from public.growth_areas as area

    where area.is_active = true

      and area.is_required = true

      and (
          area.starts_on is null
          or area.starts_on <= accountability_date
      )

      and (
          area.ends_on is null
          or area.ends_on >= accountability_date
      )

      and private.is_category_complete(
          actor_id,
          area.id,
          accountability_date
      );


    select coalesce(

        jsonb_agg(

            jsonb_build_object(

                'id',
                area.id,

                'name',
                area.name,

                'description',
                area.description,

                'required',
                area.is_required,

                'completed',
                private.is_category_complete(
                    actor_id,
                    area.id,
                    accountability_date
                ),

                'required_tasks',
                (
                    select count(*)::integer

                    from public.checklist_items as required_item

                    where required_item.growth_area_id =
                        area.id

                      and required_item.is_active = true

                      and required_item.is_required = true

                      and (
                          required_item.starts_on is null
                          or required_item.starts_on <= accountability_date
                      )

                      and (
                          required_item.ends_on is null
                          or required_item.ends_on >= accountability_date
                      )
                ),

                'completed_required_tasks',
                (
                    select count(*)::integer

                    from public.checklist_items as completed_item

                    left join public.daily_checkins as daily

                      on daily.user_id =
                         actor_id

                     and daily.checkin_date =
                         accountability_date

                    left join public.checkin_responses as answer

                      on answer.checkin_id =
                         daily.id

                     and answer.checklist_item_id =
                         completed_item.id

                    where completed_item.growth_area_id =
                        area.id

                      and completed_item.is_active = true

                      and completed_item.is_required = true

                      and (
                          completed_item.starts_on is null
                          or completed_item.starts_on <= accountability_date
                      )

                      and (
                          completed_item.ends_on is null
                          or completed_item.ends_on >= accountability_date
                      )

                      and answer.boolean_value is true
                ),

                'tasks',
                (
                    select coalesce(

                        jsonb_agg(

                            jsonb_build_object(

                                'id',
                                    item.id,

                                'label',
                                    item.label,

                                'required',
                                    item.is_required,

                                'response_type',
                                    item.response_type,

                                'completed',
                                    coalesce(
                                        response.boolean_value,
                                        false
                                    )

                            )

                            order by item.sort_order

                        ),

                        '[]'::jsonb

                    )

                    from public.checklist_items as item

                    left join public.daily_checkins as checkin

                      on checkin.user_id =
                         actor_id

                     and checkin.checkin_date =
                         accountability_date

                    left join public.checkin_responses as response

                      on response.checkin_id =
                         checkin.id

                     and response.checklist_item_id =
                         item.id

                    where item.growth_area_id =
                        area.id

                      and item.is_active = true

                      and (
                          item.starts_on is null
                          or item.starts_on <= accountability_date
                      )

                      and (
                          item.ends_on is null
                          or item.ends_on >= accountability_date
                      )
                )

            )

            order by area.sort_order

        ),

        '[]'::jsonb

    )

    into category_data

    from public.growth_areas as area

    where area.is_active = true

      and (
          area.starts_on is null
          or area.starts_on <= accountability_date
      )

      and (
          area.ends_on is null
          or area.ends_on >= accountability_date
      )

      and exists (

          select 1

          from public.checklist_items as item

          where item.growth_area_id =
              area.id

            and item.is_active = true

            and (
                item.starts_on is null
                or item.starts_on <= accountability_date
            )

            and (
                item.ends_on is null
                or item.ends_on >= accountability_date
            )

      );


    return jsonb_build_object(

        'is_open',
        true,

        'accountability_date',
        accountability_date,

        'timezone',
        timezone_name,

        'open_time',
        to_char(
            open_time,
            'HH24:MI'
        ),

        'close_time',
        to_char(
            close_time,
            'HH24:MI'
        ),

        'completed_categories',
        completed_categories,

        'total_categories',
        total_categories,

        'percentage',
        case

            when total_categories = 0
            then 0

            else round(
                completed_categories
                * 100.0
                / total_categories
            )::integer

        end,

        'streak',
        streak_count,

        'categories',
        category_data

    );

end;

$$;


-- Public read wrapper.

create or replace function public.get_today_checkin_dashboard()
returns jsonb
language sql
security invoker
set search_path = ''
as $$

    select
        private.build_today_checkin_dashboard();

$$;


-- =========================================================
-- SAFE MEMBER TASK TOGGLE
-- =========================================================

create or replace function private.member_set_checkin_task_state(
    p_checklist_item_id uuid,
    p_completed boolean
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$

declare

    actor_id uuid :=
        (select auth.uid());

    accountability_date date;

    checkin_id uuid;

    item_record record;

    existing_source public.checkin_source;

begin

    if
        actor_id is null
        or not private.is_active_member()
    then

        raise exception
            'Active member account required.';

    end if;


    accountability_date :=
        private.current_accountability_date();


    if accountability_date is null then

        raise exception
            'The Daily Check In is currently closed.';

    end if;


    select
        item.id,
        item.response_type

    into item_record

    from public.checklist_items as item

    join public.growth_areas as area

      on area.id =
         item.growth_area_id

    where item.id =
        p_checklist_item_id

      and item.is_active = true

      and area.is_active = true

      and (
          item.starts_on is null
          or item.starts_on <= accountability_date
      )

      and (
          item.ends_on is null
          or item.ends_on >= accountability_date
      )

      and (
          area.starts_on is null
          or area.starts_on <= accountability_date
      )

      and (
          area.ends_on is null
          or area.ends_on >= accountability_date
      );


    if not found then

        raise exception
            'This task is not available for the current accountability day.';

    end if;


    if item_record.response_type <> 'boolean' then

        raise exception
            'This task cannot be toggled as a checkbox.';

    end if;


    select
        id,
        source

    into
        checkin_id,
        existing_source

    from public.daily_checkins

    where user_id =
        actor_id

      and checkin_date =
        accountability_date;


    if checkin_id is null then

        insert into public.daily_checkins (

            user_id,
            checkin_date,
            source,
            created_by

        )
        values (

            actor_id,
            accountability_date,
            'member'::public.checkin_source,
            actor_id

        )

        returning id
        into checkin_id;


    elsif existing_source <>
        'member'::public.checkin_source
    then

        raise exception
            'This check-in is controlled by an administrator.';

    end if;


    insert into public.checkin_responses (

        checkin_id,
        checklist_item_id,
        boolean_value

    )
    values (

        checkin_id,
        p_checklist_item_id,
        p_completed

    )

    on conflict (
        checkin_id,
        checklist_item_id
    )

    do update

    set
        boolean_value =
            excluded.boolean_value,

        text_value =
            null,

        numeric_value =
            null,

        updated_at =
            now();


    update public.daily_checkins

    set updated_at =
        now()

    where id =
        checkin_id;


    return
        private.build_today_checkin_dashboard();

end;

$$;


create or replace function public.set_checkin_task_state(
    p_checklist_item_id uuid,
    p_completed boolean
)
returns jsonb
language sql
security invoker
set search_path = ''
as $$

    select private.member_set_checkin_task_state(
        p_checklist_item_id,
        p_completed
    );

$$;


-- Remove direct browser mutation access.
-- Task completion now goes through the controlled RPC.

revoke insert, update
on table public.daily_checkins
from authenticated;

revoke insert, update
on table public.checkin_responses
from authenticated;


-- =========================================================
-- ADMIN: CREATE PARENT TASK
-- =========================================================

create or replace function private.admin_create_growth_area_impl(

    p_name text,

    p_description text default null,

    p_starts_on date default null,

    p_ends_on date default null,

    p_required boolean default true

)
returns smallint
language plpgsql
security definer
set search_path = ''
as $$

declare

    actor_id uuid :=
        (select auth.uid());

    new_id smallint;

    new_slug text;

    new_sort_order smallint;

    effective_start date;

begin

    if
        actor_id is null
        or not private.is_admin()
    then

        raise exception
            'Administrator access required.';

    end if;


    if length(
        trim(
            coalesce(
                p_name,
                ''
            )
        )
    ) < 2 then

        raise exception
            'Parent task name is required.';

    end if;


    effective_start :=
        coalesce(
            p_starts_on,
            private.community_local_date() + 1
        );


    if
        p_ends_on is not null
        and p_ends_on < effective_start
    then

        raise exception
            'End date cannot be before start date.';

    end if;


    new_slug :=
        trim(
            both '-'
            from lower(
                regexp_replace(
                    trim(p_name),
                    '[^a-zA-Z0-9]+',
                    '-',
                    'g'
                )
            )
        );


    if new_slug = '' then

        new_slug :=
            'task';

    end if;


    if exists (

        select 1
        from public.growth_areas
        where slug =
            new_slug

    ) then

        new_slug :=
            new_slug
            || '-'
            || substr(
                replace(
                    gen_random_uuid()::text,
                    '-',
                    ''
                ),
                1,
                6
            );

    end if;


    select
        coalesce(
            max(sort_order),
            0
        ) + 1

    into new_sort_order

    from public.growth_areas;


    insert into public.growth_areas (

        slug,
        name,
        description,
        sort_order,
        is_required,
        starts_on,
        ends_on,
        is_active,
        created_by

    )
    values (

        new_slug,
        trim(p_name),
        nullif(
            trim(
                coalesce(
                    p_description,
                    ''
                )
            ),
            ''
        ),
        new_sort_order,
        p_required,
        effective_start,
        p_ends_on,
        true,
        actor_id

    )

    returning id
    into new_id;


    insert into public.admin_audit_log (

        actor_user_id,
        action,
        details

    )
    values (

        actor_id,

        'growth_area_created',

        jsonb_build_object(

            'growth_area_id',
            new_id,

            'name',
            trim(p_name),

            'starts_on',
            effective_start,

            'ends_on',
            p_ends_on

        )

    );


    return new_id;

end;

$$;


create or replace function public.admin_create_growth_area(

    p_name text,

    p_description text default null,

    p_starts_on date default null,

    p_ends_on date default null,

    p_required boolean default true

)
returns smallint
language sql
security invoker
set search_path = ''
as $$

    select private.admin_create_growth_area_impl(
        p_name,
        p_description,
        p_starts_on,
        p_ends_on,
        p_required
    );

$$;


-- =========================================================
-- ADMIN: CREATE CHILD TASK
-- =========================================================

create or replace function private.admin_create_checklist_item_impl(

    p_growth_area_id smallint,

    p_label text,

    p_required boolean default true,

    p_starts_on date default null,

    p_ends_on date default null

)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$

declare

    actor_id uuid :=
        (select auth.uid());

    new_id uuid;

    new_sort_order smallint;

    effective_start date;

begin

    if
        actor_id is null
        or not private.is_admin()
    then

        raise exception
            'Administrator access required.';

    end if;


    if length(
        trim(
            coalesce(
                p_label,
                ''
            )
        )
    ) < 1 then

        raise exception
            'Child task label is required.';

    end if;


    if not exists (

        select 1

        from public.growth_areas

        where id =
            p_growth_area_id

          and is_active = true

    ) then

        raise exception
            'Parent task does not exist.';

    end if;


    effective_start :=
        coalesce(
            p_starts_on,
            private.community_local_date() + 1
        );


    if
        p_ends_on is not null
        and p_ends_on < effective_start
    then

        raise exception
            'End date cannot be before start date.';

    end if;


    select
        coalesce(
            max(sort_order),
            0
        ) + 1

    into new_sort_order

    from public.checklist_items

    where growth_area_id =
        p_growth_area_id;


    insert into public.checklist_items (

        growth_area_id,
        label,
        response_type,
        is_required,
        sort_order,
        is_active,
        starts_on,
        ends_on,
        created_by

    )
    values (

        p_growth_area_id,
        trim(p_label),
        'boolean',
        p_required,
        new_sort_order,
        true,
        effective_start,
        p_ends_on,
        actor_id

    )

    returning id
    into new_id;


    insert into public.admin_audit_log (

        actor_user_id,
        action,
        details

    )
    values (

        actor_id,

        'checklist_item_created',

        jsonb_build_object(

            'checklist_item_id',
            new_id,

            'growth_area_id',
            p_growth_area_id,

            'label',
            trim(p_label),

            'starts_on',
            effective_start,

            'ends_on',
            p_ends_on

        )

    );


    return new_id;

end;

$$;


create or replace function public.admin_create_checklist_item(

    p_growth_area_id smallint,

    p_label text,

    p_required boolean default true,

    p_starts_on date default null,

    p_ends_on date default null

)
returns uuid
language sql
security invoker
set search_path = ''
as $$

    select private.admin_create_checklist_item_impl(
        p_growth_area_id,
        p_label,
        p_required,
        p_starts_on,
        p_ends_on
    );

$$;


-- =========================================================
-- ADMIN: ARCHIVE PARENT
--
-- Existing historical records remain intact.
-- Future scheduled records can be cancelled.
-- =========================================================

create or replace function private.admin_archive_growth_area_impl(
    p_growth_area_id smallint
)
returns void
language plpgsql
security definer
set search_path = ''
as $$

declare

    actor_id uuid :=
        (select auth.uid());

    current_local_date date :=
        private.community_local_date();

    area_start date;

begin

    if
        actor_id is null
        or not private.is_admin()
    then

        raise exception
            'Administrator access required.';

    end if;


    select starts_on
    into area_start

    from public.growth_areas

    where id =
        p_growth_area_id

    for update;


    if not found then

        raise exception
            'Parent task not found.';

    end if;


    if
        area_start is not null
        and area_start > current_local_date
    then

        update public.growth_areas

        set is_active = false

        where id =
            p_growth_area_id;

    else

        update public.growth_areas

        set ends_on =
            current_local_date

        where id =
            p_growth_area_id;

    end if;


    insert into public.admin_audit_log (

        actor_user_id,
        action,
        details

    )
    values (

        actor_id,

        'growth_area_archived',

        jsonb_build_object(
            'growth_area_id',
            p_growth_area_id
        )

    );

end;

$$;


create or replace function public.admin_archive_growth_area(
    p_growth_area_id smallint
)
returns void
language sql
security invoker
set search_path = ''
as $$

    select private.admin_archive_growth_area_impl(
        p_growth_area_id
    );

$$;


-- =========================================================
-- ADMIN: ARCHIVE CHILD
-- =========================================================

create or replace function private.admin_archive_checklist_item_impl(
    p_checklist_item_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$

declare

    actor_id uuid :=
        (select auth.uid());

    current_local_date date :=
        private.community_local_date();

    item_start date;

begin

    if
        actor_id is null
        or not private.is_admin()
    then

        raise exception
            'Administrator access required.';

    end if;


    select starts_on
    into item_start

    from public.checklist_items

    where id =
        p_checklist_item_id

    for update;


    if not found then

        raise exception
            'Child task not found.';

    end if;


    if
        item_start is not null
        and item_start > current_local_date
    then

        update public.checklist_items

        set is_active = false

        where id =
            p_checklist_item_id;

    else

        update public.checklist_items

        set ends_on =
            current_local_date

        where id =
            p_checklist_item_id;

    end if;


    insert into public.admin_audit_log (

        actor_user_id,
        action,
        details

    )
    values (

        actor_id,

        'checklist_item_archived',

        jsonb_build_object(
            'checklist_item_id',
            p_checklist_item_id
        )

    );

end;

$$;


create or replace function public.admin_archive_checklist_item(
    p_checklist_item_id uuid
)
returns void
language sql
security invoker
set search_path = ''
as $$

    select private.admin_archive_checklist_item_impl(
        p_checklist_item_id
    );

$$;


-- =========================================================
-- FUNCTION PRIVILEGES
-- =========================================================

revoke execute
on function public.get_today_checkin_dashboard()
from public, anon;

grant execute
on function public.get_today_checkin_dashboard()
to authenticated;


revoke execute
on function public.set_checkin_task_state(
    uuid,
    boolean
)
from public, anon;

grant execute
on function public.set_checkin_task_state(
    uuid,
    boolean
)
to authenticated;


revoke execute
on function public.admin_create_growth_area(
    text,
    text,
    date,
    date,
    boolean
)
from public, anon;

grant execute
on function public.admin_create_growth_area(
    text,
    text,
    date,
    date,
    boolean
)
to authenticated;


revoke execute
on function public.admin_create_checklist_item(
    smallint,
    text,
    boolean,
    date,
    date
)
from public, anon;

grant execute
on function public.admin_create_checklist_item(
    smallint,
    text,
    boolean,
    date,
    date
)
to authenticated;


revoke execute
on function public.admin_archive_growth_area(
    smallint
)
from public, anon;

grant execute
on function public.admin_archive_growth_area(
    smallint
)
to authenticated;


revoke execute
on function public.admin_archive_checklist_item(
    uuid
)
from public, anon;

grant execute
on function public.admin_archive_checklist_item(
    uuid
)
to authenticated;


grant execute
on function private.build_today_checkin_dashboard()
to authenticated;

grant execute
on function private.member_set_checkin_task_state(
    uuid,
    boolean
)
to authenticated;

grant execute
on function private.admin_create_growth_area_impl(
    text,
    text,
    date,
    date,
    boolean
)
to authenticated;

grant execute
on function private.admin_create_checklist_item_impl(
    smallint,
    text,
    boolean,
    date,
    date
)
to authenticated;

grant execute
on function private.admin_archive_growth_area_impl(
    smallint
)
to authenticated;

grant execute
on function private.admin_archive_checklist_item_impl(
    uuid
)
to authenticated;


commit;
