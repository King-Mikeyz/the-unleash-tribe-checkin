# THE UNLEASH TRIBE — PROJECT HANDOFF

**Last updated:** 14 August 2026  
**Repository:** https://github.com/King-Mikeyz/the-unleash-tribe-checkin  
**Current development target:** V1.0  
**Status:** ACTIVE DEVELOPMENT — CORE ENGINE MUCH STRONGER, FINAL V1 NOT YET COMPLETE

---

# 0. READ THIS FIRST — NEXT SESSION MUST START HERE

This file is the source of truth for the next session.

The previous work was done inside a temporary ChatGPT conversation. Do **not** rely on chat history. Read this file completely, inspect the repository, and continue from the exact stopping point documented below.

## Exact stopping point

The last confirmed completed item was:

- disabled-account / restore flow was re-tested and confirmed working after fixing stale/shared-browser-session behavior.

The next work **must resume with this three-task engine batch**:

1. **Forgot password + reset password flow**
2. **Resend invitation capability**
3. **Profile / identity foundation**

Do not start with animation, landing-page redesign, admin visual polish, or general refactoring before this batch is complete.

The working style requested by the product owner is to handle **three related tasks in parallel per batch**, then test all three and fix any errors together.

---

# 1. REQUIRED ASSISTANT PERSONA / ROLE

The assistant working on this repository must act simultaneously as:

- Senior Full-Stack Software Engineer
- Senior Backend Engineer
- Supabase/PostgreSQL Engineer
- Senior QA Engineer
- Security-minded reviewer
- Senior Product Designer
- Senior UI/UX Designer
- Mobile-first product reviewer
- Critical technical reviewer
- Release / submission-minded engineer

Do not simply agree with every idea.

If a proposed design, architecture, animation, security model, workflow, or implementation would weaken the product, create unnecessary complexity, harm mobile performance, or delay V1, call it out and recommend a better option.

The target is a reliable product, not merely pages that render.

The assistant should always distinguish between:

- engine / backend correctness
- authentication and authorization
- data-model integrity
- security
- UI polish
- interaction design
- nice-to-have animation
- V1 blockers
- V1.1 backlog

---

# 2. NON-NEGOTIABLE USER IMPLEMENTATION WORKFLOW

The product owner does **not** want to edit individual lines of code manually.

## Existing-file rule

If an EXISTING file must change:

- give the exact file path
- provide the **entire replacement file**
- do not say “change line 47”
- do not give isolated snippets unless they are only diagnostic SQL or a terminal command
- do not ask the user to hunt for an existing code block

## New-file rule

If a NEW file or folder must be created:

1. provide the exact **VS Code PowerShell** command to create it
2. provide the full contents after creation

## Command-location rule

Every command must explicitly say where to run it:

- VS Code PowerShell terminal
- Supabase SQL Editor
- Supabase Dashboard
- Browser DevTools
- Windows Command Prompt, if ever required

Do not assume the product owner knows which environment a command belongs to.

## Three-task batch rule

The product owner requested that work continue in **three-task batches** where practical.

Preferred pattern:

- Task 1
- Task 2
- Task 3
- test all three
- collect errors
- fix together
- proceed to next three

---

# 3. PRODUCT PURPOSE

The Unleash Tribe Daily Check In is a Christian accountability/community platform intended to replace manual WhatsApp daily task check-ins.

Core goals include:

- membership application
- admin review and approval
- secure invited account creation
- username-based member login
- daily accountability
- dynamic parent/child tasks
- daily completion tracking
- progress tracking
- streaks
- history
- reporting
- member administration
- onboarding questionnaire
- secure admin operations
- historical records
- mobile-first usability

The system is not supposed to behave like a generic template or AI-generated dashboard.

The product owner wants it to feel:

- premium
- intentional
- warm
- modern
- Christian/community-oriented
- highly responsive
- polished on mobile
- visually refined without becoming gimmicky

---

# 4. FUNDAMENTAL ACCOUNTABILITY RULE — DO NOT CHANGE

Tasks follow a **parent → child** model.

Example:

## Fellowship with the Holy Spirit

- Worship
- Prayer
- Bible Reading
- Listen to a Sermon

A parent task cannot be manually checked off.

A parent becomes complete only when **every REQUIRED child task under that parent is complete**.

