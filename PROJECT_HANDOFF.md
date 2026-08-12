# THE UNLEASH TRIBE — PROJECT HANDOFF

Last updated: 12 August 2026

Repository:
https://github.com/King-Mikeyz/the-unleash-tribe-checkin

Current development target:
V1.0

Status:
ACTIVE DEVELOPMENT — NOT PRODUCTION READY


# 1. DEVELOPMENT WORKING AGREEMENT

The assistant working on this repository must act as:

- Senior Full-Stack Software Engineer
- Senior Backend Engineer
- Senior QA Engineer
- Security-minded reviewer
- Senior Product Designer
- Senior UI/UX Designer
- Very critical reviewer

Do not simply agree with product ideas.

Question poor architectural, security or UX decisions and explain better alternatives.

The target is a reliable V1 product, not merely pages that render.


## User implementation workflow

The user is implementing the code locally.

Do NOT assume the user knows where commands belong.

Whenever giving a command, explicitly state whether it must be run in:

- VS Code PowerShell terminal
- Windows Command Prompt
- Supabase SQL Editor
- Supabase Dashboard
- Browser DevTools

### File editing rule

If an EXISTING HTML/CSS/JS/etc file must be replaced:

- provide the COMPLETE replacement file
- state the exact file path
- do not ask the user to hunt for individual lines

If a NEW file/folder must be created:

- give the exact VS Code PowerShell command to create it
- then provide its complete contents

Supabase migrations may continue using the migration + SQL Editor workflow.


# 2. PRODUCT PURPOSE

The Unleash Tribe Daily Check In is a Christian accountability platform intended to replace manual WhatsApp daily task check-ins.

Core objectives:

- membership application
- admin approval
- secure account creation
- daily accountability
- dynamic tasks
- task completion tracking
- streak tracking
- accountability reporting
- member administration
- historical records


# 3. ACCOUNTABILITY RULE

The fundamental task rule MUST NOT be changed.

Tasks use a parent → child model.

Example:

Fellowship with the Holy Spirit

- Worship
- Prayer
- Bible Reading
- Listen to a Sermon

A parent task cannot be manually marked complete.

A parent becomes complete ONLY when every REQUIRED child task under it is complete.

Example:

3 / 4 children complete
= parent NOT DONE

4 / 4 children complete
= parent DONE


# 4. DEFAULT SEVEN DAILY AREAS

1. Fellowship with the Holy Spirit
   - Worship
   - Prayer
   - Bible Reading
   - Listen to a Sermon

2. Scripture
   - Proverbs Chapter of the Day

3. Monthly Goal Progress
   - Work on monthly goal

4. Financial Living
   - Save
   - Avoid Debt
   - Earn
   - Give
   - Budget
   - Stay Within Budget

5. Health & Wellness
   - Exercise
   - Water
   - Rest
   - Avoid Carbonated Drinks

6. Personal Growth
   - Learn
   - Read
   - Listen
   - Improve

7. Holy Spirit Journaling
   - Write to the Holy Spirit


# 5. DYNAMIC TASK REQUIREMENT

Tasks MUST NOT be hard-coded into the application.

Admins must eventually be able to:

- create parent tasks
- create child tasks
- archive tasks
- mark tasks required/optional
- schedule start dates
- schedule end dates
- create temporary programs

Examples:

- 31 Days of Scriptural Declaration
- Seven Days of Fasting
- temporary community challenges

Historical task records must NEVER be destroyed when an admin removes a task.


# 6. ACCOUNTABILITY TIMEZONE AND WINDOW

Community timezone:

Africa/Lagos

Nigeria uses West Africa Time:

UTC/GMT +1

No daylight-saving change.

Daily accountability window:

Opens:
10:00 AM Africa/Lagos

Closes:
6:00 AM Africa/Lagos the NEXT day

Example:

12 August 10:00 AM
through
13 August 6:00 AM

belongs to accountability date:

12 August

Anything completed at 2:00 AM on 13 August belongs to the 12 August accountability day.


# 7. FEATURES CURRENTLY WORKING

The following have been implemented and tested to some degree:

## Landing

- index.html redesign
- purple/gold visual identity
- Member Login
- Request Access
- task preview
- seven growth areas
- responsive foundation

Leadership image is still missing.


## Supabase foundation

Database includes work around:

- profiles
- access_requests
- app_settings
- growth_areas
- checklist_items
- daily_checkins
- checkin_responses
- admin_audit_log
- profile status history
- onboarding questionnaire versions/questions/answers


## Authentication

Working for existing accounts:

- Supabase connection
- email/password authentication
- session persistence
- protected dashboard
- active-member checks
- admin checks
- logout


