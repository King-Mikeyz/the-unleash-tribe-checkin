begin;

-- =========================================================
-- THE UNLEASH TRIBE
-- FIX: ADMIN APPLICATION ANSWERS
--
-- Resolves the PL/pgSQL ambiguity between the local
-- version_number variable and the version_number table column.
-- =========================================================

create or replace function public.admin_get_application_answers(
    p_request_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
    actor_id uuid :=
        (select auth.uid());

    request_record
        public.access_requests%rowtype;

    questionnaire_version_number integer;

    answers_json jsonb;

begin

    -- -----------------------------------------------------
    -- AUTHORIZATION
    -- -----------------------------------------------------

    if
        actor_id is null
        or not private.is_admin()
    then
        raise exception
            'Administrator access required.';
    end if;


    -- -----------------------------------------------------
    -- LOAD APPLICATION
    -- -----------------------------------------------------

    select access_request.*
    into request_record

    from public.access_requests
        as access_request

    where access_request.id =
        p_request_id;


    if not found then

        raise exception
            'Application not found.';

    end if;


    -- -----------------------------------------------------
    -- LOAD QUESTIONNAIRE VERSION
    --
    -- IMPORTANT:
    -- The local variable deliberately does NOT share the
    -- same name as the database column.
    -- -----------------------------------------------------

    select questionnaire_version.version_number
    into questionnaire_version_number

    from public.onboarding_questionnaire_versions
        as questionnaire_version

    where questionnaire_version.id =
        request_record.questionnaire_version_id;


    -- -----------------------------------------------------
    -- LOAD APPLICATION ANSWERS
    -- -----------------------------------------------------

    select coalesce(

        jsonb_agg(

            jsonb_build_object(

                'section_title',
                question.section_title,

                'label',
                question.label,

                'field_type',
                question.field_type,

                'answer',
                answer.answer,

                'sort_order',
                question.sort_order

            )

            order by question.sort_order

        ),

        '[]'::jsonb

    )
    into answers_json

    from public.onboarding_answers
        as answer

    join public.onboarding_questions
        as question

      on question.id =
         answer.question_id

    where answer.request_id =
        p_request_id;


    -- -----------------------------------------------------
    -- RESPONSE
    -- -----------------------------------------------------

    return jsonb_build_object(

        'request_id',
        request_record.id,

        'full_name',
        request_record.full_name,

        'email',
        request_record.email,

        'version_number',
        questionnaire_version_number,

        'answers',
        answers_json

    );

end;
$$;


-- =========================================================
-- FUNCTION PERMISSIONS
-- =========================================================

revoke execute
on function public.admin_get_application_answers(uuid)
from public, anon;

grant execute
on function public.admin_get_application_answers(uuid)
to authenticated;


commit;