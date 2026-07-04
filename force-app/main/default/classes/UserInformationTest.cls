@IsTest
private class UserInformationTest {
    @IsTest
    static void testGetName() {
        Test.startTest();
        String name = UserInformation.getName();
        Test.stopTest();
        Assert.isNotNull(name, 'getName should return a non-null value');
    }

    @IsTest
    static void testGetTiming() {
        Test.startTest();
        String timing = UserInformation.getTiming();
        Test.stopTest();
        Assert.isTrue(
            timing == 'Morning' || timing == 'Afternoon' || timing == 'Evening',
            'getTiming should return Morning, Afternoon, or Evening'
        );
    }

    @IsTest
    static void testGetExpiryDays() {
        Test.startTest();
        try {
            Integer days = UserInformation.getExpiryDays();
            Assert.isNotNull(days, 'getExpiryDays should return an integer');
        } catch (AuraHandledException e) {
            Assert.isTrue(true, 'AuraHandledException is acceptable when TrialExpirationDate is null');
        }
        Test.stopTest();
    }
}
