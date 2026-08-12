begin;

-- =========================================================
-- THE UNLEASH TRIBE
-- VERSIONED ONBOARDING QUESTIONNAIRE
-- =========================================================


-- =========================================================
-- QUESTIONNAIRE VERSIONS
-- =========================================================

create table public.onboarding_questionnaire_versions (

    id uuid primary key
        default gen_random_uuid(),

    version_number integer
        not null
        unique,

    status text
        not null,

    title text
        not null,

    intro text,

    created_by uuid
        references auth.users(id)
        on delete set null,

    created_at timestamptz
        not null
        default now(),

    published_by uuid
        references auth.users(id)
        on delete set null,

    published_at timestamptz,

    constraint onboarding_questionnaire_status_check
        check (
            status in (
                'draft',
                'published',
                'archived'
            )
        ),

    constraint onboarding_questionnaire_version_positive
        check (
            version_number > 0
        ),

    constraint onboarding_questionnaire_title_not_blank
        check (
            length(trim(title)) > 0
        )
);


create unique index
onboarding_one_published_version_idx
on public.onboarding_questionnaire_versions (
    status
)
where status = 'published';


create unique index
onboarding_one_draft_version_idx
on public.onboarding_questionnaire_versions (
    status
)
where status = 'draft';


-- =========================================================
-- QUESTIONS
-- =========================================================

create table public.onboarding_questions (

    id uuid primary key
        default gen_random_uuid(),

    version_id uuid not null
        references public.onboarding_questionnaire_versions(id)
        on delete cascade,

    section_key text
        not null,

    section_title text
        not null,

    question_key text
        not null,

    label text
        not null,

    help_text text,

    field_type text
        not null,

    options jsonb
        not null
        default '[]'::jsonb,

    is_required boolean
        not null
        default false,

    sort_order integer
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

    constraint onboarding_question_field_type_check
        check (
            field_type in (
                'short_text',
                'long_text',
                'yes_no',
                'single_choice',
                'multiple_choice',
                'number',
                'date',
                'scale'
            )
        ),

    constraint onboarding_question_key_format
        check (
            question_key ~ '^[a-z0-9_]+$'
        ),

    constraint onboarding_question_options_array
        check (
            jsonb_typeof(options) = 'array'
        ),

    constraint onboarding_question_sort_positive
        check (
            sort_order > 0
        ),

    constraint onboarding_question_key_unique
        unique (
            version_id,
            question_key
        ),

    constraint onboarding_question_sort_unique
        unique (
            version_id,
            sort_order
        )
);


create trigger onboarding_questions_set_updated_at
before update
on public.onboarding_questions
for each row
execute function private.set_updated_at();


-- =========================================================
-- APPLICATION ANSWERS
-- =========================================================

alter table public.access_requests
add column if not exists questionnaire_version_id uuid
references public.onboarding_questionnaire_versions(id)
on delete restrict;


create table public.onboarding_answers (

    request_id uuid not null
        references public.access_requests(id)
        on delete cascade,

    question_id uuid not null
        references public.onboarding_questions(id)
        on delete restrict,

    answer jsonb
        not null,

    created_at timestamptz
        not null
        default now(),

    primary key (
        request_id,
        question_id
    )
);


create index onboarding_answers_request_idx
on public.onboarding_answers (
    request_id
);


-- =========================================================
-- RLS
-- =========================================================

alter table public.onboarding_questionnaire_versions
enable row level security;

alter table public.onboarding_questions
enable row level security;

alter table public.onboarding_answers
enable row level security;


create policy onboarding_versions_authenticated_select
on public.onboarding_questionnaire_versions
for select
to authenticated
using (
    status = 'published'
    or
    (select private.is_admin())
);


create policy onboarding_questions_authenticated_select
on public.onboarding_questions
for select
to authenticated
using (

    exists (

        select 1

        from public.onboarding_questionnaire_versions
            as version

        where version.id =
            onboarding_questions.version_id

          and (
              version.status = 'published'
              or
              (select private.is_admin())
          )

    )

);


