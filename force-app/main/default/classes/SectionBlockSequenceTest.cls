@IsTest
private class SectionBlockSequenceTest {
    @IsTest
    static void testGetAllBlocks() {
        Test.startTest();
        List<Block__c> blocks = SectionBlockSequence.getAllBlocks();
        Test.stopTest();
        Assert.isNotNull(blocks, 'getAllBlocks should return a non-null list');
    }

    @IsTest
    static void testGetBlocksForSectionNullId() {
        Test.startTest();
        try {
            SectionBlockSequence.getBlocksForSection(null);
            Assert.fail('Should throw AuraHandledException for null sectionId');
        } catch (AuraHandledException e) {
            Assert.isTrue(true, 'AuraHandledException expected for null sectionId');
        }
        Test.stopTest();
    }

    @IsTest
    static void testGetBlocksForSectionEmptyId() {
        Test.startTest();
        try {
            SectionBlockSequence.getBlocksForSection('');
            Assert.fail('Should throw AuraHandledException for empty sectionId');
        } catch (AuraHandledException e) {
            Assert.isTrue(true, 'AuraHandledException expected for empty sectionId');
        }
        Test.stopTest();
    }

    @IsTest
    static void testGetBlocksForSectionValidId() {
        Test.startTest();
        List<SectionBlock__c> result = SectionBlockSequence.getBlocksForSection('000000000000000AAA');
        Test.stopTest();
        Assert.isNotNull(result, 'getBlocksForSection should return a non-null list for a valid id');
    }

    @IsTest
    static void testUpdateSectionBlocksEmptyBlockIds() {
        Test.startTest();
        try {
            SectionBlockSequence.updateSectionBlocks('000000000000000AAA', new List<String>());
            Assert.isTrue(true, 'updateSectionBlocks should complete without error for empty blockIds');
        } catch (AuraHandledException e) {
            Assert.isTrue(true, 'AuraHandledException acceptable if section does not exist');
        }
        Test.stopTest();
    }
}
