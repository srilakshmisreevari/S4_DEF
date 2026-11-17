# BRF+ Catalog Viewer (read-only)

> **Current choice: SAP GUI ALV report `ZCA_BRF_DT_VIEWER`** (`report/ZCA_BRF_DT_VIEWER.prog.abap`).
> The Fiori/RAP version below is kept as an alternative and is not needed for the report.

## RAP service + BTP deployment

The RAP service runs in DFD (on-premise S/4HANA). BRF+ is not available in the BTP ABAP Environment, so the service cannot run there. BTP reaches it through the Cloud Connector, and the UI5 app is deployed to the HTML5 Application Repository and launched from SAP Build Work Zone.

DFD (package `ZDEF`, transport `DFDK903994`): `ZCX_BRF_VIEWER`, `ZI_BRF_CatalogNode`, `ZI_BRF_DecisionTable`, `ZI_BRF_DTColumn`, `ZI_BRF_DTRow`, `ZCL_BRF_VIEWER_READER`, `ZCL_BRF_VIEWER_QUERY`, `ZUI_BRF_VIEWER` (service definition), `ZUI_BRF_VIEWER_O4` (OData V4 UI binding). The reader follows catalog links the same way the report does.

Steps still to do:
1. Publish `ZUI_BRF_VIEWER_O4` (done in DFD). ADT cannot publish it (client 100 records changes automatically, client 120 allows none). Use `/IWFND/V4_ADMIN` → Publish Service Groups in client 100, system alias `LOCAL`, group `ZUI_BRF_VIEWER_O4`, on a customizing request. Copy that request to client 120 with SCC1. Transport the customizing request to DFQ together with the workbench request; nobody publishes by hand there.
2. Cloud Connector: map a virtual host to DFD and allow the path `/sap/opu/odata4/sap/zui_brf_viewer_o4/`.
3. BTP subaccount destination `DFD_BRF_VIEWER`: Type HTTP, ProxyType OnPremise, URL `http://<virtual host>:<port>`, Authentication PrincipalPropagation (or BasicAuthentication for a first test), additional properties `sap-client=120`, `WebIDEEnabled=true`, `HTML5.DynamicDestination=true`.
4. From `frontend/`: `npm install`, `npm run build:mta`, `cf login`, `npm run deploy`.
5. Work Zone: add the app (`zbrf.viewer`, inbound `BRFPlusCatalog-display`) to a content channel, role and group.

Files: `frontend/mta.yaml`, `frontend/ui5-deploy.yaml`, `frontend/webapp/xs-app.json`. In `manifest.json` the service URI is now relative and `sap.cloud` is set.

Field names changed in the service: `RowCount` is now `TotalRows`, and `Label` is now `ColumnLabel` (both are reserved words in CDS).

## ALV report ZCA_BRF_DT_VIEWER

One executable program with local classes. No DDIC objects, dynpro or GUI status to create.

| Area | How it is built |
|---|---|
| Selection screen | Catalog name (select-options, optional) and decision table name (optional, opens it directly) |
| Left | `CL_SALV_TREE`: Catalog Structure, H (link/system object icon), Status (green/yellow LED), type, description. Standard tree toolbar: expand/collapse all, find |
| Right top | General: `CL_SALV_TABLE` with ID, name, description, application, package, created/changed by and on, status, rows/columns, match settings |
| Right bottom | Table contents: `CL_GUI_ALV_GRID`, display only. One column per decision table column (no 40-column limit), result columns green, Row column as key. Standard ALV toolbar gives filter (multi-value, ranges, patterns), sort, find/find next, subtotals, layouts (saved per decision table), export to spreadsheet/local file, print, plus a Refresh button |
| Data | Same FDT API logic as the Fiori backend (`CL_FDT_FACTORY`, `IF_FDT_CATALOG`, `IF_FDT_DECISION_TABLE`); no FDT table read directly |
| Authorization | `IF_FDT_TRANSACTION~AUTHORITY_CHECK`, activity 3, per catalog and object; objects the user may not display are hidden |

