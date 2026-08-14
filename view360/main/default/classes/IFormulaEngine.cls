/**
 * Seam over the platform's formula evaluation engine. An implementation builds
 * one boolean formula against a target SObject type, then evaluates it against
 * an actual record of that type.
 *
 * An instance is reused one formula at a time: call build() for a formula,
 * then evaluate()/getReferencedFields() for that same formula, before calling
 * build() again for the next one. Callers decide what a build() failure means
 * for them — a write path treats it as a rejected save, a read path treats it
 * as a fail-closed decision.
 *
 * Kept as a pure contract so the evaluation core can be unit-tested with a stub,
 * with no dependency on a connected org or the real formula engine.
 */
public interface IFormulaEngine {
    /**
     * Builds and validates the given formula against the given anchor SObject type.
     * Throws when the formula is syntactically invalid, too long, or references
     * something that does not exist (an unknown field, function, or permission).
     *
     * @param formulaText the boolean formula in standard formula syntax
     * @param sObjectType the SObject type the formula is evaluated against
     */
    void build(String formulaText, Schema.SObjectType sObjectType);

    /**
     * Evaluates the most recently built formula against the given record.
     * Must only be called after a successful build().
     *
     * @param record the record to evaluate the formula against
     * @return the formula's boolean result
     */
    Boolean evaluate(SObject record);

    /**
     * Returns every field (including one-level parent-relationship paths, e.g.
     * "Parent.Website") the most recently built formula reads. Must only be
     * called after a successful build().
     *
     * @return the set of referenced field paths
     */
    Set<String> getReferencedFields();
}
