# Pulling current scheduled orders by terminal, customer and destination: the reasoning

Validated in DFQ (copy of Production), window 2026-11-16 to 2026-11-23. Read-only analysis; nothing was changed in any system.

**Starting point.** The textbook S/4 answer is to read open sales order schedule lines through `API_SALES_ORDER_SRV`, take the shipping point as the terminal and the ship-to as the destination, and sum the confirmed quantity. Each part of that was checked against DFQ. Several parts don't hold, because this business is built mostly on drop-ship (third-party) supply and SAP TM.

## Step 1: Decide what "scheduled" means before writing any query
- **Assumption:** an open schedule line with a confirmed quantity (BMENG > 0) in the date window.
- **What I checked:** whether confirmation is meaningful here. The third-party schedule line category (ZT) has no availability check, so its confirmed quantity just copies the ordered quantity. For those lines BMENG > 0 tells you nothing.
- **Then:** whether TM plans the loads. It does, but only for DAT (delivered) orders. In this week's window, 136 of 148 third-party lines and about 177 of 243 stock lines have no TM document. Almost all are FOB or DAP orders, which TM never touches.
- **Decision:** "scheduled" needs two layers.
  - Every open line with a due date (EDATU) in the window counts as scheduled.
  - For DAT orders, add the TM planning state (planned or not planned) and the freight order's planned pickup time. The pickup date differed from the order due date on 4 of 24 samples.

## Step 2: Define "open" correctly for each type of supply
- **Assumption:** item not rejected and not fully delivered, using overall status GBSTA ≠ C.
- **What I found:**
  - Third-party items are never delivered in SD. Their delivery status is blank and their completion is driven by billing.
  - 22,301 third-party items are fully billed but still show GBSTA as open.
- **Decision:**
  - Stock lines are open until goods issue is posted: no delivery yet, or a delivery whose goods-issue status WBSTA ≠ C. *(Corrected 2026-11-17: the earlier rule LFSTA ≠ C dropped 151 delivery items that had a delivery but no goods issue.)*
  - Third-party lines are open while billing status FKSAA ≠ C and no goods receipt (movement 101/109) exists on the purchase order.
  - Always exclude rejected lines (ABGRU).
  - Always use a date floor and a separate past-due bucket. More than 28,000 "open" items are older than 90 days and would swamp the report.

## Step 3: Work out what a "terminal" is
- **Assumption:** the item's shipping point, falling back to the plant.
- **What I found:** this is true for stock orders only. Their shipping points read "DEF Quakertown Bulk" or "DEF Taunton Packaging", and their plants are A0xx "DEF <city>".
- **Third-party lines** sit on dummy plants (A999, A000, A998, A997) with no shipping point. Their real loading point is the supplier, which appears in three places that agree with each other:
  - the order's goods-supplier partner (WL), for example Koch Fertilizer, Enid OK;
  - the goods supplier (EKKO-LLIEF) on the third-party purchase order;
  - the source location on the TM freight order.
- **Decision:**
  - Stock: terminal = shipping point and plant.
  - Third-party: terminal = WL vendor, falling back to the PO goods supplier.
  - If neither exists, show "Unsourced" (23 lines in the 90-day open population). Never show a dummy plant as a terminal.

## Step 4: Customer and destination
- **Assumption:** sold-to is the customer, ship-to is the destination, and one-time ship-to addresses override master data.
- **What I found:** sold-to and ship-to are always at header level, with no item-level ship-tos. All 592 window orders use the master address, and no manual or one-time addresses exist.
- **Decision:** keep the design as is. Read the ship-to's city, state and ZIP from the customer master. Leave a safety check for manual addresses, even though there are currently none. Some ship-tos are rail sidings, which is worth knowing when reading quantities.

## Step 5: Quantities and double counting
- **Units:** the window mixes gallons, cases, each, drums, totes and feet.
  - Never add across units.
  - Either group by unit or convert to gallons with each material's own conversion factors.
