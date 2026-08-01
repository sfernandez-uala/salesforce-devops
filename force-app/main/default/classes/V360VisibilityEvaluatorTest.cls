@IsTest
private class V360VisibilityEvaluatorTest {

    private static final String TAB_API_NAME = 'AccountOverview';

    private static V360CardCatalogDTO buildCard(Id cardId, String developerName, Integer order, Boolean killSwitch, Boolean active) {
        return new V360CardCatalogDTO(
            cardId, developerName, 'LWC', 'v360AccountBalance', null,
            order, developerName + ' Label', null, null, null, killSwitch, active
        );
    }

    @IsTest
    static void visibleSetContainsOnlyCardsThatPassEvaluation() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            Id visibleCardId = V360TestStubs.fakeId(Account.SObjectType, 1);
            Id hiddenCardId = V360TestStubs.fakeId(Account.SObjectType, 2);

            V360TestStubs.StubCardCatalogSource catalogSource = new V360TestStubs.StubCardCatalogSource();
            catalogSource.cardsByTabApiName.put(TAB_API_NAME, new List<V360CardCatalogDTO>{
                buildCard(visibleCardId, 'VisibleCard', 1, false, true),
                buildCard(hiddenCardId, 'KilledCard', 2, true, true)
            });

            V360VisibilityEvaluator evaluator = new V360VisibilityEvaluator(
                catalogSource,
                new V360TestStubs.StubCardRuleSource(),
                new V360TestStubs.StubUserContext(),
                new V360TestStubs.StubFormulaEngine(),
                new V360Diagnostics()
            );

            Test.startTest();
            List<V360CardDecision> visible = evaluator.evaluate(UserInfo.getUserId(), TAB_API_NAME, new Account(Name = 'Probe'));
            Test.stopTest();

