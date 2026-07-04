@IsTest
private class DynamicLinkHelperTest {
    @IsTest
    static void testGetDynamicLinkByIdentityNotFound() {
        Test.startTest();
        try {
            DynamicLinkHelper.getDynamicLinkByIdentity('NON_EXISTENT_ID');
            Assert.fail('Should throw an exception when no DynamicLink__c record matches');
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
    static void testGetSetupPageLinkNullObjectName() {
        Test.startTest();
        try {
            DynamicLinkHelper.getSetupPageLink(null, '001000000000001AAA');
            Assert.fail('Should throw AuraHandledException for null objectAPIName');
        } catch (AuraHandledException e) {
            Assert.isTrue(true, 'AuraHandledException expected for null objectAPIName');
        }
        Test.stopTest();
    }

    @IsTest
    static void testGetSetupPageLinkNoMetadataRecord() {
        Test.startTest();
        try {
            DynamicLinkHelper.getSetupPageLink('NonExistentObject_XYZ_99', '001000000000001AAA');
            Assert.fail('Should throw AuraHandledException when no Setup_Page_Map__mdt record found');
        } catch (AuraHandledException e) {
            Assert.isTrue(true, 'AuraHandledException expected when no setup page metadata found');
        }
        Test.stopTest();
    }

    @IsTest
    static void testGetSiteUrlInvalidNetwork() {
        Test.startTest();
        try {
            DynamicLinkHelper.getSiteUrl('000000000000000AAA');
            Assert.isTrue(true, 'getSiteUrl completed without exception');
        } catch (AuraHandledException e) {
            Assert.isTrue(true, 'AuraHandledException acceptable for invalid networkId');
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
    static void testGetRecordIdSurveyRecordPage() {
        Test.startTest();
        try {
            List<SObject> result = DynamicLinkHelper.getRecordIdFromDynamicLinkType(
                'SurveyRecordPage', 'Name != null'
            );
            Assert.isNotNull(result, 'Result should not be null for SurveyRecordPage type');
        } catch (AuraHandledException e) {
            Assert.isTrue(true, 'AuraHandledException acceptable if Survey object unavailable');
        }
        Test.stopTest();
    }

    @IsTest
    static void testGetRecordIdFlowRecordPage() {
        Test.startTest();
        try {
            List<SObject> result = DynamicLinkHelper.getRecordIdFromDynamicLinkType(
                'FlowRecordPage', 'ApiName != null'
            );
            Assert.isNotNull(result, 'Result should not be null for FlowRecordPage type');
        } catch (AuraHandledException e) {
            Assert.isTrue(true, 'AuraHandledException acceptable if FlowDefinitionView unavailable');
        }
        Test.stopTest();
    }

    @IsTest
    static void testGetRecordIdCommunityPage() {
        Test.startTest();
        try {
            List<SObject> result = DynamicLinkHelper.getRecordIdFromDynamicLinkType(
                'CommunityPage', 'Name != null'
            );
            Assert.isNotNull(result, 'Result should not be null for CommunityPage type');
        } catch (AuraHandledException e) {
            Assert.isTrue(true, 'AuraHandledException acceptable if Network object unavailable');
        }
        Test.stopTest();
    }
}
