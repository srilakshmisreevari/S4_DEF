# Scheduled Orders app (Fiori Elements V4 Analytical List Page)

Service: `ZUI_OTC_SCHEDULED_ORDERS_O4` in DFD
(`/sap/opu/odata4/sap/zui_otc_scheduled_orders_o4/srvd/sap/zui_otc_scheduled_orders/0001/`).
The app has no custom code. Charts, columns, labels, filters and the default
"Next 7 days" filter come from the CDS metadata extensions `ZC_OTC_SCHED_TERMINAL_SUM` and `ZOTC_SCHEDULED_ORDERS`.

## Pages
1. **Analytical List Page** on `TerminalSummary`:
   - visual filters: donut by supply type, bar by terminal (click to filter);
   - main chart `MainChart`;
   - summary table: Terminal, Customer, Destination, Orders, Open qty, Unit, Gallons, Bucket.
2. **Summary object page** (click a row): totals, plus the table of order lines (`_Orders`).
3. **Order line object page** (click a line): order, PO, delivery and TM details.

The summary table is a responsive table, not an analytical table. Each row is already aggregated in CDS, and the
responsive table always requests the keys, which the row click needs.

## Run locally
```
npm install
npm start
```
`ui5.yaml` proxies `/sap` to DFD client 120. The service must be published in that client. If it is
only published in 100 so far, change `client` to "100", or copy the publication to 120 with SCC1.

## Deploy to BTP
1. Cloud Connector: allow the path `/sap/opu/odata4/sap/zui_otc_scheduled_orders_o4/` on the DFD virtual host.
2. Destination `DFD_OTC_SCHED_ORDERS` (OnPremise, PrincipalPropagation, `sap-client`). Use the same setup as `DFD_BRF_VIEWER`.
3. In `mta.yaml`, redirect URIs are set for region us10.
4. `npm run build:mta`, `cf login`, `npm run deploy`.
5. Work Zone: add the app (inbound `ScheduledOrders-display`) to a content channel, role and group.

## Known points
- The default filter "Next 7 days" shows almost nothing in DFD, because the test data is old. Change DueWindow to "Past due" to see data.
- Adding up Orders across summary rows counts an order once per row it appears in. Gallons and lines are exact.
- Users need display access to the service (`S_SERVICE`) and, once the DCLs exist, `V_VBAK_AAT` / `V_VBAK_VKO` with activity 03.
