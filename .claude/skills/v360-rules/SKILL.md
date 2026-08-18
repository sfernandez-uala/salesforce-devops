---
name: v360-rules
description: Generate Vista 360 visibility rules — who sees which card on which record. Use this skill when creating or editing V360_CardRule__c or V360_RulePredicate__c records, writing visibility formulas, choosing between ALL and ANY rule match logic, restricting a card by permission set or field-level security, or debugging why a card is hidden or exposed. Covers the visibility evaluator's semantics, the FormulaEval contract, and predicate types.
metadata:
  version: "1.0"
---

# v360-rules: Generating Vista 360 Visibility Rules

A rule decides who sees a card on a record. Getting one wrong in the
restrictive direction costs a click; getting it wrong in the permissive
direction leaks data. Every default below is chosen for that asymmetry.

Related skills: `v360-model` (tabs and cards), `v360-card` (the card LWC).

## 1. How the evaluator decides — precedence, verbatim

For each card, in order (`V360VisibilityEvaluator`):

1. **Kill switch on, or card inactive** → hidden. Absolute; no rule matters.
2. **Active rules exist** → combined by the card's `RuleMatchLogic__c`:
   - **ALL** (default): every active rule is a requirement; one failure hides
     the card. Blank or unrecognised logic reads as ALL — only a deliberate
     `ANY` ever loosens a card.
   - **ANY**: each active *configured* rule is one way to qualify; passing a
     single one shows the card.
3. **No active rules** → visible to everyone. This is a state the admin
   console warns about, not a safe default.

**Within one rule row, everything is required**: the rule passes only when its
formula (if present) evaluates true AND every one of its predicates passes.
"Audience A or audience B" therefore needs **two rows under ANY**, never one
row with two predicates.

**Unconfigured rules** (no formula, no predicates): under ALL they add no
requirement and pass; under ANY they are *skipped, not granted* — otherwise
pressing "New rule" would open the card to everyone until the row was
finished. A card whose every rule is unconfigured restricts nobody.

**Fail-closed**: any error while evaluating — formula fails to build, record
field unreadable, unknown predicate — hides that card and publishes a
`V360_Diagnostic__e` with the reason. Errors never surface to the end user.

## 2. The formula contract (FormulaEval)

Formulas are boolean, built against the card's **anchor SObject** and
evaluated against the actual record (`V360FormulaGateway`):

- **Record fields**: direct fields, or **exactly one level** of parent
  traversal (`Parent.Name`, `Account.Industry`). Two levels are rejected
  (`V360FieldPathUtil`).
- **Identity globals** — the only four available: `$Permission` (custom
  permissions), `$Profile`, `$User`, `$UserRole`.
- **`$Permission` is Custom Permission, NOT Permission Set.** A permission set
  cannot be read from a formula at all — that is what the `PERMISSION_SET`
  predicate exists for.
- **Picklists need `ISPICKVAL()`**: `ISPICKVAL(Industry, 'Banking')`. A bare
  `Industry = 'Banking'` fails to build.
- Max **3900 characters**.
- Validate before saving: `V360AdminService.validateFormula(cardId, text)` —
  it builds against the card's real anchor type and throws a readable message.

```text
ISPICKVAL(Industry, 'Banking') && AnnualRevenue > 1000000
$Permission.Collections_Agent || Parent.OwnerId = $User.Id
```

## 3. Predicates — what a formula cannot express

One `V360_RulePredicate__c` row = one required condition on the **running
user's grants** (`V360PredicateEvaluator`):

| `PredicateType__c` | `TargetApiName__c` | Passes when |
| --- | --- | --- |
| `PERMISSION_SET` | Namespace-qualified API name (`ns__Name`, bare `Name` if local) — take it from `V360RuleVocabulary.getPermissionSetOptions`, which serves the qualified form | The running user holds that permission set |
| `FLS_READ` | A field on the anchor object; one-level parent paths allowed | The running user can read that field |

`FLS_READ` doubles as a data-sensitivity gate: bind the card's visibility to
the same field its content hinges on, and FLS stays the single source of
truth. Predicates have no developer name — their identity is the composite
(rule, type, target).

## 4. Recipes

**Record state and permission, together** (one row, ALL):
> Rule "CollectionsView": formula `CPCurrentDueAmount__c > 0` + predicate
> `PERMISSION_SET: Collections_Agent`. Both required.

**Two audiences** (two rows, ANY):
> Rule "Collections": predicate `PERMISSION_SET: Collections_Agent`.
> Rule "Risk": predicate `PERMISSION_SET: Risk_Analyst`.
> Card `RuleMatchLogic__c = 'ANY'`. Either audience qualifies.

**Sensitive-field card** (one row, ALL):
> Predicate `FLS_READ: CPCurrentDueAmount__c` — whoever cannot read the number
> never sees the card that shows it.

**Never**: a live card with zero configured active rules, unless "everyone in
the org sees this" is the documented intent.

## 5. Writing the records

Same write path and idempotency pattern as `v360-model` (section 5 there):
look up `V360_CardRule__c` by `DeveloperName__c`, predicates by composite key,
save via `V360AdminService.saveCardRules` / `saveRulePredicates`. Requires
`V360_ManageVisibilityRules`. Rules default `Active__c = false` — park them
until the formula validates.

Order of operations for a new restriction on a live card:
1. Create the rule inactive; add formula and predicates.
2. `validateFormula` — fix until it builds.
3. Activate the rule.
4. Only then flip the card live (if it was draft).

Activating the card first opens it to everyone for the gap.

## 6. Debugging visibility

- Card hidden unexpectedly → check `V360_Diagnostic__e` events: fail-closed
  errors (FORMULA_INVALID, unreadable field) land there with card and reason.
- Card exposed unexpectedly → count *enforced* rules (`Active__c = true` AND
  configured), not stored rows. A parked rule protects nobody. The admin
  console's toolbar and per-card banner both report this.
- Formula builds in the console but fails on a record → the record's field is
  unreadable to that user, or a parent traversal hit a null — both fail closed.
- Remember the admin previews their own view: `PERMISSION_SET` and `FLS_READ`
  apply to admins like anyone else.
