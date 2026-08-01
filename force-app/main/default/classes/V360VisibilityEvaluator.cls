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

    public V360VisibilityEvaluator(
        ICardCatalogSource catalogSource,
        ICardRuleSource ruleSource,
        IUserContext userContext,
        IFormulaEngine formulaEngine,
        V360Diagnostics diagnostics
    ) {
        this.catalogSource = catalogSource;
        this.ruleSource = ruleSource;
        this.formulaEngine = formulaEngine;
        this.predicateEvaluator = new V360PredicateEvaluator(userContext);
        this.diagnostics = diagnostics;
    }

    /**
     * @param recordId the record the tab is being evaluated for
     * @param tabApiName the tab's stable developer name
     * @param anchorRecord the already-resolved anchor record used by rule formulas/predicates
     * @return the visible cards for this tab, presentation-overlaid and sorted by order
     */
    public List<V360CardDecision> evaluate(Id recordId, String tabApiName, SObject anchorRecord) {
        List<V360CardCatalogDTO> cards = catalogSource.getCardsForTab(tabApiName);
        if (cards.isEmpty()) {
            return new List<V360CardDecision>();
        }

        Set<Id> cardIds = new Set<Id>();
        for (V360CardCatalogDTO card : cards) {
            cardIds.add(card.cardId);
        }
        Map<Id, V360RuleGraph> ruleGraphsByCardId = ruleSource.getRulesForCards(cardIds);
        String anchorSObjectApiName = anchorRecord == null
            ? null
            : anchorRecord.getSObjectType().getDescribe().getName();

        List<V360Diagnostics.Entry> diagnosticEntries = new List<V360Diagnostics.Entry>();
        List<V360CardDecision> visibleCards = new List<V360CardDecision>();

        for (V360CardCatalogDTO card : cards) {
            if (card.killSwitch || !card.active) {
                continue;
            }

            V360RuleGraph ruleGraph = ruleGraphsByCardId.get(card.cardId);
            Boolean cardIsVisible = ruleGraph == null || ruleGraph.rules.isEmpty()
                ? true
                : evaluateRules(ruleGraph, recordId, tabApiName, card, anchorRecord, anchorSObjectApiName, diagnosticEntries);

            if (cardIsVisible) {
                visibleCards.add(toDecision(card));
            }
        }

        diagnostics.publishAll(diagnosticEntries);
        visibleCards.sort(new OrderComparator());
        return visibleCards;
    }

    /**
     * A card's rule(s) pass only when every active rule row passes: each
     * rule's own formula (if present) must evaluate true AND every one of
     * that rule's predicates must pass. Any evaluation error hides the card
     * and records exactly one diagnostic for the failing step.
     */
    private Boolean evaluateRules(
        V360RuleGraph ruleGraph,
        Id recordId,
        String tabApiName,
        V360CardCatalogDTO card,
        SObject anchorRecord,
        String anchorSObjectApiName,
        List<V360Diagnostics.Entry> diagnosticEntries
    ) {
        for (V360RuleGraph.RuleRow rule : ruleGraph.rules) {
            if (!rule.active) {
                continue;
            }

            if (String.isNotBlank(rule.visibilityFormula)) {
                Boolean formulaPassed;
                try {
                    formulaEngine.build(rule.visibilityFormula, anchorRecord.getSObjectType());
                } catch (Exception buildException) {
                    diagnosticEntries.add(
                        new V360Diagnostics.Entry(
                            recordId, tabApiName, card.developerName,
                            V360Diagnostics.Reason.FORMULA_INVALID, buildException.getMessage()
                        )
                    );
                    return false;
                }
                try {
                    formulaPassed = formulaEngine.evaluate(anchorRecord);
                } catch (Exception evaluateException) {
                    diagnosticEntries.add(
                        new V360Diagnostics.Entry(
                            recordId, tabApiName, card.developerName,
                            V360Diagnostics.Reason.FORMULA_EVAL_ERROR, evaluateException.getMessage()
                        )
                    );
                    return false;
                }
                if (!formulaPassed) {
                    return false;
                }
            }

            for (V360RuleGraph.PredicateRow predicate : rule.predicates) {
                Boolean predicatePassed;
                try {
                    predicatePassed = predicateEvaluator.evaluate(predicate, anchorSObjectApiName);
                } catch (Exception predicateException) {
                    diagnosticEntries.add(
                        new V360Diagnostics.Entry(
                            recordId, tabApiName, card.developerName,
                            V360Diagnostics.Reason.PREDICATE_ERROR, predicateException.getMessage()
                        )
                    );
                    return false;
                }
                if (!predicatePassed) {
                    return false;
                }
            }
        }
        return true;
    }

    private V360CardDecision toDecision(V360CardCatalogDTO card) {
        return new V360CardDecision(
            card.developerName,
            card.componentType,
            card.componentName,
            card.label,
            card.iconName,
            card.buttonLabel,
            card.order
        );
    }

    private class OrderComparator implements Comparator<V360CardDecision> {
        public Integer compare(V360CardDecision a, V360CardDecision b) {
            Integer orderA = a.order == null ? 0 : a.order;
            Integer orderB = b.order == null ? 0 : b.order;
            return orderA - orderB;
        }
    }
}
