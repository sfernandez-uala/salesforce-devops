/**
 * The tab choices Lightning App Builder offers for c/v360Shell, so a
 * placement is configured by picking a configured tab rather than by typing
 * its developer name from memory. A typo there costs nothing at save time and
 * shows an empty component on the record page instead.
 *
 * Only tabs anchored on the object whose record page is being edited are
 * offered: a tab anchored on Account has nothing to render on an Opportunity
 * page, and offering it would be offering a placement that cannot work.
 *
 * Design-time only. It runs inside App Builder, for a user who already holds
 * Customize Application, and the value it returns is the same developer name
 * that has always been typed into this property by hand.
 */
public with sharing class V360TabPicklist extends VisualEditor.DynamicPickList {

    private final VisualEditor.DesignTimePageContext context;

    public V360TabPicklist(VisualEditor.DesignTimePageContext context) {
        this.context = context;
    }

    /**
     * @return the empty choice, which is a real state: a shell with no tab
     *         renders a panel naming the gap rather than guessing one
     */
    public override VisualEditor.DataRow getDefaultValue() {
        return new VisualEditor.DataRow('— Select a tab —', '');
    }

    /**
     * @return the empty choice followed by every tab this page could render,
     *         in the order the admin console lists them
     */
    public override VisualEditor.DynamicPickListRows getValues() {
        VisualEditor.DynamicPickListRows rows = new VisualEditor.DynamicPickListRows();
        rows.addRow(getDefaultValue());
        for (V360_Tab__c tab : tabsForThisPage()) {
            rows.addRow(new VisualEditor.DataRow(label(tab), tab.DeveloperName__c));
        }
        return rows;
    }

    /**
     * System mode deliberately. This reads configuration metadata for someone
     * already editing a Lightning page, and enforcing object access here would
     * hand an admin an empty dropdown with no way to tell an unconfigured org
     * from a missing permission -- the exact confusion the picker exists to
     * remove. Nothing about a record is read.
     */
    @SuppressWarnings('PMD.ApexCRUDViolation')
    private List<V360_Tab__c> tabsForThisPage() {
        String entityName = context?.entityName;
        // A context without an entity is not a record page; rather than
        // silently offering nothing, offer everything and let the label say
        // which object each tab belongs to.
        if (String.isBlank(entityName)) {
            return [
                SELECT DeveloperName__c, AnchorSObject__c, Active__c
                FROM V360_Tab__c
                ORDER BY Sequence__c NULLS LAST, DeveloperName__c
                LIMIT 1000
            ];
        }
        return [
            SELECT DeveloperName__c, AnchorSObject__c, Active__c
            FROM V360_Tab__c
            WHERE AnchorSObject__c = :entityName
            ORDER BY Sequence__c NULLS LAST, DeveloperName__c
            LIMIT 1000
        ];
    }

    /**
     * A parked tab is still offered, and says so.
     *
     * Hiding it would be the more obvious choice and the wrong one: the
     * evaluator does not read a tab's Active flag at all -- V360CardCatalogSelector
     * matches on developer name alone -- so a parked tab renders its cards
     * exactly like any other. Leaving it out would tell an admin it cannot be
     * used while the org goes on using it.
     */
    private String label(V360_Tab__c tab) {
        String suffix = tab.Active__c == true ? '' : ' (parked)';
        String scope = String.isBlank(context?.entityName) ? ' · ' + tab.AnchorSObject__c : '';
        return tab.DeveloperName__c + scope + suffix;
    }
}
