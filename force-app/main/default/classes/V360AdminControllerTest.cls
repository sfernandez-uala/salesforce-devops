@IsTest
private class V360AdminControllerTest {

    private static final String TEST_PROFILE = 'Standard User';

    @IsTest
    static void getCatalogReturnsNoDataWithoutTheManagePermission() {
        User plainUser = V360TestDataFactory.insertUserWithAccess(TEST_PROFILE, null);
        // Real configuration exists, so an empty result proves the
        // permission gate, not an empty org.
        V360TestDataFactory.insertTab('V360Test_Denied_Tab', 'Account');

        System.runAs(plainUser) {
            Test.startTest();
            V360AdminController.AdminCatalog catalog = V360AdminController.getCatalog();
            Test.stopTest();

            Assert.isFalse(
                catalog.hasManagePermission,
                'A user without the manage permission must be reported as such'
            );
            Assert.areEqual(0, catalog.tabs.size(), 'No configuration data may be returned without permission');
        }
    }

    @IsTest
    static void getCatalogReturnsTheConfigurationGraphForAdmins() {
        User admin = V360TestDataFactory.insertUserWithAccess(TEST_PROFILE, new List<String>{ 'V360_Admin' });
        V360_Tab__c tab = V360TestDataFactory.insertTab('V360Test_AdminUi_Tab', 'Account');
        V360_Card__c firstCard = V360TestDataFactory.insertCard(
            tab.Id,
            'V360Test_AdminUi_CardA',
            new V360_Card__c(ComponentType__c = 'LWC', ComponentName__c = 'v360AccountSnapshot', Order__c = 1)
        );
        V360TestDataFactory.insertCard(
            tab.Id,
            'V360Test_AdminUi_CardB',
            new V360_Card__c(ComponentType__c = 'LWC', ComponentName__c = 'v360LifecycleDemo', Order__c = 2)
        );
        V360TestDataFactory.insertCardRule(firstCard.Id, 'V360Test_AdminUi_Rule', null);

        System.runAs(admin) {
            Test.startTest();
            V360AdminController.AdminCatalog catalog = V360AdminController.getCatalog();
            Test.stopTest();

            Assert.isTrue(catalog.hasManagePermission, 'The admin must be reported as permitted');
            V360AdminController.AdminTab adminTab = findTab(catalog, 'V360Test_AdminUi_Tab');
            Assert.areEqual('Account', adminTab.sObjectApiName, 'The tab anchor must round-trip');
            Assert.areEqual(2, adminTab.cards.size(), 'Both cards of the tab must be returned');
            Assert.areEqual(
                'V360Test_AdminUi_CardA',
                adminTab.cards[0].developerName,
                'Cards must come back in Order__c sequence'
            );
            Assert.areEqual(1, adminTab.cards[0].ruleCount, 'The first card carries its one rule');
            Assert.areEqual(0, adminTab.cards[1].ruleCount, 'A card with no rules reports zero');
        }
    }

    private static V360AdminController.AdminTab findTab(
        V360AdminController.AdminCatalog catalog,
        String developerName
    ) {
        for (V360AdminController.AdminTab candidate : catalog.tabs) {
            if (candidate.developerName == developerName) {
                return candidate;
            }
        }
        Assert.fail('Expected tab not found in catalog: ' + developerName);
        return null;
    }
}