create policy onboarding_answers_admin_select
on public.onboarding_answers
for select
to authenticated
using (
    (select private.is_admin())
);


revoke all
on table public.onboarding_questionnaire_versions
from anon, authenticated;

revoke all
on table public.onboarding_questions
from anon, authenticated;

revoke all
on table public.onboarding_answers
from anon, authenticated;


grant select
on table public.onboarding_questionnaire_versions
to authenticated;

grant select
on table public.onboarding_questions
to authenticated;

grant select
on table public.onboarding_answers
to authenticated;


grant all
on table public.onboarding_questionnaire_versions
to service_role;

grant all
on table public.onboarding_questions
to service_role;

grant all
on table public.onboarding_answers
to service_role;


-- Members may set their own username during account setup.
grant update (username)
on table public.profiles
to authenticated;


-- =========================================================
-- SEED QUESTIONNAIRE V1
-- =========================================================

do $$

declare

    questionnaire_id uuid;

begin

    if not exists (

        select 1
        from public.onboarding_questionnaire_versions
        where status = 'published'

    ) then


        insert into public.onboarding_questionnaire_versions (
            version_number,
            status,
            title,
            intro,
            published_at
        )
        values (
            1,
            'published',
            'The Unleash Tribe Onboarding Form',
            'Please fill this form carefully and honestly. This helps us understand you and support your growth effectively.',
            now()
        )

        returning id
        into questionnaire_id;


        insert into public.onboarding_questions (
            version_id,
            section_key,
            section_title,
            question_key,
            label,
            help_text,
            field_type,
            options,
            is_required,
            sort_order
        )
        values

        (
            questionnaire_id,
            'personal',
            'Personal Information',
            'title',
            'Title',
            null,
            'single_choice',
            '["Mr","Mrs","Miss","Dr","Other"]',
            false,
            10
        ),

        (
            questionnaire_id,
            'personal',
            'Personal Information',
            'first_name',
            'First Name',
            null,
            'short_text',
            '[]',
            true,
            20
        ),

        (
            questionnaire_id,
            'personal',
            'Personal Information',
            'surname',
            'Surname',
            null,
            'short_text',
            '[]',
            true,
            30
        ),

        (
            questionnaire_id,
            'personal',
            'Personal Information',
            'gender',
            'Gender',
            null,
            'single_choice',
            '["Male","Female"]',
            true,
            40
        ),

        (
            questionnaire_id,
            'personal',
            'Personal Information',
            'date_of_birth',
            'Date of Birth',
            'Age is derived from this when required. We do not store a second duplicate age field.',
            'date',
            '[]',
            false,
            50
        ),

        (
            questionnaire_id,
            'personal',
            'Personal Information',
            'nationality',
            'Nationality',
            null,
            'short_text',
            '[]',
            false,
            60
        ),

        (
            questionnaire_id,
            'personal',
            'Personal Information',
            'country_of_residence',
            'Country of Residence',
            null,
            'short_text',
            '[]',
            true,
            70
        ),

        (
            questionnaire_id,
            'occupation',
            'Marital Status & Occupation',
            'marital_status',
            'Marital Status',
            null,
            'single_choice',
            '["Single","Married","Divorced","Separated"]',
            false,
            80
        ),

        (
            questionnaire_id,
            'occupation',
            'Marital Status & Occupation',
            'occupation',
            'Occupation',
            null,
            'short_text',
            '[]',
            false,
            90
        ),

        (
            questionnaire_id,
            'occupation',
            'Marital Status & Occupation',
            'educational_qualification',
            'Educational Qualification',
            null,
            'short_text',
            '[]',
            false,
            100
        ),

        (
            questionnaire_id,
            'occupation',
            'Marital Status & Occupation',
            'work_status',
            'Which best describes you?',
            null,
            'single_choice',
            '["Student","Employed","Business Owner","Both"]',
            false,
            110
        ),

        (
            questionnaire_id,
            'occupation',
            'Marital Status & Occupation',
            'skills',
            'What skill do you have?',
            null,
            'long_text',
            '[]',
            false,
            120
        ),

        (
            questionnaire_id,
            'spiritual',
            'Spiritual Background',
            'church',
            'What church do you attend?',
            null,
            'short_text',
            '[]',
            false,
            130
        ),

        (
            questionnaire_id,
            'spiritual',
            'Spiritual Background',
            'born_again',
            'Are you born again?',
            null,
            'yes_no',
            '["Yes","No"]',
            true,
            140
        ),

        (
            questionnaire_id,
            'spiritual',
            'Spiritual Background',
            'filled_holy_spirit',
            'Are you filled with the Holy Spirit?',
            null,
            'single_choice',
            '["Yes","No","Not sure"]',
            true,
            150
        ),

        (
            questionnaire_id,
            'spiritual',
            'Spiritual Background',
            'holy_spirit_when',
            'If yes, when did this happen?',
            null,
            'short_text',
            '[]',
            false,
            160
        ),

        (
            questionnaire_id,
            'purpose',
            'Purpose & Intention',
            'purpose',
            'What do you want to achieve with The Unleash Tribe?',
            null,
            'long_text',
            '[]',
            true,
            170
        ),

        (
            questionnaire_id,
            'goals',
            'Goals & Success',
            'goals_2026',
            'What are your top 3–5 goals for 2026?',
            'This wording is editable by administrators for future years.',
            'long_text',
            '[]',
            true,
            180
        ),

        (
            questionnaire_id,
            'goals',
            'Goals & Success',
            'success_2026',
            'What does success in 2026 mean to you?',
            null,
            'long_text',
            '[]',
            true,
            190
        ),

        (
            questionnaire_id,
            'service',
            'Community & Service',
            'open_to_volunteering',
            'Are you open to volunteering in the tribe?',
            null,
            'yes_no',
            '["Yes","No"]',
            true,
            200
        ),

        (
            questionnaire_id,
            'service',
            'Community & Service',
            'volunteer_capacity',
            'If yes, in what capacity?',
            null,
            'long_text',
            '[]',
            false,
            210
        ),

        (
            questionnaire_id,
            'growth',
            'Personal Growth',
            'biggest_struggle',
            'What is your biggest current struggle?',
            'This can contain sensitive personal information and is visible to authorized administrators.',
            'long_text',
            '[]',
            false,
            220
        ),

        (
            questionnaire_id,
            'growth',
            'Personal Growth',
            'habit',
            'What habit do you want to build or break?',
            null,
            'long_text',
            '[]',
            true,
            230
        ),

        (
            questionnaire_id,
            'growth',
            'Personal Growth',
            'growth_commitment',
            'On a scale of 1–10, how committed are you to personal growth?',
            null,
            'scale',
            '[]',
            true,
            240
        ),

        (
            questionnaire_id,
            'commitment',
            'Commitment',
            'attend_daily_sessions',
            'Are you willing to attend daily 5:30–6:00 AM sessions?',
            'Times are interpreted in The Unleash Tribe community timezone.',
            'single_choice',
            '["Yes","No","Sometimes"]',
            true,
            250
        ),

        (
            questionnaire_id,
            'commitment',
            'Commitment',
            'submit_daily_reports',
            'Are you willing to submit daily reports?',
            null,
            'single_choice',
            '["Yes","No","Sometimes"]',
            true,
            260
        ),

        (
            questionnaire_id,
            'commitment',
            'Commitment',
            'commitment_level',
            'Which commitment level are you ready for?',
            null,
            'single_choice',
            '["Full","Moderate","Observational"]',
            true,
            270
        ),

        (
            questionnaire_id,
            'bible_plan',
            'Bible Reading Plan',
            'bible_reading_plan',
            'Which Bible reading plan would you like to do?',
            null,
            'single_choice',
            '["12-month plan — Genesis to Revelation, approximately 3–4 chapters daily","9-month plan — Genesis to Revelation, approximately 4–5 chapters daily"]',
            true,
            280
        );

    end if;

