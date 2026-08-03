/**
 * Decides which cards under a tab are visible to the current evaluation
 * context. Every dependency is injected — this class issues no SOQL and no
 * DML of its own; it only orchestrates the catalog, rule, user-context, and
 * formula seams plus the predicate evaluator.
 *
 * Per-card precedence, evaluated in order:
 *   1. Kill-switch or inactive card — hidden, absolute, no other rule matters.
 *   2. One or more active rule rows — the card is visible only if every
 *      active rule passes (a rule passes when its formula, if present,
 *      evaluates true AND every one of its predicates passes).
 *   3. No active rules configured — visible by default.
 * Any error while evaluating a rule hides that card (fail-closed) and
 * records a diagnostic; it never surfaces the error to the caller.
 *
 * The anchor record is supplied by the caller, already resolved for the
 * SObject type this evaluation targets — this class has no path to read
 * a record itself, keeping it free of SOQL/DML and independently testable
 * with plain in-memory stubs.
 */
public with sharing class V360VisibilityEvaluator {

    private final ICardCatalogSource catalogSource;
    private final ICardRuleSource ruleSource;
    private final IFormulaEngine formulaEngine;
    private final V360PredicateEvaluator predicateEvaluator;
    private final V360Diagnostics diagnostics;

    /**
     * The full set of collaborators the evaluator works through. Grouped in
     * one holder so construction sites stay readable as seams grow.
     */
    public class Services {
        public ICardCatalogSource catalogSource;
        public ICardRuleSource ruleSource;
        public IUserContext userContext;
        public IFormulaEngine formulaEngine;
        public V360Diagnostics diagnostics;
    }

    public V360VisibilityEvaluator(Services services) {
        this.catalogSource = services.catalogSource;
        this.ruleSource = services.ruleSource;
        this.formulaEngine = services.formulaEngine;
        this.predicateEvaluator = new V360PredicateEvaluator(services.userContext);
        this.diagnostics = services.diagnostics;
    }

    /**
     * @param recordId the record the tab is being evaluated for
     * @param tabApiName the tab's stable developer name
     * @param record the already-resolved anchor record used by rule formulas/predicates
     * @return the visible cards for this tab, presentation-overlaid and sorted by order
     */
    public List<V360CardDecision> evaluate(Id recordId, String tabApiName, SObject record) {
        List<V360CardCatalogDTO> cards = catalogSource.getCardsForTab(tabApiName);
        if (cards.isEmpty()) {
            return new List<V360CardDecision>();
        }

        Map<Id, V360RuleGraph> ruleGraphsByCardId = ruleSource.getRulesForCards(collectCardIds(cards));
        EvalContext ctx = buildContext(recordId, tabApiName, record);

        List<V360CardDecision> visibleCards = new List<V360CardDecision>();
        for (V360CardCatalogDTO card : cards) {
            if (isVisible(card, ruleGraphsByCardId.get(card.cardId), ctx)) {
                visibleCards.add(toDecision(card));
            }
        }

        diagnostics.publishAll(ctx.entries);
        visibleCards.sort(new OrderComparator());
        return visibleCards;
    }

    /** Everything one evaluation pass shares across cards and rules. */
    private class EvalContext {
        Id recordId;
        String tabApiName;
        SObject record;
        String sObjectApiName;
        List<V360Diagnostics.Entry> entries = new List<V360Diagnostics.Entry>();

        void addEntry(V360CardCatalogDTO card, V360Diagnostics.Reason reason, String detail) {
            V360Diagnostics.Entry entry = new V360Diagnostics.Entry();
            entry.recordId = this.recordId;
            entry.tabName = this.tabApiName;
            entry.cardName = card.developerName;
            entry.reason = reason;
            entry.detail = detail;
            entries.add(entry);
        }
    }

    private EvalContext buildContext(Id recordId, String tabApiName, SObject record) {
        EvalContext ctx = new EvalContext();
        ctx.recordId = recordId;
        ctx.tabApiName = tabApiName;
        ctx.record = record;
        ctx.sObjectApiName = record == null
            ? null
            : record.getSObjectType().getDescribe().getName();
        return ctx;
    }

    private Set<Id> collectCardIds(List<V360CardCatalogDTO> cards) {
        Set<Id> cardIds = new Set<Id>();
        for (V360CardCatalogDTO card : cards) {
            cardIds.add(card.cardId);
        }
        return cardIds;
    }

    private Boolean isVisible(V360CardCatalogDTO card, V360RuleGraph ruleGraph, EvalContext ctx) {
        if (card.killSwitch || !card.active) {
            return false;
        }
        if (ruleGraph == null || ruleGraph.rules.isEmpty()) {
            return true;
        }
        for (V360RuleGraph.RuleRow rule : ruleGraph.rules) {
            if (rule.active && !rulePasses(rule, card, ctx)) {
                return false;
            }
        }
        return true;
    }

    private Boolean rulePasses(V360RuleGraph.RuleRow rule, V360CardCatalogDTO card, EvalContext ctx) {
        return passesFormula(rule, card, ctx) && passesPredicates(rule, card, ctx);
    }

    private Boolean passesFormula(V360RuleGraph.RuleRow rule, V360CardCatalogDTO card, EvalContext ctx) {
        if (String.isBlank(rule.visibilityFormula)) {
            return true;
        }
        try {
            formulaEngine.build(rule.visibilityFormula, ctx.record.getSObjectType());
        } catch (Exception buildException) {
            ctx.addEntry(card, V360Diagnostics.Reason.FORMULA_INVALID, buildException.getMessage());
            return false;
        }
        try {
            return formulaEngine.evaluate(ctx.record);
        } catch (Exception evaluateException) {
            ctx.addEntry(card, V360Diagnostics.Reason.FORMULA_EVAL_ERROR, evaluateException.getMessage());
            return false;
        }
    }

    private Boolean passesPredicates(V360RuleGraph.RuleRow rule, V360CardCatalogDTO card, EvalContext ctx) {
        for (V360RuleGraph.PredicateRow predicate : rule.predicates) {
            Boolean predicatePassed;
            try {
                predicatePassed = predicateEvaluator.evaluate(predicate, ctx.sObjectApiName);
            } catch (Exception predicateException) {
                ctx.addEntry(card, V360Diagnostics.Reason.PREDICATE_ERROR, predicateException.getMessage());
                return false;
            }
            if (!predicatePassed) {
                return false;
            }
        }
        return true;
    }

    private V360CardDecision toDecision(V360CardCatalogDTO card) {
        V360CardDecision decision = new V360CardDecision();
        decision.cardName = card.developerName;
        decision.componentType = card.componentType;
        decision.componentName = card.componentName;
        decision.label = card.label;
        decision.description = card.description;
        decision.iconName = card.iconName;
        decision.buttonLabel = card.buttonLabel;
        decision.order = card.order;
        return decision;
    }

    private class OrderComparator implements Comparator<V360CardDecision> {
        public Integer compare(V360CardDecision a, V360CardDecision b) {
            Integer orderA = a.order == null ? 0 : a.order;
            Integer orderB = b.order == null ? 0 : b.order;
            return orderA - orderB;
        }
    }
}