Example:

- 3 / 4 required children complete → parent = NOT DONE
- 4 / 4 required children complete → parent = DONE

This rule must remain enforced by the backend/database logic and not merely by frontend display state.

Historical task records must not be destroyed when tasks are archived.

---

# 5. DEFAULT SEVEN DAILY AREAS

1. **Fellowship with the Holy Spirit**
   - Worship
   - Prayer
   - Bible Reading
   - Listen to a Sermon

2. **Scripture**
   - Proverbs Chapter of the Day

3. **Monthly Goal Progress**
   - Work on monthly goal

4. **Financial Living**
   - Save
   - Avoid Debt
   - Earn
   - Give
   - Budget
   - Stay Within Budget

5. **Health & Wellness**
   - Exercise
   - Water
   - Rest
   - Avoid Carbonated Drinks

6. **Personal Growth**
   - Learn
   - Read
   - Listen
   - Improve

7. **Holy Spirit Journaling**
   - Write to the Holy Spirit

Tasks must remain database-driven/dynamic rather than hard-coded into UI files.

---

# 6. ACCOUNTABILITY TIMEZONE / WINDOW

Community timezone:

- `Africa/Lagos`
- UTC/GMT +1
- no daylight-saving change

Daily accountability window:

- opens: **10:00 AM Africa/Lagos**
- closes: **6:00 AM Africa/Lagos the next day**

Example:

- 12 Aug, 10:00 AM → 13 Aug, 6:00 AM
- belongs to accountability date: **12 Aug**

A completion at 2:00 AM on 13 Aug still belongs to 12 Aug.

This logic must be preserved and fully QA-tested before final V1.

---

# 7. LATEST SESSION SUMMARY — 14 AUGUST 2026

The previous handoff and PRD were reviewed first and used as the source of truth.

The assistant explicitly adopted the senior engineering / QA / security / product / UI role defined by the project.

The product owner added these workflow requirements:

- no single-line manual edits
- complete-file replacements
- exact PowerShell creation commands for new files
- critical review instead of automatic agreement
- engine correctness before visual excess
- three-task development batches

---

# 8. UI/UX RESEARCH AND LOCKED DESIGN DIRECTION

Research was performed around:

- Dribbble animated login designs
- CodePen login interactions
- CodeMyUI login collections
- CodingNepal sliding panels / glowing input work
- Awwwards CSS/JS/motion references
- supplied Instagram reel:
  - https://www.instagram.com/reel/Db7fSM1v8Yg/?igsh=MXR1OXZzaDVpZGExMg==

Key conclusion:

> Premium UI does not mean everything should move.

The chosen direction is:

- one recognizable signature motion idea
- restrained microinteractions
- strong typography/layout
- premium spacing
- clean mobile-first behavior
- good performance
- no unnecessary WebGL/canvas/3D overload

## Chosen concept A — “The Reveal”

Signature blade / curtain authentication transition.

Concept:

- visitor arrives at login
- purple/gold visual layer introduces/reveals the form
- successful login triggers a quick blade/wipe across viewport
- dashboard appears behind it
- target transition is short, roughly 500–700ms
- do not use theatrical page transitions everywhere

## Chosen concept B — “Welcome Home”

Split-screen editorial authentication layout.

Desktop:

- community/brand visual side
- authentication side

Mobile:

- not a shrunken desktop layout
- image may become a wide crop, compact portrait, or smaller visual
- form becomes primary
- mobile composition must be intentionally designed

## Chosen concept C — “Living Light”

Soft ambient background motion using:

- CSS gradients
- pseudo-elements
- transform / opacity
- restrained lavender/purple glow
- tiny gold highlights

Do not use a heavy canvas engine by default.

## Chosen concept D — “Journey”

Long onboarding should eventually feel guided, not like one giant database form.

Potential direction:

- section/stage progression
- progress indicator
- cleaner transitions
- better validation
- mobile-friendly controls
- possible autosave/state-resume later

## Chosen concept E — “Calm Progress”

Use microanimation to explain product state:

- child completion feedback
- parent transition when all required children complete
- progress response
- restrained streak motion

Do not make the product feel gamified or childish.

## Optional concept F — “The Companion”

Possible future elegant brand character.

