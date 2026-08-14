/**
 * System-mode read of Vista 360 visibility rules and their predicates. Runs
 * without sharing for the same reason as the catalog selector
 * (V360CardCatalogSelector): end users have no direct access to rule
 * configuration, so this selector reads the full rule graph on the
 * evaluator's behalf regardless of the calling user's own sharing access.
 */
public without sharing class V360CardRuleSelector implements ICardRuleSource {

    // Deliberately system-mode, same rationale as V360CardCatalogSelector: end users have no
    // read access to rule configuration by design.
    @SuppressWarnings('PMD.ApexCRUDViolation')
    public Map<Id, V360RuleGraph> getRulesForCards(Set<Id> cardIds) {
        Map<Id, V360RuleGraph> ruleGraphByCardId = new Map<Id, V360RuleGraph>();
        if (cardIds == null || cardIds.isEmpty()) {
            return ruleGraphByCardId;
        }

        List<V360_CardRule__c> ruleRecords = [
            SELECT Id, Card__c, DeveloperName__c, VisibilityFormula__c, Active__c,
                   (SELECT PredicateType__c, TargetApiName__c FROM V360_Rule_Predicates__r)
            FROM V360_CardRule__c
            WHERE Card__c IN :cardIds
        ];

        Map<Id, List<V360RuleGraph.RuleRow>> ruleRowsByCardId = new Map<Id, List<V360RuleGraph.RuleRow>>();
        for (V360_CardRule__c ruleRecord : ruleRecords) {
            List<V360RuleGraph.RuleRow> ruleRows = ruleRowsByCardId.get(ruleRecord.Card__c);
            if (ruleRows == null) {
                ruleRows = new List<V360RuleGraph.RuleRow>();
                ruleRowsByCardId.put(ruleRecord.Card__c, ruleRows);
            }
            ruleRows.add(toRuleRow(ruleRecord));
        }

        for (Id cardId : ruleRowsByCardId.keySet()) {
            ruleGraphByCardId.put(cardId, new V360RuleGraph(cardId, ruleRowsByCardId.get(cardId)));
        }
        return ruleGraphByCardId;
    }

    private V360RuleGraph.RuleRow toRuleRow(V360_CardRule__c ruleRecord) {
        V360RuleGraph.RuleRow ruleRow = new V360RuleGraph.RuleRow();
        ruleRow.ruleId = ruleRecord.Id;
        ruleRow.developerName = ruleRecord.DeveloperName__c;
        ruleRow.visibilityFormula = ruleRecord.VisibilityFormula__c;
        ruleRow.active = ruleRecord.Active__c;
        for (V360_RulePredicate__c predicateRecord : ruleRecord.V360_Rule_Predicates__r) {
            ruleRow.predicates.add(
                new V360RuleGraph.PredicateRow(predicateRecord.PredicateType__c, predicateRecord.TargetApiName__c)
            );
        }
        return ruleRow;
    }
}
