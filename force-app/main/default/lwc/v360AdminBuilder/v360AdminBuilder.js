import { LightningElement, wire } from 'lwc';
import { getObjectInfo } from 'lightning/uiObjectInfoApi';
import getPermissionSetOptions from '@salesforce/apex/V360RuleVocabulary.getPermissionSetOptions';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { loadStyle } from 'lightning/platformResourceLoader';
import { EnclosingTabId, IsConsoleNavigation, setTabLabel, setTabIcon } from 'lightning/platformWorkspaceApi';
import BUILDER_OVERRIDES from '@salesforce/resourceUrl/v360BuilderOverrides';
import { names as registeredCardNames } from 'c/v360CardRegistry';
import getCatalog from '@salesforce/apex/V360AdminController.getCatalog';
import saveCardProperties from '@salesforce/apex/V360AdminController.saveCardProperties';
import updateCardOrder from '@salesforce/apex/V360AdminController.updateCardOrder';
import activateCard from '@salesforce/apex/V360AdminController.activateCard';
import deactivateCard from '@salesforce/apex/V360AdminController.deactivateCard';
import engageKillSwitch from '@salesforce/apex/V360AdminController.engageKillSwitch';
import releaseKillSwitch from '@salesforce/apex/V360AdminController.releaseKillSwitch';
import setRuleMatchLogic from '@salesforce/apex/V360AdminController.setRuleMatchLogic';
import validateRuleFormula from '@salesforce/apex/V360AdminController.validateRuleFormula';
import saveRuleFormula from '@salesforce/apex/V360AdminController.saveRuleFormula';
import addRulePredicate from '@salesforce/apex/V360AdminController.addRulePredicate';
import deleteRulePredicate from '@salesforce/apex/V360AdminController.deleteRulePredicate';
import deleteRule from '@salesforce/apex/V360AdminController.deleteRule';
import createCard from '@salesforce/apex/V360AdminController.createCard';
import createRule from '@salesforce/apex/V360AdminController.createRule';
import deleteCard from '@salesforce/apex/V360AdminController.deleteCard';
import saveTab from '@salesforce/apex/V360AdminController.saveTab';
import deleteTab from '@salesforce/apex/V360AdminController.deleteTab';

const STATUS_LOADING = 'loading';
const STATUS_LOADED = 'loaded';
const STATUS_ERROR = 'error';
const COMPONENT_TYPE_LWC = 'LWC';
const COMPONENT_TYPE_FLOW = 'Flow';
const BINDING_SEPARATOR = ':';

/** Gates the static resource's rule; see renderedCallback. */
const FULL_BLEED_CLASS = 'v360-builder-full-bleed';
const TEMPLATE_WRAPPER = '.slds-template_default';

/**
 * The workspace tab's icon, kept in step with the motif on the custom tab
 * itself -- "Custom70: Handsaw" in V360_Admin_Console.tab-meta.xml. Two icons
 * for one destination is how a console ends up looking like two apps.
 */
const BUILDER_TAB_ICON = 'custom:custom70';

/**
 * How a card's rules combine. The same two words the server stores and the
 * evaluator branches on, so the screen and the decision cannot drift.
 */
const MATCH_ALL = 'ALL';
const MATCH_ANY = 'ANY';

const PREDICATE_PERMISSION_SET = 'PERMISSION_SET';
const PREDICATE_FLS_READ = 'FLS_READ';

const SECTION_TILE = 'tile';
const SECTION_RULES = 'rules';
const SECTION_RELEASE = 'release';
const SECTIONS = [
    { key: SECTION_TILE, label: 'Tile', iconName: 'utility:side_list' },
    { key: SECTION_RULES, label: 'Rules', iconName: 'utility:shield' },
    // utility:rocket is not in the SLDS utility set, so the tile rendered
    // with no glyph at all.
    { key: SECTION_RELEASE, label: 'Release', iconName: 'utility:upload' }
];

/**
 * The Vista 360 builder: one card at a time, in the shape Salesforce's own
 * builders use. A document header names what is open and switches between
 * tabs, a list picks the card, and a rail picks which question about that
 * card the canvas answers -- its tile, the rules that decide who sees it, or
 * its release state. Those are three separate questions, so they get three
 * separate canvases instead of one column you scroll through.
 *
 * It reads and writes through V360AdminController, the same boundary the
 * original console uses; nothing here talks to the visibility engine.
 */
export default class V360AdminBuilder extends LightningElement {
    status = STATUS_LOADING;
    data;
    selectedTabId;
    selectedCardId;
    selectedSection = SECTION_TILE;
    busy = false;
    refreshing = false;
    switcherOpen = false;
    newCardOpen = false;
    newCardType = COMPONENT_TYPE_LWC;
    newCardIcon = '';
    newRuleOpen = false;
    tabModalOpen = false;
    editingTabId = null;
    iconPickerOpen = false;
    iconPickerTarget = null;
    tileIconDraft;
    deleteTarget = null;
    helpOpen = false;
    formulaFeedback = {};

    /**
     * The half-built predicate for each rule, keyed by rule id. Every open rule
     * renders its own type-and-target row, so a single shared draft would make
     * every one of those rows echo the last choice made in any of them.
     */
    predicateDrafts = {};

    /**
     * The predicate pickers read their own vocabulary: permission sets from
     * the server, fields from whatever object the open tab is anchored on.
     */
    @wire(getPermissionSetOptions)
    permissionSetOptions;

    @wire(getObjectInfo, { objectApiName: '$anchorSObject' })
    anchorInfo;

    get permissionSets() {
        return this.permissionSetOptions?.data ?? [];
    }

