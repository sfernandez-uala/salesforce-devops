@IsTest
private class V360PredicateEvaluatorTest {

    @IsTest
    static void permissionSetPredicateResolvesTrueWhenUserHasIt() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            V360TestStubs.StubUserContext userContext = new V360TestStubs.StubUserContext();
            userContext.assignedPermissionSets.add('V360_Admin');
            V360PredicateEvaluator evaluator = new V360PredicateEvaluator(userContext);
            V360RuleGraph.PredicateRow predicate = new V360RuleGraph.PredicateRow(
                V360PredicateEvaluator.PERMISSION_SET, 'V360_Admin'
            );

            Test.startTest();
            Boolean result = evaluator.evaluate(predicate, 'Account');
            Test.stopTest();

            Assert.isTrue(result, 'User assigned V360_Admin must satisfy the PERMISSION_SET predicate');
        }
    }

    @IsTest
    static void permissionSetPredicateResolvesFalseWhenUserLacksIt() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            V360TestStubs.StubUserContext userContext = new V360TestStubs.StubUserContext();
            V360PredicateEvaluator evaluator = new V360PredicateEvaluator(userContext);
            V360RuleGraph.PredicateRow predicate = new V360RuleGraph.PredicateRow(
                V360PredicateEvaluator.PERMISSION_SET, 'V360_Admin'
            );

            Test.startTest();
            Boolean result = evaluator.evaluate(predicate, 'Account');
            Test.stopTest();

            Assert.isFalse(result, 'A user with no matching Permission Set assignment must fail the predicate');
        }
    }

    @IsTest
    static void flsReadPredicateResolvesTrueWhenFieldIsReadable() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            V360TestStubs.StubUserContext userContext = new V360TestStubs.StubUserContext();
            userContext.readableFields.add('Account.AnnualRevenue');
            V360PredicateEvaluator evaluator = new V360PredicateEvaluator(userContext);
            V360RuleGraph.PredicateRow predicate = new V360RuleGraph.PredicateRow(
                V360PredicateEvaluator.FLS_READ, 'AnnualRevenue'
            );

            Test.startTest();
            Boolean result = evaluator.evaluate(predicate, 'Account');
            Test.stopTest();

            Assert.isTrue(result, 'A field the user can read must satisfy the FLS_READ predicate');
        }
    }

    @IsTest
    static void flsReadPredicateResolvesFalseWhenFieldIsNotReadable() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            V360TestStubs.StubUserContext userContext = new V360TestStubs.StubUserContext();
            V360PredicateEvaluator evaluator = new V360PredicateEvaluator(userContext);
            V360RuleGraph.PredicateRow predicate = new V360RuleGraph.PredicateRow(
                V360PredicateEvaluator.FLS_READ, 'AnnualRevenue'
            );

            Test.startTest();
            Boolean result = evaluator.evaluate(predicate, 'Account');
            Test.stopTest();

            Assert.isFalse(result, 'A field the user cannot read must fail the FLS_READ predicate, never substituted');
        }
    }

    @IsTest
    static void unknownPredicateTypeThrows() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            V360PredicateEvaluator evaluator = new V360PredicateEvaluator(new V360TestStubs.StubUserContext());
            V360RuleGraph.PredicateRow predicate = new V360RuleGraph.PredicateRow('NOT_A_REAL_TYPE', 'Anything');

            Test.startTest();
            Boolean threw = false;
            try {
                evaluator.evaluate(predicate, 'Account');
            } catch (V360PredicateEvaluator.V360PredicateEvaluatorException ex) {
                threw = true;
            }
            Test.stopTest();

            Assert.isTrue(threw, 'An unrecognized predicate type must be rejected, not silently ignored');
        }
    }

    @IsTest
    static void nullPredicateThrows() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            V360PredicateEvaluator evaluator = new V360PredicateEvaluator(new V360TestStubs.StubUserContext());

            Test.startTest();
            Boolean threw = false;
            try {
                evaluator.evaluate(null, 'Account');
            } catch (V360PredicateEvaluator.V360PredicateEvaluatorException ex) {
                threw = true;
            }
            Test.stopTest();

            Assert.isTrue(threw, 'A null predicate row must be rejected');
        }
    }

    @IsTest
    static void flsReadPredicateWithoutAnchorSObjectApiNameThrows() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            V360PredicateEvaluator evaluator = new V360PredicateEvaluator(new V360TestStubs.StubUserContext());
            V360RuleGraph.PredicateRow predicate = new V360RuleGraph.PredicateRow(
                V360PredicateEvaluator.FLS_READ, 'AnnualRevenue'
            );

            Test.startTest();
            Boolean threw = false;
            try {
                evaluator.evaluate(predicate, null);
            } catch (V360PredicateEvaluator.V360PredicateEvaluatorException ex) {
                threw = true;
            }
            Test.stopTest();

            Assert.isTrue(threw, 'An FLS_READ predicate cannot be resolved without the anchor SObject API name');
        }
    }
}
