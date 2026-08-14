/**
 * The thin @AuraEnabled boundary the frontend calls: resolves the visible
 * cards for a record's tab and returns them, wiring every collaborator the
 * evaluator needs. Holds no logic of its own beyond that wiring — the
 * decision is entirely the evaluator's.
 *
 * getVisibleCards is cacheable for @wire/LDS composition; getVisibleCardsFresh
 * is the non-cacheable escape hatch for incident-grade forced reads. Both
 * resolve the same way; only the caching contract differs.
 *
 * Note on cost: the catalog and rule graph are read here (to resolve the
 * anchor record's field set) and read again inside the evaluator's own
 * frozen contract, which takes an already-built anchor record and re-reads
 * both sources itself. That duplication is intentional — the evaluator's
 * signature stays untouched — and is governor-trivial: both reads are one
 * SOQL each, over the tiny per-tab configuration volume a real tab ever has.
 */
public with sharing class V360VisibilityController {

    @AuraEnabled(cacheable=true)
    public static List<V360CardDecision> getVisibleCards(Id recordId, String tabApiName) {
        // A cacheable method may not perform DML, and publishing a diagnostic
        // is DML -- so this path collects diagnostics and publishes none.
        // Publishing here did not lose a diagnostic, it failed the whole read.
        return resolveVisibleCards(recordId, tabApiName, false);
    }

    @AuraEnabled
    public static List<V360CardDecision> getVisibleCardsFresh(Id recordId, String tabApiName) {
        // Not cacheable, so this is where a fail-closed decision gets recorded.
        // The shell calls it on retry and whenever an admin changes the tab.
        return resolveVisibleCards(recordId, tabApiName, true);
    }

    private static List<V360CardDecision> resolveVisibleCards(Id recordId, String tabApiName, Boolean publishDiagnostics) {
        try {
            return evaluate(recordId, tabApiName, publishDiagnostics);
        } catch (Exception unexpected) {
            throw new AuraHandledException('Unable to resolve visible cards for this tab.');
        }
    }

    private static List<V360CardDecision> evaluate(Id recordId, String tabApiName, Boolean publishDiagnostics) {
        if (recordId == null || String.isBlank(tabApiName)) {
            return new List<V360CardDecision>();
        }

        ICardCatalogSource catalogSource = new V360CardCatalogSelector();
        List<V360CardCatalogDTO> cards = catalogSource.getCardsForTab(tabApiName);
        if (cards.isEmpty()) {
            return new List<V360CardDecision>();
        }

        ICardRuleSource ruleSource = new V360CardRuleSelector();
        Map<Id, V360RuleGraph> ruleGraphsByCardId = ruleSource.getRulesForCards(collectCardIds(cards));

        IFormulaEngine formulaEngine = new V360FormulaGateway();
        V360Diagnostics diagnostics = new V360Diagnostics(publishDiagnostics);

        V360RecordSelector.Request request = new V360RecordSelector.Request();
        request.recordId = recordId;
        request.tabApiName = tabApiName;
        request.sObjectApiName = cards[0].sObjectApiName;
        request.cards = cards;
        request.ruleGraphsByCardId = ruleGraphsByCardId;
        request.formulaEngine = formulaEngine;
        request.diagnostics = diagnostics;
        SObject record = new V360RecordSelector().resolveRecord(request);

        V360VisibilityEvaluator.Services services = new V360VisibilityEvaluator.Services();
        services.catalogSource = catalogSource;
        services.ruleSource = ruleSource;
        services.userContext = new V360UserContext();
        services.formulaEngine = formulaEngine;
        services.diagnostics = diagnostics;

        return new V360VisibilityEvaluator(services).evaluate(recordId, tabApiName, record);
    }

    private static Set<Id> collectCardIds(List<V360CardCatalogDTO> cards) {
        Set<Id> cardIds = new Set<Id>();
        for (V360CardCatalogDTO card : cards) {
            cardIds.add(card.cardId);
        }
        return cardIds;
    }
}
