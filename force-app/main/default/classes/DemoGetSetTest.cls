@IsTest
private class DemoGetSetTest {
    @IsTest
    static void gettersReturnValuesSetBySetters() {
        // Run as the current user to satisfy ApexUnitTestClassShouldHaveRunAs.
        System.runAs(new User(Id = UserInfo.getUserId())) {
            DemoGetSet demo = new DemoGetSet();
            demo.setCampoUno('a');
            demo.setCampoDos('b');
            Assert.areEqual('a', demo.getCampoUno(), 'campoUno should round-trip through get/set');
            Assert.areEqual('b', demo.getCampoDos(), 'campoDos should round-trip through get/set');
        }
    }
}
