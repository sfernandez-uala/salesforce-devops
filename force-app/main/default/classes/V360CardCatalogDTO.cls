/**
 * One catalog row: a card's identity, component binding, tab placement,
 * presentation, and kill-switch state. Carries everything the evaluator
 * needs to decide and present a card, without exposing the underlying
 * SObject to the decision core.
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
    public Boolean killSwitch;
    public Boolean active;

    public V360CardCatalogDTO(
        Id cardId,
        String developerName,
        String componentType,
        String componentName,
        String anchorSObject,
        Integer order,
        String label,
        String description,
        String buttonLabel,
        String iconName,
        Boolean killSwitch,
        Boolean active
    ) {
        this.cardId = cardId;
        this.developerName = developerName;
        this.componentType = componentType;
        this.componentName = componentName;
        this.anchorSObject = anchorSObject;
        this.order = order;
        this.label = label;
        this.description = description;
        this.buttonLabel = buttonLabel;
        this.iconName = iconName;
        this.killSwitch = killSwitch;
        this.active = active;
    }
}