    get anchorFields() {
        return this.anchorInfo?.data?.fields ?? {};
    }

    stylesRequested = false;
    fullBleedWrapper;
    appliedTabLabel;
    appliedTabIcon = false;

    @wire(IsConsoleNavigation) isConsoleNavigation;
    @wire(EnclosingTabId) enclosingTabId;

    connectedCallback() {
        this.load();
    }

    /**
     * The page template's gutter lives on an ancestor outside this shadow
     * tree, so removing it takes a document-level stylesheet: no scoped
     * sheet can reach that wrapper.
     *
     * The sheet itself is never unloaded. loadStyle keeps a module-level
     * cache keyed by URL, so pulling its <link> on disconnect would make a
     * later remount resolve instantly against that cache and never
     * re-inject -- the override would be gone for the rest of the session.
     * The class below is what turns the rule on and off instead: it goes on
     * while the builder is mounted and comes off when it leaves, so no other
     * page inherits a stripped gutter.
     */
    renderedCallback() {
        if (!this.stylesRequested) {
            this.stylesRequested = true;
            loadStyle(this, BUILDER_OVERRIDES).catch(() => {
                // Worst case the tab keeps its default gutter; nothing else
                // in the builder depends on this sheet.
            });
        }
        if (!this.fullBleedWrapper) {
            const wrapper = this.template.host.closest(TEMPLATE_WRAPPER);
            if (wrapper) {
                wrapper.classList.add(FULL_BLEED_CLASS);
                this.fullBleedWrapper = wrapper;
            }
        }
        this.measureTopOffset();
        this.observeViewport();
        this.syncTabLabel();
        this.syncTabIcon();
    }

    /**
     * Names the workspace tab after whatever the builder currently has open,
     * so a console with several tabs open does not show a row of identical
     * ones. Only in console navigation -- standard navigation has no
     * workspace tab to name -- and only when the label actually changed,
     * since this runs on every render.
     */
    syncTabLabel() {
        if (!this.isConsoleNavigation || !this.enclosingTabId) {
            return;
        }
        const label = this.tab ? `${this.tab.developerName} · Vista 360` : 'Vista 360 Builder';
        if (label === this.appliedTabLabel) {
            return;
        }
        this.appliedTabLabel = label;
        setTabLabel(this.enclosingTabId, label).catch(() => {
            // A tab that will not take a label is cosmetic; let it keep the
            // platform's default rather than surface an error over it.
            this.appliedTabLabel = undefined;
        });
    }

    /**
     * Gives the workspace tab the same icon the Vista 360 tab carries in app
     * navigation, so the two read as one thing and a narrow console tab is
     * still recognisable once its label truncates.
     *
     * Applied once rather than on every render: the icon names the app, not
     * whichever tab is open, so unlike the label there is nothing for it to
     * follow. Failure is left alone for the same reason as the label -- a tab
     * that will not take an icon keeps the platform's default.
     */
    syncTabIcon() {
        if (!this.isConsoleNavigation || !this.enclosingTabId || this.appliedTabIcon) {
            return;
        }
        this.appliedTabIcon = true;
        setTabIcon(this.enclosingTabId, BUILDER_TAB_ICON, { iconAlt: 'Vista 360 builder' }).catch(() => {
            this.appliedTabIcon = false;
        });
    }

    /**
     * Publishes how far down the page the builder starts, so the stylesheet can
     * subtract exactly that from the viewport instead of a constant that has to
     * guess at app navigation, a console tab bar, or a debug banner.
     *
     * Re-measured on resize because those can appear and disappear without the
     * component re-rendering.
     */
    measureTopOffset() {
        const host = this.template.host;
        const top = Math.max(0, Math.round(host.getBoundingClientRect().top));
        if (top !== this.topOffset) {
            this.topOffset = top;
            host.style.setProperty('--v360-builder-top', `${top}px`);
        }
    }

    /**
     * Watches the host's own box rather than the window: the banners and tab
     * bars above the builder come and go without the window ever resizing, and
     * each one moves where the component starts.
     */
    observeViewport() {
        if (this.viewportObserver) {
            return;
        }
        this.viewportObserver = new ResizeObserver(() => this.measureTopOffset());
        this.viewportObserver.observe(document.body);
    }

    disconnectedCallback() {
        if (this.viewportObserver) {
            this.viewportObserver.disconnect();
            this.viewportObserver = undefined;
        }
        if (this.fullBleedWrapper) {
            this.fullBleedWrapper.classList.remove(FULL_BLEED_CLASS);
            this.fullBleedWrapper = undefined;
        }
    }

    async load() {
        this.status = STATUS_LOADING;
        try {
            this.data = await getCatalog();
            this.status = STATUS_LOADED;
            this.ensureSelection();
        } catch (error) {
            this.status = STATUS_ERROR;
        }
    }

    /** Keeps the open tab and card pointing at rows that still exist. */
    ensureSelection() {
        const tabs = this.data?.tabs ?? [];
        if (!tabs.some((tab) => tab.tabId === this.selectedTabId)) {
            this.selectedTabId = tabs.length ? tabs[0].tabId : undefined;
        }
        const cards = this.cards;
        if (!cards.some((card) => card.cardId === this.selectedCardId)) {
            this.selectedCardId = cards.length ? cards[0].cardId : undefined;
        }
    }

    /** Re-reads the catalog behind a spinner, keeping the current view on screen. */
    async refresh() {
        this.refreshing = true;
        try {
            this.data = await getCatalog();
            this.ensureSelection();
        } catch (error) {
            this.toast('Refresh failed', this.message(error), 'error');
        } finally {
            this.refreshing = false;
        }
    }