Must remain subtle and brand-appropriate.

Avoid a childish cartoon/yeti feel.

## Explicit rejection — “Awwwards everywhere”

Do not combine:

- WebGL
- particles
- canvas
- 3D objects
- parallax
- mascot
- glowing everything
- elaborate navigation transitions

all at once.

That would damage usability, performance, and delivery speed.

---

# 9. BRAND / VISUAL DIRECTION

Keep the purple/gold identity.

Recommended balance:

- ~75% white / warm neutral
- ~20% purple / lavender
- ~5% gold

Gold should feel special rather than being used everywhere.

Supporting colors may include:

- pale lavender
- warm ivory
- ink / dark plum
- subtle gray-violet

---

# 10. MOBILE-FIRST RULE

Do not think:

> desktop → shrink → mobile

Think:

> same product → intentionally different composition per available space

Examples:

- desktop hero may use a square/near-square image
- mobile may use a wide crop or smaller portrait
- image aspect ratio may change by breakpoint
- use `object-fit`, `object-position`, responsive sizing, or separate sources when useful
- buttons and fields must remain touch-friendly
- navigation must feel like an intentional mobile interface

Mobile is expected to be a primary access mode for community members.

---

# 11. REQUEST ACCESS / ONBOARDING FIXES COMPLETED

The product owner supplied screenshots showing:

- malformed text such as `3â€“5`
- malformed ranges such as `1â€“10`
- bad native select-arrow placement
- unnecessary helper paragraphs
- unnecessary pre-submit email invitation explanation
- long / template-like form rhythm

The design decision:

- keep the architecture for optional `help_text`
- remove only unnecessary current help text
- preserve the feature for genuinely useful guidance

## Migration

### `supabase/migrations/20260813171500_fix_onboarding_copy.sql`

Created/prepared to:

- correct `3–5`
- correct `1–10`
- correct `5:30–6:00`
- correct Bible-plan range text
- remove unnecessary help text for selected question keys

## `request-access.html`

Replaced with cleaner markup.

Changes included:

- removed hard-coded invitation explanation under email
- simplified privacy copy
- preserved JS-required IDs
- cleaner hierarchy

## `css/onboarding.css`

Replaced.

Changes included:

- custom select chevron
- better select padding
- improved focus states
- tighter section spacing
- compact scale controls
- 5×2 scale on mobile
- improved responsive behavior
- reduced-motion support
- more deliberate border/shadow treatment

The product owner said this pass was acceptable and moved on.

---

# 12. AMBIGUOUS `version_number` SQL BUG

Original critical bug:

`admin_get_application_answers()` produced:

> column reference "version_number" is ambiguous

Cause:

A local PL/pgSQL variable named `version_number` collided with a table column named `version_number`.

A corrective migration was prepared:

### `supabase/migrations/20260813170000_fix_admin_application_answers.sql`

Approach:

- rename local variable to `questionnaire_version_number`
- fully qualify table columns
- preserve the RPC response shape

**NEXT SESSION VERIFICATION REQUIRED:**  
Inspect git history, migration state, hosted function definition, and browser application review to confirm this is fully applied in the final current checkout and hosted Supabase database.

Do not treat “drafted” as the same thing as “verified in hosted state.”

---

# 13. INVITATION EDGE FUNCTION / AUTH REDIRECT — WORKING

Existing function preserved:

### `supabase/functions/invite-approved-member/index.ts`

It was explicitly **not deleted**.

Architecture reviewed:

- Deno Edge Function
- Supabase JS
- authenticated caller validation
- active-admin validation
- server-side service-role client
- Supabase Auth invitation
- redirect to `setup-account.html`

The Supabase CLI was used to:

- log in
- link project
- set `APP_SITE_URL`
- deploy function

The product owner confirmed the invitation flow worked.

Local redirect testing was configured around:

- `http://127.0.0.1:5500`
- `setup-account.html`

Final production redirect configuration still needs production QA before release.

---

# 14. DENO / VS CODE TOOLING FIXES

VS Code initially showed TypeScript/Deno errors around Edge Functions.

Files/configuration were added/fixed:

## `.vscode/settings.json`

Deno enabled only for:

- `./supabase/functions`

Important correction:

Do **not** set:

```json
"deno.importMap": "./supabase/functions/deno.json"
```

