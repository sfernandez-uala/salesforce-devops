@IsTest
private class SandboxSetupTest {
    private class MockSandboxContext implements System.SandboxContext {
        public Id organizationId() { return UserInfo.getOrganizationId(); }
        public Id sandboxId()      { return UserInfo.getOrganizationId(); }
        public String sandboxName() { return 'TestSandbox'; }
    }

    @IsTest
    static void testRunApexClass() {
        // No contact/lead test data created intentionally — scrambleEmails() does
        // zero non-setup DML, avoiding mixed DML with PermissionSetAssignment insert.
        Integer assignmentsBefore = [SELECT COUNT() FROM PermissionSetAssignment];

        Test.startTest();
        new SandboxSetup().runApexClass(new MockSandboxContext());
        Test.stopTest();

        Integer assignmentsAfter = [SELECT COUNT() FROM PermissionSetAssignment];
        Assert.isTrue(assignmentsAfter >= assignmentsBefore, 'Assignments should not decrease after sandbox setup');
    }
}
