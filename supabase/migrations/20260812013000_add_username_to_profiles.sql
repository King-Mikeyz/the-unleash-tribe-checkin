begin;

alter table public.profiles
add column if not exists username text;

create unique index if not exists profiles_username_unique_idx
on public.profiles (lower(username))
where username is not null;

do $$
begin
    if not exists (
        select 1
        from pg_constraint
        where conname = 'profiles_username_format_check'
    ) then
        alter table public.profiles
        add constraint profiles_username_format_check
        check (
            username is null
            or username ~ '^[a-zA-Z0-9_]{3,30}$'
        );
    end if;
end
$$;

commit;
