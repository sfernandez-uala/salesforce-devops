trigger Pipeline_ProbeTrigger on Pipeline_Probe__c (before insert) {
    Pipeline_ProbeTriggerHandler.handleBeforeInsert(Trigger.new);
}
