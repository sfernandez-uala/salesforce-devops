@IsTest
private class V360AdminServiceTest {

    private static final String TEST_PROFILE = 'Standard User';

    private static User adminUser() {
        return V360TestDataFactory.insertUserWithAccess(TEST_PROFILE, new List<String>{ 'V360_Admin' });
    }

    @IsTest
    static void saveTabsSucceedsWhenUserHasManagePermission() {
        User admin = adminUser();
        V360_Tab__c newTab = new V360_Tab__c(
            DeveloperName__c = 'V360Test_Admin_Tab',
            AnchorSObject__c = 'Account',
            Sequence__c = 1,
            Active__c = true
        );

        System.runAs(admin) {
            Test.startTest();
            List<Database.UpsertResult> results = V360AdminService.saveTabs(new List<V360_Tab__c>{ newTab });
            Test.stopTest();

            Assert.areEqual(1, results.size(), 'One upsert result should come back for one tab');
            Assert.isTrue(results[0].isSuccess(), 'A well-formed tab save by an admin must succeed');
        }
    }

    @IsTest
    static void saveCardsSucceedsWhenLwcBindingIsNonBlank() {
        User admin = adminUser();
        V360_Tab__c tab = V360TestDataFactory.insertTab('V360Test_Admin_LwcTab', 'Account');
        V360_Card__c newCard = new V360_Card__c(
            DeveloperName__c = 'V360Test_Admin_LwcCard',
            Tab__c = tab.Id,
            ComponentType__c = 'LWC',
            ComponentName__c = 'v360AccountSnapshot',
            Label__c = 'Snapshot'
        );

        System.runAs(admin) {
            Test.startTest();
            List<Database.UpsertResult> results = V360AdminService.saveCards(new List<V360_Card__c>{ newCard });
            Test.stopTest();

            Assert.isTrue(results[0].isSuccess(), 'A valid, non-blank LWC binding must save successfully');
        }
    }

    @IsTest
    static void saveCardRulesSucceedsWhenFormulaIsValid() {
        User admin = adminUser();
        V360_Tab__c tab = V360TestDataFactory.insertTab('V360Test_Admin_RuleTab', 'Account');
        V360_Card__c card = V360TestDataFactory.insertCard(
            tab.Id, 'V360Test_Admin_RuleCard', new V360_Card__c(ComponentType__c = 'LWC', ComponentName__c = 'v360Snapshot')
        );
        V360_CardRule__c newRule = new V360_CardRule__c(
            Card__c = card.Id,
            DeveloperName__c = 'V360Test_Admin_Rule',
            VisibilityFormula__c = 'ISPICKVAL(Industry, \'Banking\')'
        );

        System.runAs(admin) {
            Test.startTest();
            List<Database.UpsertResult> results = V360AdminService.saveCardRules(new List<V360_CardRule__c>{ newRule });
            Test.stopTest();

            Assert.isTrue(results[0].isSuccess(), 'A syntactically valid formula must be accepted at save');
        }
    }

    @IsTest
    static void saveRulePredicatesSucceedsAndPreservesTheMasterDetailParentReference() {
        User admin = adminUser();
        V360_Tab__c tab = V360TestDataFactory.insertTab('V360Test_Admin_PredTab', 'Account');
        V360_Card__c card = V360TestDataFactory.insertCard(
            tab.Id, 'V360Test_Admin_PredCard', new V360_Card__c(ComponentType__c = 'LWC', ComponentName__c = 'v360Snapshot')
        );
        V360_CardRule__c rule = V360TestDataFactory.insertCardRule(card.Id, 'V360Test_Admin_PredRule', null);
        V360_RulePredicate__c newPredicate = new V360_RulePredicate__c(
            CardRule__c = rule.Id,
            PredicateType__c = 'FLS_READ',
            TargetApiName__c = 'AnnualRevenue'
        );

        List<Database.UpsertResult> results;
        System.runAs(admin) {
            Test.startTest();
            results = V360AdminService.saveRulePredicates(new List<V360_RulePredicate__c>{ newPredicate });
            Test.stopTest();
        }

        Assert.isTrue(
            results[0].isSuccess(),
            'A well-formed predicate save by an admin must succeed: ' + results[0].getErrors()
        );
        V360_RulePredicate__c saved = [
            SELECT CardRule__c FROM V360_RulePredicate__c WHERE Id = :results[0].getId()
        ];
        Assert.areEqual(
            rule.Id,
            saved.CardRule__c,
            'The required master-detail parent reference must never be stripped from a predicate save'
        );
    }

