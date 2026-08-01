@IsTest
private class V360DiagnosticsTest {

    @IsTest
    static void publishSendsOneEventWithAllFieldsPopulated() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            V360Diagnostics diagnostics = new V360Diagnostics();
            Id fakeRecordId = V360TestStubs.fakeId(Account.SObjectType, 1);
            V360Diagnostics.Entry entry = new V360Diagnostics.Entry(
                fakeRecordId, 'AccountOverview', 'AccountBalanceCard',
                V360Diagnostics.Reason.FORMULA_EVAL_ERROR, 'Formula raised a runtime error.'
            );

            Test.startTest();
            Database.SaveResult result = diagnostics.publish(entry);
            Test.stopTest();

            Assert.isTrue(result.isSuccess(), 'Publishing a well-formed diagnostic must succeed');
        }
    }

    @IsTest
    static void publishAllSendsOneEventPerEntryInOneCall() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            V360Diagnostics diagnostics = new V360Diagnostics();
            Id fakeRecordId = V360TestStubs.fakeId(Account.SObjectType, 2);
            List<V360Diagnostics.Entry> entries = new List<V360Diagnostics.Entry>{
                new V360Diagnostics.Entry(fakeRecordId, 'AccountOverview', 'CardOne', V360Diagnostics.Reason.UNKNOWN_FIELD, 'field missing'),
                new V360Diagnostics.Entry(fakeRecordId, 'AccountOverview', 'CardTwo', V360Diagnostics.Reason.PREDICATE_ERROR, 'predicate blew up')
            };

            Test.startTest();
            List<Database.SaveResult> results = diagnostics.publishAll(entries);
            Test.stopTest();

            Assert.areEqual(2, results.size(), 'One SaveResult must come back per diagnostic entry');
            for (Database.SaveResult result : results) {
                Assert.isTrue(result.isSuccess(), 'Every diagnostic in the batch must publish successfully');
            }
        }
    }

    @IsTest
    static void publishAllWithEmptyListIsANoOp() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            V360Diagnostics diagnostics = new V360Diagnostics();

            Test.startTest();
            List<Database.SaveResult> resultsForEmptyList = diagnostics.publishAll(new List<V360Diagnostics.Entry>());
            List<Database.SaveResult> resultsForNullList = diagnostics.publishAll(null);
            Test.stopTest();

            Assert.areEqual(0, resultsForEmptyList.size(), 'An empty list must publish nothing');
            Assert.areEqual(0, resultsForNullList.size(), 'A null list must publish nothing, not throw');
        }
    }

    @IsTest
    static void publishAllRejectsAnEntryWithNoReason() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            V360Diagnostics diagnostics = new V360Diagnostics();
            Id fakeRecordId = V360TestStubs.fakeId(Account.SObjectType, 3);
            V360Diagnostics.Entry entryWithNoReason = new V360Diagnostics.Entry(
                fakeRecordId, 'AccountOverview', 'CardOne', null, 'no reason given'
            );

            Test.startTest();
            Boolean threw = false;
            try {
                diagnostics.publishAll(new List<V360Diagnostics.Entry>{ entryWithNoReason });
            } catch (V360Diagnostics.V360DiagnosticsException ex) {
                threw = true;
            }
            Test.stopTest();

            Assert.isTrue(threw, 'A diagnostic entry must always carry a reason');
        }
    }

    @IsTest
    static void reasonEnumCoversTheClosedFailClosedVocabulary() {
        Assert.areEqual('FORMULA_INVALID', V360Diagnostics.Reason.FORMULA_INVALID.name());
        Assert.areEqual('FORMULA_EVAL_ERROR', V360Diagnostics.Reason.FORMULA_EVAL_ERROR.name());
        Assert.areEqual('UNKNOWN_FIELD', V360Diagnostics.Reason.UNKNOWN_FIELD.name());
        Assert.areEqual('UNKNOWN_BINDING', V360Diagnostics.Reason.UNKNOWN_BINDING.name());
        Assert.areEqual('PREDICATE_ERROR', V360Diagnostics.Reason.PREDICATE_ERROR.name());
    }
}