- **Kits:** the kit header and its components both carry quantity. Count one or the other, not both.
- **TM join:** one order line can have a freight unit, a freight order and a tender copy. Joining all of them multiplies rows, so:
  - exclude the tender copies (TOR_CAT = 'TC');
  - deduplicate on order, item and schedule line.
- **Deliveries:** deliveries are created shortly before loading. *(Updated 2026-11-17: 151 delivery items in the window now exist with goods issue not yet posted, so a "delivery created, not loaded" bucket is worth showing.)*
- **TM link for third-party lines:** freight units and freight orders hang off the **purchase order** (BASE_BTD_TCO = '001'), not the sales order. Filter PO-based freight orders through the PO account assignment (EKKN) to a sales order, because inbound stock-transfer POs (type ZIB1) also have freight orders.

## Step 6: Choose the access path

How the API list was worked out (checked in DFQ 2026-11-17):

| Question | Check | Finding |
|---|---|---|
| Which release? | CVERS | S4CORE 107 (S/4HANA 2022): API names looked up, not assumed |
| Which OData V2 services are active? | `/IWFND/I_MED_SRH` | Only sales order, business partner, PO process and pricing conditions |
| Do the other APIs exist? | TADIR (IWSV) | Outbound delivery (0001, 0002), product, billing document, material document and purchase requisition APIs are shipped but not registered |
| Is there a TM API? | `API_FREIGHT*`, TM packages | None. Only freight agreement and rate table APIs, so TM is a gap, not an activation task |
| What TM data is released? | `ARS_W_API_STATE` | `I_TransportationOrderAnalytics`, `I_TranspOrdItemAnalytics`, `I_TranspOrdStopAnalytics` |
| Which V4 services are published? | `/IWFND/C_V4_MSGR` | `API_PURCHASEORDER_2`; no delivery or TM services |
| Are the endpoints (ICF nodes) active? | ICFSERVICE | Active for sales order, business partner and PO; none for the delivery API or the Z services |
| What are the two custom services? | Package ZPTP_IN | `ZOTCR_PURCHASE_ORDERS_AN_CDS` ("Third Party Supplied") and `ZOTCR_DELIVERY_AN_CDS` ("Musket Supplied"). Generated, not registered; both report actuals (goods receipts, goods issues), not open schedules |

| Data needed | API | Status in DFQ | Activate? |
|---|---|---|---|
| Orders, schedule lines, partners | `API_SALES_ORDER_SRV` | Active | No |
| Names and addresses | `API_BUSINESS_PARTNER` | Active | No |
| PO and goods supplier | `API_PURCHASEORDER_PROCESS_SRV` / `API_PURCHASEORDER_2` | Active / published | No |
| Outbound deliveries | `API_OUTBOUND_DELIVERY_SRV` (0002) | Shipped, not registered | Only if users need delivery drill-down |
| Goods receipts, billing status, TM dates, unit conversion | None that fits | — | Custom view |

- Don't activate the two `ZOTCR_*` services for this report; they show history, not open lines.
- Reusable objects: `ZRTR_FREIGHTUNIT` (TM), `ZPTP_EKPO` (unit conversion), and the TM link logic in ZOTCR_009_OPERATIONAL_REP.
- **Decision:** the standard APIs alone can't give the right answer, because they can't see TM dates, goods receipts or the billing-status rule. Build one custom CDS view that combines:
  - the stock path: order → shipping point/plant → TM;
  - the third-party path: order → requisition → PO → goods supplier → goods receipt → TM;
  - the open-quantity filter;
  - unit handling.
- Build it on released views where they exist (sales document schedule line/item/partner, PO API views and PO history, delivery item, the TM analytics views, product units of measure, plant, shipping point, customer, supplier). Read tables only where a released view lacks a field.
- Publish that view as one OData service (V4 preferred). Estimated 5–8 days including access control and reconciliation against ZOTC_OPREP.