    // ---- state --------------------------------------------------------

    get isLoading() {
        return this.status === STATUS_LOADING;
    }

    get isError() {
        return this.status === STATUS_ERROR;
    }

    get isDenied() {
        return this.status === STATUS_LOADED && !this.data.hasManagePermission;
    }

    get isEmptyOrg() {
        return this.status === STATUS_LOADED && this.data.hasManagePermission && !this.data.tabs.length;
    }

    get isReady() {
        return this.status === STATUS_LOADED && this.data.hasManagePermission && this.data.tabs.length > 0;
    }

    get tab() {
        return this.data?.tabs.find((candidate) => candidate.tabId === this.selectedTabId) ?? null;
    }

    get cards() {
        return this.tab?.cards ?? [];
    }

    get card() {
        return this.cards.find((candidate) => candidate.cardId === this.selectedCardId) ?? null;
    }

    // ---- header -------------------------------------------------------

    /** The document name in the builder header: the tab, and the object it hangs off. */
    get documentName() {
        const tab = this.tab;
        return tab ? tab.developerName : 'Vista 360';
    }

    get documentMeta() {
        const tab = this.tab;
        return tab ? `${tab.sObjectApiName} · ${this.cards.length} cards` : '';
    }

    /** Tabs grouped under their anchor object, for the header switcher. */
    get tabGroups() {
        const groups = [];
        for (const tab of this.data?.tabs ?? []) {
            let group = groups.find((candidate) => candidate.sObjectApiName === tab.sObjectApiName);
            if (!group) {
                group = { sObjectApiName: tab.sObjectApiName, tabs: [] };
                groups.push(group);
            }
            group.tabs.push({ ...tab, cardCount: `${tab.cards.length}` });
        }
        return groups;
    }

    get switcherClass() {
        const base = 'slds-builder-header__nav-item slds-dropdown-trigger slds-dropdown-trigger_click';
        return this.switcherOpen ? `${base} slds-is-open` : base;
    }

    handleToggleSwitcher() {
        this.switcherOpen = !this.switcherOpen;
    }

    /**
     * Closes the switcher when focus leaves it entirely. relatedTarget is the
     * element focus moved to, so a jump between the trigger and its own menu
     * items keeps the dropdown open.
     */
    handleSwitcherFocusOut(event) {
        if (!event.currentTarget.contains(event.relatedTarget)) {
            this.switcherOpen = false;
        }
    }

    handleTabPick(event) {
        this.selectedTabId = event.currentTarget.dataset.tabId;
        this.selectedCardId = undefined;
        this.formulaFeedback = {};
        this.switcherOpen = false;
        this.ensureSelection();
    }

    // ---- card list ----------------------------------------------------

    get cardList() {
        const last = this.cards.length - 1;
        return this.cards.map((card, index) => {
            const presentation = this.presentation(card);
            const isSelected = card.cardId === this.selectedCardId;
            return {
                ...card,
                ...presentation,
                isSelected,
                rowClass: isSelected
                    ? 'v360-builder-cardrow v360-builder-cardrow_selected'
                    : 'v360-builder-cardrow',
                upDisabled: index === 0 || this.busy,
                downDisabled: index === last || this.busy
            };
        });
    }

    get hasNoCards() {
        return this.cards.length === 0;
    }

    get cardListCount() {
        const count = this.cards.length;
        return `${count} card${count === 1 ? '' : 's'}`;
    }

    handleCardSelect(event) {
        this.selectedCardId = event.currentTarget.dataset.cardId;
        this.formulaFeedback = {};
        // An unsaved icon pick belongs to the card it was made on.
        this.tileIconDraft = undefined;
    }

    handleCardKeydown(event) {
        if (event.key === 'Enter' || event.key === ' ') {
            event.preventDefault();
            this.handleCardSelect(event);
        }
    }

    handleMoveUp(event) {
        event.stopPropagation();
        this.move(event.currentTarget.dataset.cardId, -1);
    }

    handleMoveDown(event) {
        event.stopPropagation();
        this.move(event.currentTarget.dataset.cardId, 1);
    }

    /** Optimistic reorder; a failed save reloads the server's truth. */
    async move(cardId, offset) {
        if (this.busy) {
            return;
        }
        const cards = [...this.cards];
        const from = cards.findIndex((card) => card.cardId === cardId);
        const to = from + offset;
        if (from < 0 || to < 0 || to >= cards.length) {
            return;
        }
        const [moved] = cards.splice(from, 1);
        cards.splice(to, 0, moved);
        this.data = {
            ...this.data,
            tabs: this.data.tabs.map((tab) => (tab.tabId === this.selectedTabId ? { ...tab, cards } : tab))
        };

        this.busy = true;
        try {
            await updateCardOrder({ orderedCardIds: cards.map((card) => card.cardId) });
        } catch (error) {
            this.toast('Reorder failed', 'Showing the last saved order.', 'error');
            await this.refresh();
        } finally {
            this.busy = false;
        }
    }

    // ---- rail ---------------------------------------------------------

    handleSectionSelect(event) {
        this.selectedSection = event.currentTarget.dataset.section;
    }

    get isTileSection() {
        return this.selectedSection === SECTION_TILE;
    }

    get isRulesSection() {
        return this.selectedSection === SECTION_RULES;
    }

    get isReleaseSection() {
        return this.selectedSection === SECTION_RELEASE;
    }

