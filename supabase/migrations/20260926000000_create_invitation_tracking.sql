-- =====================================================
-- Invitation Tracking Lifecycle
-- The Unleash Tribe
--
-- Purpose:
-- Tracks invitation history while Supabase Auth
-- remains responsible for invitation tokens.
-- =====================================================


create table if not exists public.invitation_tracking (

    id uuid primary key default gen_random_uuid(),

    member_id uuid references public.profiles(id)
        on delete cascade,

    email text not null,

    status text not null default 'sent'
        check (
            status in (
                'sent',
                'accepted',
                'expired',
                'cancelled'
            )
        ),

    invited_by uuid references public.profiles(id)
        on delete set null,

    sent_at timestamptz not null default now(),

    accepted_at timestamptz,

    resend_count integer not null default 0,

    last_resend_at timestamptz,

    created_at timestamptz not null default now(),

    updated_at timestamptz not null default now()

);



-- =====================================================
-- Indexes
-- =====================================================

create index if not exists invitation_tracking_member_idx
on public.invitation_tracking(member_id);


create index if not exists invitation_tracking_email_idx
on public.invitation_tracking(email);


create index if not exists invitation_tracking_status_idx
on public.invitation_tracking(status);



-- =====================================================
-- Updated timestamp trigger
-- =====================================================

create or replace function public.update_invitation_tracking_timestamp()
returns trigger
language plpgsql
as $$

begin

    new.updated_at = now();

    return new;

end;

$$;



drop trigger if exists invitation_tracking_updated_at
on public.invitation_tracking;



create trigger invitation_tracking_updated_at

before update
on public.invitation_tracking

for each row

execute function public.update_invitation_tracking_timestamp();



-- =====================================================
-- Row Level Security
-- =====================================================

alter table public.invitation_tracking
enable row level security;



-- =====================================================
-- Admin read access
-- =====================================================

create policy "Admins can view invitation history"

on public.invitation_tracking

for select

using (

    exists (

        select 1

        from public.profiles

        where profiles.id = auth.uid()

        and profiles.role = 'admin'

    )

);



-- =====================================================
-- Block direct browser writes
-- Edge Functions will handle writes
-- =====================================================

create policy "Block client invitation inserts"

on public.invitation_tracking

for insert

with check (false);



create policy "Block client invitation updates"

on public.invitation_tracking

for update

using (false);