end
$$;


-- =========================================================
-- PUBLIC QUESTIONNAIRE
-- =========================================================

create or replace function public.get_published_onboarding_questionnaire()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$

declare

    version_record
        public.onboarding_questionnaire_versions%rowtype;

    questions_json jsonb;

begin

    select *
    into version_record

    from public.onboarding_questionnaire_versions

    where status = 'published'

    limit 1;


    if not found then

        raise exception
            'No onboarding questionnaire is currently published.';

    end if;


    select coalesce(

        jsonb_agg(

            jsonb_build_object(

                'id',
                question.id,

                'section_key',
                question.section_key,

                'section_title',
                question.section_title,

                'question_key',
                question.question_key,

                'label',
                question.label,

                'help_text',
                question.help_text,

                'field_type',
                question.field_type,

                'options',
                question.options,

                'required',
                question.is_required,

                'sort_order',
                question.sort_order

            )

            order by question.sort_order

        ),

        '[]'::jsonb

    )
    into questions_json

    from public.onboarding_questions
        as question

    where question.version_id =
        version_record.id

      and question.is_active = true;


    return jsonb_build_object(

        'version_id',
        version_record.id,

        'version_number',
        version_record.version_number,

        'title',
        version_record.title,

        'intro',
        version_record.intro,

        'questions',
        questions_json

    );