    /**
     * The rail carries the one number that decides whether a section needs
     * attention: how many rules the evaluator will actually enforce, never
     * the stored total -- a parked rule protects nobody.
     */
    get rail() {
        const card = this.card;
        const enforced = card ? this.enforcement(card).enforced : 0;
        const openToAll = Boolean(card) && enforced === 0;
        const isDraft = Boolean(card) && !card.active && !card.killSwitch;
        return SECTIONS.map((section) => {
            const isSelected = section.key === this.selectedSection;
            const warns =
                (section.key === SECTION_RULES && openToAll) || (section.key === SECTION_RELEASE && isDraft);
            return {
                ...section,
                isSelected,
                tabIndex: isSelected ? 0 : -1,
                itemClass: isSelected
                    ? 'v360-builder-rail-item v360-builder-rail-item_active'
                    : 'v360-builder-rail-item',
                hasBadge: warns || (section.key === SECTION_RULES && enforced > 0),
                badgeLabel: warns ? '!' : `${enforced}`,
                badgeClass: warns
                    ? 'slds-badge slds-theme_warning v360-builder-rail-badge'
                    : 'slds-badge v360-builder-rail-badge',
                title: warns
                    ? section.key === SECTION_RULES
                        ? 'No active rule restricts this card'
                        : 'This card is still a draft'
                    : section.label
            };
        });
    }

    // ---- shared card presentation --------------------------------------

    /**
     * How many of a card's rules actually restrict someone. The evaluator
     * only lets an active rule block a card, so the stored total and the
     * enforced count are different facts. Every warning uses the second; a
     * catalog that omits it is not assumed to be protected.
     */
    enforcement(card) {
        const rules = card.rules ?? [];
        return {
            total: card.ruleCount ?? rules.length,
            enforced: card.activeRuleCount ?? rules.filter((rule) => rule.active).length
        };
    }

    presentation(card) {
        const state = card.killSwitch ? 'killed' : card.active ? 'live' : 'draft';
        const { total, enforced } = this.enforcement(card);
        const isLive = state === 'live';
        const parked = total === 0 ? 'No rules' : `${total} rule${total === 1 ? '' : 's'}, none active`;
        return {
            iconNameOrDefault: card.iconName || 'standard:default',
            binding: `${card.componentType}: ${card.componentName}`,
            stateLabel: { killed: 'Kill switch on', live: 'Live', draft: 'Draft' }[state],
            stateClass: {
                killed: 'slds-badge slds-theme_warning',
                live: 'slds-badge slds-theme_success',
                draft: 'slds-badge'
            }[state],
            isDraft: state === 'draft',
            isLive,
            isKilled: state === 'killed',
            enforcedRules: enforced,
            hasNoEnforcedRules: enforced === 0,
            isOpenToEveryone: isLive && enforced === 0,
            ruleSummary:
                enforced > 0
                    ? enforced === total
                        ? `${enforced} visibility rule${enforced === 1 ? '' : 's'}`
                        : `${enforced} of ${total} visibility rules active`
                    : isLive
                      ? `${parked} — visible to everyone who can see the page`
                      : parked
        };
    }

    // ---- canvas: tile ---------------------------------------------------

    get detail() {
        const card = this.card;
        if (!card) {
            return null;
        }
        return {
            ...card,
            ...this.presentation(card),
            bindingValue: `${card.componentType}${BINDING_SEPARATOR}${card.componentName}`,
            buttonLabelOrDefault: card.buttonLabel || 'Consultar'
        };
    }

    /** The object every formula on this tab is built and validated against. */
    get anchorSObject() {
        return this.tab?.sObjectApiName;
    }

    get breadcrumb() {
        const tab = this.tab;
        const card = this.card;
        return tab && card ? `${tab.sObjectApiName} › ${tab.developerName} › ${card.label}` : '';
    }

    get componentOptions() {
        const options = registeredCardNames().map((name) => ({
            label: `${COMPONENT_TYPE_LWC}: ${name}`,
            value: `${COMPONENT_TYPE_LWC}${BINDING_SEPARATOR}${name}`
        }));
        const card = this.card;
        if (card && card.componentType === COMPONENT_TYPE_FLOW) {
            options.unshift({
                label: `${COMPONENT_TYPE_FLOW}: ${card.componentName}`,
                value: `${COMPONENT_TYPE_FLOW}${BINDING_SEPARATOR}${card.componentName}`
            });
        }
        return options;
    }

    async handleSaveTile() {
        if (this.busy) {
            return;
        }
        const label = this.template.querySelector('[data-id="tile-label"]');
        if (!String(label.value ?? '').trim()) {
            label.reportValidity();
            this.toast('Missing information', 'A card needs a label.', 'error');
            return;
        }
        const binding = this.template.querySelector('[data-id="tile-component"]').value;
        const at = binding.indexOf(BINDING_SEPARATOR);
        this.busy = true;
        try {
            await saveCardProperties({
                input: {
                    cardId: this.selectedCardId,
                    label: label.value,
                    description: this.template.querySelector('[data-id="tile-description"]').value,
                    iconName: this.tileIconValue,
                    buttonLabel: this.template.querySelector('[data-id="tile-button-label"]').value,
                    componentType: binding.slice(0, at),
                    componentName: binding.slice(at + 1)
                }
            });
            this.toast('Card saved', `“${label.value}” was saved.`, 'success');
            await this.refresh();
        } catch (error) {
            this.toast('Save failed', this.message(error), 'error');
        } finally {
            this.busy = false;
        }
    }

    // ---- canvas: rules ---------------------------------------------------

