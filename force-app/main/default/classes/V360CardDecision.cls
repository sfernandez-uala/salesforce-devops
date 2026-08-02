/**
 * A single card the current user is allowed to see, returned to the client.
 * Only visible cards are ever built into this shape — a card that failed
 * closed or was killed never reaches the client in any form.
 *
 * Plain data holder: construct empty and assign fields.
 */
public class V360CardDecision {
    @AuraEnabled public String cardName;
    @AuraEnabled public String componentType;
    @AuraEnabled public String componentName;
    @AuraEnabled public String label;
    @AuraEnabled public String iconName;
    @AuraEnabled public String buttonLabel;
    @AuraEnabled public Integer order;
}
