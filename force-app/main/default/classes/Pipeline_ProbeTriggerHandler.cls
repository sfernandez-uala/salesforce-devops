public with sharing class Pipeline_ProbeTriggerHandler {
    public static void handleBeforeInsert(List<Pipeline_Probe__c> records) {
        for (Pipeline_Probe__c record : records) {
            if (String.isBlank(record.Probe_Note__c)) {
                record.Probe_Note__c = 'auto-v2';
            }
        }
    }
}
