@IsTest
private class SectionBlockControllerTest {
    @IsTest
    static void testGetSectionsByTypeNullSectionType() {
        Test.startTest();
        try {
            SectionBlockController.getSectionsByType(null, 'HomePage');
            Assert.fail('Should throw AuraHandledException for null sectionType');
        } catch (AuraHandledException e) {
            Assert.isTrue(true, 'AuraHandledException expected for null sectionType');
        }
        Test.stopTest();
    }

    @IsTest
    static void testGetSectionsByTypeNullPageType() {
        Test.startTest();
        try {
            SectionBlockController.getSectionsByType('Banner', null);
            Assert.fail('Should throw AuraHandledException for null pageType');
        } catch (AuraHandledException e) {
            Assert.isTrue(true, 'AuraHandledException expected for null pageType');
        }
        Test.stopTest();
    }

    @IsTest
    static void testGetSectionsByTypeNoPageRecord() {
        Test.startTest();
        try {
            SectionBlockController.getSectionsByType('Banner', 'NonExistentPageType_XYZ');
            Assert.fail('Should throw AuraHandledException when no Page__c record found');
        } catch (AuraHandledException e) {
            Assert.isTrue(true, 'AuraHandledException expected when no Page__c record matches pageType');
        }
        Test.stopTest();
    }

    @IsTest
    static void testGetSectionsByPageIdNullSectionType() {
        Test.startTest();
        try {
            SectionBlockController.getSectionsByPageId(null, '000000000000000AAA');
            Assert.fail('Should throw AuraHandledException for null sectionType');
        } catch (AuraHandledException e) {
            Assert.isTrue(true, 'AuraHandledException expected for null sectionType');
        }
        Test.stopTest();
    }

    @IsTest
    static void testGetSectionsByPageIdNullPageId() {
        Test.startTest();
        try {
            SectionBlockController.getSectionsByPageId('Banner', null);
            Assert.fail('Should throw AuraHandledException for null pageId');
        } catch (AuraHandledException e) {
            Assert.isTrue(true, 'AuraHandledException expected for null pageId');
        }
        Test.stopTest();
    }

    @IsTest
    static void testGetSectionsByPageIdValidParams() {
        Test.startTest();
        List<Section__c> result = SectionBlockController.getSectionsByPageId('Banner', '000000000000000AAA');
        Test.stopTest();
        Assert.isNotNull(result, 'getSectionsByPageId should return a non-null list');
    }

    @IsTest
    static void testGetDynamicLinksEmptyList() {
        Test.startTest();
        List<DynamicLink__c> result = SectionBlockController.getDynamicLinks(new List<String>());
        Test.stopTest();
        Assert.isNotNull(result, 'getDynamicLinks with empty list should return an empty non-null list');
        Assert.areEqual(0, result.size(), 'getDynamicLinks with empty input should return empty list');
    }

    @IsTest
    static void testGetDynamicLinksNonEmptyList() {
        Test.startTest();
        List<DynamicLink__c> result = SectionBlockController.getDynamicLinks(
            new List<String>{ '000000000000000AAA' }
        );
        Test.stopTest();
        Assert.isNotNull(result, 'getDynamicLinks with a fake id should return a non-null list');
    }

    @IsTest
    static void testGetSectionWithBlockBySectionIdNull() {
        Test.startTest();
        try {
            SectionBlockController.getSectionWithBlockBySectionId(null);
            Assert.fail('Should throw AuraHandledException for null sectionId');
        } catch (AuraHandledException e) {
            Assert.isTrue(true, 'AuraHandledException expected for null sectionId');
        }
        Test.stopTest();
    }

    @IsTest
    static void testGetSectionWithBlockBySectionIdNoData() {
        Test.startTest();
        try {
            SectionBlockController.getSectionWithBlockBySectionId('000000000000000AAA');
            Assert.fail('Should throw when no matching Section__c record exists');
        } catch (Exception e) {
            Assert.isTrue(true, 'Exception expected when no Section__c data matches the given id');
        }
        Test.stopTest();
    }

    @IsTest
    static void testGetSectionsWithBlocksByTypeNullSectionType() {
        Test.startTest();
        try {
            SectionBlockController.getSectionsWithBlocksByType(null, 'HomePage');
            Assert.fail('Should throw AuraHandledException for null sectionType');
        } catch (AuraHandledException e) {
            Assert.isTrue(true, 'AuraHandledException expected for null sectionType');
        }
        Test.stopTest();
    }

    @IsTest
    static void testGetSectionsWithBlocksByTypeNullPageType() {
        Test.startTest();
        try {
            SectionBlockController.getSectionsWithBlocksByType('Banner', null);
            Assert.fail('Should throw AuraHandledException for null pageType');
        } catch (AuraHandledException e) {
            Assert.isTrue(true, 'AuraHandledException expected for null pageType');
        }
        Test.stopTest();
    }

    @IsTest
    static void testGetSectionsWithBlocksByTypeNoPage() {
        Test.startTest();
        try {
            SectionBlockController.getSectionsWithBlocksByType('Banner', 'NonExistentPageType_XYZ');
            Assert.fail('Should throw AuraHandledException when no Page__c record found');
        } catch (AuraHandledException e) {
            Assert.isTrue(true, 'AuraHandledException expected when no Page__c record matches pageType');
        }
        Test.stopTest();
    }

    @IsTest
    static void testGetSectionsWithBlocksByPageIdNullSectionType() {
        Test.startTest();
        try {
            SectionBlockController.getSectionsWithBlocksByPageId(null, '000000000000000AAA');
            Assert.fail('Should throw AuraHandledException for null sectionType');
        } catch (AuraHandledException e) {
            Assert.isTrue(true, 'AuraHandledException expected for null sectionType');
        }
        Test.stopTest();
    }

    @IsTest
    static void testGetSectionsWithBlocksByPageIdNullPageId() {
        Test.startTest();
        try {
            SectionBlockController.getSectionsWithBlocksByPageId('Banner', null);
            Assert.fail('Should throw AuraHandledException for null pageId');
        } catch (AuraHandledException e) {
            Assert.isTrue(true, 'AuraHandledException expected for null pageId');
        }
        Test.stopTest();
    }

    @IsTest
    static void testGetSectionsWithBlocksByPageIdValidParams() {
        Test.startTest();
        List<Map<String, Object>> result = SectionBlockController.getSectionsWithBlocksByPageId(
            'Banner', '000000000000000AAA'
        );
        Test.stopTest();
        Assert.isNotNull(result, 'getSectionsWithBlocksByPageId should return a non-null list');
    }
}
