@IsTest
private class B2FailProbeTest {
    // Gate test B2: a deliberately failing assertion. Because uat/main run
    // RunLocalTests, this test must FAIL the delta-check-deploy / deploy
    // validation, proving the RunLocalTests boundary blocks failing tests.
    // This branch must NEVER merge; it is deleted after the gate fails.
    @IsTest
    static void deliberateFailure() {
        Test.startTest();
        Integer actual = 1;
        Test.stopTest();
        Assert.areEqual(2, actual, 'B2 gate probe: intentional failing assertion (expected 2, got 1)');
    }
}
