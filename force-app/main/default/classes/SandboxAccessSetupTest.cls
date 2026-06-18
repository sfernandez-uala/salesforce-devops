@IsTest
private class SandboxAccessSetupTest {
    @IsTest
    static void testAssignDeveloperPermissionSets() {
        Test.startTest();
        SandboxAccessSetup.assignDeveloperPermissionSets();
        Test.stopTest();
        // Verifies the method completes without exception whether
        // Test_Httpbin_Access is already assigned, absent, or the user list is empty.
    }
}
