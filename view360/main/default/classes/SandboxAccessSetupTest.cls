@IsTest
private class SandboxAccessSetupTest {
    @IsTest
    static void testAssignDeveloperPermissionSets() {
        Integer assignmentsBefore = [SELECT COUNT() FROM PermissionSetAssignment];

        Test.startTest();
        SandboxAccessSetup.assignDeveloperPermissionSets();
        Test.stopTest();

        Integer assignmentsAfter = [SELECT COUNT() FROM PermissionSetAssignment];
        Assert.isTrue(assignmentsAfter >= assignmentsBefore, 'Assignments should not decrease');
    }
}