    @IsTest
    static void saveTabsThrowsWhenUserLacksManagePermission() {
        User plainUser = V360TestDataFactory.insertUserWithAccess(TEST_PROFILE, null);
        V360_Tab__c newTab = new V360_Tab__c(
            DeveloperName__c = 'V360Test_Denied_Tab',
            AnchorSObject__c = 'Account'
        );

        System.runAs(plainUser) {
            Test.startTest();
            Boolean threw = false;
            try {
                V360AdminService.saveTabs(new List<V360_Tab__c>{ newTab });
                Assert.fail('Expected a permission-denied exception');
            } catch (V360AdminService.V360AdminServiceException ex) {
                threw = true;
            }
            Test.stopTest();

            Assert.isTrue(threw, 'A user without V360_ManageVisibilityRules must be rejected before any DML runs');
        }
    }

    @IsTest
    static void saveCardsThrowsWhenLwcComponentNameIsBlank() {
        User admin = adminUser();
        V360_Tab__c tab = V360TestDataFactory.insertTab('V360Test_Admin_BlankLwcTab', 'Account');
        V360_Card__c invalidCard = new V360_Card__c(
            DeveloperName__c = 'V360Test_Admin_BlankLwcCard',
            Tab__c = tab.Id,
            ComponentType__c = 'LWC',
            ComponentName__c = ''
        );

        System.runAs(admin) {
            Test.startTest();
            Boolean threw = false;
            try {
                V360AdminService.saveCards(new List<V360_Card__c>{ invalidCard });
                Assert.fail('Expected a blank LWC binding to be rejected');
            } catch (V360AdminService.V360AdminServiceException ex) {
                threw = true;
            }
            Test.stopTest();

            Assert.isTrue(threw, 'An LWC card must name a non-blank component');
        }
    }

    @IsTest
    static void saveCardsThrowsWhenFlowBindingHasNoActiveScreenFlow() {
        User admin = adminUser();
        V360_Tab__c tab = V360TestDataFactory.insertTab('V360Test_Admin_FlowTab', 'Account');
        V360_Card__c invalidCard = new V360_Card__c(
            DeveloperName__c = 'V360Test_Admin_FlowCard',
            Tab__c = tab.Id,
            ComponentType__c = 'Flow',
            ComponentName__c = 'V360_Test_Nonexistent_Flow_XYZ'
        );

        System.runAs(admin) {
            Test.startTest();
            Boolean threw = false;
            try {
                V360AdminService.saveCards(new List<V360_Card__c>{ invalidCard });
                Assert.fail('Expected a Flow binding with no active screen flow to be rejected');
            } catch (V360AdminService.V360AdminServiceException ex) {
                threw = true;
            }
            Test.stopTest();

            Assert.isTrue(threw, 'A Flow card must name an active screen flow');
        }
    }

    @IsTest
    static void saveCardRulesThrowsWhenFormulaIsInvalid() {
        User admin = adminUser();
        V360_Tab__c tab = V360TestDataFactory.insertTab('V360Test_Admin_BadFormulaTab', 'Account');
        V360_Card__c card = V360TestDataFactory.insertCard(
            tab.Id, 'V360Test_Admin_BadFormulaCard',
            new V360_Card__c(ComponentType__c = 'LWC', ComponentName__c = 'v360Snapshot')
        );
        V360_CardRule__c invalidRule = new V360_CardRule__c(
            Card__c = card.Id,
            DeveloperName__c = 'V360Test_Admin_BadFormula',
            VisibilityFormula__c = 'ISPICKVAL(Industry, \'Banking\') AND ('
        );

        System.runAs(admin) {
            Test.startTest();
            Boolean threw = false;
            try {
                V360AdminService.saveCardRules(new List<V360_CardRule__c>{ invalidRule });
                Assert.fail('Expected a syntactically invalid formula to be rejected at save');
            } catch (V360AdminService.V360AdminServiceException ex) {
                threw = true;
            }
            Test.stopTest();

            Assert.isTrue(threw, 'An invalid formula must never be persisted');
        }
    }

