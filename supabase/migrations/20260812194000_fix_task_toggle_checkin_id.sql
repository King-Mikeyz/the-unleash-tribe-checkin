begin;

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

    v_checkin_id uuid;

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
        on area.id = item.growth_area_id

    where item.id = p_checklist_item_id

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
        daily.id,
        daily.source

    into
        v_checkin_id,
        existing_source

    from public.daily_checkins as daily

    where daily.user_id = actor_id

      and daily.checkin_date =
          accountability_date;


    if v_checkin_id is null then

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
        into v_checkin_id;


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
        v_checkin_id,
        p_checklist_item_id,
        p_completed
    )

    on conflict on constraint
        checkin_responses_unique_item

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
        v_checkin_id;


    return
        private.build_today_checkin_dashboard();

end;

$$;


grant execute
on function private.member_set_checkin_task_state(
    uuid,
    boolean
)
to authenticated;


commit;