end;

$$;


-- =========================================================
-- SUBMIT APPLICATION
-- =========================================================

create or replace function public.submit_access_application(

    p_email text,

    p_answers jsonb

)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$

declare

    version_record
        public.onboarding_questionnaire_versions%rowtype;

    request_id uuid;

    normalized_email text;

    first_name text;

    surname text;

    full_name text;

    purpose_text text;

begin

    normalized_email :=
        lower(
            trim(
                coalesce(
                    p_email,
                    ''
                )
            )
        );


    if normalized_email !~*
        '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$'
    then

        raise exception
            'Please provide a valid email address.';

    end if;


    if
        p_answers is null
        or jsonb_typeof(p_answers) <> 'object'
    then

        raise exception
            'Application answers are required.';

    end if;


    if exists (

        select 1

        from public.access_requests

        where lower(email) =
            normalized_email

          and status in (
              'pending'::public.access_request_status,
              'approved'::public.access_request_status
          )

    ) then

        raise exception
            'An application for this email is already pending or approved.';

    end if;


    select *
    into version_record

    from public.onboarding_questionnaire_versions

    where status = 'published'

    limit 1;


    if not found then

        raise exception
            'Applications are temporarily unavailable.';

    end if;


    -- Validate required answers.

    if exists (

        select 1

        from public.onboarding_questions
            as question

        where question.version_id =
            version_record.id

          and question.is_active = true

          and question.is_required = true

          and (

              not (
                  p_answers
                  ? question.id::text
              )

              or
              p_answers -> question.id::text
                  is null

              or
              p_answers -> question.id::text =
                  'null'::jsonb

              or (
                  jsonb_typeof(
                      p_answers -> question.id::text
                  ) = 'string'

                  and length(
                      trim(
                          p_answers ->> question.id::text
                      )
                  ) = 0
              )

              or (
                  jsonb_typeof(
                      p_answers -> question.id::text
                  ) = 'array'

                  and jsonb_array_length(
                      p_answers -> question.id::text
                  ) = 0
              )

          )

    ) then

        raise exception
            'Please answer every required onboarding question.';

    end if;


    -- Validate single-choice answers.

    if exists (

        select 1

        from public.onboarding_questions
            as question

        where question.version_id =
            version_record.id

          and question.is_active = true

          and question.field_type in (
              'single_choice',
              'yes_no'
          )

          and p_answers
              ? question.id::text

          and not (
              question.options
              ? (
                  p_answers ->>
                  question.id::text
              )
          )

    ) then

        raise exception
            'One or more selected answers are invalid.';

    end if;


    -- Validate scale answers.

    if exists (

        select 1

        from public.onboarding_questions
            as question

        where question.version_id =
            version_record.id

          and question.is_active = true

          and question.field_type =
            'scale'

          and p_answers
              ? question.id::text

          and (

              jsonb_typeof(
                  p_answers -> question.id::text
              ) <> 'number'

              or (
                  p_answers ->>
                  question.id::text
              )::numeric < 1

              or (
                  p_answers ->>
                  question.id::text
              )::numeric > 10

          )

    ) then

        raise exception
            'Scale answers must be between 1 and 10.';

    end if;


    select
        trim(
            p_answers ->>
            question.id::text
        )
    into first_name

    from public.onboarding_questions
        as question

    where question.version_id =
        version_record.id

      and question.question_key =
        'first_name';


    select
        trim(
            p_answers ->>
            question.id::text
        )
    into surname

    from public.onboarding_questions
        as question

    where question.version_id =
        version_record.id

      and question.question_key =
        'surname';


    full_name :=
        trim(
            concat_ws(
                ' ',
                first_name,
                surname
            )
        );


    if length(full_name) < 2 then

        raise exception
            'First name and surname are required.';

    end if;


    select
        nullif(
            trim(
                p_answers ->>
                question.id::text
            ),
            ''
        )
    into purpose_text

    from public.onboarding_questions
        as question

    where question.version_id =
        version_record.id

      and question.question_key =
        'purpose';


    insert into public.access_requests (
        full_name,
        email,
        message,
        questionnaire_version_id
    )
    values (
        full_name,
        normalized_email,
        purpose_text,
        version_record.id
    )

    returning id
    into request_id;


    insert into public.onboarding_answers (
        request_id,
        question_id,
        answer
    )

    select
        request_id,
        question.id,
        p_answers -> question.id::text

    from public.onboarding_questions
        as question

    where question.version_id =
        version_record.id

      and question.is_active = true

      and p_answers
          ? question.id::text;


    return request_id;