    @IsTest
    static void saveCardsSilentlyStripsFieldWhenUserLacksFlsOnThatFieldOnly() {
        CustomPermission managePermission = [
            SELECT Id FROM CustomPermission WHERE DeveloperName = 'V360_ManageVisibilityRules'
        ];
        V360_Tab__c tab = V360TestDataFactory.insertTab('V360Test_Admin_FlsTab', 'Account');
        User scopedUser = V360TestDataFactory.insertUserWithAccess(TEST_PROFILE, null);

        System.runAs(new User(Id = UserInfo.getUserId())) {
            PermissionSet scopedPermSet = new PermissionSet(
                Label = 'V360 Test Scoped Card Access',
                Name = 'V360_Test_Scoped_' + String.valueOf(DateTime.now().getTime())
            );
            insert scopedPermSet;
            insert new List<ObjectPermissions>{
                new ObjectPermissions(
                    ParentId = scopedPermSet.Id,
                    SobjectType = 'V360_Card__c',
                    PermissionsRead = true,
                    PermissionsCreate = true,
                    PermissionsEdit = true
                ),
                // A required lookup (Tab__c) can never carry its own explicit FieldPermissions row
                // (the platform rejects it — required fields aren't valid FLS targets), but
                // Security.stripInaccessible still strips it unless the user can also read the
                // referenced object — so V360_Tab__c needs at least object-level read here.
                new ObjectPermissions(
                    ParentId = scopedPermSet.Id,
                    SobjectType = 'V360_Tab__c',
                    PermissionsRead = true
                )
            };
            insert new List<FieldPermissions>{
                new FieldPermissions(
                    ParentId = scopedPermSet.Id, SobjectType = 'V360_Card__c',
                    Field = 'V360_Card__c.Order__c', PermissionsRead = true, PermissionsEdit = true
                ),
                new FieldPermissions(
                    ParentId = scopedPermSet.Id, SobjectType = 'V360_Card__c',
                    Field = 'V360_Card__c.Active__c', PermissionsRead = true, PermissionsEdit = true
                )
                // Label__c is deliberately left with no grant, to prove it gets silently stripped.
            };
            insert new SetupEntityAccess(ParentId = scopedPermSet.Id, SetupEntityId = managePermission.Id);
            insert new PermissionSetAssignment(AssigneeId = scopedUser.Id, PermissionSetId = scopedPermSet.Id);
        }

        V360_Card__c cardToSave = new V360_Card__c(
            DeveloperName__c = 'V360Test_Admin_FlsCard',
            Tab__c = tab.Id,
            ComponentType__c = 'LWC',
            ComponentName__c = 'v360Snapshot',
            Label__c = 'Should be stripped',
            Order__c = 7
        );

        List<Database.UpsertResult> results;
        System.runAs(scopedUser) {
            Test.startTest();
            results = V360AdminService.saveCards(new List<V360_Card__c>{ cardToSave });
            Test.stopTest();
        }

        Assert.isTrue(
            results[0].isSuccess(),
            'The scoped user must be able to create the card at all: ' + results[0].getErrors()
        );
        V360_Card__c savedCard = [
            SELECT Label__c, Order__c FROM V360_Card__c WHERE DeveloperName__c = 'V360Test_Admin_FlsCard'
        ];
        Assert.isNull(savedCard.Label__c, 'A field with no FLS grant must be silently stripped, not saved');
        Assert.areEqual(7, Integer.valueOf(savedCard.Order__c), 'A granted field must still save normally');
    }

    @IsTest
    static void configCardQueryThrowsWhenUserIsEndUserOnly() {
        User endUser = V360TestDataFactory.insertUserWithAccess(TEST_PROFILE, new List<String>{ 'V360_EndUser' });

        System.runAs(endUser) {
            Test.startTest();
            Boolean threw = false;
            try {
                Integer cardCount = [SELECT COUNT() FROM V360_Card__c WITH USER_MODE];
                Assert.fail('Expected a denial for end-user config read access, got count: ' + cardCount);
            } catch (System.SecurityException securityException) {
                threw = true;
            }
            Test.stopTest();

            Assert.isTrue(threw, 'An end user must have zero read access to the config catalog by design');
        }
    }
}
