/**
 * Publishes one diagnostic event per fail-closed decision. A card the
 * evaluator hides due to a malformed rule, an evaluation error, or an
 * invalid binding never explains itself to the end user — this is the
 * server-side signal an admin can subscribe to instead.
 *
 * The reason enum is enforced here, in code, because Platform Event fields
 * cannot be Picklists on this platform — Reason__c is a plain Text field,
 * and this class is the single place allowed to decide what values it holds.
 */
public with sharing class V360Diagnostics {

    /**
     * Whether this instance may actually publish.
     *
     * Publishing a platform event is DML, and an @AuraEnabled(cacheable=true)
     * method may not perform DML — so on that path the attempt does not merely
     * fail to record a diagnostic, it fails the entire read. A card that failed
     * closed would take the whole panel down with it, turning "one card is
     * hidden" into "Vista 360 is broken", which is the worse outcome by a wide
     * margin and the exact opposite of what fail-closed is for.
     *
     * It only bit users who produce a diagnostic at all: an admin who can read
     * every field referenced by every formula generates no entries, so the
     * publish was skipped and the path looked healthy.
     */
    /**
     * Named rather than a boolean, because `new V360Diagnostics(false)` at a
     * call site says nothing about which half of the rule it is choosing.
     */
    public enum Delivery {
        PUBLISH,
        COLLECT_ONLY
    }

    // Not named `delivery`: Apex identifiers are case-insensitive, so a field
    // of that name shadows the Delivery enum and every Delivery.PUBLISH inside
    // this class stops compiling. Same trap as ChangeType in V360ConfigChange.
    private final Delivery deliveryMode;

    /** Publishes, for the callers that are allowed to. */
    public V360Diagnostics() {
        this(Delivery.PUBLISH);
    }

    /**
     * @param requested COLLECT_ONLY on a cacheable read path, where DML is forbidden
     */
    public V360Diagnostics(Delivery requested) {
        // Not `delivery`: a parameter of that name shadows the enum here too,
        // one level below the field. The same fix as ChangeType in
        // V360ConfigChange -- name the parameter for what it is, a request.
        this.deliveryMode = requested == null ? Delivery.PUBLISH : requested;
    }

    public enum Reason {
        FORMULA_INVALID,
        FORMULA_EVAL_ERROR,
        UNKNOWN_FIELD,
        UNKNOWN_BINDING,
        PREDICATE_ERROR
    }

    /**
     * One fail-closed decision to publish. Kept as a plain data holder so
     * callers can batch up every diagnostic from one evaluation pass and
     * publish them together (bulk-safe: one EventBus.publish() call, not one
     * per hidden card).
     */
    public class Entry {
        public Id recordId;
        public String tabName;
        public String cardName;
        public Reason reason;
        public String detail;
    }

    /**
     * @param entry the single diagnostic to publish
     * @return the publish result for that one event
     */
    public Database.SaveResult publish(Entry entry) {
        return publishAll(new List<Entry>{ entry })[0];
    }

    /**
     * @param entries the diagnostics to publish; a null or empty list is a no-op,
     *        and so is any list at all on an instance that may not publish
     * @return the publish result per entry, in the same order as entries
     */
    public List<Database.SaveResult> publishAll(List<Entry> entries) {
        if (entries == null || entries.isEmpty() || deliveryMode == Delivery.COLLECT_ONLY) {
            return new List<Database.SaveResult>();
        }

        List<V360_Diagnostic__e> events = new List<V360_Diagnostic__e>();
        for (Entry entry : entries) {
            if (entry.reason == null) {
                throw new V360DiagnosticsException('A diagnostic entry must have a reason.');
            }
            events.add(
                new V360_Diagnostic__e(
                    RecordId__c = entry.recordId,
                    TabName__c = entry.tabName,
                    CardName__c = entry.cardName,
                    UserId__c = UserInfo.getUserId(),
                    Reason__c = entry.reason.name(),
                    Detail__c = entry.detail,
                    OccurredAt__c = System.now()
                )
            );
        }

        return EventBus.publish(events);
    }

    public class V360DiagnosticsException extends Exception {
    }
}
