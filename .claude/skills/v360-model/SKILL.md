---
name: v360-model
description: Generate and evolve the Vista 360 configuration model — tabs and cards — as records in an org. Use this skill when creating a Vista 360 tab, adding or binding cards (LWC or Flow) to a tab, seeding or migrating V360 configuration between orgs, wiring the shell onto a record page, or activating, ordering, or kill-switching cards. Covers V360_Tab__c, V360_Card__c, V360AdminService, and the seed-script pattern.
metadata:
  version: "1.0"
---

# v360-model: Generating the Vista 360 Configuration Model

Vista 360 configuration is **data, not metadata**: tabs and cards live as
custom-object records in the org. "Generating the model" means creating those
records correctly. Read this before writing any of them.

Related skills: `v360-rules` (visibility rules on cards), `v360-card`
(authoring the card LWC itself), `v360-design` (frontend conventions).

## 1. The shape of the model

```
V360_Tab__c  (a named surface, anchored to one SObject)
  └── V360_Card__c  (one tile: presentation + component binding + release state)
        └── V360_CardRule__c / V360_RulePredicate__c  (see v360-rules)
```

One record page hosts one tab: the `c/v360Shell` FlexiPage component carries a
`tabApiName` property, whose picklist (`V360TabPicklist`) offers the tabs
anchored on that page's object and stores the tab's **developer name** — never
an Id, so configuration survives moves between orgs.

## 2. V360_Tab__c — exactly three fields

| Field | Meaning | Constraints |
| --- | --- | --- |
| `DeveloperName__c` | Stable identity | Unique, external Id, **locked after creation** — record pages reference it and cross-org upserts key on it; renaming breaks the page and duplicates the tab |
| `AnchorSObject__c` | Object whose record pages host this tab | Validated against the schema on save; must be an object with record pages (`EntityDefinition.IsLayoutable`) |
| `Sequence__c` | Carried, not consumed | Placement is decided in Lightning App Builder, not here |

There is **no `Active__c` on tabs**. Do not invent one; activation is a card
concept.

## 3. V360_Card__c — presentation, binding, release

| Group | Fields | Notes |
| --- | --- | --- |
| Identity | `DeveloperName__c`, `Tab__c` | Developer name unique/external Id, locked after creation |
| Presentation | `Label__c`, `Description__c`, `IconName__c`, `ButtonLabel__c`, `Order__c` | `IconName__c` must be a real SLDS icon (`standard:*`, `utility:*`, `custom:*`) — an unknown name renders no glyph at all |
| Binding | `ComponentType__c` (`LWC` \| `Flow`), `ComponentName__c` | For `LWC`, the name **must be registered in `c/v360CardRegistry`** or the shell renders "Card unavailable"; for `Flow`, the active screen flow's API name |
| Release | `Active__c`, `KillSwitch__c`, `RuleMatchLogic__c` (`ALL` \| `ANY`) | See lifecycle below |
| Override | `AnchorSObject__c` | Optional per-card override of the tab's anchor; leave blank to inherit |

### Card lifecycle

- **Draft** — `Active__c = false`. Invisible to everyone. Cards are born here.
- **Live** — `Active__c = true`, `KillSwitch__c = false`. Visible to whoever
  the rules admit — and to **everyone** if no active rule restricts it.
- **Killed** — `KillSwitch__c = true`. Hidden absolutely; overrides every rule.
  Incident control, not a scheduling tool.

A card with zero enforced rules that goes live is **open to the whole org**.
Never activate a card before its rules exist unless that is the intent — the
admin console's toolbar counts these as "cards visible to everyone".

## 4. The write path — always V360AdminService

Never write these objects with raw DML. `V360AdminService` is the one write
path, and it does four things raw DML skips:

1. Requires the `V360_ManageVisibilityRules` custom permission (granted by
   the `V360_Admin` permission set) — throws without it.
2. Enforces CRUD/FLS (`stripInaccessible` + `USER_MODE`).
3. Validates anchors against the schema and component bindings by type
   (non-blank LWC name, active screen flow).
4. Publishes `V360_ConfigChange__e` so open shells refresh their catalog.

Methods: `saveTabs`, `saveCards`, `saveCardRules`, `saveRulePredicates`,
matching `delete*`, and `validateFormula`. All save methods upsert **by Id
only** — resolve the Id yourself first (section 5).

## 5. Idempotent seeding — the canonical recipe

`scripts/apex/v360-seed-vertical-slice.apex` is the reference: one tab → card
→ rule → predicate slice, safe to re-run. The pattern for every record:

```apex
// 1. Look up by natural identity (DeveloperName__c is unique + external Id)
List<V360_Tab__c> existing = [SELECT Id FROM V360_Tab__c
                              WHERE DeveloperName__c = :devName LIMIT 1];
V360_Tab__c tab = existing.isEmpty() ? new V360_Tab__c() : existing[0];
// 2. Set every field the seed owns (idempotent: same input, same result)
tab.DeveloperName__c = devName;
tab.Name = devName;
tab.AnchorSObject__c = 'Account';
tab.Sequence__c = 1;
// 3. Save through the service, never raw DML
V360AdminService.saveTabs(new List<V360_Tab__c>{ tab });
```

`V360_RulePredicate__c` has no developer name (by design): look it up by its
natural composite key — parent rule + `PredicateType__c` + `TargetApiName__c`.

Run with: `sf apex run --file <script> --target-org <alias>`. The running user
needs `V360_Admin`.

## 6. Wiring a tab onto a record page

1. Seed the tab (anchored on the page's object) and its cards.
2. In Lightning App Builder — or the FlexiPage XML — add `c:v360Shell` and set
   `tabApiName` to the tab's developer name. The property is a dynamic
   picklist; it only offers tabs anchored on that page's object.
3. One shell per FlexiPage component, one tab per shell. Two tabs on one page
   means two shell instances.

The shell with no `tabApiName` renders a configuration-gap panel, not an empty
list — that state is expected during setup, not an error.

## 7. Checklist before calling the model done

- [ ] Every `ComponentName__c` of type `LWC` exists in `c/v360CardRegistry`
- [ ] Every `IconName__c` is a real SLDS icon
- [ ] Developer names follow PascalCase and will never need renaming
- [ ] No card is live without either a deliberate "open to everyone" decision
      or at least one active, configured rule (see `v360-rules`)
- [ ] The seed script re-runs cleanly (idempotency is the test)
- [ ] `V360_Admin` grants access to any new Apex the flow touches
