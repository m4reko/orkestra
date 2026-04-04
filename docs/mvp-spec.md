# Uppsala Blåsarsymfoniker — Internal System MVP Spec

## Overview

An internal member management and project planning system for Uppsala Blåsarsymfoniker. The system tracks member contact information, organizes concert projects with rehearsals, and lets section leaders manage their sections.

## Roles

| Role | Auth method | Description |
|------|-------------|-------------|
| **Admin** | Google SSO | Full system access. Manages section leader assignments, creates projects, adds links, manages all members. |
| **Section leader** | Google SSO | Manages their own section(s): assigns members to projects, tracks rehearsal absences. Can view substitute/old member contact info. A person can be section leader for multiple sections. Multiple people can share section leader responsibility for one section. |
| **Member** | Magic link (email, project-scoped) | Can view and edit their own contact info, see their project assignments, and report rehearsal absences. No account creation required. |

### Member access model

Members do not have accounts. When a project starts, each assigned member receives an email with a unique link. The link is valid until the project ends but grants access to all of the member's projects (not just the triggering one). A browser cookie preserves the session so members don't need to find the link each time.

**Accepted trade-off:** Anyone with a member's link can view/edit that member's info and see their assignments for the duration of the link's validity. This is considered acceptable for an internal orchestra tool.

---

## Sections (hardcoded)

| Section | Instruments |
|---------|-------------|
| Flöjt | Tvärflöjt, Piccolaflöjt |
| Oboe | Oboe, Engelskt horn |
| Fagott | Fagott |
| Klarinett | Klarinett, Essklarinett, Altklarinett, Basklarinett, Kontrabasklarinett |
| Saxofon | Sopransaxofon, Altsaxofon, Tenorsaxofon, Barytonsaxofon |
| Valthorn | Valthorn |
| Trumpet | Kornett, Trumpet |
| Trombon | Trombon, Bastrombon |
| Euphonium | Euphonium |
| Tuba | Tuba |
| Slagverk | Slagverk |
| Kontrabas/Harpa/Piano | Kontrabas, Harpa, Piano |
| Dirigent | Dirigering |

Each instrument belongs to exactly one section.

---

## Data Model (conceptual)

### Person

| Field | Notes |
|-------|-------|
| Förnamn | |
| Efternamn | |
| E-post | |
| Telefonnummer | |
| Gatuadress | |
| Postnummer | |
| Postort | |
| Instruments | All instruments this person can play (multi-select) |
| Section | The single section this person belongs to organizationally |
| Metadata | Free-text, e.g. where contact info originated |

A person exists in the system regardless of membership status. The same record is used for current members, former members, and substitutes.

### Membership log

A log of membership periods per person:

| Field | Notes |
|-------|-------|
| Person | |
| Start date | When they became a member |
| End date | Null if currently active |

A person can have multiple membership periods (left and re-joined). Replaces the old "Aktiva år" column. A person with an active membership period (no end date) is considered a current member.

### Project

| Field | Notes |
|-------|-------|
| Name | |
| Concert date | |
| Rehearsal dates | List of dates |
| Sheet music links | List of {label, URL}, admin-managed |
| Status | Derived from dates: **planned** (today < first rehearsal date), **active** (today ≥ first rehearsal date and ≤ concert date), **completed** (today > concert date) |

### Project assignment

| Field | Notes |
|-------|-------|
| Project | |
| Person | |
| Instrument | The instrument they play for this project (independent of their usual instruments) |
| Part | Optional (e.g. "1", "2"). Can be set later or left blank. |

### Rehearsal absence

| Field | Notes |
|-------|-------|
| Project | |
| Person | |
| Rehearsal date | Must be one of the project's rehearsal dates |
| Reported by | The person who reported it (member themselves or a section leader) |

---

## User Stories

### US-1: Member management

#### US-1.1: Add a person

> As an **admin**, I want to add a new person to the system so that their contact information is stored.

**Acceptance criteria:**
- Admin can enter all person fields (name, email, phone, address, instruments, section, metadata)
- Instruments is a multi-select from the hardcoded instrument list
- Section is a single-select from the hardcoded section list
- The person is created without any membership period by default

#### US-1.2: Edit a person's contact info (admin/section leader)

> As an **admin or section leader**, I want to edit a person's contact information.

**Acceptance criteria:**
- Admins can edit any person
- Section leaders can edit people in their section(s)
- All person fields are editable

#### US-1.3: Edit own contact info (member)

> As a **member**, I want to update my own contact information so it stays current.

**Acceptance criteria:**
- Member can edit: email, phone, address
- Member cannot change: instruments, section (these are managed by leaders/admins)
- Changes take effect immediately

#### US-1.4: Manage membership periods

> As an **admin**, I want to record when a person becomes or stops being a member.

**Acceptance criteria:**
- Admin can add a membership start date for a person
- Admin can set an end date on an active membership period
- A person can have multiple non-overlapping membership periods
- The system derives "current member" status from having an active period (no end date)

#### US-1.5: Browse members

> As an **admin or section leader**, I want to browse and search people in the system.

**Acceptance criteria:**
- List view of all people with key info (name, instrument, section, membership status)
- Filter by: current member / former member / non-member (substitute)
- Filter by section
- Search by name
- Section leaders can see contact details for people in their section(s) and all substitutes/former members
- Admins can see everything
- Regular members cannot browse other members

