/**
 * System-mode read of the Vista 360 card catalog. Runs without sharing
 * because end users have no direct read access to the catalog by design —
 * this is the security fix vista360 exists for. The evaluator is the only
 * trusted mediator between this configuration data and the running user, so
 * this selector deliberately ignores record-level sharing and reads every
 * card configured under a tab, regardless of the calling user's own access.
 *
 * A card's anchor SObject resolves from its own override when present,
 * otherwise it inherits the tab's default — the evaluator only ever sees
 * one already-resolved value per card.
 */
public without sharing class V360CardCatalogSelector implements ICardCatalogSource {

    // Deliberately system-mode: end users have no read access to the catalog by design, so this
    // query cannot be CRUD/FLS-enforced for them — the evaluator is the trusted mediator.
    @SuppressWarnings('PMD.ApexCRUDViolation')
    public List<V360CardCatalogDTO> getCardsForTab(String tabApiName) {
        if (String.isBlank(tabApiName)) {
            return new List<V360CardCatalogDTO>();
        }

        List<V360_Card__c> cardRecords = [
            SELECT Id, DeveloperName__c, ComponentType__c, ComponentName__c, AnchorSObject__c,
                   Order__c, Label__c, Description__c, ButtonLabel__c, IconName__c,
                   KillSwitch__c, Active__c, Tab__r.AnchorSObject__c
            FROM V360_Card__c
            WHERE Tab__r.DeveloperName__c = :tabApiName
        ];

        List<V360CardCatalogDTO> cards = new List<V360CardCatalogDTO>();
        for (V360_Card__c cardRecord : cardRecords) {
            cards.add(toDto(cardRecord));
        }
        return cards;
    }

    private V360CardCatalogDTO toDto(V360_Card__c cardRecord) {
        V360CardCatalogDTO dto = new V360CardCatalogDTO();
        dto.cardId = cardRecord.Id;
        dto.developerName = cardRecord.DeveloperName__c;
        dto.componentType = cardRecord.ComponentType__c;
        dto.componentName = cardRecord.ComponentName__c;
        dto.anchorSObject = String.isNotBlank(cardRecord.AnchorSObject__c)
            ? cardRecord.AnchorSObject__c
            : cardRecord.Tab__r.AnchorSObject__c;
        dto.order = cardRecord.Order__c == null ? null : Integer.valueOf(cardRecord.Order__c);
        dto.label = cardRecord.Label__c;
        dto.description = cardRecord.Description__c;
        dto.buttonLabel = cardRecord.ButtonLabel__c;
        dto.iconName = cardRecord.IconName__c;
        dto.killSwitch = cardRecord.KillSwitch__c;
        dto.active = cardRecord.Active__c;
        return dto;
    }
}