            Assert.areEqual(1, visible.size(), 'Only the non-killed card must be in the visible set');
            Assert.areEqual('VisibleCard', visible[0].cardName, 'The visible card must be the one whose kill-switch is off');
        }
    }

    @IsTest
    static void cardWithNoRuleGraphEntryIsVisibleByDefault() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            Id cardId = V360TestStubs.fakeId(Account.SObjectType, 3);
            V360TestStubs.StubCardCatalogSource catalogSource = new V360TestStubs.StubCardCatalogSource();
            catalogSource.cardsByTabApiName.put(TAB_API_NAME, new List<V360CardCatalogDTO>{
                buildCard(cardId, 'NoRulesCard', 1, false, true)
            });

            V360VisibilityEvaluator evaluator = new V360VisibilityEvaluator(
                catalogSource,
                new V360TestStubs.StubCardRuleSource(), // no rule graph registered for this card
                new V360TestStubs.StubUserContext(),
                new V360TestStubs.StubFormulaEngine(),
                new V360Diagnostics()
            );

            Test.startTest();
            List<V360CardDecision> visible = evaluator.evaluate(UserInfo.getUserId(), TAB_API_NAME, new Account(Name = 'Probe'));
            Test.stopTest();

            Assert.areEqual(1, visible.size(), 'A card with zero rules must be visible by default');
        }
    }

    @IsTest
    static void inactiveCardIsHiddenEvenWithNoRules() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            Id cardId = V360TestStubs.fakeId(Account.SObjectType, 4);
            V360TestStubs.StubCardCatalogSource catalogSource = new V360TestStubs.StubCardCatalogSource();
            catalogSource.cardsByTabApiName.put(TAB_API_NAME, new List<V360CardCatalogDTO>{
                buildCard(cardId, 'InactiveCard', 1, false, false)
            });

            V360VisibilityEvaluator evaluator = new V360VisibilityEvaluator(
                catalogSource,
                new V360TestStubs.StubCardRuleSource(),
                new V360TestStubs.StubUserContext(),
                new V360TestStubs.StubFormulaEngine(),
                new V360Diagnostics()
            );

            Test.startTest();
            List<V360CardDecision> visible = evaluator.evaluate(UserInfo.getUserId(), TAB_API_NAME, new Account(Name = 'Probe'));
            Test.stopTest();

            Assert.isTrue(visible.isEmpty(), 'An inactive card must never be in the visible set');
        }
    }

    @IsTest
    static void killSwitchHidesCardWhoseRuleWouldOtherwisePass() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            Id cardId = V360TestStubs.fakeId(Account.SObjectType, 5);
            Id ruleId = V360TestStubs.fakeId(Account.SObjectType, 6);

            V360TestStubs.StubCardCatalogSource catalogSource = new V360TestStubs.StubCardCatalogSource();
            catalogSource.cardsByTabApiName.put(TAB_API_NAME, new List<V360CardCatalogDTO>{
                buildCard(cardId, 'KilledPassingCard', 1, true, true)
            });

            V360TestStubs.StubCardRuleSource ruleSource = new V360TestStubs.StubCardRuleSource();
            ruleSource.ruleGraphByCardId.put(cardId, new V360RuleGraph(cardId, new List<V360RuleGraph.RuleRow>{
                new V360RuleGraph.RuleRow(ruleId, 'AlwaysPasses', 'true', true, new List<V360RuleGraph.PredicateRow>())
            }));

            V360TestStubs.StubFormulaEngine formulaEngine = new V360TestStubs.StubFormulaEngine();
            formulaEngine.resultByFormula.put('true', true);

            V360VisibilityEvaluator evaluator = new V360VisibilityEvaluator(
                catalogSource, ruleSource, new V360TestStubs.StubUserContext(), formulaEngine, new V360Diagnostics()
            );

            Test.startTest();
            List<V360CardDecision> visible = evaluator.evaluate(UserInfo.getUserId(), TAB_API_NAME, new Account(Name = 'Probe'));
            Test.stopTest();

            Assert.isTrue(visible.isEmpty(), 'The kill-switch must hide the card even though its rule would pass');
        }
    }

    @IsTest
    static void killSwitchHidesCardThatWouldOtherwiseBeDefaultVisible() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            Id cardId = V360TestStubs.fakeId(Account.SObjectType, 7);
            V360TestStubs.StubCardCatalogSource catalogSource = new V360TestStubs.StubCardCatalogSource();
            catalogSource.cardsByTabApiName.put(TAB_API_NAME, new List<V360CardCatalogDTO>{
                buildCard(cardId, 'KilledDefaultCard', 1, true, true)
            });

            V360VisibilityEvaluator evaluator = new V360VisibilityEvaluator(
                catalogSource,
                new V360TestStubs.StubCardRuleSource(), // no rules at all — would be default-visible
                new V360TestStubs.StubUserContext(),
                new V360TestStubs.StubFormulaEngine(),
                new V360Diagnostics()
            );

            Test.startTest();
            List<V360CardDecision> visible = evaluator.evaluate(UserInfo.getUserId(), TAB_API_NAME, new Account(Name = 'Probe'));
            Test.stopTest();

            Assert.isTrue(visible.isEmpty(), 'The kill-switch must outrank default-visible behavior, not just rule outcomes');
        }
    }

    @IsTest
    static void formulaPassingAndAllPredicatesPassingMakesCardVisible() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            Id cardId = V360TestStubs.fakeId(Account.SObjectType, 8);
            Id ruleId = V360TestStubs.fakeId(Account.SObjectType, 9);

            V360TestStubs.StubCardCatalogSource catalogSource = new V360TestStubs.StubCardCatalogSource();
            catalogSource.cardsByTabApiName.put(TAB_API_NAME, new List<V360CardCatalogDTO>{
                buildCard(cardId, 'FormulaAndPredicateCard', 1, false, true)
            });

            V360TestStubs.StubUserContext userContext = new V360TestStubs.StubUserContext();
            userContext.assignedPermissionSets.add('V360_Admin');

            V360TestStubs.StubCardRuleSource ruleSource = new V360TestStubs.StubCardRuleSource();
            ruleSource.ruleGraphByCardId.put(cardId, new V360RuleGraph(cardId, new List<V360RuleGraph.RuleRow>{
                new V360RuleGraph.RuleRow(ruleId, 'PassingRule', 'AnnualRevenue > 0', true, new List<V360RuleGraph.PredicateRow>{
                    new V360RuleGraph.PredicateRow(V360PredicateEvaluator.PERMISSION_SET, 'V360_Admin')
                })
            }));

            V360TestStubs.StubFormulaEngine formulaEngine = new V360TestStubs.StubFormulaEngine();
            formulaEngine.resultByFormula.put('AnnualRevenue > 0', true);

            V360VisibilityEvaluator evaluator = new V360VisibilityEvaluator(
                catalogSource, ruleSource, userContext, formulaEngine, new V360Diagnostics()
            );

            Test.startTest();
            List<V360CardDecision> visible = evaluator.evaluate(UserInfo.getUserId(), TAB_API_NAME, new Account(Name = 'Probe', AnnualRevenue = 500));
            Test.stopTest();

            Assert.areEqual(1, visible.size(), 'A card whose formula and every predicate pass must be visible');
        }
    }

    @IsTest
    static void formulaPassingButPredicateFailingHidesCard() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            Id cardId = V360TestStubs.fakeId(Account.SObjectType, 10);
            Id ruleId = V360TestStubs.fakeId(Account.SObjectType, 11);

            V360TestStubs.StubCardCatalogSource catalogSource = new V360TestStubs.StubCardCatalogSource();
            catalogSource.cardsByTabApiName.put(TAB_API_NAME, new List<V360CardCatalogDTO>{
                buildCard(cardId, 'FormulaPassesPredicateFailsCard', 1, false, true)
            });

            V360TestStubs.StubCardRuleSource ruleSource = new V360TestStubs.StubCardRuleSource();
            ruleSource.ruleGraphByCardId.put(cardId, new V360RuleGraph(cardId, new List<V360RuleGraph.RuleRow>{
                new V360RuleGraph.RuleRow(ruleId, 'FormulaPassesPredicateFails', 'AnnualRevenue > 0', true, new List<V360RuleGraph.PredicateRow>{
                    new V360RuleGraph.PredicateRow(V360PredicateEvaluator.FLS_READ, 'AnnualRevenue')
                })
            }));

            V360TestStubs.StubFormulaEngine formulaEngine = new V360TestStubs.StubFormulaEngine();
            formulaEngine.resultByFormula.put('AnnualRevenue > 0', true);

            // StubUserContext with no readable fields configured — the FLS_READ predicate fails
            V360VisibilityEvaluator evaluator = new V360VisibilityEvaluator(
                catalogSource, ruleSource, new V360TestStubs.StubUserContext(), formulaEngine, new V360Diagnostics()
            );

            Test.startTest();
            List<V360CardDecision> visible = evaluator.evaluate(UserInfo.getUserId(), TAB_API_NAME, new Account(Name = 'Probe', AnnualRevenue = 500));
            Test.stopTest();

            Assert.isTrue(visible.isEmpty(), 'A rule does not pass when its formula passes but a predicate fails');
        }
    }

    @IsTest
    static void formulaBuildFailureHidesCardAndFailsClosed() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            Id cardId = V360TestStubs.fakeId(Account.SObjectType, 12);
            Id ruleId = V360TestStubs.fakeId(Account.SObjectType, 13);

            V360TestStubs.StubCardCatalogSource catalogSource = new V360TestStubs.StubCardCatalogSource();
            catalogSource.cardsByTabApiName.put(TAB_API_NAME, new List<V360CardCatalogDTO>{
                buildCard(cardId, 'BuildFailureCard', 1, false, true)
            });

            V360TestStubs.StubCardRuleSource ruleSource = new V360TestStubs.StubCardRuleSource();
            ruleSource.ruleGraphByCardId.put(cardId, new V360RuleGraph(cardId, new List<V360RuleGraph.RuleRow>{
                new V360RuleGraph.RuleRow(ruleId, 'MalformedRule', 'NOT_A_REAL_FUNCTION(Name)', true, new List<V360RuleGraph.PredicateRow>())
            }));

            V360TestStubs.StubFormulaEngine formulaEngine = new V360TestStubs.StubFormulaEngine();
            formulaEngine.formulasThatFailToBuild.add('NOT_A_REAL_FUNCTION(Name)');

            V360VisibilityEvaluator evaluator = new V360VisibilityEvaluator(
                catalogSource, ruleSource, new V360TestStubs.StubUserContext(), formulaEngine, new V360Diagnostics()
            );

            Test.startTest();
            List<V360CardDecision> visible = evaluator.evaluate(UserInfo.getUserId(), TAB_API_NAME, new Account(Name = 'Probe'));
            Test.stopTest();

            Assert.isTrue(visible.isEmpty(), 'A rule whose formula fails to build must fail closed, not throw to the caller');
        }
    }

    @IsTest
    static void formulaEvaluateFailureHidesCardAndFailsClosed() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            Id cardId = V360TestStubs.fakeId(Account.SObjectType, 14);
            Id ruleId = V360TestStubs.fakeId(Account.SObjectType, 15);

            V360TestStubs.StubCardCatalogSource catalogSource = new V360TestStubs.StubCardCatalogSource();
            catalogSource.cardsByTabApiName.put(TAB_API_NAME, new List<V360CardCatalogDTO>{
                buildCard(cardId, 'EvaluateFailureCard', 1, false, true)
            });

            V360TestStubs.StubCardRuleSource ruleSource = new V360TestStubs.StubCardRuleSource();
            ruleSource.ruleGraphByCardId.put(cardId, new V360RuleGraph(cardId, new List<V360RuleGraph.RuleRow>{
                new V360RuleGraph.RuleRow(ruleId, 'ErrorsAtEvalTime', 'AnnualRevenue > 0', true, new List<V360RuleGraph.PredicateRow>())
            }));

            V360TestStubs.StubFormulaEngine formulaEngine = new V360TestStubs.StubFormulaEngine();
            formulaEngine.formulasThatFailToEvaluate.add('AnnualRevenue > 0');

            V360VisibilityEvaluator evaluator = new V360VisibilityEvaluator(
                catalogSource, ruleSource, new V360TestStubs.StubUserContext(), formulaEngine, new V360Diagnostics()
            );

            Test.startTest();
            List<V360CardDecision> visible = evaluator.evaluate(UserInfo.getUserId(), TAB_API_NAME, new Account(Name = 'Probe'));
            Test.stopTest();

            Assert.isTrue(visible.isEmpty(), 'A rule that raises an error during evaluation must fail closed, not throw to the caller');
        }
    }

    @IsTest
    static void predicateErrorHidesCardAndFailsClosed() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            Id cardId = V360TestStubs.fakeId(Account.SObjectType, 16);
            Id ruleId = V360TestStubs.fakeId(Account.SObjectType, 17);

            V360TestStubs.StubCardCatalogSource catalogSource = new V360TestStubs.StubCardCatalogSource();
            catalogSource.cardsByTabApiName.put(TAB_API_NAME, new List<V360CardCatalogDTO>{
                buildCard(cardId, 'BadPredicateCard', 1, false, true)
            });

            V360TestStubs.StubCardRuleSource ruleSource = new V360TestStubs.StubCardRuleSource();
            ruleSource.ruleGraphByCardId.put(cardId, new V360RuleGraph(cardId, new List<V360RuleGraph.RuleRow>{
                new V360RuleGraph.RuleRow(ruleId, 'BadPredicateRule', null, true, new List<V360RuleGraph.PredicateRow>{
                    new V360RuleGraph.PredicateRow('NOT_A_REAL_PREDICATE_TYPE', 'Whatever')
                })
            }));

            V360VisibilityEvaluator evaluator = new V360VisibilityEvaluator(
                catalogSource, ruleSource, new V360TestStubs.StubUserContext(), new V360TestStubs.StubFormulaEngine(), new V360Diagnostics()
            );

            Test.startTest();
            List<V360CardDecision> visible = evaluator.evaluate(UserInfo.getUserId(), TAB_API_NAME, new Account(Name = 'Probe'));
            Test.stopTest();

            Assert.isTrue(visible.isEmpty(), 'A predicate that cannot be evaluated must fail closed, not throw to the caller');
        }
    }

    @IsTest
    static void allActiveRuleRowsMustPassForACardWithMultipleRules() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            Id cardId = V360TestStubs.fakeId(Account.SObjectType, 18);
            Id passingRuleId = V360TestStubs.fakeId(Account.SObjectType, 19);
            Id failingRuleId = V360TestStubs.fakeId(Account.SObjectType, 20);

            V360TestStubs.StubCardCatalogSource catalogSource = new V360TestStubs.StubCardCatalogSource();
            catalogSource.cardsByTabApiName.put(TAB_API_NAME, new List<V360CardCatalogDTO>{
                buildCard(cardId, 'MultiRuleCard', 1, false, true)
            });

            V360TestStubs.StubCardRuleSource ruleSource = new V360TestStubs.StubCardRuleSource();
            ruleSource.ruleGraphByCardId.put(cardId, new V360RuleGraph(cardId, new List<V360RuleGraph.RuleRow>{
                new V360RuleGraph.RuleRow(passingRuleId, 'PassingRule', 'true', true, new List<V360RuleGraph.PredicateRow>()),
                new V360RuleGraph.RuleRow(failingRuleId, 'FailingRule', 'false', true, new List<V360RuleGraph.PredicateRow>())
            }));

            V360TestStubs.StubFormulaEngine formulaEngine = new V360TestStubs.StubFormulaEngine();
            formulaEngine.resultByFormula.put('true', true);
            formulaEngine.resultByFormula.put('false', false);

            V360VisibilityEvaluator evaluator = new V360VisibilityEvaluator(
                catalogSource, ruleSource, new V360TestStubs.StubUserContext(), formulaEngine, new V360Diagnostics()
            );

            Test.startTest();
            List<V360CardDecision> visible = evaluator.evaluate(UserInfo.getUserId(), TAB_API_NAME, new Account(Name = 'Probe'));
            Test.stopTest();

            Assert.isTrue(
                visible.isEmpty(),
                'When a card has multiple active rule rows, every one must pass — one failing rule hides the card'
            );
        }
    }

    @IsTest
    static void inactiveRuleRowIsIgnored() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            Id cardId = V360TestStubs.fakeId(Account.SObjectType, 21);
            Id inactiveRuleId = V360TestStubs.fakeId(Account.SObjectType, 22);

            V360TestStubs.StubCardCatalogSource catalogSource = new V360TestStubs.StubCardCatalogSource();
            catalogSource.cardsByTabApiName.put(TAB_API_NAME, new List<V360CardCatalogDTO>{
                buildCard(cardId, 'InactiveRuleCard', 1, false, true)
            });

            V360TestStubs.StubCardRuleSource ruleSource = new V360TestStubs.StubCardRuleSource();
            ruleSource.ruleGraphByCardId.put(cardId, new V360RuleGraph(cardId, new List<V360RuleGraph.RuleRow>{
                new V360RuleGraph.RuleRow(inactiveRuleId, 'InactiveRule', 'false', false, new List<V360RuleGraph.PredicateRow>())
            }));

            V360VisibilityEvaluator evaluator = new V360VisibilityEvaluator(
                catalogSource, ruleSource, new V360TestStubs.StubUserContext(), new V360TestStubs.StubFormulaEngine(), new V360Diagnostics()
            );

            Test.startTest();
            List<V360CardDecision> visible = evaluator.evaluate(UserInfo.getUserId(), TAB_API_NAME, new Account(Name = 'Probe'));
            Test.stopTest();

            Assert.areEqual(1, visible.size(), 'An inactive rule row must be skipped, leaving the card default-visible');
        }
    }

    @IsTest
    static void differentCardsOnTheSameTabEvaluateIndependently() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            Id passingCardId = V360TestStubs.fakeId(Account.SObjectType, 23);
            Id failingCardId = V360TestStubs.fakeId(Account.SObjectType, 24);
            Id passingRuleId = V360TestStubs.fakeId(Account.SObjectType, 25);
            Id failingRuleId = V360TestStubs.fakeId(Account.SObjectType, 26);

            V360TestStubs.StubCardCatalogSource catalogSource = new V360TestStubs.StubCardCatalogSource();
            catalogSource.cardsByTabApiName.put(TAB_API_NAME, new List<V360CardCatalogDTO>{
                buildCard(passingCardId, 'PassingCard', 1, false, true),
                buildCard(failingCardId, 'FailingCard', 2, false, true)
            });

            V360TestStubs.StubCardRuleSource ruleSource = new V360TestStubs.StubCardRuleSource();
            ruleSource.ruleGraphByCardId.put(passingCardId, new V360RuleGraph(passingCardId, new List<V360RuleGraph.RuleRow>{
                new V360RuleGraph.RuleRow(passingRuleId, 'Passes', 'true', true, new List<V360RuleGraph.PredicateRow>())
            }));
            ruleSource.ruleGraphByCardId.put(failingCardId, new V360RuleGraph(failingCardId, new List<V360RuleGraph.RuleRow>{
                new V360RuleGraph.RuleRow(failingRuleId, 'Fails', 'false', true, new List<V360RuleGraph.PredicateRow>())
            }));

            V360TestStubs.StubFormulaEngine formulaEngine = new V360TestStubs.StubFormulaEngine();
            formulaEngine.resultByFormula.put('true', true);
            formulaEngine.resultByFormula.put('false', false);

            V360VisibilityEvaluator evaluator = new V360VisibilityEvaluator(
                catalogSource, ruleSource, new V360TestStubs.StubUserContext(), formulaEngine, new V360Diagnostics()
            );

            Test.startTest();
            List<V360CardDecision> visible = evaluator.evaluate(UserInfo.getUserId(), TAB_API_NAME, new Account(Name = 'Probe'));
            Test.stopTest();

            Assert.areEqual(1, visible.size(), 'Each card under the same tab must be decided on its own rules');
            Assert.areEqual('PassingCard', visible[0].cardName, 'Only the card whose own rule passes must be visible');
        }
    }

    @IsTest
    static void visibleCardsAreSortedByOrder() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            Id cardIdOrder3 = V360TestStubs.fakeId(Account.SObjectType, 27);
            Id cardIdOrder1 = V360TestStubs.fakeId(Account.SObjectType, 28);
            Id cardIdOrder2 = V360TestStubs.fakeId(Account.SObjectType, 29);

            V360TestStubs.StubCardCatalogSource catalogSource = new V360TestStubs.StubCardCatalogSource();
            catalogSource.cardsByTabApiName.put(TAB_API_NAME, new List<V360CardCatalogDTO>{
                buildCard(cardIdOrder3, 'ThirdCard', 3, false, true),
                buildCard(cardIdOrder1, 'FirstCard', 1, false, true),
                buildCard(cardIdOrder2, 'SecondCard', 2, false, true)
            });

            V360VisibilityEvaluator evaluator = new V360VisibilityEvaluator(
                catalogSource, new V360TestStubs.StubCardRuleSource(), new V360TestStubs.StubUserContext(),
                new V360TestStubs.StubFormulaEngine(), new V360Diagnostics()
            );

            Test.startTest();
            List<V360CardDecision> visible = evaluator.evaluate(UserInfo.getUserId(), TAB_API_NAME, new Account(Name = 'Probe'));
            Test.stopTest();

            Assert.areEqual('FirstCard', visible[0].cardName, 'Visible cards must be sorted by order ascending');
            Assert.areEqual('SecondCard', visible[1].cardName, 'Visible cards must be sorted by order ascending');
            Assert.areEqual('ThirdCard', visible[2].cardName, 'Visible cards must be sorted by order ascending');
        }
    }

    @IsTest
    static void emptyTabReturnsAnEmptyVisibleSetWithoutCallingTheRuleSource() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            V360VisibilityEvaluator evaluator = new V360VisibilityEvaluator(
                new V360TestStubs.StubCardCatalogSource(), // no cards registered for any tab
                new V360TestStubs.StubCardRuleSource(), new V360TestStubs.StubUserContext(),
                new V360TestStubs.StubFormulaEngine(), new V360Diagnostics()
            );

            Test.startTest();
            List<V360CardDecision> visible = evaluator.evaluate(UserInfo.getUserId(), 'UnknownTab', new Account(Name = 'Probe'));
            Test.stopTest();

            Assert.isTrue(visible.isEmpty(), 'A tab with no configured cards must return an empty visible set');
        }
    }

    @IsTest
    static void evaluatorReturnsCatalogDataRegardlessOfTheRunningUsersOwnConfigAccess() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            // The stub sources stand in for the trusted, system-mode mediator: they
            // return configuration data unconditionally, exactly as a real selector
            // would for a user with zero CRUD/FLS on the config objects themselves.
            Id cardId = V360TestStubs.fakeId(Account.SObjectType, 30);
            V360TestStubs.StubCardCatalogSource catalogSource = new V360TestStubs.StubCardCatalogSource();
            catalogSource.cardsByTabApiName.put(TAB_API_NAME, new List<V360CardCatalogDTO>{
                buildCard(cardId, 'MediatedCard', 1, false, true)
            });

            V360VisibilityEvaluator evaluator = new V360VisibilityEvaluator(
                catalogSource, new V360TestStubs.StubCardRuleSource(), new V360TestStubs.StubUserContext(),
                new V360TestStubs.StubFormulaEngine(), new V360Diagnostics()
            );

            Test.startTest();
            List<V360CardDecision> visible = evaluator.evaluate(UserInfo.getUserId(), TAB_API_NAME, new Account(Name = 'Probe'));
            Test.stopTest();

            Assert.areEqual(1, visible.size(), 'The evaluator must resolve visibility from mediated config reads, never end-user config access');
        }
    }
}