Why ALV and not IDA: `CL_SALV_GUI_TABLE_IDA` only reads a database table or CDS view. BRF+ decision table contents are only available through the FDT API (reading the FDT tables directly is ruled out), so the classic ALV grid on an internal table is used.

Notes:
- The controls are hosted on an empty selection screen 9000 inside the report, so no screen has to be painted in SE51.
- Cells are shown up to 255 characters.
- Double-click a decision table in the tree to load it. Layout variants are stored under report key `ZBRFDT:<decision table name>`.

Setup: create program `ZCA_BRF_DT_VIEWER` (type executable), paste the source, activate. Create the text symbols and selection texts with the ADT/SE38 quick fix (literals are used until then). Optionally create a transaction (e.g. `ZBRF_VIEW`).

A Fiori app for browsing BRF+ catalogs and viewing decision table contents.
Nothing in it can create, change, activate, transport or delete a BRF+ object.

Target: S/4HANA 2022 (SAP_BASIS 757, SAP_UI 757 → UI5 1.108), checked against DFD.

## What was verified in DFD before writing the code

| Item | Result |
|---|---|
| `TECHNICAL_VARIABLE_SYSTEM_SPEC` | Catalog (CA), ID `06494007995E1EEE8E9F7CFC4BA843FE` |
| `ZDT_VARCONFIG_SYS_DEP` | Expression (EX), ID `06494007995E1EEE8E9F7CFC4BA7C3FE`, same application as the catalog |
| Catalogs in the system | 10 (ZDEF_OTC_CATALOG, ZDEF_BUSINESS_CATALOG, ZDEF_STM_CATALOG, …) |
| API used | `CL_FDT_FACTORY` (`GET_INSTANCE_GENERIC`, `GET_QUERY`, `GET_CATALOG`, `GET_APPLICATION`), `IF_FDT_CATALOG~GET_CATALOG_STRUCTURE / GET_NODE_PROPERTIES`, `IF_FDT_DECISION_TABLE~GET_COLUMNS / GET_TABLE_DATA / GET_TABLE_PROPERTY`, `IF_FDT_ADMIN_DATA~GET_NAME / GET_TEXTS / GET_CHANGE_INFO / GET_VERSIONS`, `IF_FDT_ELEMENT`, `IF_FDT_DATA_OBJECT~GET_DDIC_BINDING`. All signatures were read from DFD. |
| Authorization | `IF_FDT_TRANSACTION~AUTHORITY_CHECK` with activity 3 (Display). This is the same check the BRF+ workbench runs: application exit, then `FDT_OBJECT`, or `S_DEVELOP` for Y/Z applications. |

No FDT table is read directly.

## Objects

| Object | Type | Purpose |
|---|---|---|
| `ZI_BRF_CatalogNode` | Custom entity | Tree nodes (CatalogTree) |
| `ZI_BRF_DecisionTable` | Custom entity | Header and "General" section |
| `ZI_BRF_DTColumn` | Custom entity | Column metadata (DecisionTableMeta) |
| `ZI_BRF_DTRow` | Custom entity | Table contents (DecisionTableContent), slots C01–C40 |
| `ZCL_BRF_VIEWER_QUERY` | Class | `IF_RAP_QUERY_PROVIDER`: $filter, $search, $orderby, $top/$skip, $count |
| `ZCL_BRF_VIEWER_READER` | Class | Wrapper around the FDT API |
| `ZCX_BRF_VIEWER` | Exception class | Errors (message 00/001; no message class needed) |
| `ZUI_BRF_VIEWER` | Service definition | Exposes the 4 entities |
| `ZUI_BRF_VIEWER_O4` | Service binding | OData V4 - UI (create in ADT) |
| `frontend/` | UI5 app `zbrf.viewer` | Freestyle UI5: FlexibleColumnLayout, TreeTable, FilterBar, sap.m.Table |

The service has no behaviour definition, so OData create, update and delete are not possible.

## Design decisions

