@IsTest
private class V360CardCatalogSelectorTest {

    @TestSetup
    static void setupTestData() {
        V360_Tab__c tab = V360TestDataFactory.insertTab('V360Test_Tab', 'Account');
        V360TestDataFactory.insertCard(
            tab.Id, 'V360Test_CardA', new V360_Card__c(ComponentType__c = 'LWC', ComponentName__c = 'v360AccountSnapshot')
        );
        V360_Card__c cardB = V360TestDataFactory.insertCard(
            tab.Id, 'V360Test_CardB', new V360_Card__c(ComponentType__c = 'Flow', ComponentName__c = 'V360_Test_Flow')
        );
        cardB.AnchorSObject__c = 'Contact';
        cardB.KillSwitch__c = true;
        update cardB;
    }

    @IsTest
    static void getCardsForTabReturnsMappedCardsWhenTabHasCards() {
        // Given
        V360CardCatalogSelector selector = new V360CardCatalogSelector();

        // When
        Test.startTest();
        List<V360CardCatalogDTO> cards = selector.getCardsForTab('V360Test_Tab');
        Test.stopTest();

        // Then
        Assert.areEqual(2, cards.size(), 'Both catalog rows under the tab should be returned');
    }

    @IsTest
    static void getCardsForTabInheritsTabAnchorWhenCardHasNoOverride() {
        // Given
        V360CardCatalogSelector selector = new V360CardCatalogSelector();

        // When
        Test.startTest();
        List<V360CardCatalogDTO> cards = selector.getCardsForTab('V360Test_Tab');
        Test.stopTest();

        // Then
        V360CardCatalogDTO cardA = findByDeveloperName(cards, 'V360Test_CardA');
        Assert.areEqual('Account', cardA.anchorSObject, 'A card with no override should inherit the tab anchor');
    }

    @IsTest
    static void getCardsForTabUsesCardOverrideWhenCardAnchorIsSet() {
        // Given
        V360CardCatalogSelector selector = new V360CardCatalogSelector();

        // When
        Test.startTest();
        List<V360CardCatalogDTO> cards = selector.getCardsForTab('V360Test_Tab');
        Test.stopTest();

        // Then
        V360CardCatalogDTO cardB = findByDeveloperName(cards, 'V360Test_CardB');
        Assert.areEqual('Contact', cardB.anchorSObject, 'A card override should win over the tab default');
        Assert.isTrue(cardB.killSwitch, 'The kill-switch flag should be mapped onto the DTO');
    }

    @IsTest
    static void getCardsForTabReturnsEmptyListWhenTabApiNameIsBlank() {
        // Given
        V360CardCatalogSelector selector = new V360CardCatalogSelector();

        // When
        Test.startTest();
        List<V360CardCatalogDTO> cards = selector.getCardsForTab('');
        Test.stopTest();

        // Then
        Assert.areEqual(0, cards.size(), 'A blank tab API name should short-circuit to an empty list');
    }

    @IsTest
    static void getCardsForTabReturnsEmptyListWhenTabHasNoCards() {
        // Given
        V360CardCatalogSelector selector = new V360CardCatalogSelector();

        // When
        Test.startTest();
        List<V360CardCatalogDTO> cards = selector.getCardsForTab('V360Test_Unknown_Tab');
        Test.stopTest();

        // Then
        Assert.areEqual(0, cards.size(), 'An unknown tab should return no cards, not an error');
    }

    private static V360CardCatalogDTO findByDeveloperName(List<V360CardCatalogDTO> cards, String developerName) {
        for (V360CardCatalogDTO card : cards) {
            if (card.developerName == developerName) {
                return card;
            }
        }
        Assert.fail('No card found with developer name: ' + developerName);
        return null;
    }
}
