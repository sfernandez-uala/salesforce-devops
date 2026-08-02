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
        return resolveVisibleCards(recordId, tabApiName);
    }

    @AuraEnabled
    public static List<V360CardDecision> getVisibleCardsFresh(Id recordId, String tabApiName) {
        return resolveVisibleCards(recordId, tabApiName);
    }

    private static List<V360CardDecision> resolveVisibleCards(Id recordId, String tabApiName) {
        try {
            return evaluate(recordId, tabApiName);
        } catch (Exception unexpected) {
            throw new AuraHandledException('Unable to resolve visible cards for this tab.');
        }
    }

    private static List<V360CardDecision> evaluate(Id recordId, String tabApiName) {
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
        V360Diagnostics diagnostics = new V360Diagnostics();

        V360AnchorRecordSelector.Request anchorRequest = new V360AnchorRecordSelector.Request();
        anchorRequest.recordId = recordId;
        anchorRequest.tabApiName = tabApiName;
        anchorRequest.anchorSObjectApiName = cards[0].anchorSObject;
        anchorRequest.cards = cards;
        anchorRequest.ruleGraphsByCardId = ruleGraphsByCardId;
        anchorRequest.formulaEngine = formulaEngine;
        anchorRequest.diagnostics = diagnostics;
        SObject anchorRecord = new V360AnchorRecordSelector().resolveAnchorRecord(anchorRequest);

        V360VisibilityEvaluator.Services services = new V360VisibilityEvaluator.Services();
        services.catalogSource = catalogSource;
        services.ruleSource = ruleSource;
        services.userContext = new V360UserContext();
        services.formulaEngine = formulaEngine;
        services.diagnostics = diagnostics;

        return new V360VisibilityEvaluator(services).evaluate(recordId, tabApiName, anchorRecord);
    }

    private static Set<Id> collectCardIds(List<V360CardCatalogDTO> cards) {
        Set<Id> cardIds = new Set<Id>();
        for (V360CardCatalogDTO card : cards) {
            cardIds.add(card.cardId);
        }
        return cardIds;
    }
}
