# S4_DEF

SAP S/4HANA (DFD) developments for DEF. ABAP and CDS objects move to QA and Production through transports only; the sources here are reference copies. The UI5 apps deploy from here to SAP BTP (HTML5 Application Repository + SAP Build Work Zone).

| Folder | What | SAP objects (DFD, package ZDEF) |
|---|---|---|
| `DFD/scheduled-orders/` | Scheduled orders by terminal, customer and destination: CDS view stack, OData V4 service and a Fiori Elements Analytical List Page (`app/`) | `ZOTC_SCHEDULED_ORDERS`, `ZC_OTC_SCHED_TERMINAL_SUM`, `ZI_OTC_SCHED_*`, `ZUI_OTC_SCHEDULED_ORDERS(_O4)`. Request DFDK908431 |
| `DFD/brf-viewer/` | Read-only BRF+ catalog and decision table viewer: ALV report `ZCA_BRF_DT_VIEWER`, RAP service and UI5 app (`frontend/`) | `ZCA_BRF_DT_VIEWER`, `ZI_BRF_*`, `ZCL_BRF_VIEWER_*`, `ZUI_BRF_VIEWER(_O4)`. Request DFDK903994 |

Deploy an app: `cd <app folder>`, `npm install`, `npm run build:mta`, `cf login`, `npm run deploy`. See each app's README for the destination and Work Zone steps.
