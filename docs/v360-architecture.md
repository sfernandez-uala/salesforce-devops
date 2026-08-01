# Vista 360 — architecture overview

Vista 360 shows a set of "cards" (LWC components or screen flows) on a record page. Which cards
a given user sees is decided entirely on the server: a single Apex evaluator reads configuration
data, checks the current user's permissions and record access, and returns only the cards that
user is allowed to see. The frontend never makes a visibility decision — it renders whatever the
server returns.

## The problem this solves

Card visibility used to be filtered client-side, in the browser, after the full card
configuration had already been sent to the user. That meant the rules deciding who could see
what were visible to anyone who opened dev tools — and a client-side bug could show a card that
should have been hidden. End users also never need to read that configuration; only admins do.

Vista 360 moves the decision to a trusted server boundary: the client asks "which cards can this
user see for this record and this tab?" and receives back only the cards that passed. Hidden
cards, and the rules that hid them, never reach the browser.

## Data model

All configuration is stored as regular Salesforce records (Custom Objects), administered from a
single Lightning admin surface. Records link to each other through real lookups, so the
platform's own referential integrity guarantees a rule always points at a real card and a card
always points at a real tab.

| Object | Purpose |
|---|---|
| `V360_Tab__c` | One row per record-page tab: display order, the anchor object the tab reads from, active/inactive. |
| `V360_Card__c` | The card catalog. One row per card: which component it binds to, which tab it belongs to, its presentation (label, icon, order), and a kill-switch. |
| `V360_CardRule__c` | A visibility rule attached to a card: a boolean formula deciding whether the card is shown. |
| `V360_RulePredicate__c` | A structured condition attached to a rule, for checks a formula can't express (see "Evaluation" below). |
| `V360_Diagnostic__e` | A Platform Event published whenever a card is hidden due to a rule failure or a configuration error. |

**Cards are typed.** `V360_Card__c.ComponentType__c` is either `LWC` or `Flow`:

- An `LWC` card binds to a component name that must exist in the frontend's static component
  registry (see "Frontend" below) — the admin UI only lets you pick from that list.
- A `Flow` card binds to the API name of an active screen flow, validated against the org's flow
  definitions when the card is saved.

This keeps the visibility engine itself agnostic to how a card is actually implemented: the same
rules, kill-switch, and precedence apply whether a card is a pro-code LWC or a low-code flow.

**Why a custom object instead of custom metadata.** The configuration needs two things custom
metadata can't provide: field history tracking (so a change to a rule or a kill-switch is
audited — who changed what, and when) and same-day admin edits with no deployment. Custom
metadata is deployable and version-controlled, which is valuable for code, but this configuration
is deliberately *not* code — it's data that an org's own admins maintain directly.

## How evaluation works

A single Apex evaluator is the only place visibility decisions are made. For each card on a tab,
the evaluator applies this precedence, top to bottom:

1. **Kill-switch.** If `KillSwitch__c` is on, the card is hidden immediately, overriding
   everything else. No deployment is needed to flip it — it's a checkbox on the card's own record,
   tracked in field history so an incident response is auditable ("kill-switch turned on at
   14:32 by admin X").
2. **Rules.** If the card has one or more visibility rules, each rule must pass: its formula (if
   present) must evaluate to `true`, *and* every structured predicate on that rule must also
   pass.
3. **No rules.** A card with no rules at all is visible by default — visibility rules are an
   opt-in restriction, not a default-deny gate.

A rule's formula is standard Salesforce formula syntax — the same language admins already use in
validation rules, evaluated by the platform's formula engine rather than a custom interpreter.
This gives rules the full formula function library (`ISPICKVAL`, `CONTAINS`, date functions, and
so on) plus native `&&`/`||`/`NOT()` combinators, and it means formulas are validated for syntax
errors the moment they're saved — before they can ever reach evaluation.

Two kinds of conditions can't be expressed as a formula, so they're handled as separate
structured predicates on the rule instead:

- **Permission Set assignment** — is the current user assigned a specific Permission Set?
- **Field-level security read access** — can the current user read a specific field, including
  one level of parent-record traversal (e.g. `Parent__r.Field__c`)?

**Errors fail closed.** If a rule's formula is malformed, a referenced field doesn't exist, or a
card's component binding is invalid at render time, the card is hidden rather than shown broken
or bypassed — and a `V360_Diagnostic__e` event is published so admins have a real, subscribable
signal that something needs attention. Nothing is ever silently broken with no trace, and no
error is ever shown to the end user.

## Security model

| Concern | How it's handled |
|---|---|
| Who can change configuration | An admin Permission Set grants full CRUD on the four configuration objects plus a custom permission, `V360_ManageVisibilityRules`, which every admin write operation checks server-side before creating, updating, or deleting a tab, card, rule, or predicate. |
| What end users can access | The end-user Permission Set deliberately grants **no** access to any configuration object. End users only get access to the record page / shell itself — they never read tabs, cards, rules, or predicates directly. |
| How configuration is read during evaluation | The evaluator reads configuration in system mode (bypassing the current user's object/field permissions), because end users are intentionally denied direct read access to configuration by design — the evaluator is the trusted mediator that decides on their behalf. |
| How record data is read during evaluation | The record the card is about (the "anchor" record) is read in user mode, with field-level security enforced — this is the customer's real data, so the running user's actual access must apply. |
| How admin writes are enforced | Every admin write path enforces CRUD and field-level security in user mode, in addition to the custom permission check. |

This split is the core of the security model: configuration is protected from end users and
mediated by a trusted server component, while the actual customer data a card displays still
respects the viewing user's own record and field access.

## Frontend

- **State managers own state; cards never decide anything.** A per-record state manager
  requests the visible-card list from the server once, deduplicates concurrent requests for the
  same record and tab, and exposes a uniform `{ status, data, error }` shape to the shell.
- **`service.js` is the only Apex boundary.** Exactly one module in the frontend calls into Apex
  for visibility data, and only state managers import it — individual cards never call Apex
  directly and have no awareness of rules, the evaluator, or how they were decided visible.
- **A static component registry, not dynamic imports.** LWC cards are resolved through a
  hand-maintained map of component name to component class, built with static imports. This
  means a bundler catches a bad reference at build time, and the shell can never be asked to
  import an arbitrary string — a card that isn't in the registry renders a safe error state
  instead of attempting an unsafe dynamic import.
- **Flow cards render through one generic host.** Rather than a bespoke wrapper per flow, a
  single reusable host component wraps the platform's flow-embedding component, passing the
  configured flow's API name and the record ID as inputs at runtime. Flow cards are
  self-contained — they don't participate in the shared state manager or the shell's shared UI
  actions the way LWC cards do.

## Operating model

Vista 360 is **environment-independent**: each org's configuration — its tabs, cards, rules, and
predicates — is created and maintained by that org's own admins, directly in that org. There is
no pipeline that copies configuration from one environment to another.

- **What ships through source control:** the Apex classes, the LWC components, the static
  component registry, the object/field schema, and the Permission Sets. This is the engine —
  environment-independent code.
- **What lives only in each org:** the actual rows of configuration — which cards exist, what
  their rules are, which tabs they appear on. This is deliberately per-org data, not something
  promoted between sandboxes and production.

The tradeoff is that a new org's configuration has to be built once by its own admin team rather
than inherited automatically. That's accepted because the alternative — a promotion pipeline that
copies who-sees-what rules between environments — reintroduces exactly the kind of silent,
hard-to-audit visibility bug this design exists to prevent.
