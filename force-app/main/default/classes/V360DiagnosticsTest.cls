@IsTest
private class V360DiagnosticsTest {

    /**
     * A default diagnostic entry for the given record/card/reason, with a
     * placeholder detail. Individual tests mutate the returned instance's
     * fields (e.g. detail) rather than passing every field through a
     * constructor.
     */
    private static V360Diagnostics.Entry entry(Id recordId, String cardName, V360Diagnostics.Reason reason) {
        V360Diagnostics.Entry newEntry = new V360Diagnostics.Entry();
        newEntry.recordId = recordId;
        newEntry.tabName = 'AccountOverview';
        newEntry.cardName = cardName;
        newEntry.reason = reason;
        newEntry.detail = 'Diagnostic detail for ' + cardName;
        return newEntry;
    }

    @IsTest
    static void publishSendsOneEventWithAllFieldsPopulated() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            V360Diagnostics diagnostics = new V360Diagnostics();
            Id fakeRecordId = V360TestStubs.fakeId(Account.SObjectType, 1);
            V360Diagnostics.Entry diagnosticEntry = entry(
                fakeRecordId, 'AccountBalanceCard', V360Diagnostics.Reason.FORMULA_EVAL_ERROR
            );
            diagnosticEntry.detail = 'Formula raised a runtime error.';

            Test.startTest();
            Database.SaveResult result = diagnostics.publish(diagnosticEntry);
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
                entry(fakeRecordId, 'CardOne', V360Diagnostics.Reason.UNKNOWN_FIELD),
                entry(fakeRecordId, 'CardTwo', V360Diagnostics.Reason.PREDICATE_ERROR)
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
            V360Diagnostics.Entry entryWithNoReason = entry(fakeRecordId, 'CardOne', null);

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
        Assert.areEqual(
            'FORMULA_INVALID', V360Diagnostics.Reason.FORMULA_INVALID.name(),
            'FORMULA_INVALID must remain in the fail-closed reason vocabulary'
        );
        Assert.areEqual(
            'FORMULA_EVAL_ERROR', V360Diagnostics.Reason.FORMULA_EVAL_ERROR.name(),
            'FORMULA_EVAL_ERROR must remain in the fail-closed reason vocabulary'
        );
        Assert.areEqual(
            'UNKNOWN_FIELD', V360Diagnostics.Reason.UNKNOWN_FIELD.name(),
            'UNKNOWN_FIELD must remain in the fail-closed reason vocabulary'
        );
        Assert.areEqual(
            'UNKNOWN_BINDING', V360Diagnostics.Reason.UNKNOWN_BINDING.name(),
            'UNKNOWN_BINDING must remain in the fail-closed reason vocabulary'
        );
        Assert.areEqual(
            'PREDICATE_ERROR', V360Diagnostics.Reason.PREDICATE_ERROR.name(),
            'PREDICATE_ERROR must remain in the fail-closed reason vocabulary'
        );
    }
}