    get rules() {
        const card = this.card;
        if (!card) {
            return [];
        }
        return (card.rules ?? []).map((rule, index) => {
            const feedback = this.formulaFeedback[rule.ruleId];
            const draft = this.draftFor(rule.ruleId);
            return {
                ...rule,
                // Between rules, never above the first: a joiner with nothing
                // on one side of it reads as a missing rule.
                showJoiner: index > 0,
                formulaFieldId: `formula-${rule.ruleId}`,
                ...this.ruleState(rule),
                typeFieldId: `pred-type-${rule.ruleId}`,
                targetFieldId: `pred-target-${rule.ruleId}`,
                // The draft rides on the row rather than being read off the
                // component, so each rule's pickers show that rule's choice.
                predicateType: draft.predicateType,
                predicateTarget: draft.predicateTarget,
                predicateTargetLabel: this.targetLabelFor(draft.predicateType),
                predicateTargetPlaceholder: this.targetPlaceholderFor(draft.predicateType),
                predicateTargetOptions: this.targetOptionsFor(draft.predicateType),
                feedbackValid: feedback?.isValid === true,
                predicateLabels: (rule.predicates ?? []).map((predicate, index) => ({
                    key: `${rule.ruleId}-${index}`,
                    predicateId: predicate.predicateId,
                    label: `${predicate.predicateType} · ${predicate.targetApiName}`
                })),
                feedbackMessage: feedback?.message,
                feedbackClass: feedback?.isValid
                    ? 'slds-text-body_small slds-text-color_success'
                    : 'slds-text-body_small slds-text-color_error'
            };
        });
    }

    /**
     * The banner announces an exposure the open section would not otherwise
     * mention. Two sections already mention it themselves, and repeating it
     * above them reads as two problems rather than one:
     *
     *   Release — its readiness list always carries this exact sentence, as
     *             the row that reports how many rules are enforced.
     *   Rules   — with no rules to list, the empty state is that sentence.
     *
     * Tile says nothing about exposure, so there the banner is the only
     * warning and has to show.
     */
    get showExposureBanner() {
        const card = this.card;
        if (!card || !this.presentation(card).isOpenToEveryone) {
            return false;
        }
        if (this.isReleaseSection) {
            return false;
        }
        return !(this.isRulesSection && this.hasNoRules);
    }

    get hasNoRules() {
        return this.rules.length === 0;
    }

    /** Why this card restricts nobody, and whether that is happening now or only once it is live. */
    get exposureNote() {
        const card = this.card;
        if (!card) {
            return '';
        }
        const { total } = this.enforcement(card);
        const cause =
            total === 0
                ? 'No rules yet.'
                : `This card stores ${total} rule${total === 1 ? '' : 's'}, but none of them are active. The evaluator skips an inactive rule, so they restrict nobody.`;
        return this.presentation(card).isLive
            ? `${cause} This card is visible to everyone who can see the page.`
            : `${cause} Once this card is live it will be open to everyone who can see the page.`;
    }

    /**
     * A predicate is structured access the formula cannot express: holding a
     * permission set, or being able to read a field. Both are enforced on
     * top of the formula, never instead of it.
     */
    /**
     * What a rule's badge says, in three states rather than two.
     *
     * A rule with no formula and no required access is switched on and doing
     * nothing, and calling that "Active" is the wrong belief this whole
     * setting exists to prevent: under ALL it adds no requirement, and under
     * ANY the evaluator refuses it as a way in, precisely so that a half-
     * written rule cannot hand the card to everyone. Either way the admin is
     * owed the truth on the badge rather than a green tick.
     */
    ruleState(rule) {
        if (!rule.active) {
            return { stateLabel: 'Off · skipped', stateClass: 'slds-badge' };
        }
        const asks = Boolean(rule.formula?.trim()) || (rule.predicates ?? []).length > 0;
        return asks
            ? { stateLabel: 'Active', stateClass: 'slds-badge slds-theme_success' }
            : { stateLabel: 'Empty · no effect', stateClass: 'slds-badge slds-theme_warning' };
    }

    // ---- how a card's rules combine -------------------------------------

    /** ALL unless the card says otherwise -- see V360VisibilityEvaluator. */
    get matchLogic() {
        return this.card?.ruleMatchLogic === MATCH_ANY ? MATCH_ANY : MATCH_ALL;
    }

    get isMatchAny() {
        return this.matchLogic === MATCH_ANY;
    }

    /**
     * Worded as what the admin gets, not as boolean algebra: "ALL / ANY" alone
     * leaves the reader to work out all of what.
     */
    get matchLogicOptions() {
        return [
            { label: 'Meet every rule', value: MATCH_ALL },
            { label: 'Meet any one rule', value: MATCH_ANY }
        ];
    }

    /**
     * The consequence spelled out under the choice, because this is the one
     * setting on the card where a wrong belief decides who sees data.
     */
    get matchLogicNote() {
        return this.isMatchAny
            ? 'Each rule is a separate way in. A user passing any single active rule sees the card — so a new rule widens who sees it.'
            : 'Every active rule is a requirement. A user must pass all of them — so a new rule narrows who sees it.';
    }

    /** Drawn between rule blocks, in the vocabulary of the chosen mode. */
    get ruleJoinerLabel() {
        return this.isMatchAny ? 'OR' : 'AND';
    }

    get accessHeading() {
        return this.isMatchAny ? 'This path also requires' : 'Required access';
    }

