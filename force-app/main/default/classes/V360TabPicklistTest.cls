@IsTest
private class V360TabPicklistTest {

    /**
     * VisualEditor.DesignTimePageContext carries no public constructor and no
     * setters, so a context with a chosen entity is deserialized rather than
     * built. This is the documented way to exercise a dynamic picklist.
     */
    private static VisualEditor.DesignTimePageContext contextFor(String entityName) {
        return (VisualEditor.DesignTimePageContext) JSON.deserialize(
            '{"entityName":"' + entityName + '"}',
            VisualEditor.DesignTimePageContext.class
        );
    }

    private static Set<String> valuesOf(VisualEditor.DynamicPickListRows rows) {
        Set<String> values = new Set<String>();
        for (VisualEditor.DataRow row : rows.getDataRows()) {
            values.add(String.valueOf(row.getValue()));
        }
        return values;
    }

    private static String labelFor(VisualEditor.DynamicPickListRows rows, String value) {
        for (VisualEditor.DataRow row : rows.getDataRows()) {
            if (value.equals(String.valueOf(row.getValue()))) {
                return row.getLabel();
            }
        }
        return null;
    }

    /**
     * The point of the picker: what it stores is what the shell reads and the
     * evaluator queries on, so the value has to be the developer name and
     * nothing else -- an id would not survive a move between orgs.
     */
    @IsTest
    static void offersTabsAnchoredOnThePageObjectByDeveloperName() {
        V360TestDataFactory.insertTab('V360Test_Picklist_Account', 'Account');

        Test.startTest();
        VisualEditor.DynamicPickListRows rows = new V360TabPicklist(contextFor('Account')).getValues();
        Test.stopTest();

        Assert.isTrue(
            valuesOf(rows).contains('V360Test_Picklist_Account'),
            'A tab anchored on the page object must be offered, by developer name'
        );
    }

    /** A tab anchored elsewhere has nothing to render here, so it is not offered. */
    @IsTest
    static void leavesOutTabsAnchoredOnAnotherObject() {
        V360TestDataFactory.insertTab('V360Test_Picklist_Contact', 'Contact');

        Test.startTest();
        VisualEditor.DynamicPickListRows rows = new V360TabPicklist(contextFor('Account')).getValues();
        Test.stopTest();

        Assert.isFalse(
            valuesOf(rows).contains('V360Test_Picklist_Contact'),
            'A tab anchored on another object must not be offered for this page'
        );
    }

    /**
     * The empty choice is a real state, not a prompt to be skipped: a shell
     * with no tab renders a panel naming the gap.
     */
    @IsTest
    static void alwaysOffersTheEmptyChoice() {
        Test.startTest();
        VisualEditor.DynamicPickListRows rows = new V360TabPicklist(contextFor('Account')).getValues();
        VisualEditor.DataRow emptyChoice = new V360TabPicklist(contextFor('Account')).getDefaultValue();
        Test.stopTest();

        Assert.isTrue(valuesOf(rows).contains(''), 'Clearing the tab must be reachable from the list');
        Assert.areEqual('', String.valueOf(emptyChoice.getValue()), 'The default choice selects no tab');
    }

    /**
     * A parked tab is offered and labelled, because the evaluator ignores the
     * Active flag entirely -- it renders like any other. Hiding it would say
     * it cannot be used while the org went on using it.
     */
    @IsTest
    static void offersAParkedTabAndSaysThatItIsParked() {
        V360_Tab__c parked = V360TestDataFactory.insertTab('V360Test_Picklist_Parked', 'Account');
        parked.Active__c = false;
        update parked;

        Test.startTest();
        VisualEditor.DynamicPickListRows rows = new V360TabPicklist(contextFor('Account')).getValues();
        Test.stopTest();

        Assert.isTrue(
            valuesOf(rows).contains('V360Test_Picklist_Parked'),
            'A parked tab still renders, so it must still be offered'
        );
        Assert.isTrue(
            labelFor(rows, 'V360Test_Picklist_Parked').contains('parked'),
            'A parked tab must say so rather than look like any other'
        );
    }

    /** No entity means no record page; offer everything rather than nothing. */
    @IsTest
    static void offersEveryTabWhenThePageNamesNoObject() {
        V360TestDataFactory.insertTab('V360Test_Picklist_Any', 'Contact');

        Test.startTest();
        VisualEditor.DynamicPickListRows rows = new V360TabPicklist(contextFor('')).getValues();
        Test.stopTest();

        Assert.isTrue(
            valuesOf(rows).contains('V360Test_Picklist_Any'),
            'With no page object to filter on, every configured tab must be reachable'
        );
    }
}
