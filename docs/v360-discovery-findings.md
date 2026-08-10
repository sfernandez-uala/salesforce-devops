# Vista 360 — Current-State Discovery (uala-crm-mx)

Read-only findings from an analysis of the existing Vista 360 implementation in the `uala-crm-mx` repository, performed July 2026. This document describes what exists today, as found in the source. It contains no recommendations and takes no position on future design decisions. File references point to `uala-crm-mx` unless stated otherwise.

## 1. Platform facts (verified July 2026)

- LWC State Managers are GA since Summer '26. Custom managers are created with `defineState` from `@lwc/state`; primitives are `atom`, `computed`, `setAtom`; actions may be async; `fromContext` shares an instance down a single component tree.
- Built-in managers (`lightning/stateManagerRecord`, `lightning/stateManagerLayout`) wrap UI API calls and expose `{ status: 'unconfigured' | 'loading' | 'loaded' | 'error', data, error }` plus setter actions. They can be nested inside a custom `defineState` with their config supplied as a `computed`; an empty config `{}` keeps them in `unconfigured` (waiting) state.
- Not supported in Experience Cloud.
- This repository (`salesforce-devops`) is on `sourceApiVersion: 67.0` (Summer '26) and contains an SFDMU configuration at `data/ReferenceData/export.json`.
- References: [State Management — LWC Dev Guide](https://developer.salesforce.com/docs/platform/lwc/guide/state-management.html) · [lightning/stateManager* reference](https://developer.salesforce.com/docs/platform/lwc/guide/reference-state-managers-use.html) · [forcedotcom/state-management examples](https://github.com/forcedotcom/state-management/tree/main/examples/platform-state-managers) · [Salesforce Developers Blog, Jul 2026](https://developer.salesforce.com/blogs/2026/07/lwc-state-managers-share-reactive-state-across-components)

## 2. Container: `landingCards`

- `@api recordId`, `objectApiName`, `isMock`, `selectedTabId` (`landingCards.js:13-16`). `selectedTabId` is populated in App Builder from `CardConfigTabPicklistEditor.cls` (a `VisualEditor.DynamicPickList`) which emits `CardConfigTab__c.ExternalId__c` values.
- `@wire(getRecord)` fetches Account fields defined in `config.js:9-14` (`email`, `awsAccountId`, `awsUserId` / `Usuario_AWS__c`).
- `@wire(getConfigs)` calls `LandingCardsController.getConfigs` (`@AuraEnabled(cacheable=true)`) → `CardConfigService` → `CardConfigTabSelector`. The response includes the card list plus `userProfileId` and `userPermissions` computed server-side.
- A `props` getter (`landingCards.js:138-154`) passes `{recordId, objectApiName, isMock, email, awsAccountId, awsUserId}` to every card through `landingCardItemView`.
- Cards are filtered client-side per record/user in `componentsProxy` (`landingCards.js:170-197`) via `evaluateConfig` from `c/validationEngine`.
- Cards are loaded by dynamic import: `import("c/" + Component_Name__c)` in `landingCardItemView.js:109-125`. There is no static registry; `KNOWN_TYPE`/`COMPONENT_MAPPING` in the same file are empty `TODO` stubs (`landingCardItemView.js:9-15`). A failed import logs to console; no user-visible error state is rendered.
- Opened cards stay mounted in a `_renderedComponents` Map and are shown/hidden via CSS (`landingCards.js:19,89-97,248-253`).
- Selected-card state persists in sessionStorage via `c/tabStateService` (keyed by `recordId`) and is mirrored to the URL via `NavigationMixin`.
- Loading flags are independent per layer: `landingCards.isLoading` gates only the config wire; `landingCardItemView._isLoading` gates the dynamic import; each card manages its own flag.

## 3. Aside: `userInformation`

- The only LWC whose `js-meta.xml` targets `lightning__RecordPage` restricted to Account. It is placed on the record page independently — it is not a child of `landingCards` and does not receive its `props`.
- Follows the documented bundle convention: `render()` switching skeleton/main templates, `service.js` as the sole `@salesforce/apex` boundary, `mock.js` fixtures, `templates/` folder.
- `connectedCallback` → `fetchData()` → `UserInformationCtrl.getUserInformation`. On success it publishes `externalId` into `c/userDataStore` (`userInformation.js:46`). Refresh is a manual button that re-runs `fetchData()`.
- `userInformation/templates/userInformation.html:3,13` uses the `if:true` directive; the project convention documented in `.claude/skills/v360-developer/SKILL.md` specifies `lwc:if`.
- Apex side: `UserInformationService.cls:24-30` queries `Account.Cuenta_Relacionada__r.Usuario_AWS__c` via SOQL; `landingCards` fetches the same field via LDS for its own tree.

## 4. Cross-component data sharing (as implemented)

- `c/userDataStore` is a module-level singleton holding one value per `recordId` (`externalId`) with subscribe/publish functions and sessionStorage persistence through `tabStateService`.
- Producer: `userInformation`. Consumers: `accountDetails`, `accountStatements`, `accountMtuLimits`, `transactionHistory`.
- Each consumer subscribes and also starts a 5-second fallback `setTimeout`; if the store is not populated by then, the consumer calls `UserInformationCtrl.getUserInformation` itself (`accountDetails.js:212-231`, `accountStatements.js:208-228`, `accountMtuLimits.js:191-212`, `transactionHistory.js:348-356`). Up to 5 calls to the same endpoint for the same Account can occur (aside + 4 fallbacks).
- No Lightning Message Service, no pubsub module, no `lightning/empApi` usage exists in shipped components (`empApi` appears only in the skill's example file).
- Four cards (`accountLoans.js:116`, `accountInvestments.js:182`, `accountVerificationsHistory.js:319`, `accountPortabilities.js:121`) each dispatch a CustomEvent named `eventsubscriber` with the same payload shape to register per-card header buttons in `landingCardItemView.js:138-140`.
- `refreshApex` is used in 2 places, both outside the card/aside data path.

## 5. Card configuration subsystem

### Data model

- `CardConfigTab__c` (master): `ExternalId__c` (unique, externalId — inline help: "Utilizado solo para migración de tabs entre entornos"), `Pais__c` (restricted picklist, single value `México`), `SObject__c` (restricted picklist, single value `Account`), `RecordType__c` (plain text), `Tab_Name__c`, `QueryAux__c` (derived list of fields referenced by the tab's card filters).
- `CardComponentConfig__c` (detail, master-detail to tab): `Component_Name__c`, `Label__c`, `Description__c`, `Button_Label__c`, `Icon_Name__c`, `Order__c`, `Filters_JSON__c` (LongTextArea 32768). Name is AutoNumber `CC-{0000}`; the object has no external id field, no validation rules, no record types.
- `Filters_JSON__c` shape (per `fieldFilterBuilder.js:87-101`, `cardConfigAdminUi.js:372-385`): `{ filters: [{ field: {apiName, label, dataType}, operator, value, valueName? }], logic: 'AND'|'OR'|'CUSTOM', customLogic, profiles: [], customPermissions: [] }`. Three non-sObject "advanced" fields exist: `ProfileId`, `customPermissions`, `Area__c`. Profile targeting stores Profile record Ids (sourced from `getProfiles()` → `SELECT Id, Name FROM Profile`); Profile Ids are org-specific values. Custom-permission targeting stores `DeveloperName`s.

### Admin UI

- `cardConfigAdminUi` is exposed as a Lightning Web Tab ("Configurador de tarjetas"). Capabilities: CRUD of tabs and card components (via `lightning-record-edit-form`), drag-and-drop reordering (bulk `Order__c` update through Apex `saveCardComponentConfig`), a filter builder (`c-filter-expression`) with per-datatype operators, AND/OR/CUSTOM combination logic (custom logic strings like `1 AND (2 OR 3)`), and Profile / Custom Permission pickers. Saving filters recomputes `QueryAux__c` on the tab.
- `Component_Name__c` is chosen from an autocomplete populated by `getCardComponentTypes()`, which enumerates the org's exposed LWCs through a Tooling API callout.
- Every method in `CardConfigAdminUIController.cls` is gated by `FeatureManagement.checkPermission('CanPerformLandingCardsConfiguration')`. `saveCardComponentConfig` performs `update records;` with no additional FLS/CRUD enforcement on the DML (`CardConfigAdminUIController.cls:39-51`).
- Permission sets: `CardComponentConfig` (admin: full CRUD on both objects + the custom permission + tab visibility) and `CustomerView360` (end user: read-only on both objects).

### Rule evaluation

- Evaluation happens client-side in `c/validationEngine`. The server returns all configured cards for the tab plus `userProfileId`/`userPermissions`; the client filters.
- `evaluateFilter` (`validationEngine.js:128-181`): `ProfileId`, `customPermissions`, `Area__c` compare against a `userContext` object; all other apiNames read `record[apiName]`. Operators: equals, not equal, contains/starts with/ends with (string-guarded), is true/false, greater/less than (number-guarded), before/after (Date).
- `evaluateConfig` (`validationEngine.js:191-230`): `AND` → every, `OR` → some, `CUSTOM` → token-substitutes the stored logic string and executes it via `new Function(...)` (`validationEngine.js:217`). The syntax validators (`validateConfigStructure`, `validateCustomLogic`) run only at admin save time in `filterExpression`, not at evaluation time.
- **Confirmed defect**: `landingCards.js:191` calls `evaluateConfig(config, record, userProfiles, userPerms)` — 4 positional arguments — while the signature is `evaluateConfig(config, record, userContext)` — 3 parameters. The profiles array binds to `userContext`, so `userContext.userProfiles`, `.userPerms`, and `.userArea` are `undefined` during evaluation. Net effect on the live render path: filters on `ProfileId`, `customPermissions`, or `Area__c` never match the actual user — `equals` always evaluates false, `not equal` always true. The fourth argument is silently dropped.
- Malformed `Filters_JSON__c` is handled fail-closed: `JSON.parse`/evaluation errors are caught, logged to console, and the card is excluded from the visible list (`landingCards.js:184-196`).

### Server side

- `UserContext.cls` computes the running user's profile (SOQL on User), `Area__c`, and custom permissions (PermissionSetAssignment → SetupEntityAccess → CustomPermission DeveloperNames).
- All queries in `CardConfigTabSelector.cls` and the Account query in `CardConfigService.cls:53` use `WITH SECURITY_ENFORCED`.
- Tab lookups on the read path use `ExternalId__c`; the admin UI works with record Ids.

### Environment promotion

- The only cross-org mechanism present is `CardConfigTab__c.ExternalId__c` (unique, externalId). No SFDMU config, data trees, CSVs, or scripts referencing these objects exist in the `uala-crm-mx` repo. Configuration is entered per org through the admin UI; the developer-agent doc's post-development step is "Add to landingCards configuration" (`.claude/agents/v360-developer.md:117`).

## 6. Test coverage (as found)

- Apex: `LandingCardsControllerTest` (7 tests), `CardConfigAdminUIControllerTest` (12 tests, permission-denied branch for every method, mocked Tooling callout), `CardConfigTabPicklistEditorTest` (3 tests). No dedicated test class for `CardConfigService` or `CardConfigTabSelector`. `LandingCardsControllerTest.cls:267-280` (missing-read-permissions) states in its own comment that it documents current behavior rather than asserting enforcement.
- Jest: no tests exist for `validationEngine`, `filterExpression`, `fieldFilterBuilder`, `cardConfigAdminUi`, `addCardComponentModal`, or `addCardTabModal`.

## 7. Documented convention vs shipped code

- `.claude/skills/v360-developer/SKILL.md` documents the component bundle convention (render() multi-template switch, `service.js` as the only Apex import point, `mock.js`, skeleton templates) and prescribes `lightning/empApi` platform-event subscription for auto-refresh; no shipped component uses `empApi`, and refresh is a manual re-fetch button.
- The skill prohibits `if:true`; `userInformation.html` uses it.
