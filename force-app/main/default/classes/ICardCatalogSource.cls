/**
 * Read seam for the Vista 360 card catalog. Implementations resolve every card
 * configured under a given tab, including its presentation and kill-switch state.
 * Reads happen in system mode: end users have no direct access to the catalog,
 * so whatever implements this interface acts as the trusted mediator on their behalf.
 *
 * Kept as a pure contract so the evaluation core can be unit-tested with a stub,
 * with no dependency on a connected org.
 */
public interface ICardCatalogSource {
    /**
     * Returns every configured card under the given tab, in no particular order
     * (ordering/sorting for display is the caller's responsibility).
     *
     * @param tabApiName the tab's stable developer name
     * @return the tab's card catalog rows; an empty list when the tab has no cards
     */
    List<V360CardCatalogDTO> getCardsForTab(String tabApiName);
}
