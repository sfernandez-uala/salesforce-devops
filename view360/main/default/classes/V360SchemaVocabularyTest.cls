@IsTest
private class V360SchemaVocabularyTest {

    private static final String TEST_PROFILE = 'Standard User';

    private static Map<String, String> labelsByApiName(List<V360SchemaVocabulary.ObjectOption> options) {
        Map<String, String> labels = new Map<String, String>();
        for (V360SchemaVocabulary.ObjectOption option : options) {
            labels.put(option.apiName, option.label);
        }
        return labels;
    }

    /**
     * The same gate every other console entry point carries. An admin picker
     * that answers to anyone is a describe of the whole org handed out for
     * free.
     */
    @IsTest
    static void offersNothingWithoutTheManagePermission() {
        User plainUser = V360TestDataFactory.insertUserWithAccess(TEST_PROFILE, null);

        List<V360SchemaVocabulary.ObjectOption> options;
        System.runAs(plainUser) {
            Test.startTest();
            options = V360SchemaVocabulary.getAnchorObjectOptions();
            Test.stopTest();
        }

        Assert.isTrue(options.isEmpty(), 'Without the manage permission the picker must offer nothing');
    }

    /**
     * The point of the picker: an admin picks Account from a list instead of
     * typing an API name from memory and finding out at save time.
     */
    @IsTest
    static void offersRecordPageObjectsByLabelAndApiName() {
        User admin = V360TestDataFactory.insertUserWithAccess(TEST_PROFILE, new List<String>{ 'V360_Admin' });

        List<V360SchemaVocabulary.ObjectOption> options;
        System.runAs(admin) {
            Test.startTest();
            options = V360SchemaVocabulary.getAnchorObjectOptions();
            Test.stopTest();
        }

        Map<String, String> labels = labelsByApiName(options);
        Assert.isTrue(labels.containsKey('Account'), 'Account anchors record pages and must be offered');
        Assert.isTrue(labels.containsKey('Contact'), 'Contact anchors record pages and must be offered');
        Assert.areEqual(
            Account.SObjectType.getDescribe(SObjectDescribeOptions.DEFERRED).getLabel(),
            labels.get('Account'),
            'The option carries the object label an admin reads, not just its API name'
        );
    }

    /**
     * Everything a record page cannot be built on. Each of these is reachable
     * through getGlobalDescribe and none of them has a record page to host a
     * tab, so offering them is offering a choice that cannot work.
     */
    @IsTest
    static void leavesOutObjectsThatCannotHostARecordPage() {
        User admin = V360TestDataFactory.insertUserWithAccess(TEST_PROFILE, new List<String>{ 'V360_Admin' });

        List<V360SchemaVocabulary.ObjectOption> options;
        System.runAs(admin) {
            Test.startTest();
            options = V360SchemaVocabulary.getAnchorObjectOptions();
            Test.stopTest();
        }

        Set<String> offered = labelsByApiName(options).keySet();
        Assert.isFalse(offered.contains('AccountShare'), 'Share objects have no record page');
        Assert.isFalse(offered.contains('AccountHistory'), 'History objects have no record page');
        Assert.isFalse(offered.contains('AccountFeed'), 'Feed objects have no record page');
        Assert.isFalse(
            offered.contains('V360_ConfigChange__e'),
            'A platform event is a message, not a record with a page'
        );
    }

    /**
     * Every object the query finds is returned -- nothing is dropped on the way
     * out.
     *
     * This is deliberately not the guard for the failure that shipped here. The
     * options were once read straight out of a SOQL for-loop, which pages
     * through queryMore in batches of 200, and EntityDefinition supports no
     * queryMore at all; the picker was dead in the org while all of these tests
     * were green. It cannot be reproduced from a test: test context sees ~190
     * layoutable objects where the same org serves ~800 at runtime, so the
     * second batch that triggers it is never reached here.
     *
     * That failure is caught by running the method against a real org, not by
     * this class. What this one pins is that the mapping loop returns as many
     * options as the query returned rows, which is the part a test can see.
     */
    @IsTest
    static void returnsEveryRowTheQueryFinds() {
        User admin = V360TestDataFactory.insertUserWithAccess(TEST_PROFILE, new List<String>{ 'V360_Admin' });

        List<V360SchemaVocabulary.ObjectOption> options;
        Integer expected;
        System.runAs(admin) {
            Test.startTest();
            options = V360SchemaVocabulary.getAnchorObjectOptions();
            expected = [
                SELECT COUNT()
                FROM EntityDefinition
                WHERE IsLayoutable = TRUE AND IsQueryable = TRUE AND IsDeprecatedAndHidden = FALSE
                LIMIT 2000
            ];
            Test.stopTest();
        }

        Assert.areEqual(expected, options.size(), 'Every row the query finds must come back as an option');
    }

    /** A list an admin scans has to be in the order they read it. */
    @IsTest
    static void ordersOptionsByLabel() {
        User admin = V360TestDataFactory.insertUserWithAccess(TEST_PROFILE, new List<String>{ 'V360_Admin' });

        List<V360SchemaVocabulary.ObjectOption> options;
        System.runAs(admin) {
            Test.startTest();
            options = V360SchemaVocabulary.getAnchorObjectOptions();
            Test.stopTest();
        }

        Assert.isFalse(options.isEmpty(), 'The ordering assertion needs options to order');
        for (Integer index = 1; index < options.size(); index++) {
            // Case-insensitively, because that is what SOQL's ORDER BY
            // guarantees -- comparing raw would fail on any org whose labels
            // are not uniformly capitalised, for an ordering that is correct.
            Assert.isTrue(
                options[index - 1].label.toLowerCase().compareTo(options[index].label.toLowerCase()) <= 0,
                'Options must come out sorted by label, found ' +
                    options[index - 1].label + ' before ' + options[index].label
            );
        }
    }
}
