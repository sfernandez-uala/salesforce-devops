/**
 * The one channel Vista 360 uses to tell open shells that something they are
 * rendering has changed. Deliberately general: the event carries a change
 * type rather than encoding its meaning in the event name, so a new kind of
 * notification is a new value here and not a new platform event with its own
 * subscription, its own allocation, and its own client wiring.
 *
 * The type is enforced in code, mirroring V360Diagnostics, because Platform
 * Event fields cannot be Picklists on this platform -- ChangeType__c is a
 * plain Text field and this class is the single place allowed to decide what
 * values it holds.
 *
 * Only writes publish here. The read path stays silent: the evaluator runs on
 * every page load, and an event per evaluation would be a different order of
 * magnitude entirely (V360_Diagnostic__e covers that, and only fires on
 * fail-closed decisions).
 *
 * Events publish after commit, so a subscriber that re-reads on delivery
 * cannot observe the state from before the write it is being told about.
 */
public with sharing class V360ConfigChange {
    /**
     * What a subscriber is being told. Add a value here rather than adding a
     * platform event; shells that do not care about a type ignore it.
     */
    public enum ChangeType {
        CARDS_CHANGED,
        RULES_CHANGED,
        TAB_CHANGED
    }

    /**
     * Announces a change to the tabs owning the given cards. Resolves each
     * card's tab in one query and publishes one event per distinct tab, not
     * one per card -- reordering six cards is one change to one surface.
     *
     * @param cardIds the cards that were written or deleted
     * @param changeType what the subscriber is being told
     * @return one publish result per event, empty when there was nothing to announce
     */
    public static List<Database.SaveResult> publishForCards(Set<Id> cardIds, ChangeType changeType) {
        if (cardIds == null || cardIds.isEmpty()) {
            return new List<Database.SaveResult>();
        }
        return publishForTabNames(tabNamesForCards(cardIds), changeType);
    }

    /**
     * @param tabNames developer names of the tabs to announce
     * @param changeType what the subscriber is being told
     * @return one publish result per event, empty when there was nothing to announce
     */
    public static List<Database.SaveResult> publishForTabNames(Set<String> tabNames, ChangeType changeType) {
        if (tabNames == null || tabNames.isEmpty()) {
            return new List<Database.SaveResult>();
        }
        List<V360_ConfigChange__e> events = new List<V360_ConfigChange__e>();
        DateTime occurredAt = DateTime.now();
        for (String tabName : tabNames) {
            if (String.isBlank(tabName)) {
                continue;
            }
            events.add(
                new V360_ConfigChange__e(
                    TabName__c = tabName,
                    ChangeType__c = String.valueOf(changeType),
                    OccurredAt__c = occurredAt
                )
            );
        }
        if (events.isEmpty()) {
            return new List<Database.SaveResult>();
        }
        // One publish call for the whole batch, never one per card.
        return EventBus.publish(events);
    }

    /** One tab to announce, as a Flow hands it over. */
    public class Request {
        @InvocableVariable(
            required=true
            label='Tab developer name'
            description='V360_Tab__c.DeveloperName__c of the surface that changed.'
        )
        public String tabName;

        @InvocableVariable(
            label='Change type'
            description='CARDS_CHANGED, RULES_CHANGED or TAB_CHANGED. Defaults to CARDS_CHANGED.'
        )
        public String changeType;
    }

    /**
     * Lets a record-triggered Flow publish the same event the service does.
     * That is what covers changes the console never sees -- a Data Loader
     * run, a deploy, an edit in Setup -- without the repo taking on its first
     * Apex trigger.
     *
     * Bulk-safe: every request in the batch resolves to one publish call.
     *
     * @param requests one entry per tab to announce
     */
    @InvocableMethod(
        label='Publish Vista 360 config change'
        description='Tells open Vista 360 shells that a tab\'s configuration changed, so they re-read without a refresh.'
        category='Vista 360'
    )
    public static void publish(List<Request> requests) {
        Map<String, Set<String>> tabsByType = new Map<String, Set<String>>();
        for (Request request : requests) {
            String type = normalize(request.changeType);
            if (!tabsByType.containsKey(type)) {
                tabsByType.put(type, new Set<String>());
            }
            tabsByType.get(type).add(request.tabName);
        }
        for (String type : tabsByType.keySet()) {
            publishForTabNames(tabsByType.get(type), ChangeType.valueOf(type));
        }
    }

    /**
     * An unrecognised type from a Flow falls back rather than throwing
     * mid-automation.
     *
     * The parameter is not called changeType on purpose: Apex identifiers are
     * case-insensitive, so a local by that name shadows the ChangeType enum
     * and every reference to it inside this method resolves to the String.
     */
    private static String normalize(String requested) {
        if (String.isBlank(requested)) {
            return String.valueOf(ChangeType.CARDS_CHANGED);
        }
        String candidate = requested.trim().toUpperCase();
        for (ChangeType known : ChangeType.values()) {
            if (String.valueOf(known) == candidate) {
                return candidate;
            }
        }
        return String.valueOf(ChangeType.CARDS_CHANGED);
    }

    /**
     * Deliberately not USER_MODE: an admin holding the manage permission is
     * allowed to change these cards, and the tab's developer name is the only
     * field read -- it carries no customer data. Enforcing FLS here would let
     * a field-level restriction silently drop the notification while the
     * write it announces went through.
     */
    @SuppressWarnings('PMD.ApexCRUDViolation')
    public static Set<String> tabNamesForCards(Set<Id> cardIds) {
        Set<String> tabNames = new Set<String>();
        for (V360_Card__c card : [SELECT Tab__r.DeveloperName__c FROM V360_Card__c WHERE Id IN :cardIds]) {
            tabNames.add(card.Tab__r.DeveloperName__c);
        }
        return tabNames;
    }
}
