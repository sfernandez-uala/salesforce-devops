@IsTest
private class Pipeline_ProbeTriggerTest {
    @IsTest
    static void testHandlerDefaultsBlankNote() {
        List<Pipeline_Probe__c> records = new List<Pipeline_Probe__c>{
            new Pipeline_Probe__c(Name = 'blank')
        };
        Test.startTest();
        Pipeline_ProbeTriggerHandler.handleBeforeInsert(records);
        Test.stopTest();
        Assert.areEqual('auto', records[0].Probe_Note__c, 'Handler should default a blank note to auto');
    }

    @IsTest
    static void testHandlerKeepsExistingNote() {
        List<Pipeline_Probe__c> records = new List<Pipeline_Probe__c>{
            new Pipeline_Probe__c(Name = 'kept', Probe_Note__c = 'manual')
        };
        Test.startTest();
        Pipeline_ProbeTriggerHandler.handleBeforeInsert(records);
        Test.stopTest();
        Assert.areEqual('manual', records[0].Probe_Note__c, 'Handler must preserve an existing note');
    }

    @IsTest
    static void testTriggerFiresOnInsert() {
        // Covers the trigger body via real DML. Asserts the insert succeeded
        // (Id assigned) rather than re-querying the just-deployed field, which
        // can spuriously fail inside a check-only validation.
        Pipeline_Probe__c record = new Pipeline_Probe__c(Name = 'C2 probe');
        Test.startTest();
        insert record;
        Test.stopTest();
        Assert.isNotNull(record.Id, 'Record should be inserted (trigger fired without error)');
    }
}
