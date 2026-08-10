---
name: v360-design
description: "Design conventions for Vista 360 LWC components: SLDS-only styling, the shared empty-state wrapper, shell state contract, and card engine-agnosticism. Use this skill when building or editing V360 LWC components, shell states, empty states, error states, or SLDS styling for vista360."
metadata:
  version: "1.0"
---

# v360-design: Vista 360 Frontend Conventions

Conventions for every Lightning Web Component under the Vista 360 feature (`v360*`
component bundles). Read this before adding or editing a V360 component so new work
stays consistent with the shell, the state contract, and the styling rules below.

## 1. SLDS exclusively

Use SLDS base components (`lightning-*`) and SLDS utility classes for all layout,
spacing, color, and typography. Do not write custom CSS for something SLDS already
expresses.

Custom CSS is only acceptable when SLDS genuinely lacks the capability. There are two
places it is allowed to live, and no others:

- **Shared chrome** (a rule any V360 component could plausibly reuse — a fixed-width
  rail, a rounded-corner treatment SLDS has no utility class for, etc.) lives in
  `c/v360Styles` (see section 3). This is the default home.
- **Per-component structural CSS** (a card's own stencil/skeleton shape, a repeated
  internal layout used across more than one of the card's own templates, or any other
  rule that is genuinely that component's own presentation, not shared chrome) may
  live in the component's own stylesheet (`<component>.css`) instead. Treat this as
  the LWC-native equivalent of the legacy per-template `_shared.css` convention: the
  component's own default stylesheet carries its base rules, and any
  template-specific stylesheet only overrides on top of that base. This is the
  exception, not the default — most components need no CSS of their own at all.

Either way, every stylesheet that references a color reaches for a `c/v360Styles`
token (section 3) instead of a hardcoded hex value, and every custom rule carries a
one-line plain-language comment explaining what SLDS could not do.

Inline field rows (one or more fields plus a trailing button on a single line)
align with `slds-grid_vertical-align-start`, never `_end`: a field's validation
error grows below it, and bottom alignment shoves the neighboring controls when
it does. Give the trailing button a hidden label spacer so its control lines up
with the fields' controls:

```html
<div class="slds-form-element">
    <span class="slds-form-element__label slds-hidden" aria-hidden="true">Add</span>
    <div class="slds-form-element__control"><!-- button --></div>
</div>
```

## 2. Empty, error, and no-access states: always illustration-based

Never render an empty, error, or no-access state as bare text (a lone `<p>` or a
`<div>` with a message). Every such state renders through `c/emptyState`.

`c/emptyState` is a thin wrapper around the platform's `lightning-empty-state`
(Beta) base component. Components consume the wrapper, never
`lightning-empty-state` directly — the wrapper isolates every V360 component from a
future change to that Beta component's API, and gives one place to swap
implementations if the platform component is ever unavailable in a given org (see
"Fallback path" below).

`c/emptyState` public API:

| Property | Type | Purpose |
|---|---|---|
| `title` | String | Short heading for the state. |
| `illustrationName` | String | SLDS illustration reference, `"category:name"` (see table below). |
| `size` | String | Forwarded to the platform component (e.g. `"small"`). |
| `alternativeText` | String | Accessible text for the illustration; required whenever the illustration conveys meaning beyond decoration. |
| `description` | String | Simple text description. For richer content, omit this and slot markup into the default slot instead. |
| `retryLabel` | String | When set, renders a call-to-action button with this label; clicking it dispatches a `retry` event. Omit when there is nothing useful to retry. |
| `boxed` | Boolean | Draws the state on its own `slds-box`. Off by default, because most empty states already sit inside a surface that owns the border and boxing those doubles it. Turn it on where the state is the only thing in its region and would otherwise read as floating. |

Consumers also have a named `cta` slot for additional buttons (the platform
component supports up to two call-to-action buttons total).

### State -> illustration mapping

| Situation | `illustration-name` | Notes |
|---|---|---|
| A service/evaluation call failed and retrying is a reasonable next step | `error:recoverable` | Title like "Something went wrong"; always pair with `retryLabel` wired to the relevant refresh/fresh-data path (a state manager's `refresh()`, or `refreshApex()` for an LDS-wired property). |
| A card or binding is broken with no reasonable retry (e.g. an unknown component binding) | `error:unrecoverable` | No `retryLabel` — there is nothing a click can fix. |
| The current user lacks access to see something (permission- or FLS-shaped absence) | `access:request` | Used both for structured "no access" states and for a card that has nothing to show because every visible field was stripped by FLS. |
| A request succeeded but returned nothing to show | `noresults:unknown` | Short, factual description of why there is nothing (e.g. "No cards are configured for this tab."). |

Loading states are not empty states — keep using `lightning-spinner` (or another
appropriate SLDS loading affordance) for the `loading`/`unconfigured` portion of the
`{ status, data, error }` contract.

### Fallback path if the Beta component is unavailable

`lightning-empty-state` is a Beta base component and may not be available in every
org. Before relying on it in a new org, verify with a scoped
`sf project deploy validate` against the `c/emptyState` bundle. If the org
rejects it, reimplement `emptyState`'s internal template using the SLDS
illustration blueprint instead (the `slds-illustration` class plus an inline SVG and
`slds-text-*` classes for the heading/description), while keeping the exact same
external API (`title`, `illustrationName`, `size`, `alternativeText`, `description`,
`retryLabel`, `retry` event, `cta` slot) so every consumer is unaffected by the
swap.

## 3. Shared custom CSS: `c/v360Styles`

`c/v360Styles` is a CSS-only module: its bundle contains exactly the
stylesheet and the bundle metadata file — **no JavaScript file**. That shape
is what makes it both deployable and importable (a bundle with only the
`.css` is not recognized by the packaging tooling, and one with a JavaScript
stub is not a valid `@import` target). Components pull it into their own
stylesheet with:

```css
@import 'c/v360Styles';
```

Only import it from components that actually have their own `.css` file with a
real reason to need it. Note for unit tests: because the bundle has no
JavaScript entry, `jest.config.js` maps `c/v360Styles` straight at the
stylesheet.

### Global color tokens

`v360Styles.css` defines the tokens as CSS custom properties on `:host`, each
mapped onto an SLDS 2 global styling hook with a literal fallback so a theme or
dark-mode change is absorbed by the hook and the fallback only matters in an
org where the hook is not yet defined:

| Token | Maps to | Purpose |
|---|---|---|
| `--v360-color-brand` | `--slds-g-color-brand-base-50` | Brand-colored accents. |
| `--v360-color-text-subtle` | `--slds-g-color-neutral-base-30` | De-emphasized text (subtitles, helper copy). |
| `--v360-color-surface` | `--slds-g-color-surface-1` | Card/tile background surfaces. |
| `--v360-color-skeleton` | `--slds-g-color-neutral-base-90` | Skeleton/stencil placeholder bars (see section 7). |

Every component that needs a color reaches for one of these tokens instead of a
hardcoded hex value — that is what keeps dark mode and future theme changes a
one-file fix. Add a new token here (with the same hook-plus-fallback shape) rather
than inventing a bespoke color in a component stylesheet.

`v360Styles.css` also carries the handful of shared, non-color chrome rules SLDS has
no utility class for — for example the shell sidebar's rounded-corner selected-item
treatment (section 9). Each such rule keeps its own one-line justification comment.
A card's own structural rules (like its skeleton stencils) live in that card's own
stylesheet, referencing the imported global tokens — never a hardcoded hex value.

## 4. The `{ status, data, error }` state contract

Every V360 state manager (and every component that surfaces state to the user)
follows the same uniform contract: `status` is one of `unconfigured | loading |
loaded | error`, `data` holds the payload once loaded, and `error` holds whatever
the failed call produced. Render dispatch on `status` should cover all four values
(loading uses a spinner; `error` and an empty `loaded` result use
`c/emptyState` per the mapping above; a non-empty `loaded` result renders the
real content).

## 5. Cards are engine-agnostic

A card component (anything rendered as Vista 360 card content, not the shell
itself) must have zero references to Vista 360's visibility engine, rules, or
evaluator — no imports of the Apex visibility boundary, no awareness of why it was
decided visible. Cards receive their `recordId` (and any other inputs) as plain
`@api` properties and source their own data independently (LDS wire, their own
Apex controller, etc.). Degrade gracefully when a field or record is not
accessible instead of erroring — prefer `lwc:if` around missing data over letting
a template throw.

## 6. Accessibility notes

- Always set `alternative-text` on a `c/emptyState` instance whose illustration
  conveys information beyond decoration (this is all of them per the mapping table
  above — none of these are purely decorative).
- Do not assume a heading level. `c/emptyState` renders its own heading
  markup internally; a consumer nesting it inside its own heading structure should
  verify the resulting outline still makes sense (an `<h3>` title is wrong if it
  would skip past a page's actual `<h2>`) and provide the wrapper a plain-string
  `title` regardless of surrounding heading depth.
- Keep interactive affordances (the retry button) reachable via keyboard — the
  wrapper's `lightning-button` is already keyboard-accessible; do not replace it
  with a non-interactive element wired to a click handler.

## 7. Card lifecycle: the five stages every card follows

Every card component moves through the same stage machine. Only stage 1 is the
shell's responsibility; stages 2-5 belong entirely to the card itself.

1. **LOADING** (shell-owned) — shown while the card's component is being injected
   and hydrated, before the card itself has any say. In the shell's focused view
   this is the spinner shown while a selected LWC card's constructor is still
   resolving from `c/v360CardRegistry` (`isSelectedCardHydrating` in `v360Shell`).
   A card component never needs to render this stage itself.
2. **SKELETON** (card-owned) — a structural placeholder mirroring the card's real
   layout while *its own* data is in flight (e.g. a wire adapter with neither `data`
   nor `error` yet). Implement as SLDS-colored stencil bars with a subtle
   shimmer — light gray rounded bars sized to roughly match the real content's
   shape. The stencil CSS (bar shape, sizing, the shimmer `@keyframes`) is a
   justified per-component exception (section 1) living in the card's own
   stylesheet, since it is that card's own structural presentation; only the bar
   and shimmer *colors* come from the imported `c/v360Styles` tokens
   (`--v360-color-skeleton`, `--v360-color-surface`). `c/v360AccountSnapshot` is
   the reference implementation — see its `isSkeleton` getter and
   `v360AccountSnapshot.css`.
3. **PRESENTATION** — the card's real data view once its own data has resolved.
4. **ERROR** (card-owned) — the card's own failure state (its own service or wire
   call failed). Uses `c/emptyState` with `error:recoverable` and a
   `retryLabel` wired to the card's own refresh path (`refreshApex` for an
   LDS-wired property, or a state manager's `refresh()`), per the mapping in
   section 2.
5. **OTHERS** (optional, per card) — any further state a specific card needs that
   is not covered above, most commonly a no-access/no-visible-fields state using
   the `access:request` illustration. `c/v360AccountSnapshot`'s
   no-visible-fields state (every field stripped by FLS) is the reference example.

Dispatch order in the template matters: check the card's own error first, then
whether it is still pending (skeleton), then render presentation (with any
stage-5 special case nested inside, as `v360AccountSnapshot` does for
no-visible-fields).

## 8. Header actions: an optional, engine-agnostic protocol

A card MAY expose actions the shell renders in its focused-view header, without
ever importing anything from Vista 360's shell or visibility engine — this keeps
cards engine-agnostic (section 5) even when they participate in shell chrome.

The interface, entirely plain `@api` members:

- `@api get headerActions()` → an array of `{ name, label, iconName }`. Return a
  fresh array each time; the shell compares by content, not by reference.
- `@api invokeHeaderAction(name)` → performs the action named by `name`.
- Optionally, dispatch a bubbling `headeractionschange` `CustomEvent` when the
  action set changes for a reason the shell would not otherwise notice; the shell
  re-reads `headerActions` off the card when it receives this event.

The shell (`v360Shell`) reads this interface off the mounted dynamic component
instance after it renders, renders each action as a `lightning-button-icon`
(`icon-name` from `iconName`, `alternative-text`/`title` from `label`) in the
focused header's right zone, and calls `invokeHeaderAction(name)` on click. It also
registers the resolved actions on `v360ShellState.registerHeaderActions(cardId,
actions)` so the state contract stays the single source of truth. A card that
implements neither member simply renders no header actions — this is the default,
zero-effort case.

`c/v360AccountSnapshot` is the reference implementation: it exposes one action,
`{ name: 'refresh', label: 'Refresh', iconName: 'utility:refresh' }`, whose
`invokeHeaderAction` runs its existing `refreshApex` retry path.

## 9. Shell interaction model: gallery and focused views

The shell (`v360Shell`) renders exactly one of two views once cards have loaded,
driven entirely by `v360ShellState`'s per-record `selectedCard`.

### Gallery (no card selected)

A responsive grid (`slds-grid slds-wrap`, `slds-large-size_1-of-3` on large
viewports, `slds-size_1-of-1` on mobile) of card **tiles**. A tile is a launcher,
never the card's mounted component:

- A bordered box (`slds-box`) with a header row: the card's icon
  (`lightning-icon`, `size="small"`) plus its label as a heading.
- The card's `description` as body text below the header row, when present.
- A divider (`<hr>`), then a centered action (`lightning-button`, `variant="base"`)
  showing the card's `buttonLabel`, falling back to `"Consultar"` when the catalog
  row has none configured.
- Clicking anywhere on the tile, or the action specifically, selects the card
  (`v360ShellState.selectCard`) — this is the only thing a tile does.

### Focused (a card is selected)

A two-zone `slds-grid` layout:

- **Sidebar** (`~104px` fixed-width rail, the `.v360-shell-sidebar` custom class):
  every visible card as a minimized launcher — icon stacked above a small
  centered label, no card content. The selected item gets the
  `slds-theme_shade` utility class (background) plus the shared
  `.v360-shell-sidebar-item_active` custom class (rounded corners — see section
  3). Clicking any item switches the selection, including switching away from
  the currently focused card.
- **Main area**: a bordered header row with a back button
  (`lightning-button-icon`, `utility:chevronleft`, clears the selection back to
  the gallery), the selected card's icon, label, and description, and any header
  actions (section 8) right-aligned; below it, the selected card's component,
  mounted full-width through the same dynamic-dispatch contract as before
  (`lwc:component`/`lwc:is` for a registered LWC, a labeled placeholder for a
  Flow card, `c/emptyState` for an unrecognized binding) — only the selected
  card's component is ever mounted in focused view.

Loading/error/empty states for the shell as a whole are unchanged (section 2 /
section 4) and render before either view is reached.