## Identity

Profiles currently support:

- full_name
- username
- email
- role
- status


## Daily dashboard

Working:

- dynamic seven parent areas
- child-task rendering
- parent completion logic
- overall /7 completion
- percentage
- initials avatar
- streak display foundation
- Africa/Lagos accountability window


## Admin Task Manager

Working:

- task listing
- parent creation
- child creation
- start/end dates
- required/optional support
- task archival
- timezone/window configuration


## Members

Working foundation:

- member listing
- active/admin/disabled statistics
- search
- promote member to admin
- demote admin
- disable member
- restore member

Last-active-admin protection must continue to be enforced.


## History

Working foundation:

- accountability history
- Done
- Incomplete
- Not Started
- percentages
- historical entries


## Admin reporting

Working foundation:

- Done members
- Incomplete members
- Not Started members
- expected-member count
- historical backfill


# 8. ONBOARDING QUESTIONNAIRE

The onboarding questionnaire has been implemented as a versioned dynamic system.

Current categories include:

1. Personal Information
2. Marital Status & Occupation
3. Spiritual Background
4. Purpose & Intention
5. Goals & Success
6. Community & Service
7. Personal Growth
8. Commitment
9. Bible Reading Plan

Admins must ultimately be able to edit the questionnaire.

Historical applicants must remain tied to the questionnaire version they answered.


# 9. CURRENT CRITICAL BUGS — FIX THESE BEFORE ADDING MORE FEATURES

NEXT SESSION MUST START HERE.


## BUG 1 — SQL ambiguous version_number

Admin application review currently produces:

column reference "version_number" is ambiguous

Location:

admin_get_application_answers RPC / questionnaire database logic.

Fix the PL/pgSQL variable/column collision by renaming the local variable and fully qualifying database columns.

Do not patch blindly.

Inspect the actual current migration/function first.


## BUG 2 — Character encoding / mojibake

The onboarding form displays text like:

3â€“5

instead of:

3–5

There may be other corrupted characters.

Audit:

- HTML
- JS
- SQL seeded questionnaire text
- UTF-8 file encodings
- database values

Correct all affected text.

Files must remain UTF-8.


## BUG 3 — Edge Function is not finished

File:

supabase/functions/invite-approved-member/index.ts

DO NOT DELETE THIS FILE.

It contains valuable unfinished account-invitation work.

VS Code currently reports TypeScript/Deno problems and the Supabase function deployment/configuration has not been completed successfully.

Next session:

- inspect the exact TypeScript diagnostics
- confirm correct Supabase Edge Function runtime/import syntax
- validate environment variables
- validate authorization
- deploy only after code review
- test invitation end-to-end


## BUG 4 — Supabase Dashboard URL Configuration error

Supabase Authentication → URL Configuration showed:

Failed to retrieve auth configuration

Error:
Lock broken by another request with the 'steal' option.

This appears to be a Supabase Dashboard/config retrieval problem.

The local redirect URL setup has NOT been considered verified.

Retry after system/browser restart and verify against current Supabase documentation if necessary.


## BUG 5 — Registration/account-setup UX is inconsistent

Current design:

Application:
email + questionnaire

Account setup:
username + password + confirm password

Login:
email + password

Product owner does NOT want this final experience.

Desired V1 experience:

ACCOUNT SETUP / REGISTRATION:

- Email
- Username
- Password
- Confirm Password

Because the invitation already identifies the email, email may be securely prefilled/read-only during invited account setup.

LOGIN:

- Username
- Password

The underlying Supabase identity may continue using email internally.

IMPORTANT:

Do NOT implement insecure client-side username → email lookup.

Design username login securely, probably using trusted server-side/Edge Function logic.


## BUG 6 — Username rules

Current username regex only allows:

letters
numbers
underscores

Product owner wants human-readable usernames such as:

King Michael

instead of requiring:

King_Michael

Before implementation, decide the correct architecture.

Recommended direction to investigate:

- allow human-readable display usernames with spaces
- normalize whitespace
- enforce case-insensitive uniqueness
- preserve a secure normalized lookup representation

Do not expose member email mappings publicly.


## BUG 7 — Dashboard greeting uses wrong identity field

Example applicant:

Full name:
Love King

Chosen username:
Lovely

Dashboard currently displays:

Welcome, Love.

This happens because dashboard greeting uses the first word of full_name.

Desired behavior:

The dashboard should use the member's chosen username/display identity according to the final identity model.

Do not truncate it to the first word unless that is explicitly the chosen product rule.


## BUG 8 — Admin wording is inconsistent

Some UI has been changed to:

