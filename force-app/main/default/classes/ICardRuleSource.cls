/**
 * Read seam for Vista 360 visibility rules and their predicates. Implementations
 * resolve every rule row (and nested predicate rows) attached to a set of cards.
 * Reads happen in system mode, for the same reason as the catalog seam
 * (ICardCatalogSource): end users have no direct access to rule configuration.
 *
 * Kept as a pure contract so the evaluation core can be unit-tested with a stub,
 * with no dependency on a connected org.
 */
public interface ICardRuleSource {
    /**
     * Returns the rule graph (rules + predicates) for each of the given cards.
     * A card with no rules simply has no entry in the returned map — the caller
     * treats a missing entry as "no rules configured" (default-visible).
     *
     * @param cardIds the card record Ids to resolve rules for
     * @return a map keyed by card Id to that card's rule graph
     */
    Map<Id, V360RuleGraph> getRulesForCards(Set<Id> cardIds);
}
