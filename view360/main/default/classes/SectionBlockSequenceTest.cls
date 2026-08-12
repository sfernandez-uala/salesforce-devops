@IsTest
private class SectionBlockSequenceTest {
    // Creates a Section + Block + SectionBlock so the real query/loop paths run.
    private static Id[] buildSectionAndBlock() {
        Page__c page = new Page__c(Type__c = 'Home');
        insert page;

        Block__c block = new Block__c(Active__c = true, Header__c = 'Header', Name = 'Block A');
        insert block;

        Id rtId = Schema.SObjectType.Section__c
            .getRecordTypeInfosByDeveloperName()
            .get('Top')
            .getRecordTypeId();
        Section__c section = new Section__c(Active__c = true, Page__c = page.Id, RecordTypeId = rtId);
        insert section;

        SectionBlock__c sb = new SectionBlock__c(
            Section__c = section.Id,
            Block__c = block.Id,
            Order_Sequence__c = 1
        );
        insert sb;

        return new Id[]{ section.Id, block.Id };
    }

    @IsTest
    static void testGetAllBlocks() {
        insert new Block__c(Active__c = true, Name = 'Solo Block');
        Test.startTest();
        List<Block__c> blocks = SectionBlockSequence.getAllBlocks();
        Test.stopTest();
        Assert.isFalse(blocks.isEmpty(), 'getAllBlocks should return the inserted block');
    }

    @IsTest
    static void testGetBlocksForSectionValidId() {
        Id[] ids = buildSectionAndBlock();
        Test.startTest();
        List<SectionBlock__c> result = SectionBlockSequence.getBlocksForSection(ids[0]);
        Test.stopTest();
        Assert.isFalse(result.isEmpty(), 'getBlocksForSection should return the linked SectionBlock__c');
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
    static void testUpdateSectionBlocksReplacesExisting() {
        Id[] ids = buildSectionAndBlock();
        Id sectionId = ids[0];
        Block__c newBlock = new Block__c(Active__c = true, Name = 'New Block');
        insert newBlock;

        Test.startTest();
        // Deletes the existing SectionBlock and inserts a new junction row (loop + upsert path).
        SectionBlockSequence.updateSectionBlocks(sectionId, new List<String>{ newBlock.Id });
        Test.stopTest();

        List<SectionBlock__c> current = [
            SELECT Block__c FROM SectionBlock__c WHERE Section__c = :sectionId
        ];
        Assert.areEqual(1, current.size(), 'Section should have exactly one junction after update');
        Assert.areEqual(newBlock.Id, current[0].Block__c, 'The junction should point to the new block');
    }

    @IsTest
    static void testUpdateSectionBlocksEmptyBlockIds() {
        Id[] ids = buildSectionAndBlock();
        Test.startTest();
        SectionBlockSequence.updateSectionBlocks(ids[0], new List<String>());
        Test.stopTest();
        List<SectionBlock__c> current = [
            SELECT Id FROM SectionBlock__c WHERE Section__c = :ids[0]
        ];
        Assert.areEqual(0, current.size(), 'All junctions should be removed when block list is empty');
    }
}
