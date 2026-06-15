public class SandboxDataSanitizer {
    public static void scrambleEmails() {
        List<Contact> contacts = [
            SELECT Id, Email FROM Contact WHERE Email != null LIMIT 10000
        ];
        for (Contact c : contacts) {
            c.Email = 'sandbox.' + c.Id + '@example.com';
        }
        update contacts;

        List<Lead> leads = [
            SELECT Id, Email FROM Lead WHERE Email != null LIMIT 10000
        ];
        for (Lead l : leads) {
            l.Email = 'sandbox.' + l.Id + '@example.com';
        }
        update leads;
    }
}
