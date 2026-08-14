@IsTest
private class V360RecordSelectorTest {

    private static final String TAB_API_NAME = 'V360Test_AnchorTab';

    @TestSetup
    static void setupTestData() {
        Account parentAccount = new Account(Name = 'V360 Test Parent', Industry = 'Banking');
        insert parentAccount;
        Account childAccount = new Account(Name = 'V360 Test Child', Industry = 'Technology', ParentId = parentAccount.Id);
        insert childAccount;
    }

    private static V360CardCatalogDTO cardDto(Id cardId, String developerName) {
        V360CardCatalogDTO dto = new V360CardCatalogDTO();
        dto.cardId = cardId;
        dto.developerName = developerName;
        return dto;
    }

    private static V360RecordSelector.Request buildRequest(
        Id recordId, Id cardId, V360RuleGraph ruleGraph
    ) {
        V360RecordSelector.Request request = new V360RecordSelector.Request();
        request.recordId = recordId;
        request.tabApiName = TAB_API_NAME;
        request.sObjectApiName = 'Account';
        request.cards = new List<V360CardCatalogDTO>{ cardDto(cardId, 'V360Test_Card') };
        request.ruleGraphsByCardId = new Map<Id, V360RuleGraph>{ cardId => ruleGraph };
        request.formulaEngine = new V360FormulaGateway();
        request.diagnostics = new V360Diagnostics();
        return request;
    }

    @IsTest
    static void resolveRecordQueriesDirectAndParentFormulaFieldsWhenBothValid() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            // Given
            Account childAccount = [SELECT Id FROM Account WHERE Name = 'V360 Test Child'];
            Id cardId = V360TestStubs.fakeId(V360_Card__c.SObjectType, 1);
            V360RuleGraph.RuleRow rule = new V360RuleGraph.RuleRow();
            rule.active = true;
            rule.visibilityFormula = 'ISPICKVAL(Industry, \'Technology\') || ISPICKVAL(Parent.Industry, \'Banking\')';
            V360RuleGraph ruleGraph = new V360RuleGraph(cardId, new List<V360RuleGraph.RuleRow>{ rule });
            V360RecordSelector selector = new V360RecordSelector();

            // When
            Test.startTest();
            SObject record = selector.resolveRecord(buildRequest(childAccount.Id, cardId, ruleGraph));
            Test.stopTest();

            // Then
            Assert.areEqual('Technology', (String) record.get('Industry'), 'Direct field must be queried');
            Assert.areEqual(
                'Banking', (String) record.getSObject('Parent').get('Industry'),
                'One-level parent field must be queried'
            );
        }
    }

    @IsTest
    static void resolveRecordOmitsUnknownFieldWhenFlsReadTargetsNonexistentField() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            // Given
            Account childAccount = [SELECT Id FROM Account WHERE Name = 'V360 Test Child'];
            Id cardId = V360TestStubs.fakeId(V360_Card__c.SObjectType, 2);
            V360RuleGraph.RuleRow rule = new V360RuleGraph.RuleRow();
            rule.active = true;
            rule.predicates.add(new V360RuleGraph.PredicateRow('FLS_READ', 'Nonexistent_Field__c'));
            V360RuleGraph ruleGraph = new V360RuleGraph(cardId, new List<V360RuleGraph.RuleRow>{ rule });
            V360RecordSelector selector = new V360RecordSelector();

            // When
            Test.startTest();
            SObject record = selector.resolveRecord(buildRequest(childAccount.Id, cardId, ruleGraph));
            Test.stopTest();

            // Then
            Boolean threwOnUnqueriedField = false;
            try {
                record.get('Nonexistent_Field__c');
            } catch (Exception fieldNotQueriedException) {
                threwOnUnqueriedField = true;
            }
            Assert.isTrue(threwOnUnqueriedField, 'An unknown field must never be added to the anchor SOQL');
        }
    }

    @IsTest
    static void resolveRecordOmitsDeeperFieldWhenFormulaReferencesTwoParentLevels() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            // Given
            Account childAccount = [SELECT Id FROM Account WHERE Name = 'V360 Test Child'];
            Id cardId = V360TestStubs.fakeId(V360_Card__c.SObjectType, 3);
            V360RuleGraph.RuleRow rule = new V360RuleGraph.RuleRow();
            rule.active = true;
            rule.visibilityFormula = 'ISPICKVAL(Parent.Parent.Industry, \'Banking\')';
            V360RuleGraph ruleGraph = new V360RuleGraph(cardId, new List<V360RuleGraph.RuleRow>{ rule });
            V360RecordSelector selector = new V360RecordSelector();

            // When
            Test.startTest();
            SObject record = selector.resolveRecord(buildRequest(childAccount.Id, cardId, ruleGraph));
            Test.stopTest();

            // Then
            Boolean threwOnUnqueriedParent = false;
            try {
                record.getSObject('Parent').getSObject('Parent');
            } catch (Exception fieldNotQueriedException) {
                threwOnUnqueriedParent = true;
            }
            Assert.isTrue(threwOnUnqueriedParent, 'A path deeper than one parent level must never reach the anchor SOQL');
        }
    }

    @IsTest
    static void resolveRecordSkipsInactiveRulesWhenGatheringFields() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            // Given
            Account childAccount = [SELECT Id FROM Account WHERE Name = 'V360 Test Child'];
            Id cardId = V360TestStubs.fakeId(V360_Card__c.SObjectType, 4);
            V360RuleGraph.RuleRow inactiveRule = new V360RuleGraph.RuleRow();
            inactiveRule.active = false;
            inactiveRule.visibilityFormula = 'ISPICKVAL(Industry, \'Technology\')';
            V360RuleGraph ruleGraph = new V360RuleGraph(cardId, new List<V360RuleGraph.RuleRow>{ inactiveRule });
            V360RecordSelector selector = new V360RecordSelector();

            // When
            Test.startTest();
            SObject record = selector.resolveRecord(buildRequest(childAccount.Id, cardId, ruleGraph));
            Test.stopTest();

            // Then
            Boolean threwOnUnqueriedField = false;
            try {
                record.get('Industry');
            } catch (Exception fieldNotQueriedException) {
                threwOnUnqueriedField = true;
            }
            Assert.isTrue(threwOnUnqueriedField, 'An inactive rule\'s fields must never be gathered');
        }
    }

    @IsTest
    static void resolveRecordThrowsWhenAnchorRecordIsNotFound() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            // Given
            Id fakeAccountId = V360TestStubs.fakeId(Account.SObjectType, 99);
            V360RecordSelector.Request request = new V360RecordSelector.Request();
            request.recordId = fakeAccountId;
            request.tabApiName = TAB_API_NAME;
            request.sObjectApiName = 'Account';
            request.cards = new List<V360CardCatalogDTO>();
            request.ruleGraphsByCardId = new Map<Id, V360RuleGraph>();
            request.formulaEngine = new V360FormulaGateway();
            request.diagnostics = new V360Diagnostics();
            V360RecordSelector selector = new V360RecordSelector();

            // When / Then
            Test.startTest();
            Boolean threw = false;
            try {
                selector.resolveRecord(request);
                Assert.fail('Expected V360RecordSelectorException for a nonexistent anchor record');
            } catch (V360RecordSelector.V360RecordSelectorException ex) {
                threw = true;
            }
            Test.stopTest();

            Assert.isTrue(threw, 'A record Id that resolves to nothing must fail loudly, not silently');
        }
    }
}
