@IsTest
private class SectionBlockControllerTest {
    // Builds a full Page -> Section -> SectionBlock -> Block(action) graph so the
    // query/loop bodies actually execute (not just the guard clauses).
    private static Id buildGraph() {
        DynamicLink__c dl = new DynamicLink__c(Identity__c = 'SBC_TEST', Object__c = 'Contact');
        insert dl;

        Page__c page = new Page__c(Type__c = 'Home');
        insert page;

        Block__c block = new Block__c(
            Active__c = true,
            Header__c = 'Block Header',
            Sub_Header__c = 'Block Sub',
            Description__c = 'Block Desc',
            Action__c = dl.Id,
            ActionText__c = 'Go'
        );
        insert block;

        Id rtId = Schema.SObjectType.Section__c
            .getRecordTypeInfosByDeveloperName()
            .get('Top')
            .getRecordTypeId();
        Section__c section = new Section__c(
            Active__c = true,
            Header__c = 'Section Header',
            Sub_Header__c = 'Section Sub',
            Page__c = page.Id,
            RecordTypeId = rtId
        );
        insert section;

        SectionBlock__c sb = new SectionBlock__c(
            Section__c = section.Id,
            Block__c = block.Id,
            Order_Sequence__c = 1
        );
        insert sb;

        return section.Id;
    }

    @IsTest
    static void testGetSectionsByTypeValid() {
        buildGraph();
        Test.startTest();
        List<Section__c> result = SectionBlockController.getSectionsByType('Top', 'Home');
        Test.stopTest();
        Assert.isFalse(result.isEmpty(), 'Should return the section created for page type Home / record type Top');
    }

    @IsTest
    static void testGetSectionsByTypeNullSectionType() {
        Test.startTest();
        try {
            SectionBlockController.getSectionsByType(null, 'Home');
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
            SectionBlockController.getSectionsByType('Top', null);
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
            SectionBlockController.getSectionsByType('Top', 'Detail');
            Assert.fail('Should throw AuraHandledException when no Page__c record found for the type');
        } catch (AuraHandledException e) {
            Assert.isTrue(true, 'AuraHandledException expected when no Page__c record matches pageType');
        }
        Test.stopTest();
    }

    @IsTest
    static void testGetSectionsByPageIdNullSectionType() {
        Test.startTest();
        try {
            SectionBlockController.getSectionsByPageId(null, 'anything');
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
            SectionBlockController.getSectionsByPageId('Top', null);
            Assert.fail('Should throw AuraHandledException for null pageId');
        } catch (AuraHandledException e) {
            Assert.isTrue(true, 'AuraHandledException expected for null pageId');
        }
        Test.stopTest();
    }

    @IsTest
    static void testGetDynamicLinksEmptyList() {
        Test.startTest();
        List<DynamicLink__c> result = SectionBlockController.getDynamicLinks(new List<String>());
        Test.stopTest();
        Assert.areEqual(0, result.size(), 'getDynamicLinks with empty input should return empty list');
    }

    @IsTest
    static void testGetDynamicLinksNonEmptyList() {
        DynamicLink__c dl = new DynamicLink__c(Identity__c = 'LINK_TEST', Object__c = 'Contact');
        insert dl;
        Test.startTest();
        List<DynamicLink__c> result = SectionBlockController.getDynamicLinks(new List<String>{ dl.Id });
        Test.stopTest();
        Assert.areEqual(1, result.size(), 'getDynamicLinks should return the requested DynamicLink__c record');
    }

    @IsTest
    static void testGetSectionWithBlockBySectionIdValid() {
        Id sectionId = buildGraph();
        Test.startTest();
        List<Map<String, Object>> result = SectionBlockController.getSectionWithBlockBySectionId(sectionId);
        Test.stopTest();
        Assert.isFalse(result.isEmpty(), 'Should return a section/block map for a valid section id');
        Assert.isTrue(result[0].containsKey('block'), 'Result should contain the block map');
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
    static void testGetSectionsWithBlocksByTypeValid() {
        buildGraph();
        Test.startTest();
        List<Map<String, Object>> result = SectionBlockController.getSectionsWithBlocksByType('Top', 'Home');
        Test.stopTest();
        Assert.isFalse(result.isEmpty(), 'Should return sections with blocks for the created data');
    }

    @IsTest
    static void testGetSectionsWithBlocksByTypeNullSectionType() {
        Test.startTest();
        try {
            SectionBlockController.getSectionsWithBlocksByType(null, 'Home');
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
            SectionBlockController.getSectionsWithBlocksByType('Top', null);
            Assert.fail('Should throw AuraHandledException for null pageType');
        } catch (AuraHandledException e) {
            Assert.isTrue(true, 'AuraHandledException expected for null pageType');
        }
        Test.stopTest();
    }

    @IsTest
    static void testGetSectionsWithBlocksByPageIdValid() {
        buildGraph();
        Page__c page = [SELECT Id FROM Page__c LIMIT 1];
        Test.startTest();
        List<Map<String, Object>> result = SectionBlockController.getSectionsWithBlocksByPageId('Top', page.Id);
        Test.stopTest();
        Assert.isFalse(result.isEmpty(), 'Should return sections with blocks for the page id');
    }

    @IsTest
    static void testGetSectionsWithBlocksByPageIdNullSectionType() {
        Test.startTest();
        try {
            SectionBlockController.getSectionsWithBlocksByPageId(null, 'anything');
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
            SectionBlockController.getSectionsWithBlocksByPageId('Top', null);
            Assert.fail('Should throw AuraHandledException for null pageId');
        } catch (AuraHandledException e) {
            Assert.isTrue(true, 'AuraHandledException expected for null pageId');
        }
        Test.stopTest();
    }
}