    async handleMatchLogicChange(event) {
        const matchLogic = event.detail.value;
        if (this.busy || matchLogic === this.matchLogic) {
            return;
        }
        this.busy = true;
        try {
            await setRuleMatchLogic({ cardId: this.card.cardId, matchLogic });
            await this.refresh();
            this.toast(
                'Rules updated',
                matchLogic === MATCH_ANY
                    ? 'Passing any single active rule now shows this card.'
                    : 'Every active rule is now required to show this card.',
                'success'
            );
        } catch (error) {
            this.toast('Change failed', this.message(error), 'error');
        } finally {
            this.busy = false;
        }
    }

    get predicateTypeOptions() {
        return [
            { label: 'Permission set', value: 'PERMISSION_SET' },
            { label: 'Field read access', value: 'FLS_READ' }
        ];
    }

    /**
     * The two predicate types take different targets from different places: a
     * permission set is a record the server lists, a field read is a field of
     * the tab's anchor object the UI API already describes. Both are chosen,
     * never typed -- an API name from memory is exactly what the rule editor
     * exists to stop.
     */
    targetOptionsFor(predicateType) {
        if (predicateType === PREDICATE_FLS_READ) {
            return Object.values(this.anchorFields ?? {}).map((field) => ({
                key: field.apiName,
                label: field.label,
                value: `${this.anchorSObject}.${field.apiName}`,
                detail: `${field.apiName} · ${field.dataType}`
            }));
        }
        return (this.permissionSets ?? []).map((option) => ({
            key: option.apiName,
            label: option.label,
            value: option.apiName,
            detail: option.apiName
        }));
    }

    targetLabelFor(predicateType) {
        return predicateType === PREDICATE_FLS_READ ? 'Field' : 'Permission set';
    }

    targetPlaceholderFor(predicateType) {
        return predicateType === PREDICATE_FLS_READ ? 'Search fields' : 'Search permission sets';
    }

    /** An untouched rule starts on the type an admin reaches for most. */
    draftFor(ruleId) {
        return this.predicateDrafts[ruleId] ?? { predicateType: PREDICATE_PERMISSION_SET };
    }

    /**
     * Reassigned rather than mutated in place: the drafts map is read through
     * the rules getter, and a getter only re-runs when the field it reads is
     * assigned.
     */
    setDraft(ruleId, changes) {
        this.predicateDrafts = {
            ...this.predicateDrafts,
            [ruleId]: { ...this.draftFor(ruleId), ...changes }
        };
    }

    handlePredicateTypeChange(event) {
        this.setDraft(event.currentTarget.dataset.ruleId, {
            predicateType: event.detail.value,
            // The chosen target belongs to the type it was chosen under.
            predicateTarget: undefined
        });
    }

    handlePredicateTargetSelect(event) {
        this.setDraft(event.currentTarget.dataset.ruleId, { predicateTarget: event.detail.value });
    }

    async handleAddPredicate(event) {
        if (this.busy) {
            return;
        }
        const ruleId = event.currentTarget.dataset.ruleId;
        const draft = this.draftFor(ruleId);
        if (!draft.predicateTarget) {
            const target = this.targetLabelFor(draft.predicateType).toLowerCase();
            this.toast('Missing information', `Pick a ${target} first.`, 'error');
            return;
        }
        this.busy = true;
        try {
            await addRulePredicate({
                ruleId,
                predicateType: draft.predicateType,
                targetApiName: draft.predicateTarget
            });
            this.setDraft(ruleId, { predicateTarget: undefined });
            await this.refresh();
        } catch (error) {
            this.toast('Add failed', this.message(error), 'error');
        } finally {
            this.busy = false;
        }
    }

    async handleRemovePredicate(event) {
        if (this.busy) {
            return;
        }
        this.busy = true;
        try {
            await deleteRulePredicate({ predicateId: event.currentTarget.dataset.predicateId });
            await this.refresh();
        } catch (error) {
            this.toast('Delete failed', this.message(error), 'error');
        } finally {
            this.busy = false;
        }
    }

    async handleDeleteRule(event) {
        if (this.busy) {
            return;
        }
        this.busy = true;
        try {
            await deleteRule({ ruleId: event.currentTarget.dataset.ruleId });
            this.toast('Rule deleted', 'The rule and its predicates were deleted.', 'success');
            await this.refresh();
        } catch (error) {
            this.toast('Delete failed', this.message(error), 'error');
        } finally {
            this.busy = false;
        }
    }

    // ---- icon picker ------------------------------------------------------

    /**
     * One picker serves both the tile form and the new-card modal;
     * iconPickerTarget records which draft the single select handler writes
     * back to. An icon reference is not something anyone types from memory,
     * so neither place offers a bare text field.
     */
    handleOpenIconPicker(event) {
        this.iconPickerTarget = event.currentTarget.dataset.target;
        this.iconPickerOpen = true;
    }

    handleCloseIconPicker() {
        this.iconPickerOpen = false;
    }

    handleIconSelect(event) {
        if (this.iconPickerTarget === 'newCard') {
            this.newCardIcon = event.detail.value;
        } else {
            this.tileIconDraft = event.detail.value;
        }
        this.iconPickerOpen = false;
    }

    /** The tile's icon: an unsaved pick if there is one, else what the card carries. */
    get tileIconValue() {
        return this.tileIconDraft ?? this.card?.iconName ?? '';
    }

    get tileIconLabel() {
        return this.tileIconValue || 'Choose an icon';
    }

    get tileIconPreview() {
        return this.tileIconValue || 'standard:default';
    }

    get newCardIconLabel() {
        return this.newCardIcon || 'Choose an icon';
    }

    get newCardIconPreview() {
        return this.newCardIcon || 'standard:default';
    }

    get selectedIconForPicker() {
        return this.iconPickerTarget === 'newCard' ? this.newCardIcon : this.tileIconValue;
    }

