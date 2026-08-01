/**
 * Evaluates one structured predicate row against the running user's live grants.
 * Structured predicates cover the two conditions a formula cannot express:
 * Permission Set assignment and field-level-security read access. Pure unit
 * of decision logic — everything about the user comes through IUserContext.
 */
public with sharing class V360PredicateEvaluator {

    public static final String PERMISSION_SET = 'PERMISSION_SET';
    public static final String FLS_READ = 'FLS_READ';

    private final IUserContext userContext;

    public V360PredicateEvaluator(IUserContext userContext) {
        this.userContext = userContext;
    }

    /**
     * @param predicate the predicate row to evaluate
     * @param anchorSObjectApiName the anchor SObject's API name; only used by FLS_READ predicates
     * @return true when the predicate passes for the running user
     */
    public Boolean evaluate(V360RuleGraph.PredicateRow predicate, String anchorSObjectApiName) {
        if (predicate == null || String.isBlank(predicate.predicateType)) {
            throw new V360PredicateEvaluatorException('A predicate row must have a predicate type.');
        }

        if (predicate.predicateType == PERMISSION_SET) {
            if (String.isBlank(predicate.targetApiName)) {
                throw new V360PredicateEvaluatorException('A PERMISSION_SET predicate must name a Permission Set.');
            }
            return userContext.hasPermissionSet(predicate.targetApiName);
        }

        if (predicate.predicateType == FLS_READ) {
            if (String.isBlank(predicate.targetApiName)) {
                throw new V360PredicateEvaluatorException('An FLS_READ predicate must name a field.');
            }
            if (String.isBlank(anchorSObjectApiName)) {
                throw new V360PredicateEvaluatorException('An FLS_READ predicate requires the anchor SObject API name.');
            }
            return userContext.isFieldReadable(anchorSObjectApiName, predicate.targetApiName);
        }

        throw new V360PredicateEvaluatorException('Unknown predicate type: ' + predicate.predicateType);
    }

    public class V360PredicateEvaluatorException extends Exception {
    }
}
