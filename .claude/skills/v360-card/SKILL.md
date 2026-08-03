---
name: v360-card
description: Author a new Vista 360 card LWC end to end. Use this skill when creating or modifying a V360 card component (the child LWCs the Vista 360 shell renders), wiring a card into the registry and catalog, implementing card lifecycle stages (skeleton, presentation, error), or exposing card header actions.
---

# v360-card: Authoring a Vista 360 Card

A Vista 360 card is a plain LWC that the shell (`c/v360Shell`) mounts when the
server says the current user may see it. This skill is the recipe for building
one. Read `.claude/skills/v360-design/SKILL.md` first for the system-wide
design conventions; this file is the card-specific, step-by-step contract.
`c/v360AccountSnapshot` is the canonical reference implementation.

## 1. A card knows nothing about Vista 360

The single most important rule: a card never imports anything from the shell,
the state managers, the registry, or the visibility engine, and never asks
"am I visible?" — the server already decided that before the card existed.
A card receives `recordId` as its only required `@api` property, fetches its
own data (UI API wire or its own Apex via its own service boundary), and
renders. It must work dropped on any Lightning page by itself.

## 2. The lifecycle stages (see v360-design section 7)

A card implements stages 2-5; stage 1 (LOADING) belongs to the shell:

- **SKELETON** — while the card's own data request is in flight (wire emitted
  neither `data` nor `error`): render stencil bars mirroring the card's real
  layout. Structural stencil rules live in the card's own stylesheet; colors
  come from the global tokens (`--v360-color-skeleton`, `--v360-color-surface`).
- **PRESENTATION** — the data view. SLDS read-only form elements for fields,
  `lightning-formatted-*` for typed values.
- **ERROR** — the request failed: `c/v360EmptyState` with
  `illustration-name="error:recoverable"` and a retry wired to the card's own
  refresh path (or `error:unrecoverable` when retrying cannot help).
- **OTHERS** (optional) — for example, data loaded but every field was
  FLS-stripped: `c/v360EmptyState` with `illustration-name="access:request"`.
  Only implement the states the card genuinely needs.

Stage selection is a simple derivation, never stored state:
wire pending → SKELETON; wire error → ERROR; data → PRESENTATION (or OTHERS).

## 3. Header actions (optional; see v360-design section 8)

A card MAY expose actions the shell surfaces in the focused-view header —
still with zero Vista 360 imports:

```js
@api get headerActions() {
    return [{ name: 'refresh', label: 'Refresh', iconName: 'utility:refresh' }];
}

@api invokeHeaderAction(name) {
    if (name === 'refresh') {
        refreshApex(this.record);
    }
}
```

If the action set changes at runtime, dispatch a bubbling
`headeractionschange` CustomEvent and the shell re-reads the getter. Cards
without actions simply omit both members.

## 4. CSS rules (see v360-design section 3)

- SLDS utility classes and base components first, always.
- Colors only through the global `--v360-color-*` tokens (defined on the
  shell's stylesheet; they cascade into every mounted card). Never hardcode a
  hex value in a card stylesheet.
- A card's own structural rules (stencil bars, layout quirks SLDS cannot
  express) live in the card's own `.css` with a one-line justification
  comment. No stylesheet at all is the best stylesheet.

## 5. Wiring checklist (every new card)

1. **Component**: `force-app/main/default/lwc/<cardName>/` — `isExposed`
   false unless the card must also stand alone on pages; api version matches
   the codebase.
2. **Registry**: add a static import + map entry in
   `c/v360CardRegistry` (`<cardName>: CardConstructor`). The bundler then
   guarantees the component exists; never any dynamic import.
3. **Catalog row** (org data, per org — via the admin surface or the seed
   script pattern in `scripts/apex/`): `DeveloperName__c` (stable unique
   name), `ComponentType__c` = `LWC`, `ComponentName__c` = the exact bundle
   name, `Label__c`, `Description__c` (shown on the gallery tile and focused
   header), `ButtonLabel__c` (tile action label, e.g. "Consultar"),
   `IconName__c` (SLDS icon like `standard:account`), `Order__c`, `Active__c`.
4. **Visibility rule** (optional): a `V360_CardRule__c` row with a boolean
   `VisibilityFormula__c` (validated at save; max 3,900 characters;
   `$Permission`/`$Profile`/`$User`/`$UserRole` globals available; picklist
   fields need `ISPICKVAL`) and/or structured predicates (`PERMISSION_SET`,
   `FLS_READ`). No rules means the card is visible to everyone who can see
   the page.
5. **Jest** (one suite per card, minimum):
   - SKELETON renders while the wire is pending.
   - PRESENTATION renders the fields when data arrives.
   - ERROR state renders the recoverable illustration and retry re-requests.
   - OTHERS states the card implements.
   - Header actions getter shape + `invokeHeaderAction` behavior, when present.
6. **Run everything**: `npm run test:unit` green; deploy to your own sandbox
   and view the card through the shell before opening a PR.

## 6. What NOT to do

- No `import` from `c/v360Shell`, `c/v360CustomerState`, `c/v360ShellState`,
  or `c/v360CardRegistry` inside a card.
- No visibility logic inside a card — not even "hide if field X is empty
  because the user probably lacks access"; render the OTHERS state instead.
- No bare text for empty/error states — always `c/v360EmptyState`.
- No hardcoded colors, no new prefix conventions, no process references in
  comments.
