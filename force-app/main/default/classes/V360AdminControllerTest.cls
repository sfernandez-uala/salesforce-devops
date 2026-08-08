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

    /**
     * The evaluator only lets an *active* rule block a card
     * (V360VisibilityEvaluator: `if (rule.active && !rulePasses(...))`), so a
     * card whose rules are all inactive is visible to everyone -- exactly as
     * if it had none. A single total cannot express that difference, so the
     * catalog reports both counts and the console warns on the effective one.
     */
    /**
     * The editor offers only what V360FormulaGateway enables. Permission sets
     * are absent on purpose: $Permission is a Custom Permission, and permission
     * set membership is the PERMISSION_SET predicate's job, not a formula's.
     */
    @IsTest
    static void formulaVocabularyServesInsertableIdentityValues() {
        User admin = V360TestDataFactory.insertUserWithAccess(TEST_PROFILE, new List<String>{ 'V360_Admin' });

        System.runAs(admin) {
            Test.startTest();
            V360AdminController.FormulaVocabulary vocabulary = V360AdminController.getFormulaVocabulary();
            Test.stopTest();

            Assert.isNotNull(vocabulary.customPermissions, 'Custom permissions must always be a list');
            Assert.isNotNull(vocabulary.profiles, 'Profiles must always be a list');
            Assert.isFalse(vocabulary.profiles.isEmpty(), 'Every org has at least one profile');

            V360AdminController.VocabularyEntry profileEntry = vocabulary.profiles[0];
            Assert.isNotNull(profileEntry.label, 'A profile entry needs a label to pick from');
            // A profile name carries spaces, so the inserted text has to quote
            // it or the formula will not build.
            Assert.isTrue(
                profileEntry.insertText.startsWith('$Profile.Name = "'),
                'A profile must be inserted as a quoted comparison, got: ' + profileEntry.insertText
            );
        }
    }

    @IsTest
    static void formulaVocabularyIsEmptyWithoutTheManagePermission() {
        User plainUser = V360TestDataFactory.insertUserWithAccess(TEST_PROFILE, null);

        System.runAs(plainUser) {
            Test.startTest();
            V360AdminController.FormulaVocabulary vocabulary = V360AdminController.getFormulaVocabulary();
            Test.stopTest();

            // Empty rather than an error: the console already renders its own
            // access state from getCatalog.
            Assert.isTrue(vocabulary.customPermissions.isEmpty(), 'No vocabulary without the manage permission');
            Assert.isTrue(vocabulary.profiles.isEmpty(), 'No vocabulary without the manage permission');
        }
    }

    @IsTest
    static void getCatalogCountsActiveRulesSeparatelyFromTheTotal() {
        User admin = V360TestDataFactory.insertUserWithAccess(TEST_PROFILE, new List<String>{ 'V360_Admin' });
        V360_Tab__c tab = V360TestDataFactory.insertTab('V360Test_ActiveRules_Tab', 'Account');
        V360_Card__c guarded = V360TestDataFactory.insertCard(
            tab.Id,
            'V360Test_ActiveRules_Guarded',
            new V360_Card__c(ComponentType__c = 'LWC', ComponentName__c = 'v360AccountSnapshot', Order__c = 1)
        );
        V360_Card__c parkedOnly = V360TestDataFactory.insertCard(
            tab.Id,
            'V360Test_ActiveRules_ParkedOnly',
            new V360_Card__c(ComponentType__c = 'LWC', ComponentName__c = 'v360LifecycleDemo', Order__c = 2)
        );
        V360TestDataFactory.insertCardRule(guarded.Id, 'V360Test_ActiveRules_On', null);
        // The factory activates every rule it inserts, so park these two in a
        // second DML -- the state a data load or a sandbox refresh can produce.
        V360_CardRule__c parkedOnGuarded = V360TestDataFactory.insertCardRule(
            guarded.Id,
            'V360Test_ActiveRules_OffA',
            null
        );
        V360_CardRule__c parkedOnOpenCard = V360TestDataFactory.insertCardRule(
            parkedOnly.Id,
            'V360Test_ActiveRules_OffB',
            null
        );
        parkedOnGuarded.Active__c = false;
        parkedOnOpenCard.Active__c = false;
        update new List<V360_CardRule__c>{ parkedOnGuarded, parkedOnOpenCard };

        System.runAs(admin) {
            Test.startTest();
            V360AdminController.AdminCatalog catalog = V360AdminController.getCatalog();
            Test.stopTest();

            V360AdminController.AdminTab adminTab = findTab(catalog, 'V360Test_ActiveRules_Tab');
            Assert.areEqual(2, adminTab.cards[0].ruleCount, 'Both of the guarded card rules count toward the total');
            Assert.areEqual(
                1,
                adminTab.cards[0].activeRuleCount,
                'Only the active rule of the guarded card restricts anyone'
            );
            Assert.areEqual(1, adminTab.cards[1].ruleCount, 'The parked-only card still reports its stored rule');
            Assert.areEqual(
                0,
                adminTab.cards[1].activeRuleCount,
                'A card whose every rule is parked restricts nobody and must report zero'
            );
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
            // What matters is that the engine's own sentence survives to the
            // admin, not that a layer of our own prefixes wraps it. The
            // previous assertion pinned the prefix, which is how the message
            // ended up reading "Formula failed to validate: Formula failed to
            // build: Syntax error".
            Assert.isTrue(
                bad.message.contains('Syntax error'),
                'The rejection must carry what the engine actually objected to: ' + bad.message
            );
            Assert.isFalse(
                bad.message.contains('failed to validate: Formula failed to build'),
                'The rejection must not stack one prefix on another: ' + bad.message
            );
            // The platform writes its build errors for the Setup UI, anchor tag
            // and all. None of that markup may reach a client.
            Assert.isFalse(bad.message.contains('<'), 'The rejection must carry no markup: ' + bad.message);
        }
    }

    @IsTest
    static void activateCardTakesADraftCardLive() {
        User admin = V360TestDataFactory.insertUserWithAccess(TEST_PROFILE, new List<String>{ 'V360_Admin' });
        V360_Tab__c tab = V360TestDataFactory.insertTab('V360Test_Activate_Tab', 'Account');
        V360_Card__c draft = V360TestDataFactory.insertCard(
            tab.Id,
            'V360Test_Activate_Card',
            new V360_Card__c(ComponentType__c = 'LWC', ComponentName__c = 'v360AccountSnapshot', Active__c = false)
        );

        System.runAs(admin) {
            Test.startTest();
            V360AdminController.activateCard(draft.Id);
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
            V360AdminController.CardPropertiesInput input = new V360AdminController.CardPropertiesInput();
            input.cardId = card.Id;
            input.label = 'Renamed';
            input.description = 'Shows the renamed details.';
            input.iconName = 'standard:contact';
            input.buttonLabel = 'Open';
            input.componentType = 'LWC';
            input.componentName = 'v360LifecycleDemo';
            V360AdminController.saveCardProperties(input);
            Test.stopTest();
        }

        V360_Card__c saved = [
            SELECT Label__c, Description__c, IconName__c, ButtonLabel__c, ComponentName__c
            FROM V360_Card__c
            WHERE Id = :card.Id
        ];
        Assert.areEqual('Renamed', saved.Label__c, 'The label must round-trip');
        Assert.areEqual('standard:contact', saved.IconName__c, 'The icon must round-trip');
        Assert.areEqual('Shows the renamed details.', saved.Description__c, 'The description must round-trip');
        Assert.areEqual('Open', saved.ButtonLabel__c, 'The button label must round-trip');
        Assert.areEqual('v360LifecycleDemo', saved.ComponentName__c, 'The binding must round-trip');
    }

    @IsTest
    static void saveRuleFormulaPersistsThroughTheGatedWritePath() {
        User admin = V360TestDataFactory.insertUserWithAccess(TEST_PROFILE, new List<String>{ 'V360_Admin' });
        V360_Tab__c tab = V360TestDataFactory.insertTab('V360Test_RuleSave_Tab', 'Account');
        V360_Card__c card = V360TestDataFactory.insertCard(
            tab.Id,
            'V360Test_RuleSave_Card',
            new V360_Card__c(ComponentType__c = 'LWC', ComponentName__c = 'v360AccountSnapshot')
        );
        V360_CardRule__c rule = V360TestDataFactory.insertCardRule(card.Id, 'V360Test_RuleSave_Rule', null);

        System.runAs(admin) {
            Test.startTest();
            V360AdminController.saveRuleFormula(rule.Id, card.Id, 'ISPICKVAL(Industry, \'Banking\')');
            Test.stopTest();
        }

        V360_CardRule__c saved = [SELECT VisibilityFormula__c, Card__c FROM V360_CardRule__c WHERE Id = :rule.Id];
        Assert.areEqual(
            'ISPICKVAL(Industry, \'Banking\')',
            saved.VisibilityFormula__c,
            'The formula must persist through the gated write path'
        );
        Assert.areEqual(card.Id, saved.Card__c, 'The card reference must survive the save');
    }

    @IsTest
    static void saveRuleFormulaThrowsWithoutTheManagePermission() {
        User plainUser = V360TestDataFactory.insertUserWithAccess(TEST_PROFILE, null);
        V360_Tab__c tab = V360TestDataFactory.insertTab('V360Test_RuleDenied_Tab', 'Account');
        V360_Card__c card = V360TestDataFactory.insertCard(
            tab.Id,
            'V360Test_RuleDenied_Card',
            new V360_Card__c(ComponentType__c = 'LWC', ComponentName__c = 'v360AccountSnapshot')
        );
        V360_CardRule__c rule = V360TestDataFactory.insertCardRule(card.Id, 'V360Test_RuleDenied_Rule', null);

        System.runAs(plainUser) {
            Test.startTest();
            Boolean threw = false;
            try {
                V360AdminController.saveRuleFormula(rule.Id, card.Id, '$Permission.V360_Advisor');
            } catch (AuraHandledException expected) {
                threw = true;
            }
            Test.stopTest();
            Assert.isTrue(threw, 'Saving a rule without the manage permission must be rejected');
        }
    }

    @IsTest
    static void createCardCreatesADraftWithItsProperties() {
        User admin = V360TestDataFactory.insertUserWithAccess(TEST_PROFILE, new List<String>{ 'V360_Admin' });
        V360_Tab__c tab = V360TestDataFactory.insertTab('V360Test_Create_Tab', 'Account');

        System.runAs(admin) {
            Test.startTest();
            V360AdminController.NewCardInput input = new V360AdminController.NewCardInput();
            input.tabId = tab.Id;
            input.developerName = 'V360Test_Created_Card';
            input.label = 'Created';
            input.description = 'Created from the wizard.';
            input.iconName = 'standard:account';
            input.buttonLabel = 'Open';
            input.componentType = 'LWC';
            input.componentName = 'v360AccountSnapshot';
            input.order = 4;
            V360AdminController.createCard(input);
            Test.stopTest();
        }

        V360_Card__c created = [
            SELECT Active__c, KillSwitch__c, Label__c, Order__c, Tab__c
            FROM V360_Card__c
            WHERE DeveloperName__c = 'V360Test_Created_Card'
        ];
        Assert.isFalse(created.Active__c, 'A new card must be born as a draft');
        Assert.isFalse(created.KillSwitch__c, 'A new card must not be kill-switched');
        Assert.areEqual('Created', created.Label__c, 'The label must round-trip');
        Assert.areEqual(4, created.Order__c, 'The order must round-trip');
        Assert.areEqual(tab.Id, created.Tab__c, 'The card must land on its tab');
    }

    @IsTest
    static void createRuleAndPredicateThenDeleteThemRoundTrips() {
        User admin = V360TestDataFactory.insertUserWithAccess(TEST_PROFILE, new List<String>{ 'V360_Admin' });
        V360_Tab__c tab = V360TestDataFactory.insertTab('V360Test_RuleCrud_Tab', 'Account');
        V360_Card__c card = V360TestDataFactory.insertCard(
            tab.Id,
            'V360Test_RuleCrud_Card',
            new V360_Card__c(ComponentType__c = 'LWC', ComponentName__c = 'v360AccountSnapshot')
        );

        System.runAs(admin) {
            Test.startTest();
            V360AdminController.createRule(card.Id, 'V360Test_Crud_Rule', 'ISPICKVAL(Industry, \'Banking\')');
            Id ruleId = [SELECT Id FROM V360_CardRule__c WHERE DeveloperName__c = 'V360Test_Crud_Rule'].Id;
            V360AdminController.addRulePredicate(ruleId, 'FLS_READ', 'AnnualRevenue');
            Id predicateId = [SELECT Id FROM V360_RulePredicate__c WHERE CardRule__c = :ruleId].Id;
            V360AdminController.deleteRulePredicate(predicateId);
            Assert.areEqual(
                0,
                [SELECT COUNT() FROM V360_RulePredicate__c WHERE CardRule__c = :ruleId],
                'The predicate must be gone after its deletion'
            );
            V360AdminController.deleteRule(ruleId);
            Test.stopTest();

            Assert.areEqual(
                0,
                [SELECT COUNT() FROM V360_CardRule__c WHERE Card__c = :card.Id],
                'The rule must be gone after its deletion'
            );
        }
    }

    @IsTest
    static void deleteCardRemovesItsRulesAndPredicatesFirst() {
        User admin = V360TestDataFactory.insertUserWithAccess(TEST_PROFILE, new List<String>{ 'V360_Admin' });
        V360_Tab__c tab = V360TestDataFactory.insertTab('V360Test_DeleteCard_Tab', 'Account');
        V360_Card__c card = V360TestDataFactory.insertCard(
            tab.Id,
            'V360Test_DeleteCard_Card',
            new V360_Card__c(ComponentType__c = 'LWC', ComponentName__c = 'v360AccountSnapshot')
        );
        V360_CardRule__c rule = V360TestDataFactory.insertCardRule(card.Id, 'V360Test_DeleteCard_Rule', null);
        insert new V360_RulePredicate__c(
            CardRule__c = rule.Id,
            PredicateType__c = 'FLS_READ',
            TargetApiName__c = 'AnnualRevenue'
        );

        System.runAs(admin) {
            Test.startTest();
            V360AdminController.deleteCard(card.Id);
            Test.stopTest();
        }

        Assert.areEqual(0, [SELECT COUNT() FROM V360_Card__c WHERE Id = :card.Id], 'The card must be gone');
        Assert.areEqual(0, [SELECT COUNT() FROM V360_CardRule__c WHERE Id = :rule.Id], 'Its rule must be gone');
        Assert.areEqual(
            0,
            [SELECT COUNT() FROM V360_RulePredicate__c WHERE CardRule__c = :rule.Id],
            'The rule predicates must cascade'
        );
    }

    @IsTest
    static void deleteCardThrowsWithoutTheManagePermission() {
        User plainUser = V360TestDataFactory.insertUserWithAccess(TEST_PROFILE, null);
        V360_Tab__c tab = V360TestDataFactory.insertTab('V360Test_DeleteDenied_Tab', 'Account');
        V360_Card__c card = V360TestDataFactory.insertCard(
            tab.Id,
            'V360Test_DeleteDenied_Card',
            new V360_Card__c(ComponentType__c = 'LWC', ComponentName__c = 'v360AccountSnapshot')
        );

        System.runAs(plainUser) {
            Test.startTest();
            Boolean threw = false;
            try {
                V360AdminController.deleteCard(card.Id);
            } catch (AuraHandledException expected) {
                threw = true;
            }
            Test.stopTest();
            Assert.isTrue(threw, 'Deleting a card without the manage permission must be rejected');
        }
    }

    @IsTest
    static void killSwitchEngagesAndReleases() {
        User admin = V360TestDataFactory.insertUserWithAccess(TEST_PROFILE, new List<String>{ 'V360_Admin' });
        V360_Tab__c tab = V360TestDataFactory.insertTab('V360Test_Kill_Tab', 'Account');
        V360_Card__c card = V360TestDataFactory.insertCard(
            tab.Id,
            'V360Test_Kill_Card',
            new V360_Card__c(ComponentType__c = 'LWC', ComponentName__c = 'v360AccountSnapshot')
        );

        System.runAs(admin) {
            Test.startTest();
            V360AdminController.engageKillSwitch(card.Id);
            Assert.isTrue(
                [SELECT KillSwitch__c FROM V360_Card__c WHERE Id = :card.Id].KillSwitch__c,
                'The kill switch must be on after engaging it'
            );
            V360AdminController.releaseKillSwitch(card.Id);
            Test.stopTest();
        }

        Assert.isFalse(
            [SELECT KillSwitch__c FROM V360_Card__c WHERE Id = :card.Id].KillSwitch__c,
            'The kill switch must be off after releasing it'
        );
    }

    @IsTest
    static void saveTabCreatesAndUpdatesATab() {
        User admin = V360TestDataFactory.insertUserWithAccess(TEST_PROFILE, new List<String>{ 'V360_Admin' });

        System.runAs(admin) {
            Test.startTest();
            V360AdminController.TabInput createInput = new V360AdminController.TabInput();
            createInput.developerName = 'V360Test_TabAbm';
            createInput.sObjectApiName = 'Case';
            createInput.sequence = 5;
            createInput.active = true;
            V360AdminController.saveTab(createInput);

            V360_Tab__c created = [SELECT Id, Active__c FROM V360_Tab__c WHERE DeveloperName__c = 'V360Test_TabAbm'];
            V360AdminController.TabInput updateInput = new V360AdminController.TabInput();
            updateInput.tabId = created.Id;
            updateInput.developerName = 'V360Test_TabAbm';
            updateInput.sObjectApiName = 'Case';
            updateInput.sequence = 6;
            updateInput.active = false;
            V360AdminController.saveTab(updateInput);
            Test.stopTest();

            V360_Tab__c updated = [
                SELECT Sequence__c, Active__c FROM V360_Tab__c WHERE DeveloperName__c = 'V360Test_TabAbm'
            ];
            Assert.areEqual(6, updated.Sequence__c, 'The sequence must round-trip on update');
            Assert.isFalse(updated.Active__c, 'The active flag must round-trip on update');
        }
    }

    @IsTest
    static void saveTabRejectsAnUnknownAnchorSObject() {
        User admin = V360TestDataFactory.insertUserWithAccess(TEST_PROFILE, new List<String>{ 'V360_Admin' });

        System.runAs(admin) {
            Test.startTest();
            Boolean threw = false;
            try {
                V360AdminController.TabInput input = new V360AdminController.TabInput();
                input.developerName = 'V360Test_BadAnchor';
                input.sObjectApiName = 'No_Such_Object__c';
                input.sequence = 1;
                input.active = true;
                V360AdminController.saveTab(input);
            } catch (AuraHandledException expected) {
                threw = true;
            }
            Test.stopTest();
            Assert.isTrue(threw, 'An unknown anchor SObject must be rejected at save');
        }
    }

    @IsTest
    static void deleteTabIsRejectedWhileItStillHasCards() {
        User admin = V360TestDataFactory.insertUserWithAccess(TEST_PROFILE, new List<String>{ 'V360_Admin' });
        V360_Tab__c tab = V360TestDataFactory.insertTab('V360Test_TabBusy', 'Account');
        V360TestDataFactory.insertCard(
            tab.Id,
            'V360Test_TabBusy_Card',
            new V360_Card__c(ComponentType__c = 'LWC', ComponentName__c = 'v360AccountSnapshot')
        );

        System.runAs(admin) {
            Test.startTest();
            Boolean threw = false;
            try {
                V360AdminController.deleteTab(tab.Id);
            } catch (AuraHandledException expected) {
                threw = true;
            }
            Test.stopTest();
            Assert.isTrue(threw, 'Deleting a tab that still has cards must be rejected');
        }
        Assert.areEqual(1, [SELECT COUNT() FROM V360_Tab__c WHERE Id = :tab.Id], 'The tab must survive');
    }

    @IsTest
    static void deleteTabRemovesAnEmptyTab() {
        User admin = V360TestDataFactory.insertUserWithAccess(TEST_PROFILE, new List<String>{ 'V360_Admin' });
        V360_Tab__c tab = V360TestDataFactory.insertTab('V360Test_TabEmpty', 'Account');

        System.runAs(admin) {
            Test.startTest();
            V360AdminController.deleteTab(tab.Id);
            Test.stopTest();
        }

        Assert.areEqual(0, [SELECT COUNT() FROM V360_Tab__c WHERE Id = :tab.Id], 'The empty tab must be gone');
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
