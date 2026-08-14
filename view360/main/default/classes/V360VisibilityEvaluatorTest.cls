@IsTest
private class V360VisibilityEvaluatorTest {

    private static final String TAB_API_NAME = 'AccountOverview';

    /**
     * A default-visible card: kill-switch off, active, order 1. Individual
     * tests mutate the returned instance's fields (order, killSwitch, active)
     * rather than passing every field through a constructor.
     */
    private static V360CardCatalogDTO visibleCard(Id cardId, String developerName) {
        V360CardCatalogDTO card = new V360CardCatalogDTO();
        card.cardId = cardId;
        card.developerName = developerName;
        card.componentType = 'LWC';
        card.componentName = 'v360AccountBalance';
        card.order = 1;
        card.label = developerName + ' Label';
        return card;
    }

    /** The same card, switched to reading its rules as alternatives. */
    private static V360CardCatalogDTO cardMatchingAnyRule(Id cardId, String developerName) {
        V360CardCatalogDTO card = visibleCard(cardId, developerName);
        card.ruleMatchLogic = 'ANY';
        return card;
    }

    /**
     * A default active rule row with the given formula and no predicates.
     * Individual tests mutate the returned instance (active, predicates)
     * rather than passing every field through a constructor.
     */
    private static V360RuleGraph.RuleRow ruleWithFormula(Id ruleId, String developerName, String formula) {
        V360RuleGraph.RuleRow rule = new V360RuleGraph.RuleRow();
        rule.ruleId = ruleId;
        rule.developerName = developerName;
        rule.visibilityFormula = formula;
        return rule;
    }

    /** A services holder wired with default stubs; tests override only what they need. */
    private static V360VisibilityEvaluator.Services defaultServices() {
        V360VisibilityEvaluator.Services services = new V360VisibilityEvaluator.Services();
        services.catalogSource = new V360TestStubs.StubCardCatalogSource();
        services.ruleSource = new V360TestStubs.StubCardRuleSource();
        services.userContext = new V360TestStubs.StubUserContext();
        services.formulaEngine = new V360TestStubs.StubFormulaEngine();
        services.diagnostics = new V360Diagnostics();
        return services;
    }

    @IsTest
    static void visibleSetContainsOnlyCardsThatPassEvaluation() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            Id visibleCardId = V360TestStubs.fakeId(Account.SObjectType, 1);
            Id hiddenCardId = V360TestStubs.fakeId(Account.SObjectType, 2);

            V360CardCatalogDTO killedCard = visibleCard(hiddenCardId, 'KilledCard');
            killedCard.order = 2;
            killedCard.killSwitch = true;

            V360TestStubs.StubCardCatalogSource catalogSource = new V360TestStubs.StubCardCatalogSource();
            catalogSource.cardsByTabApiName.put(TAB_API_NAME, new List<V360CardCatalogDTO>{
                visibleCard(visibleCardId, 'VisibleCard'),
                killedCard
            });

