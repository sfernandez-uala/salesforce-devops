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
     * @param entries the diagnostics to publish; a null or empty list is a no-op
     * @return the publish result per entry, in the same order as entries
     */
    public List<Database.SaveResult> publishAll(List<Entry> entries) {
        if (entries == null || entries.isEmpty()) {
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