---

### US-2: Section leader management

#### US-2.1: Assign section leader role

> As an **admin**, I want to assign the section leader role to a member for a specific section.

**Acceptance criteria:**
- Admin selects a person and assigns them as section leader for one or more sections
- A section can have multiple section leaders
- A person can be section leader for a section they don't play in
- Section leaders must have a Google SSO account

#### US-2.2: Remove section leader role

> As an **admin**, I want to remove a section leader assignment.

**Acceptance criteria:**
- Admin can remove a person's section leader role for a specific section
- The person retains their member record

---

### US-3: Project management

#### US-3.1: Create a project

> As an **admin**, I want to create a new project so the orchestra can plan a concert.

**Acceptance criteria:**
- Admin provides: name, concert date, rehearsal dates
- Project is created with no assignments
- Project appears in the project list

#### US-3.2: Edit project details

> As an **admin**, I want to edit a project's details.

**Acceptance criteria:**
- Admin can change name, concert date, add/remove rehearsal dates
- Removing a rehearsal date that has absence records shows a warning

#### US-3.3: Manage sheet music links

> As an **admin**, I want to add links to sheet music on a project's page.

**Acceptance criteria:**
- Admin can add, edit, and remove links (label + URL)
- Links are displayed on the project page visible to all assigned members

#### US-3.4: View project list

> As any **authenticated user**, I want to see a list of projects.

**Acceptance criteria:**
- Admins and section leaders see all projects
- Members see only projects they are assigned to
- List shows: project name, concert date, status

---

### US-4: Project assignments

#### US-4.1: Assign a person to a project

> As a **section leader**, I want to assign people from my section to a project with a specific instrument.

**Acceptance criteria:**
- Section leader selects a person and an instrument for the project
- The instrument does not need to be one the person normally plays
- Part number is optional and can be left blank
- Admins can assign anyone from any section

#### US-4.2: Set or change part assignment

> As a **section leader**, I want to set or update the part for an assigned person.

**Acceptance criteria:**
- Part is a free-text field (e.g. "1", "2", "Solo")
- Can be set at assignment time or updated later
- Can be cleared (set back to blank)

#### US-4.3: Remove a person from a project

> As a **section leader**, I want to remove a person from my section from a project.

**Acceptance criteria:**
- Removing an assignment also removes associated absence records
- Admins can remove anyone

#### US-4.4: View project roster

> As any **user with access to the project**, I want to see who is assigned to the project.

**Acceptance criteria:**
- Roster grouped by section, showing: name, instrument, part (if set)
- Admins and section leaders see full roster
- Members see full roster (names and instruments only, no contact details of others)

---

### US-5: Rehearsal absence tracking

#### US-5.1: Report own absence

> As a **member**, I want to report that I will miss a rehearsal.

**Acceptance criteria:**
- Member selects a rehearsal date from their project and marks it as absent
- Member can undo (remove) their own absence report

#### US-5.2: Report absence for a section member

> As a **section leader**, I want to report an absence on behalf of someone in my section.

**Acceptance criteria:**
- Section leader selects a person in their section, a project, and a rehearsal date
- Admins can report absence for anyone

#### US-5.3: View absence overview

> As a **section leader**, I want to see which members are missing from upcoming rehearsals.

**Acceptance criteria:**
- Per project: view showing each rehearsal date and who has reported absence
- Filterable by section
- Admins see all sections

---

### US-6: Project page

#### US-6.1: View project page

> As a **member assigned to a project**, I want to see a project overview page.

**Acceptance criteria:**
- Shows: project name, concert date, rehearsal dates, sheet music links
- Shows the member's own assignment (instrument, part)
- Shows full roster (names and instruments, no contact details)
- Shows which rehearsals the member has marked as absent
- Provides a way to report/remove absence (links to US-5.1)

---

### US-7: Authentication & access

#### US-7.1: Admin and section leader login

> As an **admin or section leader**, I want to log in via Google SSO.

**Acceptance criteria:**
- Google SSO login flow
- Only pre-authorized Google accounts can log in (admin whitelist)
- Session persists across browser restarts

#### US-7.2: Member magic link access

> As a **member**, I want to access the system via a link sent to my email.

**Acceptance criteria:**
- When an admin triggers "send magic links" for a project, all assigned members receive an email with a unique access link
- The link authenticates the member and sets a browser cookie
- The cookie is valid until the latest project end date the member is assigned to
- The link/cookie grants access to all of the member's projects, not just the triggering one
- If a member is added to a new project while they already have a valid cookie, no action needed — existing session covers it

---

## Future features (not MVP)

- Piece/repertoire list per project
- Announcements/notifications per project
- Export member lists or rosters as CSV/PDF
- Dedicated "project creator" role (separate from admin)
- Member confirmation flow for project assignments
- Absence reason field
- Rehearsal venue/time information
- Historical project archive/browsing

## Non-goals

- Public-facing pages (concert calendar, about us, etc.)
- Ticket sales or audience management
- Financial tracking (fees, budget)
- Sheet music file storage (links only)
- Chat or messaging between members
- Calendar integration (Google Calendar, iCal sync)
- Mobile app (web-responsive is sufficient)
