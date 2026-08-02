# Vista 360 — FormulaEval limits and what they mean for maintainers

Vista 360 decides card visibility with boolean formulas — the same formula language admins
already use in validation rules — built and evaluated server-side through the platform's
`FormulaEval` namespace (`Formula.builder()...build()` + `FormulaInstance.evaluate()`). This
document records the platform limits that were verified against a real org, and what they mean
for anyone maintaining `VisibilityFormula__c` or the code that evaluates it.

## The limits that matter

| Limit | Verified value | Practical meaning |
|---|---|---|
| Formula length | Hard cap of exactly **3,900 characters** | `build()` rejects anything longer. Enforce this at save time — schema-level length is defense in depth on top of the platform's own rejection. |
| Build + evaluate cost | 3,000 `build()`/`evaluate()` cycles in one transaction cost ~4.5% of the CPU governor budget (416–486 ms of the 10,000 ms limit) | Per-evaluation cost is negligible. A real Vista 360 page evaluates a handful of cards, each with a handful of rules — nowhere near a scale where this needs throttling or batching. |
| Test context | `build()`/`evaluate()` work normally inside `@isTest` | No special handling needed to unit-test formula evaluation. |
| `$Permission.<Name>` syntax | Validated at `build()` time against real Custom Permission records | A formula referencing a permission that doesn't exist fails to build — the same referential validation as any other formula identifier, not just a syntax check. |
| `getReferencedFields()` | Returns `Set<String>`, not a list of field tokens | Includes parent-relationship paths as full strings (e.g. `Parent.Website`), not the local lookup field. Split on `.` to detect one level of parent traversal. |

## Why this matters for the schema and the write path

- **Enforce the 3,900-character cap when a rule is saved.** It is not a soft guideline — it is
  the platform's hard limit, confirmed by a rejected build at 3,971 characters with the message
  *"Formula is too long ... Maximum length is 3,900 characters"* (locale-formatted with `.` as a
  thousands separator, which reads confusingly as "3.900" but means 3,900).
- **Don't over-engineer around per-evaluation cost.** The measured cost per build+evaluate cycle
  is a fraction of a millisecond. There is no realistic Vista 360 workload (per-record, per-tab
  card evaluation) that comes close to the CPU budget this consumes.
- **Picklist fields need `ISPICKVAL()`/`TEXT()`.** Bare equality or `ISBLANK()` against a
  picklist field is rejected by the platform — standard formula-language behavior, not specific
  to Vista 360. Surface the platform's own rejection message to whoever authors the rule.
- **An invalid formula fails at `build()`, before it is ever stored.** This is the write-time
  gate: unknown functions and misspelled identifiers are rejected immediately, not discovered
  later at evaluation time.

## A documented extension seam: building a formula against an Apex class instead of a record

`Formula.builder().withType()` does not require an SObject — it also accepts a plain, global
Apex class as the formula's context. This is useful the moment a rule needs a value that is not
a field on the record itself (a computed total, for instance), because the evaluator can hand
the formula a small Apex object carrying that computed value alongside the record.

This was verified by probing against a sandbox with a temporary class shaped like this:

```apex
global class ExampleFormulaContext {
    global Account Record;
    global Decimal TotalBalance;
}
```

Findings, all confirmed against a real org and consistent with the limits above:

- **Traversing into a record field through the Apex class works exactly like a direct field.**
  A formula can reference `Record.Name`, a picklist field via `TEXT(Record.Industry)`, and a
  plain (non-record) property like `TotalBalance`, and combine all of them in one expression —
  no different from writing a formula directly against the record.
- **`getReferencedFields()` follows the same pattern as parent-record traversal.** A record field
  reached through the Apex class comes back as `PropertyName.FieldName` (e.g.
  `Record.AnnualRevenue`); a plain top-level property on the Apex class comes back as its bare
  name (e.g. `TotalBalance`). The same "split on the dot" logic that detects parent-record
  traversal on a direct-record formula also correctly separates these two cases.
- **Per-evaluation cost is unchanged.** Building and evaluating a formula against this kind of
  Apex context costs the same order of magnitude per cycle as evaluating directly against a
  record — there is no meaningful extra cost from the indirection.

None of this is used by any production code today — it is a confirmed, ready-to-use option for
the day a rule needs a computed value the record itself doesn't carry.

## Methodology

These numbers come from probing `FormulaEval` with anonymous Apex against a sandbox org — a
read-only exercise with no permanent org changes (a temporary test class was deployed, run, and
then deleted to confirm the build/evaluate-in-test-context behavior; a second temporary class
was deployed, probed, and deleted the same way to confirm the Apex-context behavior above). No
script is committed to this repository; the findings above are the durable, reusable output of
that exercise.
