@IsTest
private class V360FormulaGatewayTest {

    @IsTest
    static void evaluateReturnsTrueWhenFormulaMatchesRecord() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            V360FormulaGateway gateway = new V360FormulaGateway();
            gateway.build('ISBLANK(Name) = false', Account.SObjectType);
            Account probe = new Account(Name = 'Vista 360 Probe');

            Test.startTest();
            Boolean result = gateway.evaluate(probe);
            Test.stopTest();

            Assert.isTrue(result, 'A non-blank Name should satisfy ISBLANK(Name) = false');
        }
    }

    @IsTest
    static void evaluateReturnsFalseWhenFormulaDoesNotMatchRecord() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            V360FormulaGateway gateway = new V360FormulaGateway();
            gateway.build('AnnualRevenue > 1000000', Account.SObjectType);
            Account probe = new Account(Name = 'Vista 360 Probe', AnnualRevenue = 100);

            Test.startTest();
            Boolean result = gateway.evaluate(probe);
            Test.stopTest();

            Assert.isFalse(result, 'AnnualRevenue = 100 should not satisfy AnnualRevenue > 1000000');
        }
    }

    @IsTest
    static void combinedExpressionWithParenthesesEvaluatesCorrectly() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            // A AND (B OR C): Name is set (A=true), AnnualRevenue <= 0 (B=false), NumberOfEmployees > 0 (C=true)
            V360FormulaGateway gateway = new V360FormulaGateway();
            gateway.build(
                'ISBLANK(Name) = false && (AnnualRevenue > 0 || NumberOfEmployees > 0)',
                Account.SObjectType
            );
            Account probe = new Account(Name = 'Vista 360 Probe', AnnualRevenue = 0, NumberOfEmployees = 5);

            Test.startTest();
            Boolean result = gateway.evaluate(probe);
            Test.stopTest();

            Assert.isTrue(result, 'A AND (B OR C) must resolve true when A and C are true even though B is false');
        }
    }

    @IsTest
    static void buildRejectsFormulaOverTheMaxLength() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            String oversizedFormula = 'ISBLANK(Name) = false && '.repeat(200);
            Assert.isTrue(
                oversizedFormula.length() > V360FormulaGateway.MAX_FORMULA_LENGTH,
                'Test fixture must actually exceed the cap for this assertion to be meaningful'
            );
            V360FormulaGateway gateway = new V360FormulaGateway();

            Test.startTest();
            Boolean threw = false;
            try {
                gateway.build(oversizedFormula, Account.SObjectType);
            } catch (V360FormulaGateway.V360FormulaGatewayException ex) {
                threw = true;
            }
            Test.stopTest();

            Assert.isTrue(threw, 'A formula over the max length must be rejected before it reaches the platform');
        }
    }

    @IsTest
    static void buildRejectsANullAnchorType() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            V360FormulaGateway gateway = new V360FormulaGateway();

            Test.startTest();
            Boolean threw = false;
            try {
                gateway.build('ISBLANK(Name) = false', null);
            } catch (V360FormulaGateway.V360FormulaGatewayException ex) {
                threw = true;
            }
            Test.stopTest();

            Assert.isTrue(threw, 'A formula cannot be built without an anchor SObject type');
        }
    }

    @IsTest
    static void buildRejectsBlankFormula() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            V360FormulaGateway gateway = new V360FormulaGateway();

            Test.startTest();
            Boolean threw = false;
            try {
                gateway.build('', Account.SObjectType);
            } catch (V360FormulaGateway.V360FormulaGatewayException ex) {
                threw = true;
            }
            Test.stopTest();

            Assert.isTrue(threw, 'A blank formula must be rejected');
        }
    }

    @IsTest
    static void buildRejectsSyntacticallyInvalidFormula() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            V360FormulaGateway gateway = new V360FormulaGateway();

            Test.startTest();
            Boolean threw = false;
            try {
                gateway.build('NOT_A_REAL_FUNCTION(Name)', Account.SObjectType);
            } catch (V360FormulaGateway.V360FormulaGatewayException ex) {
                threw = true;
            }
            Test.stopTest();

            Assert.isTrue(threw, 'An invalid formula must be rejected at build time, not stored');
        }
    }

    @IsTest
    static void getReferencedFieldsIncludesOneLevelParentTraversal() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            V360FormulaGateway gateway = new V360FormulaGateway();
            gateway.build('ISBLANK(Name) = false && ISBLANK(Parent.Name) = false', Account.SObjectType);

            Test.startTest();
            Set<String> referencedFields = gateway.getReferencedFields();
            Test.stopTest();

            Assert.isTrue(referencedFields.contains('Name'), 'Direct field Name must be referenced');
            Assert.isTrue(
                referencedFields.contains('Parent.Name'),
                'One-level parent traversal must be represented as the full relationship path'
            );
        }
    }

    @IsTest
    static void evaluateBeforeBuildThrows() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            V360FormulaGateway gateway = new V360FormulaGateway();

            Test.startTest();
            Boolean threw = false;
            try {
                gateway.evaluate(new Account(Name = 'Vista 360 Probe'));
            } catch (V360FormulaGateway.V360FormulaGatewayException ex) {
                threw = true;
            }
            Test.stopTest();

            Assert.isTrue(threw, 'evaluate() must require a prior successful build()');
        }
    }

    @IsTest
    static void getReferencedFieldsBeforeBuildThrows() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            V360FormulaGateway gateway = new V360FormulaGateway();

            Test.startTest();
            Boolean threw = false;
            try {
                gateway.getReferencedFields();
            } catch (V360FormulaGateway.V360FormulaGatewayException ex) {
                threw = true;
            }
            Test.stopTest();

            Assert.isTrue(threw, 'getReferencedFields() must require a prior successful build()');
        }
    }

    @IsTest
    static void buildAcceptsAFormulaReferencingAnExistingCustomPermission() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            V360FormulaGateway gateway = new V360FormulaGateway();

            Test.startTest();
            gateway.build('$Permission.V360_ManageVisibilityRules', Account.SObjectType);
            Boolean result = gateway.evaluate(new Account(Name = 'Vista 360 Probe'));
            Test.stopTest();

            Assert.isNotNull(result, 'A formula referencing an existing Custom Permission must build and evaluate');
        }
    }
}