end;

$$;


-- The old simple public insert path is no longer used.
drop policy if exists
access_requests_public_insert
on public.access_requests;


revoke insert
on table public.access_requests
from anon, authenticated;


-- =========================================================
-- ADMIN: CREATE / LOAD DRAFT
-- =========================================================

create or replace function public.admin_create_questionnaire_draft()
returns uuid
language plpgsql
security definer
set search_path = ''
as $$

declare

    actor_id uuid :=
        (select auth.uid());

    existing_draft uuid;

    published_version
        public.onboarding_questionnaire_versions%rowtype;

    new_version_id uuid;

    next_version_number integer;

begin

    if
        actor_id is null
        or not private.is_admin()
    then

        raise exception
            'Administrator access required.';

    end if;


    select id
    into existing_draft

    from public.onboarding_questionnaire_versions

    where status = 'draft'

    limit 1;


    if existing_draft is not null then

        return existing_draft;

    end if;


    select *
    into published_version

    from public.onboarding_questionnaire_versions

    where status = 'published'

    limit 1;


    if not found then

        raise exception
            'A published questionnaire is required before creating a draft.';

    end if;


    select
        coalesce(
            max(version_number),
            0
        ) + 1

    into next_version_number

    from public.onboarding_questionnaire_versions;


    insert into public.onboarding_questionnaire_versions (
        version_number,
        status,
        title,
        intro,
        created_by
    )
    values (
        next_version_number,
        'draft',
        published_version.title,
        published_version.intro,
        actor_id
    )

    returning id
    into new_version_id;


    insert into public.onboarding_questions (
        version_id,
        section_key,
        section_title,
        question_key,
        label,
        help_text,
        field_type,
        options,
        is_required,
        sort_order,
        is_active
    )

    select
        new_version_id,
        question.section_key,
        question.section_title,
        question.question_key,
        question.label,
        question.help_text,
        question.field_type,
        question.options,
        question.is_required,
        question.sort_order,
        question.is_active

    from public.onboarding_questions
        as question

    where question.version_id =
        published_version.id;


    insert into public.admin_audit_log (
        actor_user_id,
        action,
        details
    )
    values (
        actor_id,
        'questionnaire_draft_created',
        jsonb_build_object(
            'version_id',
            new_version_id,
            'version_number',
            next_version_number
        )
    );


    return new_version_id;

end;

$$;