for a real Deno config.

That caused VS Code to interpret the file as a pure import map and reject top-level keys.

Use:

```json
"deno.config": "./supabase/functions/deno.json"
```

## `supabase/functions/deno.json`

Configured for Deno/npm dependency handling.

The product owner ultimately succeeded in checking/deploying the new function.

---

# 15. USERNAME IDENTITY MODEL IMPLEMENTED

Migration:

### `supabase/migrations/20260813180000_username_identity_model.sql`

Goals:

- human-readable usernames
- spaces allowed
- normalized whitespace
- case-insensitive uniqueness
- normalized lookup representation
- no public username→email mapping

Example:

Display:

- `King Michael`

Normalized lookup:

- `king michael`

Expected username rule:

- 3–30 characters
- letters
- numbers
- spaces
- hyphens
- underscores
- starts/ends with a letter or number

---

# 16. SECURE USERNAME LOGIN EDGE FUNCTION — DEPLOYED

Created:

### `supabase/functions/username-login/index.ts`

The product owner confirmed it was deployed.

Security architecture:

1. browser sends username + password
2. Edge Function normalizes username
3. trusted server-side service-role client resolves profile/Auth user
4. email remains server-side
5. Supabase Auth verifies password
6. function returns session tokens
7. browser calls `auth.setSession()`

The browser must never receive a general username→email lookup capability.

Inactive accounts are rejected.

---

# 17. ACCOUNT SETUP UPDATED — WORKING

Files replaced:

## `setup-account.html`

New flow:

- invited email shown read-only
- username
- password
- confirm password
- complete account setup

## `js/pages/setup-account.js`

Behavior:

- detects invite session
- validates username
- validates password
- validates password confirmation
- updates profile username
- sets permanent Auth password
- stores username in Auth metadata as a convenience copy
- signs out invitation session locally
- redirects to login

The product owner confirmed the setup flow worked.

---

# 18. LOGIN UPDATED TO USERNAME + PASSWORD — WORKING

Files replaced:

## `login.html`

Now asks for:

- Username
- Password

## `js/auth/auth.js`

Behavior:

- invokes `username-login`
- receives access/refresh token
- calls Supabase `auth.setSession()`
- loads profile
- requires active status
- redirects to dashboard
- uses generic invalid credential messaging
- does not reveal username existence
- supports reason messages for setup/session/inactive/logout

The product owner tested:

- correct username/password
- wrong password
- fresh approved account
- username with spaces

and reported all working.

---

# 19. DASHBOARD IDENTITY FIX IMPLEMENTED

Problem:

- full name: `Love King`
- username: `Lovely`
- old dashboard showed `Welcome, Love.`

`js/pages/dashboard.js` was replaced so display identity now prefers:

1. `profile.username`
2. `profile.full_name`
3. `Member`

Avatar initials derive from the same display identity.

**Next session:** perform one quick browser verification after restart to confirm latest checkout displays the full chosen username.

---

# 20. SHARED CHROME SESSION / STALE ADMIN PAGE BUG — UNDERSTOOD AND FIXED

During disable/restore QA:

- Michael admin and Emmanuel member were opened in multiple normal Chrome windows under the same Chrome profile
- Supabase `persistSession: true` meant both windows shared one browser-storage session
- logging into Emmanuel replaced the stored identity used by the origin
- the already-open Michael admin page could remain visually stale
- disabling Emmanuel then disabled the currently shared session
- Restore appeared broken because the browser was no longer truly authenticated as Michael

This was not primarily a Restore-RPC bug.

## Correct simultaneous-account QA

Use isolated browser storage:

- Chrome normal = Michael admin
- Chrome Incognito = Emmanuel member

or:

- Chrome = Michael
- Edge = Emmanuel

or separate Chrome profiles.

Do not use two normal windows in the same Chrome profile and expect isolated Supabase sessions.

---

# 21. SESSION GUARD HARDENING — CONFIRMED

File replaced:

### `js/auth/guards.js`

New behavior:

- uses server-confirmed `auth.getUser()` for protected identity
- loads profile
- rejects inactive users
- uses local sign-out when appropriate
- installs `onAuthStateChange()` protection
- rechecks stored identity when window regains focus
- reloads/revalidates if another tab changes the account underneath the page
- prevents stale admin UI from remaining trusted after account switching

