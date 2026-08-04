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
            new V360_Card__c(
                ComponentType__c = 'LWC',
                ComponentName__c = 'v360AccountSnapshot',
                Order__c = 1,
                ButtonLabel__c = 'Open'
            )
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
            Assert.areEqual('Open', adminTab.cards[0].buttonLabel, 'The tile button label must round-trip');
            Assert.areEqual(0, adminTab.cards[1].ruleCount, 'A card with no rules reports zero');
        }
    }

    @IsTest
    static void updateCardOrderRewritesTheSequenceForAdmins() {
        User admin = V360TestDataFactory.insertUserWithAccess(TEST_PROFILE, new List<String>{ 'V360_Admin' });
        V360_Tab__c tab = V360TestDataFactory.insertTab('V360Test_Reorder_Tab', 'Account');
        V360_Card__c first = V360TestDataFactory.insertCard(
            tab.Id,
            'V360Test_Reorder_CardA',
            new V360_Card__c(ComponentType__c = 'LWC', ComponentName__c = 'v360AccountSnapshot', Order__c = 1)
        );
        V360_Card__c second = V360TestDataFactory.insertCard(
            tab.Id,
            'V360Test_Reorder_CardB',
            new V360_Card__c(ComponentType__c = 'LWC', ComponentName__c = 'v360LifecycleDemo', Order__c = 2)
        );

        System.runAs(admin) {
            Test.startTest();
            V360AdminController.updateCardOrder(new List<Id>{ second.Id, first.Id });
            Test.stopTest();
        }

        Map<Id, V360_Card__c> saved = new Map<Id, V360_Card__c>(
            [SELECT Order__c FROM V360_Card__c WHERE Id IN :new List<Id>{ first.Id, second.Id }]
        );
        Assert.areEqual(1, saved.get(second.Id).Order__c, 'The first id in the sequence becomes order 1');
        Assert.areEqual(2, saved.get(first.Id).Order__c, 'The second id in the sequence becomes order 2');
    }

    @IsTest
    static void updateCardOrderThrowsWithoutTheManagePermission() {
        User plainUser = V360TestDataFactory.insertUserWithAccess(TEST_PROFILE, null);
        V360_Tab__c tab = V360TestDataFactory.insertTab('V360Test_ReorderDenied_Tab', 'Account');
        V360_Card__c card = V360TestDataFactory.insertCard(
            tab.Id,
            'V360Test_ReorderDenied_Card',
            new V360_Card__c(ComponentType__c = 'LWC', ComponentName__c = 'v360AccountSnapshot', Order__c = 1)
        );

        System.runAs(plainUser) {
            Test.startTest();
            Boolean threw = false;
            try {
                V360AdminController.updateCardOrder(new List<Id>{ card.Id });
            } catch (AuraHandledException expected) {
                threw = true;
            }
            Test.stopTest();
            Assert.isTrue(threw, 'Reordering without the manage permission must be rejected');
        }
    }

    @IsTest
    static void getCatalogReturnsRulesWithPredicatesOnTheirCard() {
        User admin = V360TestDataFactory.insertUserWithAccess(TEST_PROFILE, new List<String>{ 'V360_Admin' });
        V360_Tab__c tab = V360TestDataFactory.insertTab('V360Test_Rules_Tab', 'Account');
        V360_Card__c card = V360TestDataFactory.insertCard(
            tab.Id,
            'V360Test_Rules_Card',
            new V360_Card__c(ComponentType__c = 'LWC', ComponentName__c = 'v360AccountSnapshot', Order__c = 1)
        );
        V360_CardRule__c rule = V360TestDataFactory.insertCardRule(
            card.Id,
            'V360Test_Rules_Rule',
            'ISPICKVAL(Industry, \'Banking\')'
        );
        insert new V360_RulePredicate__c(
            CardRule__c = rule.Id,
            PredicateType__c = 'FLS_READ',
            TargetApiName__c = 'AnnualRevenue'
        );

        System.runAs(admin) {
            Test.startTest();
            V360AdminController.AdminCatalog catalog = V360AdminController.getCatalog();
            Test.stopTest();

            V360AdminController.AdminCard adminCard = findTab(catalog, 'V360Test_Rules_Tab').cards[0];
            Assert.areEqual(1, adminCard.rules.size(), 'The card carries its rule');
            Assert.areEqual(
                'ISPICKVAL(Industry, \'Banking\')',
                adminCard.rules[0].formula,
                'The rule formula must round-trip'
            );
            Assert.areEqual(1, adminCard.rules[0].predicates.size(), 'The rule carries its predicate');
            Assert.areEqual('FLS_READ', adminCard.rules[0].predicates[0].predicateType, 'Predicate type round-trips');
        }
    }

    @IsTest
    static void validateRuleFormulaReportsValidAndInvalidFormulas() {
        User admin = V360TestDataFactory.insertUserWithAccess(TEST_PROFILE, new List<String>{ 'V360_Admin' });
        V360_Tab__c tab = V360TestDataFactory.insertTab('V360Test_Validate_Tab', 'Account');
        V360_Card__c card = V360TestDataFactory.insertCard(
            tab.Id,
            'V360Test_Validate_Card',
            new V360_Card__c(ComponentType__c = 'LWC', ComponentName__c = 'v360AccountSnapshot', Order__c = 1)
        );

        System.runAs(admin) {
            Test.startTest();
            V360AdminController.FormulaValidation good = V360AdminController.validateRuleFormula(
                card.Id,
                'ISPICKVAL(Industry, \'Banking\')'
            );
            V360AdminController.FormulaValidation bad = V360AdminController.validateRuleFormula(
                card.Id,
                'ISPICKVAL(Industry, \'Banking\''
            );
            Test.stopTest();

            Assert.isTrue(good.isValid, 'A well-formed formula must validate: ' + good.message);
            Assert.isFalse(bad.isValid, 'A malformed formula must be rejected');
            Assert.isTrue(
                bad.message.startsWith('Formula failed to validate'),
                'The rejection carries the engine message: ' + bad.message
            );
        }
    }

    @IsTest
    static void setCardActiveActivatesADraftCard() {
        User admin = V360TestDataFactory.insertUserWithAccess(TEST_PROFILE, new List<String>{ 'V360_Admin' });
        V360_Tab__c tab = V360TestDataFactory.insertTab('V360Test_Activate_Tab', 'Account');
        V360_Card__c draft = V360TestDataFactory.insertCard(
            tab.Id,
            'V360Test_Activate_Card',
            new V360_Card__c(ComponentType__c = 'LWC', ComponentName__c = 'v360AccountSnapshot', Active__c = false)
        );

        System.runAs(admin) {
            Test.startTest();
            V360AdminController.setCardActive(draft.Id, true);
            Test.stopTest();
        }

        Assert.isTrue(
            [SELECT Active__c FROM V360_Card__c WHERE Id = :draft.Id].Active__c,
            'The draft card must be active after activation'
        );
    }

    @IsTest
    static void saveCardPropertiesUpdatesPresentationAndBinding() {
        User admin = V360TestDataFactory.insertUserWithAccess(TEST_PROFILE, new List<String>{ 'V360_Admin' });
        V360_Tab__c tab = V360TestDataFactory.insertTab('V360Test_Props_Tab', 'Account');
        V360_Card__c card = V360TestDataFactory.insertCard(
            tab.Id,
            'V360Test_Props_Card',
            new V360_Card__c(ComponentType__c = 'LWC', ComponentName__c = 'v360AccountSnapshot')
        );

        System.runAs(admin) {
            Test.startTest();
            V360AdminController.saveCardProperties(
                card.Id,
                'Renamed',
                'Shows the renamed details.',
                'Open',
                'LWC',
                'v360LifecycleDemo'
            );
            Test.stopTest();
        }

        V360_Card__c saved = [
            SELECT Label__c, Description__c, ButtonLabel__c, ComponentName__c
            FROM V360_Card__c
            WHERE Id = :card.Id
        ];
        Assert.areEqual('Renamed', saved.Label__c, 'The label must round-trip');
        Assert.areEqual('Shows the renamed details.', saved.Description__c, 'The description must round-trip');
        Assert.areEqual('Open', saved.ButtonLabel__c, 'The button label must round-trip');
        Assert.areEqual('v360LifecycleDemo', saved.ComponentName__c, 'The binding must round-trip');
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
