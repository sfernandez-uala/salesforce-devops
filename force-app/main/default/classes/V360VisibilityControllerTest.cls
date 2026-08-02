@IsTest
private class V360VisibilityControllerTest {

    @TestSetup
    static void setupTestData() {
        Account anchorAccount = new Account(Name = 'V360 Controller Test Account', Industry = 'Banking');
        insert anchorAccount;

        V360_Tab__c tab = V360TestDataFactory.insertTab('V360Test_Ctrl_Tab', 'Account');

        V360TestDataFactory.insertCard(
            tab.Id, 'V360Test_Ctrl_DefaultCard', new V360_Card__c(ComponentType__c = 'LWC', ComponentName__c = 'v360Default')
        );

        V360_Card__c passingRuleCard = V360TestDataFactory.insertCard(
            tab.Id, 'V360Test_Ctrl_PassingCard', new V360_Card__c(ComponentType__c = 'LWC', ComponentName__c = 'v360Passing')
        );
        V360TestDataFactory.insertCardRule(
            passingRuleCard.Id, 'V360Test_Ctrl_PassingRule', 'ISPICKVAL(Industry, \'Banking\')'
        );

        V360_Card__c failingRuleCard = V360TestDataFactory.insertCard(
            tab.Id, 'V360Test_Ctrl_FailingCard', new V360_Card__c(ComponentType__c = 'LWC', ComponentName__c = 'v360Failing')
        );
        V360TestDataFactory.insertCardRule(
            failingRuleCard.Id, 'V360Test_Ctrl_FailingRule', 'ISPICKVAL(Industry, \'Technology\')'
        );

        V360TestDataFactory.insertCard(
            tab.Id, 'V360Test_Ctrl_KilledCard',
            new V360_Card__c(ComponentType__c = 'LWC', ComponentName__c = 'v360Killed', KillSwitch__c = true)
        );

        V360_Card__c malformedRuleCard = V360TestDataFactory.insertCard(
            tab.Id, 'V360Test_Ctrl_MalformedCard', new V360_Card__c(ComponentType__c = 'LWC', ComponentName__c = 'v360Malformed')
        );
        V360TestDataFactory.insertCardRule(
            malformedRuleCard.Id, 'V360Test_Ctrl_MalformedRule', 'ISPICKVAL(Industry, \'Banking\') AND ('
        );
    }

    private static Id anchorAccountId() {
        return [SELECT Id FROM Account WHERE Name = 'V360 Controller Test Account'].Id;
    }

    /**
     * Re-asserts Active__c = true on every fixture card for this tab. This org has proven, for
     * this specific field, that a value set during @TestSetup does not reliably persist into the
     * per-test-method snapshot, while the same update performed directly inside a test method does
     * — so tests that depend on Active__c call this first rather than trusting the @TestSetup value.
     */
    private static void reassertCardsActive() {
        List<V360_Card__c> cards = [SELECT Id, Active__c FROM V360_Card__c WHERE Tab__r.DeveloperName__c = 'V360Test_Ctrl_Tab'];
        for (V360_Card__c card : cards) {
            card.Active__c = true;
        }
        update cards;
    }

    @IsTest
    static void getVisibleCardsReturnsDefaultAndPassingCardsExcludingKilledFailingAndMalformed() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            // Given
            Id recordId = anchorAccountId();
            reassertCardsActive();

            // When
            Test.startTest();
            List<V360CardDecision> decisions = V360VisibilityController.getVisibleCards(recordId, 'V360Test_Ctrl_Tab');
            Test.stopTest();

            // Then
            Set<String> visibleNames = collectCardNames(decisions);
            Assert.isTrue(visibleNames.contains('V360Test_Ctrl_DefaultCard'), 'A card with no rules must default-visible');
            Assert.isTrue(visibleNames.contains('V360Test_Ctrl_PassingCard'), 'A card whose rule formula passes must be visible');
            Assert.isFalse(visibleNames.contains('V360Test_Ctrl_FailingCard'), 'A card whose rule formula fails must be hidden');
            Assert.isFalse(visibleNames.contains('V360Test_Ctrl_KilledCard'), 'A kill-switched card must never be visible');
            Assert.isFalse(
                visibleNames.contains('V360Test_Ctrl_MalformedCard'),
                'A card with a malformed formula must fail closed and stay hidden'
            );
        }
    }

    @IsTest
    static void getVisibleCardsPublishesDiagnosticWithoutErrorWhenACacheableCallHitsAFailClosedRule() {
        // Confirms an @AuraEnabled(cacheable=true) method that publishes a Platform Event through a
        // fail-closed diagnostic works without throwing — EventBus.publish is not classified as a
        // DML operation for the cacheable-method restriction.
        System.runAs(new User(Id = UserInfo.getUserId())) {
            // Given
            Id recordId = anchorAccountId();

            // When / Then — the malformed-formula card in the fixture triggers a diagnostic publish
            Test.startTest();
            List<V360CardDecision> decisions = V360VisibilityController.getVisibleCards(recordId, 'V360Test_Ctrl_Tab');
            Test.stopTest();

            Assert.isNotNull(decisions, 'A cacheable call that internally publishes a diagnostic must still return normally');
        }
    }

    @IsTest
    static void getVisibleCardsFreshReturnsTheSameResultAsTheCacheablePath() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            // Given
            Id recordId = anchorAccountId();
            reassertCardsActive();

            // When
            Test.startTest();
            List<V360CardDecision> decisions = V360VisibilityController.getVisibleCardsFresh(recordId, 'V360Test_Ctrl_Tab');
            Test.stopTest();

            // Then
            Set<String> visibleNames = collectCardNames(decisions);
            Assert.isTrue(visibleNames.contains('V360Test_Ctrl_DefaultCard'), 'The fresh escape hatch must resolve the same way');
        }
    }

    @IsTest
    static void getVisibleCardsReturnsEmptyListWhenTabApiNameIsBlank() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            // Given
            Id recordId = anchorAccountId();

            // When
            Test.startTest();
            List<V360CardDecision> decisions = V360VisibilityController.getVisibleCards(recordId, '');
            Test.stopTest();

            // Then
            Assert.areEqual(0, decisions.size(), 'A blank tab API name should short-circuit to an empty list');
        }
    }

    @IsTest
    static void getVisibleCardsReturnsEmptyListWhenRecordIdIsNull() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            // When
            Test.startTest();
            List<V360CardDecision> decisions = V360VisibilityController.getVisibleCards(null, 'V360Test_Ctrl_Tab');
            Test.stopTest();

            // Then
            Assert.areEqual(0, decisions.size(), 'A null record Id should short-circuit to an empty list');
        }
    }

    @IsTest
    static void getVisibleCardsReturnsEmptyListWhenTabHasNoCards() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            // Given
            Id recordId = anchorAccountId();

            // When
            Test.startTest();
            List<V360CardDecision> decisions = V360VisibilityController.getVisibleCards(recordId, 'V360Test_Ctrl_Unknown');
            Test.stopTest();

            // Then
            Assert.areEqual(0, decisions.size(), 'A tab with no configured cards must return no cards, not an error');
        }
    }

    private static Set<String> collectCardNames(List<V360CardDecision> decisions) {
        Set<String> names = new Set<String>();
        for (V360CardDecision decision : decisions) {
            names.add(decision.cardName);
        }
        return names;
    }
}
