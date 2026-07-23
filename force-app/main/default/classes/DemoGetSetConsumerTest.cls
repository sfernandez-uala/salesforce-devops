@IsTest
private class DemoGetSetConsumerTest {
    @IsTest
    static void buildLabelCombinesBothFields() {
        Test.startTest();
        String result = DemoGetSetConsumer.buildLabel('uno', 'dos');
        Test.stopTest();
        Assert.areEqual('uno - dos', result, 'Should combine both fields separated by a dash');
    }
}