-- =========================================================
-- ADMIN: SAVE QUESTION
-- =========================================================

create or replace function public.admin_save_onboarding_question(

    p_question_id uuid,

    p_section_key text,

    p_section_title text,

    p_question_key text,

    p_label text,

    p_help_text text,

    p_field_type text,

    p_options jsonb,

    p_required boolean,

    p_sort_order integer

)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$

declare

    actor_id uuid :=
        (select auth.uid());

    draft_id uuid;

    saved_id uuid;

    normalized_options jsonb :=
        coalesce(
            p_options,
            '[]'::jsonb
        );

begin

    if
        actor_id is null
        or not private.is_admin()
    then

        raise exception
            'Administrator access required.';

    end if;


    select id
    into draft_id

    from public.onboarding_questionnaire_versions

    where status = 'draft'

    limit 1;


    if draft_id is null then

        raise exception
            'Create a questionnaire draft first.';

    end if;


    if p_field_type not in (
        'short_text',
        'long_text',
        'yes_no',
        'single_choice',
        'multiple_choice',
        'number',
        'date',
        'scale'
    ) then

        raise exception
            'Unsupported question type.';

    end if;


    if
        trim(
            coalesce(
                p_question_key,
                ''
            )
        ) !~
        '^[a-z0-9_]+$'
    then

        raise exception
            'Question key may contain lowercase letters, numbers and underscores only.';

    end if;


    if
        length(
            trim(
                coalesce(
                    p_label,
                    ''
                )
            )
        ) = 0
    then

        raise exception
            'Question label is required.';

    end if;


    if p_sort_order <= 0 then

        raise exception
            'Sort order must be greater than zero.';

    end if;


    if jsonb_typeof(normalized_options) <>
        'array'
    then

        raise exception
            'Question options must be an array.';

    end if;


    if
        p_field_type = 'yes_no'
        and jsonb_array_length(
            normalized_options
        ) = 0
    then

        normalized_options :=
            '["Yes","No"]'::jsonb;

    end if;


    if
        p_field_type in (
            'single_choice',
            'multiple_choice'
        )
        and jsonb_array_length(
            normalized_options
        ) = 0
    then

        raise exception
            'Choice questions require at least one option.';

    end if;


    if p_question_id is null then

        insert into public.onboarding_questions (
            version_id,
            section_key,
            section_title,
            question_key,
            label,
            help_text,
            field_type,
            options,
            is_required,
            sort_order
        )
        values (
            draft_id,
            trim(p_section_key),
            trim(p_section_title),
            trim(p_question_key),
            trim(p_label),
            nullif(
                trim(
                    coalesce(
                        p_help_text,
                        ''
                    )
                ),
                ''
            ),
            p_field_type,
            normalized_options,
            p_required,
            p_sort_order
        )

        returning id
        into saved_id;

    else

        update public.onboarding_questions

        set
            section_key =
                trim(p_section_key),

            section_title =
                trim(p_section_title),

            question_key =
                trim(p_question_key),

            label =
                trim(p_label),

            help_text =
                nullif(
                    trim(
                        coalesce(
                            p_help_text,
                            ''
                        )
                    ),
                    ''
                ),

            field_type =
                p_field_type,

            options =
                normalized_options,

            is_required =
                p_required,

            sort_order =
                p_sort_order

        where id =
            p_question_id

          and version_id =
            draft_id

        returning id
        into saved_id;


        if saved_id is null then

            raise exception
                'Draft question not found.';

        end if;

    end if;


    return saved_id;

end;

$$;


-- =========================================================
-- ADMIN: DELETE DRAFT QUESTION
-- =========================================================