- **Dynamic columns.** Every row comes back as one record. Its cells sit in generic fields C01–C40, and `DecisionTableMeta.Slot` maps each slot to a column. This keeps server-side `$filter`, `$orderby` and paging working per row, which a row/column/value triplet design would not. A table with more than 40 columns shows the first 40 and a warning (`ColumnsTruncated`).
- **Cell text** follows the BRF+ workbench: `=PTP`, `[100..200]`, `<>A998`, `NOT ( … )`, and several ranges joined with `; `. A cell that points to another BRF+ object shows `[OBJECT_NAME]`.
- **Lazy tree.** The first call reads only the catalog roots (`ParentNodeId eq ''`). Expanding a catalog loads that whole catalog in one call (`CatalogId eq …`). Search and Expand all load every catalog first.
- **Filters.** Multi-value means OR within one column, sent as `contains()`, which the backend matches case-insensitively. Columns named `*_LOW` / `*_HIGH` and number, date, amount and quantity elements get From/To fields. Free text goes to `$search` across all columns. An OR across two different columns can't be expressed as ranges and is rejected with a clear message; the UI never sends one.
- **Variants** are saved per decision table in the browser (localStorage). In the launchpad this can be replaced by the `ushell` personalization service if views must follow the user across devices.
- **Highlighting.** Result columns are shaded green, as in the workbench. Cells that match the **Find** term are highlighted, and Next/Previous moves through the loaded rows.
- **Group** groups the rows loaded so far, after a server-side sort on that column.

## Setup (DFD)

1. Create a package (or use an existing one) and a transport.
2. In ADT, create the objects in this order and paste the sources from `backend/`:
   `ZCX_BRF_VIEWER` → `ZI_BRF_*` (4 data definitions, "Define Custom Entity" template) → `ZCL_BRF_VIEWER_READER` → `ZCL_BRF_VIEWER_QUERY` → `ZUI_BRF_VIEWER`.
3. Activate everything together. The custom entities and the classes refer to each other.
4. Create the service binding `ZUI_BRF_VIEWER_O4` (OData V4 - UI) for `ZUI_BRF_VIEWER`, and publish it as described in "RAP service + BTP deployment", step 1.
5. Test in the binding preview or with the URLs below.
6. Frontend: `cd frontend && npm install && npm start` for a local run through the proxy in `ui5.yaml`. To deploy, follow "RAP service + BTP deployment" (HTML5 Application Repository + Work Zone). No BSP is used.

### Test URLs

```
.../zui_brf_viewer/0001/CatalogTree?$filter=ParentNodeId eq ''
.../zui_brf_viewer/0001/CatalogTree?$filter=CatalogId eq '06494007995E1EEE8E9F7CFC4BA843FE'
.../zui_brf_viewer/0001/DecisionTable('06494007995E1EEE8E9F7CFC4BA7C3FE')
.../zui_brf_viewer/0001/DecisionTableMeta?$filter=DecisionTableId eq '06494007995E1EEE8E9F7CFC4BA7C3FE'
.../zui_brf_viewer/0001/DecisionTableContent?$filter=DecisionTableId eq '06494007995E1EEE8E9F7CFC4BA7C3FE' and contains(C03,'EMAILID')&$count=true&$top=50
```

## Authorizations for users

- `S_SERVICE` for the OData V4 service and the launchpad catalog/role.
- BRF+ display authorization for the applications they should see: `FDT_OBJECT` with `FDT_ACT = 3`, or `S_DEVELOP` display for Y/Z applications. Objects the user may not display are left out of the tree.
- For an extra app-specific gate, see the commented `ZBRF_VIEW` check in `ZCL_BRF_VIEWER_READER->IS_AUTHORIZED`.

## Not yet done

- "H…" column: the screenshot doesn't show what it means. It is mapped to "technical" (link node or SAP system object); change `IsTechnical` if it means something else.
- Text symbols 001–003 in the reader class and 001–002 in the query class still need to be created (ADT quick fix), or the literals stay as they are.
