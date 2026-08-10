/**
 * One catalog row: a card's identity, component binding, tab placement,
 * presentation, and kill-switch state. Carries everything the evaluator
 * needs to decide and present a card, without exposing the underlying
 * SObject to the decision core.
 *
 * Plain data holder: construct empty and assign fields.
 */
public class V360CardCatalogDTO {
    public Id cardId;
    public String developerName;
    public String componentType;
    public String componentName;
    public String sObjectApiName;
    public Integer order;
    public String label;
    public String description;
    public String buttonLabel;
    public String iconName;
    public Boolean killSwitch = false;
    public Boolean active = true;

    /**
     * How this card's rules combine: ALL (every active rule is a requirement)
     * or ANY (each active rule is one way to qualify).
     *
     * Defaults to ALL here as well as on the field, so a row that arrives
     * without the value -- an older record, a partial query, a hand-built
     * stub -- is read the restrictive way rather than the permissive one.
     */
    public String ruleMatchLogic = 'ALL';
}
