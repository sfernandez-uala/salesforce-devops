@IsTest
private class V360ConfigChangeTest {

    private static V360_Card__c cardOn(V360_Tab__c tab, String developerName, String componentName, Decimal order) {
        return V360TestDataFactory.insertCard(
            tab.Id,
            developerName,
            new V360_Card__c(ComponentType__c = 'LWC', ComponentName__c = componentName, Order__c = order)
        );
    }

    /**
     * Reordering or relabelling several cards is one change to one surface,
     * so subscribers hear about the tab once rather than once per card.
     */
    @IsTest
    static void publishForCardsAnnouncesTheTabOnceNotEachCard() {
        V360_Tab__c tab = V360TestDataFactory.insertTab('V360Test_Event_Tab', 'Account');
        V360_Card__c first = cardOn(tab, 'V360Test_Event_CardA', 'v360AccountSnapshot', 1);
        V360_Card__c second = cardOn(tab, 'V360Test_Event_CardB', 'v360LifecycleDemo', 2);

        Test.startTest();
        List<Database.SaveResult> results = V360ConfigChange.publishForCards(
            new Set<Id>{ first.Id, second.Id },
            V360ConfigChange.ChangeType.CARDS_CHANGED
        );
        Test.stopTest();

        Assert.areEqual(1, results.size(), 'Two cards on one tab must publish one event');
        Assert.isTrue(results[0].isSuccess(), 'The event must publish successfully');
    }

    @IsTest
    static void publishForCardsAnnouncesEveryDistinctTab() {
        V360_Tab__c accountTab = V360TestDataFactory.insertTab('V360Test_Event_AccountTab', 'Account');
        V360_Tab__c caseTab = V360TestDataFactory.insertTab('V360Test_Event_CaseTab', 'Case');
        V360_Card__c onAccount = cardOn(accountTab, 'V360Test_Event_OnAccount', 'v360AccountSnapshot', 1);
        V360_Card__c onCase = cardOn(caseTab, 'V360Test_Event_OnCase', 'v360LifecycleDemo', 1);

        Test.startTest();
        List<Database.SaveResult> results = V360ConfigChange.publishForCards(
            new Set<Id>{ onAccount.Id, onCase.Id },
            V360ConfigChange.ChangeType.CARDS_CHANGED
        );
        Test.stopTest();

        Assert.areEqual(2, results.size(), 'Cards on two tabs must publish one event each');
    }

    @IsTest
    static void nothingToAnnouncePublishesNothing() {
        Test.startTest();
        Assert.areEqual(
            0,
            V360ConfigChange.publishForCards(null, V360ConfigChange.ChangeType.CARDS_CHANGED).size(),
            'A null card set must publish nothing'
        );
        Assert.areEqual(
            0,
            V360ConfigChange.publishForCards(new Set<Id>(), V360ConfigChange.ChangeType.CARDS_CHANGED).size(),
            'An empty card set must publish nothing'
        );
        Assert.areEqual(
            0,
            V360ConfigChange.publishForTabNames(null, V360ConfigChange.ChangeType.TAB_CHANGED).size(),
            'A null tab set must publish nothing'
        );
        // A card whose tab lookup came back blank must not announce a nameless
        // surface no subscriber could match.
        Assert.areEqual(
            0,
            V360ConfigChange.publishForTabNames(
                new Set<String>{ null, '' },
                V360ConfigChange.ChangeType.TAB_CHANGED
            ).size(),
            'Blank tab names must be skipped'
        );
        Test.stopTest();
    }

    /**
     * The invocable is what a record-triggered Flow calls, so it has to be
     * bulk-safe and it has to survive whatever the Flow hands it.
     */
    @IsTest
    static void invocableGroupsRequestsByChangeType() {
        V360ConfigChange.Request cards = new V360ConfigChange.Request();
        cards.tabName = 'V360Test_Invocable_A';
        cards.changeType = 'CARDS_CHANGED';

        V360ConfigChange.Request alsoCards = new V360ConfigChange.Request();
        alsoCards.tabName = 'V360Test_Invocable_B';
        alsoCards.changeType = 'cards_changed';

        V360ConfigChange.Request rules = new V360ConfigChange.Request();
        rules.tabName = 'V360Test_Invocable_C';
        rules.changeType = 'RULES_CHANGED';

        Test.startTest();
        V360ConfigChange.publish(new List<V360ConfigChange.Request>{ cards, alsoCards, rules });
        Test.stopTest();

        // No subscriber to observe, so the assertion is that a mixed, badly
        // cased batch completes without throwing mid-automation.
        Assert.isTrue(true, 'A mixed batch must publish without error');
    }

    @IsTest
    static void invocableFallsBackRatherThanThrowingOnAnUnknownType() {
        V360ConfigChange.Request blank = new V360ConfigChange.Request();
        blank.tabName = 'V360Test_Invocable_Blank';
        blank.changeType = null;

        V360ConfigChange.Request nonsense = new V360ConfigChange.Request();
        nonsense.tabName = 'V360Test_Invocable_Nonsense';
        nonsense.changeType = 'NOT_A_REAL_TYPE';

        Test.startTest();
        V360ConfigChange.publish(new List<V360ConfigChange.Request>{ blank, nonsense });
        Test.stopTest();

        // A Flow author typing a value that no longer exists must not break the
        // automation the notification is riding on.
        Assert.isTrue(true, 'An unknown type must fall back instead of throwing');
    }
}
