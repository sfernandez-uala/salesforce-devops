/**
 * The set of visibility rules attached to one card, each with its own
 * structured predicates. A card with no rules configured has no
 * V360RuleGraph at all (see ICardRuleSource) rather than an empty one —
 * callers should treat "no entry" as the default-visible case.
 *
 * The rows are alternatives, not requirements: one card, one row per audience
 * that should reach it. c/V360VisibilityEvaluator owns that reading and the
 * two cases it turns on — a row switched off, and a row not yet written.
 */
public class V360RuleGraph {
    public Id cardId;
    public List<RuleRow> rules;

    public V360RuleGraph(Id cardId, List<RuleRow> rules) {
        this.cardId = cardId;
        this.rules = rules == null ? new List<RuleRow>() : rules;
    }

    /**
     * One visibility rule row: an optional boolean formula plus zero or more
     * structured predicates. Passes only when its formula (if present)
     * evaluates true AND every one of its predicates passes.
     *
     * Plain data holder: construct empty and assign fields.
     */
    public class RuleRow {
        public Id ruleId;
        public String developerName;
        public String visibilityFormula;
        public Boolean active = true;
        public List<PredicateRow> predicates = new List<PredicateRow>();
    }

    /**
     * One structured predicate row — a condition a formula cannot express:
     * a Permission Set assignment check, or a field-level-security read check.
     */
    public class PredicateRow {
        public String predicateType;
        public String targetApiName;

        public PredicateRow(String predicateType, String targetApiName) {
            this.predicateType = predicateType;
            this.targetApiName = targetApiName;
        }
    }
}
