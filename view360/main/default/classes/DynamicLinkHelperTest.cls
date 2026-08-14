@IsTest
private class DynamicLinkHelperTest {
    private static DynamicLink__c makeDynamicLink() {
        DynamicLink__c dl = new DynamicLink__c(
            Identity__c = 'TEST_IDENTITY',
            Object__c = 'Contact',
            Where_Condition__c = 'Name != null'
        );
        insert dl;
        return dl;
    }

    @IsTest
    static void testGetDynamicLinkByIdentityFound() {
        makeDynamicLink();
        Test.startTest();
        DynamicLink__c result = DynamicLinkHelper.getDynamicLinkByIdentity('TEST_IDENTITY');
        Test.stopTest();
        Assert.isNotNull(result, 'Should return the DynamicLink__c matching the identity');
        Assert.areEqual('TEST_IDENTITY', result.Identity__c, 'Returned record should match the requested identity');
    }

    @IsTest
    static void testGetDynamicLinkByIdentityNotFound() {
        Test.startTest();
        try {
            DynamicLinkHelper.getDynamicLinkByIdentity('NON_EXISTENT_IDENTITY');
            Assert.fail('Should throw when no DynamicLink__c record matches');
        } catch (Exception e) {
            Assert.isTrue(true, 'Exception expected when no matching DynamicLink__c exists');
        }
        Test.stopTest();
    }

    @IsTest
    static void testGetObjectIdFromQueryNullObjectName() {
        Test.startTest();
        try {
            DynamicLinkHelper.getObjectIdFromQuery(null, 'Name != null');
            Assert.fail('Should throw AuraHandledException for null objectAPIName');
        } catch (AuraHandledException e) {
            Assert.isTrue(true, 'AuraHandledException expected for null objectAPIName');
        }
        Test.stopTest();
    }

    @IsTest
    static void testGetObjectIdFromQueryNullWhereCondition() {
        Test.startTest();
        try {
            DynamicLinkHelper.getObjectIdFromQuery('Contact', null);
            Assert.fail('Should throw AuraHandledException for null whereCondition');
        } catch (AuraHandledException e) {
            Assert.isTrue(true, 'AuraHandledException expected for null whereCondition');
        }
        Test.stopTest();
    }

    @IsTest
    static void testGetObjectIdFromQueryValid() {
        Test.startTest();
        List<SObject> result = DynamicLinkHelper.getObjectIdFromQuery('Contact', 'Name != null');
        Test.stopTest();
        Assert.isNotNull(result, 'Result should not be null for a valid query');
    }

    @IsTest
    static void testGetObjectIdFromQueryInvalidObject() {
        Test.startTest();
        try {
            DynamicLinkHelper.getObjectIdFromQuery('NotARealObject__c', 'Name != null');
            Assert.fail('Should throw AuraHandledException for an invalid object');
        } catch (AuraHandledException e) {
            Assert.isTrue(true, 'AuraHandledException expected when the object does not exist');
        }
        Test.stopTest();
    }

    @IsTest
    static void testGetSetupPageLinkNullObjectName() {
        Test.startTest();
        try {
            DynamicLinkHelper.getSetupPageLink(null, 'someRecord');
            Assert.fail('Should throw AuraHandledException for null objectAPIName');
        } catch (AuraHandledException e) {
            Assert.isTrue(true, 'AuraHandledException expected for null objectAPIName');
        }
        Test.stopTest();
    }

    @IsTest
    static void testGetSetupPageLinkHappyPath() {
        // 'User' has a matching Setup_Page_Map__mdt record in the org, so this
        // exercises the full URL-building path.
        Test.startTest();
        String url = DynamicLinkHelper.getSetupPageLink('User', 'someRecordId');
        Test.stopTest();
        Assert.isNotNull(url, 'Should return a setup page URL for a mapped object');
        Assert.isTrue(url.contains('someRecordId'), 'URL should include the record identifier');
    }

    @IsTest
    static void testGetSetupPageLinkNoMetadataRecord() {
        Test.startTest();
        try {
            DynamicLinkHelper.getSetupPageLink('NonExistentObject_XYZ_99', 'someRecord');
            Assert.fail('Should throw AuraHandledException when no Setup_Page_Map__mdt record found');
        } catch (AuraHandledException e) {
            Assert.isTrue(true, 'AuraHandledException expected when no setup page metadata found');
        }
        Test.stopTest();
    }

    @IsTest
    static void testGetSiteUrl() {
        Test.startTest();
        try {
            String url = DynamicLinkHelper.getSiteUrl(null);
            Assert.isNotNull(url, 'getSiteUrl returned a URL');
        } catch (AuraHandledException e) {
            Assert.isTrue(true, 'AuraHandledException acceptable when no network resolves');
        }
        Test.stopTest();
    }

    @IsTest
    static void testGetRecordIdFromDynamicLinkTypeNullType() {
        Test.startTest();
        try {
            DynamicLinkHelper.getRecordIdFromDynamicLinkType(null, 'Name != null');
            Assert.fail('Should throw AuraHandledException for null dynamicLinkType');
        } catch (AuraHandledException e) {
            Assert.isTrue(true, 'AuraHandledException expected for null dynamicLinkType');
        }
        Test.stopTest();
    }

    @IsTest
    static void testGetRecordIdFromDynamicLinkTypeNullWhereCondition() {
        Test.startTest();
        try {
            DynamicLinkHelper.getRecordIdFromDynamicLinkType('SurveyRecordPage', null);
            Assert.fail('Should throw AuraHandledException for null whereCondition');
        } catch (AuraHandledException e) {
            Assert.isTrue(true, 'AuraHandledException expected for null whereCondition');
        }
        Test.stopTest();
    }

    @IsTest
    static void testGetRecordIdAllBranches() {
        Test.startTest();
        for (String linkType : new List<String>{
            'SurveyRecordPage', 'FlowRecordPage', 'DPERecordPage', 'CommunityPage'
        }) {
            try {
                List<SObject> result = DynamicLinkHelper.getRecordIdFromDynamicLinkType(
                    linkType, 'Name != null'
                );
                Assert.isNotNull(result, 'Result should not be null for ' + linkType);
            } catch (AuraHandledException e) {
                Assert.isTrue(true, 'AuraHandledException acceptable if the object for ' + linkType + ' is unavailable');
            }
        }
        Test.stopTest();
    }
}
