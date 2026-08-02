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
    public String anchorSObject;
    public Integer order;
    public String label;
    public String description;
    public String buttonLabel;
    public String iconName;
    public Boolean killSwitch = false;
    public Boolean active = true;
}