The product owner re-tested with proper browser isolation and confirmed:

> disable restore fixed

This is the latest confirmed completed milestone.

---

# 22. DISABLE / RESTORE SECURITY EXPECTATION

Must remain true:

- active admin can disable member
- disabled member cannot continue protected operations
- disabled member is rejected on refresh/login
- admin can restore member
- restored member can sign in again
- last active admin remains protected
- backend authorization remains authoritative

Hiding buttons alone is never enough.

---

# 23. PARENT / CHILD ENGINE STATUS

Existing task engine already supports:

- dynamic parents
- dynamic children
- required/optional children
- parent completion from child state
- overall completion
- percentage
- persistence
- Africa/Lagos accountability window
- admin task-manager foundation

Include a final regression test before V1 release:

- 3/4 required children → Not Done
- 4/4 → Done
- refresh preserves state
- unchecking a required child reverts parent to Not Done
- overall completed-parent count updates correctly

---

# 24. UI ISSUES LOGGED FOR FINAL POLISH

These were explicitly requested by the product owner and must not be forgotten.

## Members alignment

Current role/status/action controls do not align cleanly between rows.

Need:

- real grid/column alignment
- aligned Active chips
- aligned role chips
- aligned action buttons
- professional table/card rhythm

## Persistent admin shell

Current admin pages visually change their header/navigation from page to page.

Need:

- one consistent admin shell
- stable navigation
- consistent page hierarchy
- clear sense that all pages belong to the same admin dashboard

## “Admin Control” wording

“Admin Control” feels vague/cheap.

Likely replacement:

- `Admin Dashboard`

or another deliberately chosen label during navigation redesign.

## Admin vs Administration

Preferred rule:

- **Admin** for product/navigation labels
- **Administrator** only where grammar requires it
- perform one complete copy audit

## Request Access form

Already improved, but final UI QA should revisit:

- spacing
- mobile form rhythm
- select controls
- option alignment
- long-form fatigue
- post-submit state
- premium consistency

---

# 25. EXACT NEXT SESSION — THREE TASKS

## START HERE

### TASK 1 — FORGOT PASSWORD + RESET PASSWORD

Inspect current:

- `forgot-password.html`
- any reset-password implementation
- auth JS
- Supabase redirect settings
- current username-login architecture

Important product/security point:

Login is username-based, but password-recovery delivery uses the member's account email.

Need a safe recovery UX.

Requirements:

- neutral response to avoid account enumeration
- recovery email
- correct redirect
- reset-password page/session detection
- new password
- confirm password
- expired-link handling
- successful reset → return to username login
- mobile QA
- production redirect QA

Do **not** build an insecure username→email recovery lookup in the browser.

### TASK 2 — RESEND INVITATION

Admins need a safe resend capability for an approved applicant/member whose setup is incomplete.

Inspect:

- `invite-approved-member`
- access request state
- Auth-user state
- Admin Applications UI

Requirements:

- admin-only
- avoid accidental duplicate profile creation
- handle existing Auth user safely
- clear state/error messages
- ideally audit action
- only resend when it makes sense
- test expired/unused invite cases

### TASK 3 — PROFILE / IDENTITY FOUNDATION

Build a proper V1 profile foundation.

Likely data:

- username
- full name
- email
- role
- status
- joined date

Need to decide:

- what member can edit
- what admin controls
- whether username changes are allowed
- safe column/RLS permissions
- source of truth for display identity
- profile page structure

Do not overbuild uploaded profile photos in V1 unless priority changes. Uploaded photos are a V1.1 item.

---

# 26. REMAINING V1 ENGINE ORDER AFTER NEXT BATCH

## Batch 2

1. onboarding questionnaire editor QA
2. application-review / rejection-reason QA
3. privacy/data-minimization review

## Batch 3

1. members/admin-role QA
2. audit-log viewer
3. reporting/task-scheduling QA

## Batch 4

1. member history refinements
2. check-in closed-window / empty / error states
3. streak / reporting verification

Then do navigation/UI/mobile polish and final QA.

---

# 27. V1 FEATURE STATUS

## Membership / Authentication