## Process flows (checked on real orders, 2026-11-17)

**Stock order** (example SO 1000312732, due 18 Nov)
1. Order item: plant A009, shipping point B009; schedule line ZS, 5,200 GLL.
2. TM freight unit and freight order link to the sales order (BASE_BTD_TCO = '114', order + item + schedule line). Source location = shipping point.
3. Planned pickup = freight order's first stop (STOP_CAT = 'O', PLAN_TRANS_TIME, UTC).
4. Delivery created from the order (2000218563, 17 Nov), goods issue not posted yet.
5. Goods issue (movement 601) closes the line; billing follows.

**Third-party order** (example SO 1000314739, due 20 Nov)
1. Order item: dummy plant A999, schedule line ZT, 1,500 GLL, purchase requisition attached. Goods-supplier partner (WL) 3000031.
2. Purchase requisition → PO 4200094018; goods supplier (LLIEF) 3000031; PO account assignment (EKKN) points back to the sales order.
3. TM freight unit and freight order link to the **PO** (BASE_BTD_TCO = '001'). Source = goods supplier, destination = ship-to.
4. Freight order pickup 15:22 UTC vs tender copy 12:30: exclude tender copies.
5. Goods receipt (101/109) on the PO closes the line (none yet here). Billing status C also closes it, even when the overall status still shows open.

DAP third-party orders have no TM document on either the order or the PO.

**Not yet verified:** whether freight units and freight orders move to the delivery once it is created; the billing step on a live document; exact fields exposed by the sales order API and the TM analytics views; Gateway system aliases and user authorisations.

## Step 7: Aggregate
- Group: terminal → customer → destination → date → unit.
- Count orders and sum open quantity.
- Add a status bucket on each row: FO planned / FU not planned / no TM (FOB or DAP) / past due.

## Step 8: Prove it before trusting it
- **Reconciliation baseline:** the operational report ZOTC_OPREP, not VA05. It already follows the same third-party chain and TM links.
  - It selects by order creation date and reports actuals. It's good for checking links and individual orders, but not for matching weekly totals.
- **Warnings the output must always raise:**
  - lines with no TM document;
  - third-party lines with no PO;
  - lines whose confirmed quantity is 0 even though a PO exists (7 this week);
  - mixed units;
  - duplicated kit quantities;
  - the stale billed-but-open backlog.

## What this looks like in practice (DFQ, 11/16–11/23)

| Terminal | Customer | Destination | Orders | Open qty | Bucket |
|---|---|---|---|---|---|
| Koch Fertilizer, Wever IA | Kem Krest LLC | Fowlerville, MI | 8 | 185,000 GLL | Third-party, no TM |
| Dyno Nobel, Cheyenne WY | Tartan Oil LLC | Knoxville, TN | 16 | 86,400 GLL | Third-party, no TM |
| PCS/Nutrien, Lima OH | Browns Oil Service | Fountaintown, IN | 2 | 10,400 GLL | Third-party DAT, freight order planned |
| DEF Quakertown Bulk | PPC Lubricants | Jonestown, PA | 6 | 31,200 GLL | Stock DAT, freight order planned |
| DEF Taunton Packaging | FleetPride | North Haven, CT | 2 | 3,520 CS | Stock DAT, freight order planned |
| DEF Jacksonville Bulk | Love's Master Account | St Augustine, FL | 3 | 12,100 GLL | Stock FOB, no TM |

## Decisions the business still has to make
1. For FOB and DAP orders, is the order due date the scheduled date, or is a lift appointment kept somewhere else, such as Gravitate?
2. Should the stale open backlog be cleaned up in the system, or just filtered out of the report?
3. Should past-due lines appear in the current view?
4. For kits, should the report count the header or the components?
5. Should loads Gravitate creates after the fact (unplanned drops) be counted?