Admin

but other hero/eyebrow sections still say:

Administration

Product owner wants consistent wording:

Admin

or where grammatically necessary:

Administrator

Perform a complete text audit later rather than fixing one occurrence at a time.


## BUG 9 — UI/UX quality is currently below target

The current application is functional but visually too heavy.

Problems observed:

- excessive bold typography
- oversized headings
- repetitive card styling
- weak visual hierarchy
- insufficient visual rhythm
- admin UI feels utilitarian
- onboarding form feels long and monotonous
- insufficient premium/community personality
- interactions are not yet polished enough

Do NOT merely change font sizes randomly.

Before the final V1 design pass, perform research into modern:

- accountability platforms
- habit tracking products
- check-in systems
- community dashboards
- onboarding/questionnaire systems
- admin dashboards

Analyze:

- navigation architecture
- information hierarchy
- daily check-in interaction
- progress visualization
- streak visualization
- mobile behavior
- long-form onboarding UX
- admin reporting UX
- empty states
- error states
- microinteractions

Then redesign The Unleash Tribe in its own brand rather than copying another product.


# 10. ACCOUNT / ADMIN MODEL

Both Michael/project owner and the community leader should be able to be admins.

Do NOT invent a superadmin role unless there is a genuine requirement.

The platform must always retain at least one active admin.

An admin must eventually be able to:

- approve applications
- reject applications
- manage tasks
- manage members
- promote admins
- demote admins
- disable accounts
- restore accounts
- view reports
- backfill historical accountability
- edit onboarding questions
- view audit history


# 11. V1 REMAINING FEATURES

After fixing the critical bugs:

## Membership / authentication

- finish approved-member invitation flow
- username-based login
- password setup
- email verification/invitation
- resend invitation
- forgot password
- reset password
- profile page
- consistent identity/display-name model


## Onboarding

- questionnaire editor QA
- publish/draft QA
- applicant response review
- rejection reason
- privacy/data-minimization review


## Admin

- improved navigation
- audit-log viewer
- members QA
- reporting QA
- task scheduling QA
- application management QA


## Member

- profile
- history refinements
- check-in refinements
- closed-window state
- empty states
- error states


## Landing

- add Emmanuela/leader photograph supplied by product owner
- verify content
- mobile polish


## Final V1 QA

Test:

- desktop
- tablet
- mobile
- authentication
- authorization
- RLS
- admin-only pages
- member-only actions
- username uniqueness
- account setup
- invitations
- password recovery
- session expiry
- 10 AM opening
- midnight crossover
- 6 AM closure
- parent completion
- daily completion
- streaks
- temporary tasks
- archived tasks
- history
- reporting
- disabled accounts
- last-admin protection
- malformed inputs
- network failures
- console errors
- accessibility basics
- keyboard navigation


# 12. V1.1 BACKLOG

Do not allow these to delay V1 unless priorities change:

- uploaded profile photos
- automated reminder engine
- email reminders
- web push notifications
- PWA
- calendar integration
- richer statistics
- advanced animation
- deeper visual refinement


# 13. NEXT SESSION START PROCEDURE

Do NOT immediately start writing code.

First:

1. Open repository.
2. Read this PROJECT_HANDOFF.md completely.
3. Read PRD.md.
4. Run git status.
5. Inspect git log.
6. Inspect all migrations added during the last session.
7. Inspect current HTML/CSS/JS files.
8. Verify what is actually in the hosted Supabase database.
9. Cross-check browser UI.
10. Review console errors.
11. Fix the current critical bugs before adding new features.

Priority order:

1. Fix ambiguous version_number SQL error.
2. Fix corrupted UTF-8 questionnaire characters.
3. Inspect/fix Edge Function TypeScript issues.
4. Verify Supabase auth redirect configuration.
5. Redesign account identity flow:
   registration/setup = email + username + password + confirm password
   login = username + password
6. Fix dashboard greeting identity.
7. Complete invitation/account setup flow.
8. Perform full navigation/wording audit.
9. Continue remaining V1 functionality.
10. Research competing/current check-in products.
11. Perform serious UI/UX redesign/refinement.
12. Run comprehensive QA/security review.
13. Update this handoff again before ending the next session.


# 14. IMPORTANT CURRENT FILE

DO NOT DELETE:

supabase/functions/invite-approved-member/index.ts

It is unfinished, not disposable.


# 15. GIT / DOCUMENTATION RULE

Before every major stopping point:

- Save all files.
- Review git status.
- Commit progress.
- Push to GitHub.
- Update PROJECT_HANDOFF.md.

The project must never again depend on temporary-chat history to understand its current state.