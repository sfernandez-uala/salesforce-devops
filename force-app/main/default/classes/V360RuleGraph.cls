/**
 * The set of visibility rules attached to one card, each with its own
 * structured predicates. A card with no rules configured has no
 * V360RuleGraph at all (see ICardRuleSource) rather than an empty one —
 * callers should treat "no entry" as the default-visible case.
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
     */
    public class RuleRow {
        public Id ruleId;
        public String developerName;
        public String visibilityFormula;
        public Boolean active;
        public List<PredicateRow> predicates;

        public RuleRow(
            Id ruleId,
            String developerName,
            String visibilityFormula,
            Boolean active,
            List<PredicateRow> predicates
        ) {
            this.ruleId = ruleId;
            this.developerName = developerName;
            this.visibilityFormula = visibilityFormula;
            this.active = active;
            this.predicates = predicates == null ? new List<PredicateRow>() : predicates;
        }
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