create or replace function public.admin_delete_onboarding_question(
    p_question_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$

declare

    actor_id uuid :=
        (select auth.uid());

    deleted_count integer;

begin

    if
        actor_id is null
        or not private.is_admin()
    then

        raise exception
            'Administrator access required.';

    end if;


    delete from public.onboarding_questions

    where id =
        p_question_id

      and version_id in (

          select id

          from public.onboarding_questionnaire_versions

          where status = 'draft'

      );


    get diagnostics
        deleted_count =
        row_count;


    if deleted_count = 0 then

        raise exception
            'Draft question not found.';

    end if;

end;

$$;


-- =========================================================
-- ADMIN: PUBLISH DRAFT
-- =========================================================

create or replace function public.admin_publish_questionnaire()
returns integer
language plpgsql
security definer
set search_path = ''
as $$

declare

    actor_id uuid :=
        (select auth.uid());

    draft_record
        public.onboarding_questionnaire_versions%rowtype;

begin

    if
        actor_id is null
        or not private.is_admin()
    then

        raise exception
            'Administrator access required.';

    end if;


    select *
    into draft_record

    from public.onboarding_questionnaire_versions

    where status = 'draft'

    limit 1

    for update;


    if not found then

        raise exception
            'No questionnaire draft exists.';

    end if;


    if not exists (

        select 1

        from public.onboarding_questions

        where version_id =
            draft_record.id

          and question_key =
            'first_name'

          and is_active = true

    )
    or
    not exists (

        select 1

        from public.onboarding_questions

        where version_id =
            draft_record.id

          and question_key =
            'surname'

          and is_active = true

    ) then

        raise exception
            'The questionnaire must retain first_name and surname questions.';

    end if;


    update public.onboarding_questionnaire_versions

    set status =
        'archived'

    where status =
        'published';


    update public.onboarding_questionnaire_versions

    set
        status =
            'published',

        published_by =
            actor_id,

        published_at =
            now()

    where id =
        draft_record.id;


    insert into public.admin_audit_log (
        actor_user_id,
        action,
        details
    )
    values (
        actor_id,
        'questionnaire_published',
        jsonb_build_object(
            'version_id',
            draft_record.id,
            'version_number',
            draft_record.version_number
        )
    );


    return draft_record.version_number;

end;

$$;


-- =========================================================
-- ADMIN: APPLICATION ANSWERS
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

    version_number integer;

    answers_json jsonb;

begin

    if
        actor_id is null
        or not private.is_admin()
    then

        raise exception
            'Administrator access required.';

    end if;


    select *
    into request_record

    from public.access_requests

    where id =
        p_request_id;


    if not found then

        raise exception
            'Application not found.';

    end if;


    select version_number
    into version_number

    from public.onboarding_questionnaire_versions

    where id =
        request_record.questionnaire_version_id;


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


    return jsonb_build_object(

        'request_id',
        request_record.id,

        'full_name',
        request_record.full_name,

        'email',
        request_record.email,

        'version_number',
        version_number,

        'answers',
        answers_json

    );

end;

$$;


-- =========================================================
-- FUNCTION PRIVILEGES
-- =========================================================

revoke execute
on function public.get_published_onboarding_questionnaire()
from public;

grant execute
on function public.get_published_onboarding_questionnaire()
to anon, authenticated;


revoke execute
on function public.submit_access_application(
    text,
    jsonb
)
from public;

grant execute
on function public.submit_access_application(
    text,
    jsonb
)
to anon, authenticated;


revoke execute
on function public.admin_create_questionnaire_draft()
from public, anon;

grant execute
on function public.admin_create_questionnaire_draft()
to authenticated;


revoke execute
on function public.admin_save_onboarding_question(
    uuid,
    text,
    text,
    text,
    text,
    text,
    text,
    jsonb,
    boolean,
    integer
)
from public, anon;

grant execute
on function public.admin_save_onboarding_question(
    uuid,
    text,
    text,
    text,
    text,
    text,
    text,
    jsonb,
    boolean,
    integer
)
to authenticated;


revoke execute
on function public.admin_delete_onboarding_question(uuid)
from public, anon;

grant execute
on function public.admin_delete_onboarding_question(uuid)
to authenticated;


revoke execute
on function public.admin_publish_questionnaire()
from public, anon;

grant execute
on function public.admin_publish_questionnaire()
to authenticated;


revoke execute
on function public.admin_get_application_answers(uuid)
from public, anon;

grant execute
on function public.admin_get_application_answers(uuid)
to authenticated;


commit;