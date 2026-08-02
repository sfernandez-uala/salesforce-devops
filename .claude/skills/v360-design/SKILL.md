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

Custom CSS is only acceptable when SLDS genuinely lacks the capability, and it must
live in `c/v360Styles` (see below) — never inline in a component-specific stylesheet
without a reason. When custom CSS is added, include a one-line plain-language comment
in `v360Styles.css` explaining what SLDS could not do.

## 2. Empty, error, and no-access states: always illustration-based

Never render an empty, error, or no-access state as bare text (a lone `<p>` or a
`<div>` with a message). Every such state renders through `c/v360EmptyState`.

`c/v360EmptyState` is a thin wrapper around the platform's `lightning-empty-state`
(Beta) base component. Components consume the wrapper, never
`lightning-empty-state` directly — the wrapper isolates every V360 component from a
future change to that Beta component's API, and gives one place to swap
implementations if the platform component is ever unavailable in a given org (see
"Fallback path" below).

`c/v360EmptyState` public API:

| Property | Type | Purpose |
|---|---|---|
| `title` | String | Short heading for the state. |
| `illustrationName` | String | SLDS illustration reference, `"category:name"` (see table below). |
| `size` | String | Forwarded to the platform component (e.g. `"small"`). |
| `alternativeText` | String | Accessible text for the illustration; required whenever the illustration conveys meaning beyond decoration. |
| `description` | String | Simple text description. For richer content, omit this and slot markup into the default slot instead. |
| `retryLabel` | String | When set, renders a call-to-action button with this label; clicking it dispatches a `retry` event. Omit when there is nothing useful to retry. |

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
`sf project deploy validate` against the `c/v360EmptyState` bundle. If the org
rejects it, reimplement `v360EmptyState`'s internal template using the SLDS
illustration blueprint instead (the `slds-illustration` class plus an inline SVG and
`slds-text-*` classes for the heading/description), while keeping the exact same
external API (`title`, `illustrationName`, `size`, `alternativeText`, `description`,
`retryLabel`, `retry` event, `cta` slot) so every consumer is unaffected by the
swap.

## 3. Shared custom CSS: `c/v360Styles`

`c/v360Styles` is a CSS-only shared module (a minimal `LightningElement` that is
never rendered as a component, plus its `.css` file). It exists so that if a
component genuinely needs custom CSS SLDS cannot express, there is exactly one
shared home for it, rather than duplicated rules scattered across component
stylesheets. Pull it into a component's own stylesheet with:

```css
@import 'c/v360Styles';
```

Only import it from components that actually have their own `.css` file with a
real reason to need it — do not add an empty stylesheet to a component purely to
import this module.

## 4. The `{ status, data, error }` state contract

Every V360 state manager (and every component that surfaces state to the user)
follows the same uniform contract: `status` is one of `unconfigured | loading |
loaded | error`, `data` holds the payload once loaded, and `error` holds whatever
the failed call produced. Render dispatch on `status` should cover all four values
(loading uses a spinner; `error` and an empty `loaded` result use
`c/v360EmptyState` per the mapping above; a non-empty `loaded` result renders the
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

- Always set `alternative-text` on a `c/v360EmptyState` instance whose illustration
  conveys information beyond decoration (this is all of them per the mapping table
  above — none of these are purely decorative).
- Do not assume a heading level. `c/v360EmptyState` renders its own heading
  markup internally; a consumer nesting it inside its own heading structure should
  verify the resulting outline still makes sense (an `<h3>` title is wrong if it
  would skip past a page's actual `<h2>`) and provide the wrapper a plain-string
  `title` regardless of surrounding heading depth.
- Keep interactive affordances (the retry button) reachable via keyboard — the
  wrapper's `lightning-button` is already keyboard-accessible; do not replace it
  with a non-interactive element wired to a click handler.