    // ---- creating things -------------------------------------------------

    handleNewCard() {
        this.newCardType = COMPONENT_TYPE_LWC;
        this.newCardIcon = '';
        this.newCardOpen = true;
    }

    handleNewRule() {
        this.newRuleOpen = true;
    }

    handleNewTab() {
        this.editingTabId = null;
        this.tabModalOpen = true;
        this.switcherOpen = false;
    }

    handleEditTab() {
        this.editingTabId = this.selectedTabId;
        this.tabModalOpen = true;
        this.switcherOpen = false;
    }

    get tabModalTitle() {
        return this.editingTabId ? 'Edit tab' : 'New tab';
    }

    get isEditingTab() {
        return Boolean(this.editingTabId);
    }

    /** The tab modal's values: the tab being edited, or blanks for a new one. */
    get tabForm() {
        const editing = this.data?.tabs.find((tab) => tab.tabId === this.editingTabId);
        return editing
            ? { developerName: editing.developerName, sObjectApiName: editing.sObjectApiName }
            : { developerName: '', sObjectApiName: '' };
    }

    handleOpenHelp() {
        this.helpOpen = true;
    }

    handleCloseModals() {
        this.newCardOpen = false;
        this.newRuleOpen = false;
        this.tabModalOpen = false;
        this.helpOpen = false;
        this.deleteTarget = null;
    }

    get isNewCardFlow() {
        return this.newCardType === COMPONENT_TYPE_LWC;
    }

    get newCardTypeOptions() {
        return [
            { label: 'Lightning component', value: COMPONENT_TYPE_LWC },
            { label: 'Screen flow', value: COMPONENT_TYPE_FLOW }
        ];
    }

    handleNewCardTypeChange(event) {
        this.newCardType = event.detail.value;
    }

    /** Every listed field must be non-blank before a create call goes out. */
    fieldsFilled(selectors) {
        let valid = true;
        for (const selector of selectors) {
            const field = this.template.querySelector(selector);
            if (!field) {
                continue;
            }
            if (typeof field.reportValidity === 'function') {
                field.reportValidity();
            }
            if (!String(field.value ?? '').trim()) {
                valid = false;
            }
        }
        if (!valid) {
            this.toast('Missing information', 'Complete the required fields.', 'error');
        }
        return valid;
    }

    async handleCreateCard() {
        if (this.busy) {
            return;
        }
        const bindingField = this.isNewCardFlow ? '[data-id="nc-component"]' : '[data-id="nc-flow"]';
        if (!this.fieldsFilled(['[data-id="nc-devname"]', '[data-id="nc-label"]', bindingField])) {
            return;
        }
        const binding = this.template.querySelector(bindingField).value;
        const componentName = this.isNewCardFlow ? binding.slice(COMPONENT_TYPE_LWC.length + 1) : binding;
        this.busy = true;
        try {
            await createCard({
                input: {
                    tabId: this.selectedTabId,
                    developerName: this.template.querySelector('[data-id="nc-devname"]').value,
                    label: this.template.querySelector('[data-id="nc-label"]').value,
                    description: this.template.querySelector('[data-id="nc-description"]').value,
                    iconName: this.newCardIcon,
                    buttonLabel: this.template.querySelector('[data-id="nc-button-label"]').value,
                    componentType: this.newCardType,
                    componentName,
                    order: this.cards.length + 1
                }
            });
            this.newCardOpen = false;
            this.toast('Card created', 'It starts as a draft — activate it from Release when it is ready.', 'success');
            await this.refresh();
        } catch (error) {
            this.toast('Create failed', this.message(error), 'error');
        } finally {
            this.busy = false;
        }
    }

    async handleCreateRule() {
        if (this.busy) {
            return;
        }
        if (!this.fieldsFilled(['[data-id="nr-devname"]'])) {
            return;
        }
        this.busy = true;
        try {
            await createRule({
                cardId: this.selectedCardId,
                developerName: this.template.querySelector('[data-id="nr-devname"]').value,
                formulaText: this.template.querySelector('[data-id="nr-formula"]').value
            });
            this.newRuleOpen = false;
            this.toast('Rule created', 'The visibility rule was created.', 'success');
            await this.refresh();
        } catch (error) {
            this.toast('Create failed', this.message(error), 'error');
        } finally {
            this.busy = false;
        }
    }

    /** One path for both: a blank id creates, an id updates. */
    async handleSaveTab() {
        if (this.busy) {
            return;
        }
        if (!this.fieldsFilled(['[data-id="nt-devname"]', '[data-id="nt-anchor"]'])) {
            return;
        }
        const editing = this.isEditingTab;
        this.busy = true;
        try {
            await saveTab({
                input: {
                    tabId: this.editingTabId,
                    developerName: this.template.querySelector('[data-id="nt-devname"]').value,
                    sObjectApiName: this.template.querySelector('[data-id="nt-anchor"]').value,
                    // Sequence and active are carried by the DTO but nothing on
                    // the read path consumes them: the shell takes one tab per
                    // FlexiPage component, so App Builder decides placement.
                    sequence: (this.data?.tabs.length ?? 0) + 1,
                    active: true
                }
            });
            this.tabModalOpen = false;
            this.toast(
                editing ? 'Tab saved' : 'Tab created',
                editing ? 'The tab was updated.' : 'Add cards to it from the Cards list.',
                'success'
            );
            await this.refresh();
        } catch (error) {
            this.toast('Save failed', this.message(error), 'error');
        } finally {
            this.busy = false;
        }
    }

    // ---- deleting ---------------------------------------------------------