- [x] approved-member invitation foundation
- [x] invitation Edge Function deployed/tested
- [x] invited account setup
- [x] email read-only during setup
- [x] human-readable username model
- [x] username login
- [x] secure server-side username resolution
- [x] password setup / confirmation
- [x] inactive-account rejection
- [x] stale/shared-session hardening
- [ ] forgot password
- [ ] reset password
- [ ] resend invitation
- [ ] profile page
- [ ] final identity/display QA
- [ ] session-expiry QA
- [ ] production redirect QA
- [ ] recovery-flow security QA

## Onboarding

- [x] dynamic questionnaire foundation
- [x] request-access visual cleanup
- [x] custom select treatment
- [x] unnecessary helper copy cleanup
- [x] mojibake correction work
- [ ] verify hosted data after restart
- [ ] questionnaire editor QA
- [ ] publish/draft QA
- [ ] applicant response review QA
- [ ] rejection reason
- [ ] privacy/data-minimization review
- [ ] guided premium long-form redesign

## Admin

- [x] applications foundation
- [x] members foundation
- [x] disable/restore foundation
- [x] promote/demote foundation
- [x] task manager foundation
- [x] reporting foundation
- [ ] persistent admin shell
- [ ] replace vague “Admin Control”
- [ ] Admin/Administration copy audit
- [ ] member-row alignment polish
- [ ] audit-log viewer
- [ ] applications QA
- [ ] members QA
- [ ] reporting QA
- [ ] task scheduling QA
- [ ] last-active-admin regression QA

## Member

- [x] dashboard foundation
- [x] dynamic tasks
- [x] progress
- [x] username-display logic implemented
- [ ] quick post-restart username display verification
- [ ] profile
- [ ] history refinements
- [ ] closed-window refinement
- [ ] empty/error states
- [ ] final streak QA

## Landing

- [x] purple/gold brand foundation
- [x] member login
- [x] request access
- [x] responsive base
- [ ] leader / Emmanuela photo when supplied/approved
- [ ] content audit
- [ ] premium responsive composition
- [ ] mobile polish

---

# 28. FINAL V1 UI PASS

After technical engines are stable, perform the serious UI/UX pass.

Priority:

1. consistent admin shell
2. member dashboard hierarchy
3. auth/login/setup polish
4. request-access guided experience
5. mobile composition
6. table/member alignment
7. error/loading/empty states
8. accessibility
9. microinteractions
10. optional lightweight signature transition only if low-risk

The visual direction is already locked. Do not restart the design strategy from zero.

---

# 29. V1 VS V1.1 ANIMATION BOUNDARY

## Safe for V1 if low-risk

- hover/focus refinement
- loading/press feedback
- child-task completion feedback
- progress animation
- soft CSS ambient background
- restrained auth entrance
- reduced-motion support
- possibly a lightweight blade/reveal transition if schedule and stability allow

## Expanded V1.1 motion

- full blade/curtain auth choreography
- richer login-to-dashboard transitions
- optional elegant companion character
- more elaborate onboarding motion
- deeper dashboard microinteractions
- expanded transition system
- richer illustration/image choreography
- advanced CSS/JS animation system
- canvas/WebGL experimentation only if justified

Animation must never become a dependency for basic use.

---

# 30. V1.1 BACKLOG

Do not allow these to delay V1 unless priorities explicitly change:

- uploaded profile photos
- automated reminder engine
- email reminders
- web push notifications
- PWA
- offline-friendly improvements where appropriate
- calendar integration
- richer statistics
- richer streak visualization
- deeper historical analytics
- advanced animation
- full blade/curtain auth choreography
- optional elegant brand companion
- richer illustration system
- deeper visual refinement
- canvas/WebGL experiments only if performance allows
- notification preferences
- richer user settings
- production email customization
- advanced audit-history UX
- advanced admin-report filters
- onboarding autosave / step-resume if not completed in V1
- extended accessibility refinement
- broader automated tests
- low-end Android performance profiling

---

# 31. FINAL V1 QA CHECKLIST

## Authentication

- username login
- wrong username
- wrong password
- generic non-enumerating errors
- invited setup
- invite expiry
- resend invite
- forgot password
- reset password
- inactive account
- restored account
- logout
- refresh persistence
- session expiry
- cross-tab identity change
- separate-browser testing
- production redirect URLs