            V360VisibilityEvaluator.Services services = defaultServices();
            services.catalogSource = catalogSource;
            V360VisibilityEvaluator evaluator = new V360VisibilityEvaluator(services);

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
                visibleCard(cardId, 'NoRulesCard')
            });

            V360VisibilityEvaluator.Services services = defaultServices();
            services.catalogSource = catalogSource; // no rule graph registered for this card
            V360VisibilityEvaluator evaluator = new V360VisibilityEvaluator(services);

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
            V360CardCatalogDTO inactiveCard = visibleCard(cardId, 'InactiveCard');
            inactiveCard.active = false;

            V360TestStubs.StubCardCatalogSource catalogSource = new V360TestStubs.StubCardCatalogSource();
            catalogSource.cardsByTabApiName.put(TAB_API_NAME, new List<V360CardCatalogDTO>{ inactiveCard });

            V360VisibilityEvaluator.Services services = defaultServices();
            services.catalogSource = catalogSource;
            V360VisibilityEvaluator evaluator = new V360VisibilityEvaluator(services);

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

            V360CardCatalogDTO killedCard = visibleCard(cardId, 'KilledPassingCard');
            killedCard.killSwitch = true;

            V360TestStubs.StubCardCatalogSource catalogSource = new V360TestStubs.StubCardCatalogSource();
            catalogSource.cardsByTabApiName.put(TAB_API_NAME, new List<V360CardCatalogDTO>{ killedCard });

            V360TestStubs.StubCardRuleSource ruleSource = new V360TestStubs.StubCardRuleSource();
            ruleSource.ruleGraphByCardId.put(cardId, new V360RuleGraph(cardId, new List<V360RuleGraph.RuleRow>{
                ruleWithFormula(ruleId, 'AlwaysPasses', 'true')
            }));

            V360TestStubs.StubFormulaEngine formulaEngine = new V360TestStubs.StubFormulaEngine();
            formulaEngine.resultByFormula.put('true', true);

            V360VisibilityEvaluator.Services services = defaultServices();
            services.catalogSource = catalogSource;
            services.ruleSource = ruleSource;
            services.formulaEngine = formulaEngine;
            V360VisibilityEvaluator evaluator = new V360VisibilityEvaluator(services);

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
            V360CardCatalogDTO killedCard = visibleCard(cardId, 'KilledDefaultCard');
            killedCard.killSwitch = true;

            V360TestStubs.StubCardCatalogSource catalogSource = new V360TestStubs.StubCardCatalogSource();
            catalogSource.cardsByTabApiName.put(TAB_API_NAME, new List<V360CardCatalogDTO>{ killedCard });

            V360VisibilityEvaluator.Services services = defaultServices();
            services.catalogSource = catalogSource; // no rules at all — would be default-visible
            V360VisibilityEvaluator evaluator = new V360VisibilityEvaluator(services);

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
                visibleCard(cardId, 'FormulaAndPredicateCard')
            });

            V360TestStubs.StubUserContext userContext = new V360TestStubs.StubUserContext();
            userContext.assignedPermissionSets.add('V360_Admin');

            V360RuleGraph.RuleRow rule = ruleWithFormula(ruleId, 'PassingRule', 'AnnualRevenue > 0');
            rule.predicates.add(new V360RuleGraph.PredicateRow(V360PredicateEvaluator.PERMISSION_SET, 'V360_Admin'));

            V360TestStubs.StubCardRuleSource ruleSource = new V360TestStubs.StubCardRuleSource();
            ruleSource.ruleGraphByCardId.put(cardId, new V360RuleGraph(cardId, new List<V360RuleGraph.RuleRow>{ rule }));

            V360TestStubs.StubFormulaEngine formulaEngine = new V360TestStubs.StubFormulaEngine();
            formulaEngine.resultByFormula.put('AnnualRevenue > 0', true);

            V360VisibilityEvaluator.Services services = defaultServices();
            services.catalogSource = catalogSource;
            services.ruleSource = ruleSource;
            services.userContext = userContext;
            services.formulaEngine = formulaEngine;
            V360VisibilityEvaluator evaluator = new V360VisibilityEvaluator(services);

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
                visibleCard(cardId, 'FormulaPassesPredicateFailsCard')
            });

            V360RuleGraph.RuleRow rule = ruleWithFormula(ruleId, 'FormulaPassesPredicateFails', 'AnnualRevenue > 0');
            rule.predicates.add(new V360RuleGraph.PredicateRow(V360PredicateEvaluator.FLS_READ, 'AnnualRevenue'));

            V360TestStubs.StubCardRuleSource ruleSource = new V360TestStubs.StubCardRuleSource();
            ruleSource.ruleGraphByCardId.put(cardId, new V360RuleGraph(cardId, new List<V360RuleGraph.RuleRow>{ rule }));

            V360TestStubs.StubFormulaEngine formulaEngine = new V360TestStubs.StubFormulaEngine();
            formulaEngine.resultByFormula.put('AnnualRevenue > 0', true);

            // StubUserContext with no readable fields configured — the FLS_READ predicate fails
            V360VisibilityEvaluator.Services services = defaultServices();
            services.catalogSource = catalogSource;
            services.ruleSource = ruleSource;
            services.formulaEngine = formulaEngine;
            V360VisibilityEvaluator evaluator = new V360VisibilityEvaluator(services);

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
                visibleCard(cardId, 'BuildFailureCard')
            });

            V360TestStubs.StubCardRuleSource ruleSource = new V360TestStubs.StubCardRuleSource();
            ruleSource.ruleGraphByCardId.put(cardId, new V360RuleGraph(cardId, new List<V360RuleGraph.RuleRow>{
                ruleWithFormula(ruleId, 'MalformedRule', 'NOT_A_REAL_FUNCTION(Name)')
            }));

            V360TestStubs.StubFormulaEngine formulaEngine = new V360TestStubs.StubFormulaEngine();
            formulaEngine.formulasThatFailToBuild.add('NOT_A_REAL_FUNCTION(Name)');

            V360VisibilityEvaluator.Services services = defaultServices();
            services.catalogSource = catalogSource;
            services.ruleSource = ruleSource;
            services.formulaEngine = formulaEngine;
            V360VisibilityEvaluator evaluator = new V360VisibilityEvaluator(services);

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
                visibleCard(cardId, 'EvaluateFailureCard')
            });

            V360TestStubs.StubCardRuleSource ruleSource = new V360TestStubs.StubCardRuleSource();
            ruleSource.ruleGraphByCardId.put(cardId, new V360RuleGraph(cardId, new List<V360RuleGraph.RuleRow>{
                ruleWithFormula(ruleId, 'ErrorsAtEvalTime', 'AnnualRevenue > 0')
            }));

            V360TestStubs.StubFormulaEngine formulaEngine = new V360TestStubs.StubFormulaEngine();
            formulaEngine.formulasThatFailToEvaluate.add('AnnualRevenue > 0');

            V360VisibilityEvaluator.Services services = defaultServices();
            services.catalogSource = catalogSource;
            services.ruleSource = ruleSource;
            services.formulaEngine = formulaEngine;
            V360VisibilityEvaluator evaluator = new V360VisibilityEvaluator(services);

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
                visibleCard(cardId, 'BadPredicateCard')
            });

            V360RuleGraph.RuleRow rule = ruleWithFormula(ruleId, 'BadPredicateRule', null);
            rule.predicates.add(new V360RuleGraph.PredicateRow('NOT_A_REAL_PREDICATE_TYPE', 'Whatever'));

            V360TestStubs.StubCardRuleSource ruleSource = new V360TestStubs.StubCardRuleSource();
            ruleSource.ruleGraphByCardId.put(cardId, new V360RuleGraph(cardId, new List<V360RuleGraph.RuleRow>{ rule }));

            V360VisibilityEvaluator.Services services = defaultServices();
            services.catalogSource = catalogSource;
            services.ruleSource = ruleSource;
            V360VisibilityEvaluator evaluator = new V360VisibilityEvaluator(services);

            Test.startTest();
            List<V360CardDecision> visible = evaluator.evaluate(UserInfo.getUserId(), TAB_API_NAME, new Account(Name = 'Probe'));
            Test.stopTest();

            Assert.isTrue(visible.isEmpty(), 'A predicate that cannot be evaluated must fail closed, not throw to the caller');
        }
    }

    /**
     * The safety test for the whole feature: a card that says nothing about
     * how its rules combine gets the restrictive reading.
     *
     * Everything else here can be argued about. This cannot: a card created
     * before the setting existed, restored from a data load, or built by a
     * caller that never heard of it must not silently become an OR. Note
     * that the card is the plain helper -- ruleMatchLogic is never assigned.
     */
    @IsTest
    static void aCardThatDoesNotChooseItsMatchLogicRequiresEveryRule() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            Id cardId = V360TestStubs.fakeId(Account.SObjectType, 38);
            Id passingRuleId = V360TestStubs.fakeId(Account.SObjectType, 39);
            Id failingRuleId = V360TestStubs.fakeId(Account.SObjectType, 40);

            V360TestStubs.StubCardCatalogSource catalogSource = new V360TestStubs.StubCardCatalogSource();
            catalogSource.cardsByTabApiName.put(TAB_API_NAME, new List<V360CardCatalogDTO>{
                visibleCard(cardId, 'UnsetLogicCard')
            });

            V360TestStubs.StubCardRuleSource ruleSource = new V360TestStubs.StubCardRuleSource();
            ruleSource.ruleGraphByCardId.put(cardId, new V360RuleGraph(cardId, new List<V360RuleGraph.RuleRow>{
                ruleWithFormula(passingRuleId, 'PassingRule', 'true'),
                ruleWithFormula(failingRuleId, 'FailingRule', 'false')
            }));

            V360TestStubs.StubFormulaEngine formulaEngine = new V360TestStubs.StubFormulaEngine();
            formulaEngine.resultByFormula.put('true', true);
            formulaEngine.resultByFormula.put('false', false);

            V360VisibilityEvaluator.Services services = defaultServices();
            services.catalogSource = catalogSource;
            services.ruleSource = ruleSource;
            services.formulaEngine = formulaEngine;
            V360VisibilityEvaluator evaluator = new V360VisibilityEvaluator(services);

            Test.startTest();
            List<V360CardDecision> visible = evaluator.evaluate(UserInfo.getUserId(), TAB_API_NAME, new Account(Name = 'Probe'));
            Test.stopTest();

            Assert.isTrue(
                visible.isEmpty(),
                'With no match logic chosen the rules are requirements, so one failing rule hides the card'
            );
        }
    }

    /** An unrecognised value is not a licence to loosen: it reads as ALL too. */
    @IsTest
    static void anUnrecognisedMatchLogicRequiresEveryRule() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            Id cardId = V360TestStubs.fakeId(Account.SObjectType, 41);
            Id failingRuleId = V360TestStubs.fakeId(Account.SObjectType, 42);

            V360CardCatalogDTO card = visibleCard(cardId, 'GarbageLogicCard');
            card.ruleMatchLogic = 'SOMETHING_ELSE';

            V360TestStubs.StubCardCatalogSource catalogSource = new V360TestStubs.StubCardCatalogSource();
            catalogSource.cardsByTabApiName.put(TAB_API_NAME, new List<V360CardCatalogDTO>{ card });

            V360TestStubs.StubCardRuleSource ruleSource = new V360TestStubs.StubCardRuleSource();
            ruleSource.ruleGraphByCardId.put(cardId, new V360RuleGraph(cardId, new List<V360RuleGraph.RuleRow>{
                ruleWithFormula(failingRuleId, 'FailingRule', 'false')
            }));

            V360TestStubs.StubFormulaEngine formulaEngine = new V360TestStubs.StubFormulaEngine();
            formulaEngine.resultByFormula.put('false', false);

            V360VisibilityEvaluator.Services services = defaultServices();
            services.catalogSource = catalogSource;
            services.ruleSource = ruleSource;
            services.formulaEngine = formulaEngine;
            V360VisibilityEvaluator evaluator = new V360VisibilityEvaluator(services);

            Test.startTest();
            List<V360CardDecision> visible = evaluator.evaluate(UserInfo.getUserId(), TAB_API_NAME, new Account(Name = 'Probe'));
            Test.stopTest();

            Assert.isTrue(visible.isEmpty(), 'Only the exact ANY value may loosen a card');
        }
    }

    /**
     * Under ANY each rule row is one way to qualify, not one more hurdle: a
     * card shown to two audiences needs two rules, because a Permission Set
     * cannot be read from a formula and the predicates inside a single rule
     * are all required together.
     */
    @IsTest
    static void anySinglePassingRuleRowMakesTheCardVisible() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            Id cardId = V360TestStubs.fakeId(Account.SObjectType, 18);
            Id passingRuleId = V360TestStubs.fakeId(Account.SObjectType, 19);
            Id failingRuleId = V360TestStubs.fakeId(Account.SObjectType, 20);

            V360TestStubs.StubCardCatalogSource catalogSource = new V360TestStubs.StubCardCatalogSource();
            catalogSource.cardsByTabApiName.put(TAB_API_NAME, new List<V360CardCatalogDTO>{
                cardMatchingAnyRule(cardId, 'MultiRuleCard')
            });

            V360TestStubs.StubCardRuleSource ruleSource = new V360TestStubs.StubCardRuleSource();
            ruleSource.ruleGraphByCardId.put(cardId, new V360RuleGraph(cardId, new List<V360RuleGraph.RuleRow>{
                ruleWithFormula(failingRuleId, 'FailingRule', 'false'),
                ruleWithFormula(passingRuleId, 'PassingRule', 'true')
            }));

            V360TestStubs.StubFormulaEngine formulaEngine = new V360TestStubs.StubFormulaEngine();
            formulaEngine.resultByFormula.put('true', true);
            formulaEngine.resultByFormula.put('false', false);

            V360VisibilityEvaluator.Services services = defaultServices();
            services.catalogSource = catalogSource;
            services.ruleSource = ruleSource;
            services.formulaEngine = formulaEngine;
            V360VisibilityEvaluator evaluator = new V360VisibilityEvaluator(services);

            Test.startTest();
            List<V360CardDecision> visible = evaluator.evaluate(UserInfo.getUserId(), TAB_API_NAME, new Account(Name = 'Probe'));
            Test.stopTest();

            Assert.areEqual(
                1,
                visible.size(),
                'One rule row passing is one qualifying path, and that is enough to show the card'
            );
        }
    }

    /**
     * A rule that requires nothing is not a way in.
     *
     * This only bites once rows are alternatives. Under an "all must pass"
     * reading an unconfigured row was harmless — it passed, and the other
     * rows still did the work. As an alternative it would pass for everyone
     * and hand the whole card over. That turns "New rule", clicked to add a
     * second audience, into an exposure lasting until the row is filled in:
     * the admin restricting a card would be opening it.
     */
    @IsTest
    static void anUnconfiguredRuleRowIsNotAQualifyingPath() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            Id cardId = V360TestStubs.fakeId(Account.SObjectType, 33);
            Id realRuleId = V360TestStubs.fakeId(Account.SObjectType, 34);
            Id emptyRuleId = V360TestStubs.fakeId(Account.SObjectType, 35);

            V360TestStubs.StubCardCatalogSource catalogSource = new V360TestStubs.StubCardCatalogSource();
            catalogSource.cardsByTabApiName.put(TAB_API_NAME, new List<V360CardCatalogDTO>{
                cardMatchingAnyRule(cardId, 'HalfEditedCard')
            });

            V360TestStubs.StubCardRuleSource ruleSource = new V360TestStubs.StubCardRuleSource();
            ruleSource.ruleGraphByCardId.put(cardId, new V360RuleGraph(cardId, new List<V360RuleGraph.RuleRow>{
                ruleWithFormula(realRuleId, 'RestrictingRule', 'false'),
                // Exactly what "New rule" leaves behind: no formula, no predicates.
                ruleWithFormula(emptyRuleId, 'JustCreatedRule', null)
            }));

            V360TestStubs.StubFormulaEngine formulaEngine = new V360TestStubs.StubFormulaEngine();
            formulaEngine.resultByFormula.put('false', false);

            V360VisibilityEvaluator.Services services = defaultServices();
            services.catalogSource = catalogSource;
            services.ruleSource = ruleSource;
            services.formulaEngine = formulaEngine;
            V360VisibilityEvaluator evaluator = new V360VisibilityEvaluator(services);

            Test.startTest();
            List<V360CardDecision> visible = evaluator.evaluate(UserInfo.getUserId(), TAB_API_NAME, new Account(Name = 'Probe'));
            Test.stopTest();

            Assert.isTrue(
                visible.isEmpty(),
                'A rule row that asks for nothing must not open the card to everyone while it is being written'
            );
        }
    }

    /**
     * The flip side, and why the empty row is skipped rather than failed: a
     * card carrying nothing but unconfigured rows restricts no one, which is
     * the same position as a card with no rows at all.
     */
    @IsTest
    static void cardWithOnlyUnconfiguredRuleRowsStaysVisible() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            Id cardId = V360TestStubs.fakeId(Account.SObjectType, 36);
            Id emptyRuleId = V360TestStubs.fakeId(Account.SObjectType, 37);

            V360TestStubs.StubCardCatalogSource catalogSource = new V360TestStubs.StubCardCatalogSource();
            catalogSource.cardsByTabApiName.put(TAB_API_NAME, new List<V360CardCatalogDTO>{
                cardMatchingAnyRule(cardId, 'BlankRuleCard')
            });

            V360TestStubs.StubCardRuleSource ruleSource = new V360TestStubs.StubCardRuleSource();
            ruleSource.ruleGraphByCardId.put(cardId, new V360RuleGraph(cardId, new List<V360RuleGraph.RuleRow>{
                ruleWithFormula(emptyRuleId, 'JustCreatedRule', null)
            }));

            V360VisibilityEvaluator.Services services = defaultServices();
            services.catalogSource = catalogSource;
            services.ruleSource = ruleSource;
            V360VisibilityEvaluator evaluator = new V360VisibilityEvaluator(services);

            Test.startTest();
            List<V360CardDecision> visible = evaluator.evaluate(UserInfo.getUserId(), TAB_API_NAME, new Account(Name = 'Probe'));
            Test.stopTest();

            Assert.areEqual(1, visible.size(), 'Rules that ask for nothing leave the card as unrestricted as no rules would');
        }
    }

    /** The other half of the same rule: every active path failing hides it. */
    @IsTest
    static void cardIsHiddenWhenEveryActiveRuleRowFails() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            Id cardId = V360TestStubs.fakeId(Account.SObjectType, 30);
            Id firstRuleId = V360TestStubs.fakeId(Account.SObjectType, 31);
            Id secondRuleId = V360TestStubs.fakeId(Account.SObjectType, 32);

            V360TestStubs.StubCardCatalogSource catalogSource = new V360TestStubs.StubCardCatalogSource();
            catalogSource.cardsByTabApiName.put(TAB_API_NAME, new List<V360CardCatalogDTO>{
                cardMatchingAnyRule(cardId, 'NoPathCard')
            });

            V360TestStubs.StubCardRuleSource ruleSource = new V360TestStubs.StubCardRuleSource();
            ruleSource.ruleGraphByCardId.put(cardId, new V360RuleGraph(cardId, new List<V360RuleGraph.RuleRow>{
                ruleWithFormula(firstRuleId, 'FirstRule', 'false'),
                ruleWithFormula(secondRuleId, 'SecondRule', 'false')
            }));

            V360TestStubs.StubFormulaEngine formulaEngine = new V360TestStubs.StubFormulaEngine();
            formulaEngine.resultByFormula.put('false', false);

            V360VisibilityEvaluator.Services services = defaultServices();
            services.catalogSource = catalogSource;
            services.ruleSource = ruleSource;
            services.formulaEngine = formulaEngine;
            V360VisibilityEvaluator evaluator = new V360VisibilityEvaluator(services);

            Test.startTest();
            List<V360CardDecision> visible = evaluator.evaluate(UserInfo.getUserId(), TAB_API_NAME, new Account(Name = 'Probe'));
            Test.stopTest();

            Assert.isTrue(visible.isEmpty(), 'With no qualifying path left, the card stays hidden');
        }
    }

    @IsTest
    static void inactiveRuleRowIsIgnored() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            Id cardId = V360TestStubs.fakeId(Account.SObjectType, 21);
            Id inactiveRuleId = V360TestStubs.fakeId(Account.SObjectType, 22);

            V360TestStubs.StubCardCatalogSource catalogSource = new V360TestStubs.StubCardCatalogSource();
            catalogSource.cardsByTabApiName.put(TAB_API_NAME, new List<V360CardCatalogDTO>{
                visibleCard(cardId, 'InactiveRuleCard')
            });

            V360RuleGraph.RuleRow inactiveRule = ruleWithFormula(inactiveRuleId, 'InactiveRule', 'false');
            inactiveRule.active = false;

            V360TestStubs.StubCardRuleSource ruleSource = new V360TestStubs.StubCardRuleSource();
            ruleSource.ruleGraphByCardId.put(cardId, new V360RuleGraph(cardId, new List<V360RuleGraph.RuleRow>{ inactiveRule }));

            V360VisibilityEvaluator.Services services = defaultServices();
            services.catalogSource = catalogSource;
            services.ruleSource = ruleSource;
            V360VisibilityEvaluator evaluator = new V360VisibilityEvaluator(services);

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

            V360CardCatalogDTO failingCard = visibleCard(failingCardId, 'FailingCard');
            failingCard.order = 2;

            V360TestStubs.StubCardCatalogSource catalogSource = new V360TestStubs.StubCardCatalogSource();
            catalogSource.cardsByTabApiName.put(TAB_API_NAME, new List<V360CardCatalogDTO>{
                visibleCard(passingCardId, 'PassingCard'),
                failingCard
            });

            V360TestStubs.StubCardRuleSource ruleSource = new V360TestStubs.StubCardRuleSource();
            ruleSource.ruleGraphByCardId.put(passingCardId, new V360RuleGraph(passingCardId, new List<V360RuleGraph.RuleRow>{
                ruleWithFormula(passingRuleId, 'Passes', 'true')
            }));
            ruleSource.ruleGraphByCardId.put(failingCardId, new V360RuleGraph(failingCardId, new List<V360RuleGraph.RuleRow>{
                ruleWithFormula(failingRuleId, 'Fails', 'false')
            }));

            V360TestStubs.StubFormulaEngine formulaEngine = new V360TestStubs.StubFormulaEngine();
            formulaEngine.resultByFormula.put('true', true);
            formulaEngine.resultByFormula.put('false', false);

            V360VisibilityEvaluator.Services services = defaultServices();
            services.catalogSource = catalogSource;
            services.ruleSource = ruleSource;
            services.formulaEngine = formulaEngine;
            V360VisibilityEvaluator evaluator = new V360VisibilityEvaluator(services);

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

            V360CardCatalogDTO thirdCard = visibleCard(cardIdOrder3, 'ThirdCard');
            thirdCard.order = 3;
            V360CardCatalogDTO secondCard = visibleCard(cardIdOrder2, 'SecondCard');
            secondCard.order = 2;

            V360TestStubs.StubCardCatalogSource catalogSource = new V360TestStubs.StubCardCatalogSource();
            catalogSource.cardsByTabApiName.put(TAB_API_NAME, new List<V360CardCatalogDTO>{
                thirdCard,
                visibleCard(cardIdOrder1, 'FirstCard'),
                secondCard
            });

            V360VisibilityEvaluator.Services services = defaultServices();
            services.catalogSource = catalogSource;
            V360VisibilityEvaluator evaluator = new V360VisibilityEvaluator(services);

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
            V360VisibilityEvaluator.Services services = defaultServices(); // no cards registered for any tab
            V360VisibilityEvaluator evaluator = new V360VisibilityEvaluator(services);

            Test.startTest();
            List<V360CardDecision> visible = evaluator.evaluate(UserInfo.getUserId(), 'UnknownTab', new Account(Name = 'Probe'));
            Test.stopTest();

            Assert.isTrue(visible.isEmpty(), 'A tab with no configured cards must return an empty visible set');
        }
    }

    @IsTest
    static void descriptionFlowsFromCatalogDtoToDecision() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            Id cardId = V360TestStubs.fakeId(Account.SObjectType, 31);
            V360CardCatalogDTO card = visibleCard(cardId, 'DescribedCard');
            card.description = 'Shows the account\'s key details.';

            V360TestStubs.StubCardCatalogSource catalogSource = new V360TestStubs.StubCardCatalogSource();
            catalogSource.cardsByTabApiName.put(TAB_API_NAME, new List<V360CardCatalogDTO>{ card });

            V360VisibilityEvaluator.Services services = defaultServices();
            services.catalogSource = catalogSource;
            V360VisibilityEvaluator evaluator = new V360VisibilityEvaluator(services);

            Test.startTest();
            List<V360CardDecision> visible = evaluator.evaluate(UserInfo.getUserId(), TAB_API_NAME, new Account(Name = 'Probe'));
            Test.stopTest();

            Assert.areEqual(1, visible.size(), 'The described card must be visible');
            Assert.areEqual(
                'Shows the account\'s key details.',
                visible[0].description,
                'The catalog description must be carried onto the decision returned to the client'
            );
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
                visibleCard(cardId, 'MediatedCard')
            });

            V360VisibilityEvaluator.Services services = defaultServices();
            services.catalogSource = catalogSource;
            V360VisibilityEvaluator evaluator = new V360VisibilityEvaluator(services);

            Test.startTest();
            List<V360CardDecision> visible = evaluator.evaluate(UserInfo.getUserId(), TAB_API_NAME, new Account(Name = 'Probe'));
            Test.stopTest();

            Assert.areEqual(1, visible.size(), 'The evaluator must resolve visibility from mediated config reads, never end-user config access');
        }
    }
}