    handleRequestDeleteCard() {
        const card = this.card;
        this.deleteTarget = { kind: 'card', id: card.cardId, label: card.label };
    }

    handleRequestDeleteTab() {
        const tab = this.tab;
        this.tabModalOpen = false;
        this.deleteTarget = { kind: 'tab', id: tab.tabId, label: tab.developerName };
    }

    get deleteMessage() {
        if (!this.deleteTarget) {
            return '';
        }
        return this.deleteTarget.kind === 'tab'
            ? `The tab “${this.deleteTarget.label}” will be deleted. A tab that still has cards is rejected.`
            : `“${this.deleteTarget.label}” and its visibility rules will be deleted. This cannot be undone.`;
    }

    async handleConfirmDelete() {
        if (this.busy || !this.deleteTarget) {
            return;
        }
        const target = this.deleteTarget;
        this.deleteTarget = null;
        this.busy = true;
        try {
            if (target.kind === 'tab') {
                await deleteTab({ tabId: target.id });
                this.selectedTabId = undefined;
                this.toast('Tab deleted', `“${target.label}” was deleted.`, 'success');
            } else {
                await deleteCard({ cardId: target.id });
                this.toast('Card deleted', `“${target.label}” and its rules were deleted.`, 'success');
            }
            this.selectedCardId = undefined;
            await this.refresh();
        } catch (error) {
            this.toast('Delete failed', this.message(error), 'error');
        } finally {
            this.busy = false;
        }
    }

    /**
     * The editor owns the text and hands it over on the event, so the formula
     * is never read back out of the DOM. A draft therefore survives anything
     * that re-renders this pane, which reading from the DOM did not.
     */
    async handleValidateFormula(event) {
        if (this.busy) {
            return;
        }
        const ruleId = event.currentTarget.dataset.ruleId;
        const formulaText = event.detail.value;
        this.busy = true;
        try {
            const result = await validateRuleFormula({ cardId: this.selectedCardId, formulaText });
            this.formulaFeedback = { ...this.formulaFeedback, [ruleId]: result };
        } catch (error) {
            this.formulaFeedback = {
                ...this.formulaFeedback,
                [ruleId]: { isValid: false, message: this.message(error) }
            };
        } finally {
            this.busy = false;
        }
    }

    async handleSaveFormula(event) {
        if (this.busy) {
            return;
        }
        const ruleId = event.currentTarget.dataset.ruleId;
        const formulaText = event.detail.value;
        this.busy = true;
        try {
            await saveRuleFormula({ ruleId, cardId: this.selectedCardId, formulaText });
            this.toast('Rule saved', 'The visibility formula was saved.', 'success');
            await this.refresh();
        } catch (error) {
            this.toast('Save failed', this.message(error), 'error');
        } finally {
            this.busy = false;
        }
    }

    // ---- canvas: release --------------------------------------------------

    /**
     * The checklist behind activation, driven by the enforced rule count so a
     * card whose rules are all parked cannot pass with a green check.
     */
    get releaseChecks() {
        const card = this.card;
        if (!card) {
            return [];
        }
        const { total, enforced } = this.enforcement(card);
        const checks = [
            {
                key: 'binding',
                ok: true,
                text: 'Component binding resolves',
                detail: `${card.componentType}: ${card.componentName} is configured.`
            },
            enforced > 0
                ? {
                      key: 'rules',
                      ok: true,
                      text: `${enforced} active visibility rule${enforced === 1 ? '' : 's'}`,
                      detail: 'A user who passes any one of them will see this card.'
                  }
                : {
                      key: 'rules',
                      ok: false,
                      text: total > 0 ? `${total} rule${total === 1 ? '' : 's'}, none active` : 'No visibility rules',
                      detail:
                          total > 0
                              ? 'The evaluator skips an inactive rule, so these restrict nobody.'
                              : 'Everyone who can see the page will see this card.'
                  },
            {
                key: 'tile',
                ok: true,
                text: 'Tile presentation set',
                detail: `Label “${card.label}”, button “${card.buttonLabel || 'Consultar'}”.`
            }
        ];
        return checks.map((check) => ({
            ...check,
            boxClass: check.ok
                ? 'slds-box slds-box_x-small slds-m-bottom_x-small'
                : 'slds-box slds-box_x-small slds-m-bottom_x-small slds-theme_warning',
            iconName: check.ok ? 'utility:success' : 'utility:warning',
            iconVariant: check.ok ? 'success' : 'warning'
        }));
    }

    handleActivate() {
        this.runCardAction(activateCard, 'Card activated', 'is now live for end users.');
    }

    handleDeactivate() {
        this.runCardAction(deactivateCard, 'Card deactivated', 'is a draft again.');
    }

    handleEngageKill() {
        this.runCardAction(engageKillSwitch, 'Kill switch on', 'is hidden everywhere.', 'warning');
    }

    handleReleaseKill() {
        this.runCardAction(releaseKillSwitch, 'Kill switch released', 'follows its rules again.');
    }

    async runCardAction(action, title, tail, variant = 'success') {
        if (this.busy) {
            return;
        }
        const card = this.card;
        this.busy = true;
        try {
            await action({ cardId: card.cardId });
            this.toast(title, `“${card.label}” ${tail}`, variant);
            await this.refresh();
        } catch (error) {
            this.toast('Action failed', this.message(error), 'error');
        } finally {
            this.busy = false;
        }
    }

    handleRefresh() {
        this.refresh();
    }

    handleRetry() {
        this.load();
    }

    // ---- plumbing ---------------------------------------------------------

    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    message(error) {
        return error?.body?.message || 'Something went wrong.';
    }
}
