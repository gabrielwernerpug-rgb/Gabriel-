# Composio automation ideas

Automation suggestions based on the app integrations currently connected to this
account. Each idea names the apps involved, the event that should start it, and
the commands to verify it is actually supported before building.

## What this is based on

These are the integrations connected right now:

| Status | Apps |
| --- | --- |
| Connected and active | Asana, Canva, Figma, Notion, Sentry, Supabase, MongoDB Atlas, Lovable, Higgsfield, Emergent |
| Installed, not connected | Slack, Riverside, Topview |
| Implied by account | Gmail, GitHub |

That mix reads as one workflow: build web apps (Lovable, Supabase, MongoDB
Atlas), watch them in production (Sentry), design for them (Figma, Canva), plan
the work (Notion, Asana), and market them with video (Higgsfield, Riverside,
Topview). The ideas below follow that same loop, ordered by how much manual work
they remove.

## How Composio automations are wired

Composio splits into two halves, and it is worth knowing which half an idea needs.

**Tools** are actions you call. They are named `{TOOLKIT}_{ACTION}` — for example
`GITHUB_CREATE_ISSUE`. Run one directly:

```sh
composio execute GITHUB_CREATE_ISSUE -d '{ owner: "me", repo: "app", title: "..." }'
```

**Triggers** are events you subscribe to. A trigger type is a category of event
such as `GITHUB_COMMIT_EVENT`; activating one for a connected account produces a
trigger instance with its own `ti_*` ID. Composio delivers every event to a
single webhook URL you register once per project.

Delivery speed differs by provider, which affects how you design each automation:

- **Realtime push** — Slack, Asana, Notion, Outlook.
- **Polling**, up to roughly 15 minutes of latency — Gmail, Google Calendar.

So anything built on Gmail should be treated as "within the next quarter hour",
not instant. Don't put a Gmail trigger in front of something time-critical.

## The ideas

### 1. Sentry error to a triaged task

**Trigger:** a new unresolved Sentry issue crossing a severity or event-count threshold.
**Action:** create a GitHub issue with the stack trace and suspect file, then link it into Asana.

This is the highest-value one for this stack, because Sentry, GitHub, and Asana
are all connected and the manual version of this job is pure copy-paste. Key
detail: dedupe on the Sentry issue fingerprint, not the message text, or one
noisy bug will file a hundred tasks.

Worth pairing with Sentry's own analysis so the created issue arrives with a
suggested cause already attached rather than a raw trace.

### 2. Signup to onboarding

**Trigger:** a new row in the Supabase users table.
**Action:** send a Gmail welcome message, add a row to a Notion CRM database, and post to Slack.

This is the one that pays off earliest for a product with real users, and it
replaces the "check the dashboard every morning" habit. Make the Notion write
idempotent on user ID so a retried event doesn't create duplicate CRM rows.

Slack is installed but not yet connected, so link it first (see below) or drop
that step.

### 3. Release notes without writing them

**Trigger:** a merge to the default branch, or a Lovable deploy.
**Action:** summarise the merged commits, append to a Notion changelog page, and post the same summary to Slack.

Given how fast Lovable iterates, the changelog is usually the first thing to rot.
Generating it from commits that already exist costs nothing per release.

### 4. Weekly health digest

**Trigger:** a schedule, Monday morning.
**Action:** collect Sentry error counts week over week, Supabase and MongoDB Atlas usage, and Asana tasks completed versus slipping, into one Notion page.

Each source is a separate dashboard today. One page beats four tabs, and the
week-over-week delta is what makes it worth reading — a raw error count on its
own says nothing.

### 5. Design change to build task

**Trigger:** a Figma comment, or a change to a published component in a library file.
**Action:** open an Asana task tagged to the right project, with the frame link and a screenshot.

Best scoped to published library components rather than every file edit.
Subscribing to all Figma activity will bury the signal on an actively edited
file.

### 6. Content repurposing pipeline

**Trigger:** a finished Riverside recording.
**Action:** cut short clips (Higgsfield or Topview), draft captions, generate Canva thumbnails, and stage everything as rows in a Notion content calendar for review.

This is the biggest raw time saver of the six, and it fits the video tooling
already on the account. Stage for review rather than auto-publishing — clip
selection is the part still worth a human eye, and an auto-posted bad cut is
expensive to undo.

Riverside and Topview both need connecting before this can run.

### 7. Inbox to action items

**Trigger:** Gmail messages matching a label or filter.
**Action:** extract commitments and deadlines, create Asana tasks, and archive the handled mail.

Start this one narrow — a single label such as `clients`, never the whole inbox.
A broad filter here generates task-list noise faster than it saves time. Note the
polling latency mentioned above.

## Setting it up

Login is a browser flow and has to run on your own machine:

```sh
composio login
```

Then connect the three apps that are installed but not yet authenticated:

```sh
composio link slack
composio link riverside
composio link topview
```

Before building any idea above, confirm the trigger actually exists for that
toolkit — availability varies per app, and this is the step that saves an
afternoon:

```sh
composio triggers list sentry     # list trigger types for a toolkit
composio triggers info <slug>     # inspect one trigger's payload schema
composio tools list supabase      # list callable actions
```

`composio search` is the fastest way to find the right tool when you know the
outcome but not the slug:

```sh
composio search "create task from error report" --limit 5 --human
```

Validate an action before wiring it into anything live. `--dry-run` checks
inputs and connection status without performing the action:

```sh
composio execute ASANA_CREATE_TASK -d '{ name: "test" }' --dry-run
```

For local development, `composio dev listen` streams realtime trigger events to
your machine, so you can see a real payload before writing any handler code.

## Suggested order

Ideas 1 and 2 are the ones to build first. Both run on already-connected apps,
so neither is blocked on linking anything, and both replace work that happens
every single day. Idea 6 saves the most time per run but needs Riverside and
Topview connected first, which makes it the natural follow-up rather than the
starting point.
