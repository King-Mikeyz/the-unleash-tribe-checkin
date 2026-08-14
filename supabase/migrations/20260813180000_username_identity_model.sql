begin;

-- =========================================================
-- THE UNLEASH TRIBE
-- USERNAME IDENTITY MODEL
--
-- Goals:
-- 1. Allow human-readable usernames such as "King Michael".
-- 2. Normalize repeated whitespace.
-- 3. Enforce case-insensitive uniqueness.
-- 4. Keep a trusted normalized lookup representation.
-- 5. Allow members to set their own username during
--    invited account setup without exposing email mappings.
-- =========================================================


-- ---------------------------------------------------------
-- REMOVE OLD USERNAME RULES
-- ---------------------------------------------------------

drop index if exists
    public.profiles_username_unique_idx;

alter table public.profiles
drop constraint if exists
    profiles_username_format_check;


-- ---------------------------------------------------------
-- NORMALIZED LOOKUP COLUMN
--
-- This column is not the display value.
--
-- Example:
--
-- username:
--     King Michael
--
-- username_normalized:
--     king michael
-- ---------------------------------------------------------

alter table public.profiles
add column if not exists
    username_normalized text;


-- ---------------------------------------------------------
-- NORMALIZE EXISTING USERNAMES
-- ---------------------------------------------------------

update public.profiles
set
    username =
        regexp_replace(
            btrim(username),
            '[[:space:]]+',
            ' ',
            'g'
        ),

    username_normalized =
        lower(
            regexp_replace(
                btrim(username),
                '[[:space:]]+',
                ' ',
                'g'
            )
        )
where username is not null;


-- ---------------------------------------------------------
-- AUTOMATIC NORMALIZATION
-- ---------------------------------------------------------

create or replace function private.sync_profile_username()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin

    if new.username is null then

        new.username_normalized :=
            null;

        return new;

    end if;


    new.username :=
        regexp_replace(
            btrim(new.username),
            '[[:space:]]+',
            ' ',
            'g'
        );


    new.username_normalized :=
        lower(
            new.username
        );


    return new;

end;
$$;


drop trigger if exists
    profiles_sync_username_before_write
on public.profiles;


create trigger
    profiles_sync_username_before_write

before insert
or update of username

on public.profiles

for each row

execute function
    private.sync_profile_username();


-- ---------------------------------------------------------
-- HUMAN-READABLE USERNAME RULES
--
-- Allowed:
--
-- King Michael
-- Lovely
-- Michael_01
-- King-Michael
--
-- Requirements:
--
-- 3–30 characters
-- starts/ends with letter or number
-- spaces, underscores and hyphens allowed internally
-- ---------------------------------------------------------

alter table public.profiles
add constraint profiles_username_format_check
check (
    username is null
    or
    (
        char_length(username)
            between 3 and 30

        and username ~
            '^[A-Za-z0-9][A-Za-z0-9 _-]*[A-Za-z0-9]$'
    )
);


-- ---------------------------------------------------------
-- CASE-INSENSITIVE + WHITESPACE-NORMALIZED UNIQUENESS
-- ---------------------------------------------------------

create unique index
    profiles_username_normalized_unique_idx

on public.profiles (
    username_normalized
)

where username_normalized
    is not null;


-- ---------------------------------------------------------
-- MEMBER ACCOUNT-SETUP PERMISSION
--
-- Existing RLS already restricts a normal member to their
-- own profile.
--
-- Only the username column is granted here.
-- Role/status are NOT exposed for member mutation.
-- ---------------------------------------------------------

grant update (username)
on table public.profiles
to authenticated;


revoke update (username_normalized)
on table public.profiles
from authenticated;


commit;