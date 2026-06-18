@IsTest
private class SandboxDataSanitizerTest {
    @IsTest
    static void testScrambleEmails() {
        Contact c = new Contact(LastName = 'Test', Email = 'real@customer.com');
        insert c;
        Lead l = new Lead(LastName = 'Test', Company = 'ACME', Email = 'real@lead.com');
        insert l;

        Test.startTest();
        SandboxDataSanitizer.scrambleEmails();
        Test.stopTest();

        Contact updated = [SELECT Email FROM Contact WHERE Id = :c.Id];
        Assert.isTrue(updated.Email.startsWith('sandbox.'), 'Contact email should be scrambled');
        Assert.isTrue(updated.Email.endsWith('@example.com'), 'Contact email domain should be example.com');

        Lead updatedLead = [SELECT Email FROM Lead WHERE Id = :l.Id];
        Assert.isTrue(updatedLead.Email.startsWith('sandbox.'), 'Lead email should be scrambled');
        Assert.isTrue(updatedLead.Email.endsWith('@example.com'), 'Lead email domain should be example.com');
    }

    @IsTest
    static void testScrambleEmailsNoRecords() {
        Test.startTest();
        SandboxDataSanitizer.scrambleEmails();
        Test.stopTest();
    }
}