## Authorization / Security

- non-admin blocked from admin actions
- admin RPCs enforce admin server-side
- service-role key never exposed
- username→email mapping never publicly exposed
- inactive member blocked server-side
- last active admin protected
- RLS reviewed
- malformed inputs
- duplicate usernames
- case-insensitive uniqueness
- whitespace normalization
- duplicate/expired invitations
- expired recovery links

## Daily Check In

- 10 AM opening
- midnight crossover
- 6 AM closure
- parent completion
- optional children
- required children
- refresh persistence
- overall /7
- percentage
- streaks
- archived tasks
- temporary tasks
- history integrity

## Admin

- application review
- approval
- rejection
- resend invitation
- members search
- disable/restore
- promote/demote
- last-admin protection
- task creation
- scheduling
- archival
- reporting
- backfill
- audit history
- consistent navigation

## Responsive / UI

- desktop
- tablet
- Android widths
- iPhone widths
- no horizontal overflow
- intentional image crops
- usable mobile keyboard forms
- focus states
- keyboard navigation
- error states
- loading states
- empty states
- reduced motion
- readable contrast

## Developer QA

- no console errors
- no failing network calls
- no secrets in frontend
- no migration conflicts
- Edge Functions deployed
- production URLs configured
- clean git status
- current database state verified
- handoff updated

---

# 32. NEXT-SESSION STARTUP PROCEDURE

Do **not** immediately write code.

First:

1. open repository
2. read this `PROJECT_HANDOFF.md` completely
3. read `PRD.md`
4. run `git status`
5. run `git log --oneline -10`
6. inspect migrations added during 14 Aug session
7. inspect:
   - `supabase/functions/invite-approved-member/index.ts`
   - `supabase/functions/username-login/index.ts`
   - `supabase/functions/deno.json`
   - `.vscode/settings.json`
   - `login.html`
   - `setup-account.html`
   - `request-access.html`
   - `js/auth/auth.js`
   - `js/auth/guards.js`
   - `js/pages/setup-account.js`
   - `js/pages/dashboard.js`
   - `css/onboarding.css`
8. confirm which migrations are actually committed
9. confirm hosted Supabase migration/function state
10. check browser console
11. verify username login after restart
12. verify dashboard chosen username
13. verify invitation/redirect configuration
14. start the exact three-task batch:
   - forgot/reset password
   - resend invitation
   - profile/identity foundation

---

# 33. IMPORTANT FILES — DO NOT DELETE

- `PROJECT_HANDOFF.md`
- `PRD.md`
- `supabase/functions/invite-approved-member/index.ts`
- `supabase/functions/username-login/index.ts`
- `supabase/functions/deno.json`
- `.vscode/settings.json`
- current migrations
- task-engine migrations
- identity migrations

Especially preserve both Edge Functions unless a reviewed replacement is intentionally deployed.

---

# 34. GIT / STOPPING RULE

Before any major pause:

1. save all files
2. run `git status`
3. inspect unexpected/untracked files
4. commit intended progress
5. push to GitHub
6. update this handoff

The project must not depend on temporary-chat history to understand its state.

---

# 35. RECOMMENDED COMMIT MESSAGE

Suggested commit message:

`Stabilize V1 auth engine and update project handoff`

Suggested VS Code PowerShell sequence:

```powershell
git status
git add -A
git commit -m "Stabilize V1 auth engine and update project handoff"
git push
```

If `git status` shows secrets, unexpected generated files, or local-only credentials, inspect them before `git add -A`.

---

# 36. FINAL CONTINUATION NOTE

Do **not** re-plan this project from zero next session.

Resume with:

> Forgot/reset password → Resend invitation → Profile/identity foundation.

Then finish the remaining V1 engine and QA items.

Only after the engine is stable should the major premium UI/navigation redesign and animation work resume.

Preserve the locked visual direction:

- purple/gold brand
- mobile-first composition
- premium whitespace
- custom controls
- consistent admin shell
- signature reveal animation
- restrained microinteractions
- soft “Living Light”
- guided “Journey” onboarding
- “Calm Progress” dashboard feedback
- optional companion later
- no excessive Awwwards/WebGL-style effects

The assistant should continue as a senior engineer/designer who is willing to reject unnecessary complexity.
