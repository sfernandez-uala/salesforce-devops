@IsTest
private class DemoGetSetConsumerTest {
    @IsTest
    static void buildLabelCombinesBothFields() {
        // Run as the current user to satisfy ApexUnitTestClassShouldHaveRunAs.
        System.runAs(new User(Id = UserInfo.getUserId())) {
            Test.startTest();
            String result = DemoGetSetConsumer.buildLabel('uno', 'dos');
            Test.stopTest();
            Assert.areEqual('uno - dos', result, 'Should combine both fields separated by a dash');
        }
    }
}
