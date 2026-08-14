begin;

-- =========================================================
-- THE UNLEASH TRIBE
-- ONBOARDING COPY / ENCODING CLEANUP
--
-- Repairs known mojibake-prone questionnaire copy and removes
-- implementation/helper text that should not appear in the
-- applicant-facing form.
--
-- This intentionally updates every questionnaire version
-- containing these stable question keys so archived application
-- reviews also display clean text.
-- =========================================================


-- ---------------------------------------------------------
-- CLEAN QUESTION LABELS
-- ---------------------------------------------------------

update public.onboarding_questions
set label =
    'What are your top 3–5 goals for 2026?'
where question_key =
    'goals_2026';


update public.onboarding_questions
set label =
    'On a scale of 1–10, how committed are you to personal growth?'
where question_key =
    'growth_commitment';


update public.onboarding_questions
set label =
    'Are you willing to attend daily 5:30–6:00 AM sessions?'
where question_key =
    'attend_daily_sessions';


-- ---------------------------------------------------------
-- CLEAN BIBLE-PLAN OPTIONS
-- ---------------------------------------------------------

update public.onboarding_questions
set options =
    '[
        "12-month plan — Genesis to Revelation, approximately 3–4 chapters daily",
        "9-month plan — Genesis to Revelation, approximately 4–5 chapters daily"
    ]'::jsonb
where question_key =
    'bible_reading_plan';


-- ---------------------------------------------------------
-- REMOVE UNNECESSARY APPLICANT-FACING HELP TEXT
--
-- The help_text feature remains in the architecture.
-- We are only removing the current unnecessary copy.
-- ---------------------------------------------------------

update public.onboarding_questions
set help_text = null
where question_key in (
    'date_of_birth',
    'goals_2026',
    'biggest_struggle',
    'attend_daily_sessions'
);


commit;