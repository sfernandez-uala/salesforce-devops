@IsTest
private class V360CardRuleSelectorTest {

    @TestSetup
    static void setupTestData() {
        V360_Tab__c tab = V360TestDataFactory.insertTab('V360Test_RuleTab', 'Account');
        V360_Card__c ruledCard = V360TestDataFactory.insertCard(
            tab.Id, 'V360Test_RuledCard', new V360_Card__c(ComponentType__c = 'LWC', ComponentName__c = 'v360Snapshot')
        );
        V360_CardRule__c rule = V360TestDataFactory.insertCardRule(
            ruledCard.Id, 'V360Test_Rule', 'ISPICKVAL(Industry, \'Banking\')'
        );
        V360TestDataFactory.insertRulePredicate(rule.Id, 'PERMISSION_SET', 'V360_Sample_PermSet');
        V360TestDataFactory.insertRulePredicate(rule.Id, 'FLS_READ', 'Industry');

        V360TestDataFactory.insertCard(
            tab.Id, 'V360Test_RuleFreeCard', new V360_Card__c(ComponentType__c = 'LWC', ComponentName__c = 'v360Other')
        );
    }

    @IsTest
    static void getRulesForCardsReturnsRuleGraphWhenCardHasRulesAndPredicates() {
        // Given
        V360_Card__c ruledCard = [SELECT Id FROM V360_Card__c WHERE DeveloperName__c = 'V360Test_RuledCard'];
        V360_Card__c ruleFreeCard = [SELECT Id FROM V360_Card__c WHERE DeveloperName__c = 'V360Test_RuleFreeCard'];
        V360CardRuleSelector selector = new V360CardRuleSelector();

        // When
        Test.startTest();
        Map<Id, V360RuleGraph> ruleGraphByCardId = selector.getRulesForCards(
            new Set<Id>{ ruledCard.Id, ruleFreeCard.Id }
        );
        Test.stopTest();

        // Then
        V360RuleGraph ruleGraph = ruleGraphByCardId.get(ruledCard.Id);
        Assert.areEqual(1, ruleGraph.rules.size(), 'The ruled card should have exactly one rule row');
        Assert.areEqual(2, ruleGraph.rules[0].predicates.size(), 'The rule should carry both predicate rows');
    }

    @IsTest
    static void getRulesForCardsOmitsEntryWhenCardHasNoRules() {
        // Given
        V360_Card__c ruleFreeCard = [SELECT Id FROM V360_Card__c WHERE DeveloperName__c = 'V360Test_RuleFreeCard'];
        V360CardRuleSelector selector = new V360CardRuleSelector();

        // When
        Test.startTest();
        Map<Id, V360RuleGraph> ruleGraphByCardId = selector.getRulesForCards(new Set<Id>{ ruleFreeCard.Id });
        Test.stopTest();

        // Then
        Assert.isFalse(
            ruleGraphByCardId.containsKey(ruleFreeCard.Id),
            'A card with no rules should have no entry at all, not an empty one'
        );
    }

    @IsTest
    static void getRulesForCardsReturnsEmptyMapWhenCardIdsIsEmpty() {
        // Given
        V360CardRuleSelector selector = new V360CardRuleSelector();

        // When
        Test.startTest();
        Map<Id, V360RuleGraph> ruleGraphByCardId = selector.getRulesForCards(new Set<Id>());
        Test.stopTest();

        // Then
        Assert.areEqual(0, ruleGraphByCardId.size(), 'An empty card Id set should short-circuit to an empty map');
    }

    @IsTest
    static void getRulesForCardsMapsPredicateFieldsWhenPredicatesArePresent() {
        // Given
        V360_Card__c ruledCard = [SELECT Id FROM V360_Card__c WHERE DeveloperName__c = 'V360Test_RuledCard'];
        V360CardRuleSelector selector = new V360CardRuleSelector();

        // When
        Test.startTest();
        V360RuleGraph.PredicateRow predicate = selector.getRulesForCards(new Set<Id>{ ruledCard.Id })
            .get(ruledCard.Id).rules[0].predicates[0];
        Test.stopTest();

        // Then
        Assert.areEqual('PERMISSION_SET', predicate.predicateType, 'Predicate type should map through as stored');
        Assert.areEqual('V360_Sample_PermSet', predicate.targetApiName, 'Predicate target should map through as stored');
    }
}
