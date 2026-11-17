//----------------------------------------------------------------------
// Change log
// Date       | Author              | Request    | Description
// 2026-11-17 | Srilakshmi Sreevari | DFDK908431 | Created - current
//            |                     |            | scheduled orders by
//            |                     |            | terminal, customer and
//            |                     |            | destination (one row
//            |                     |            | per open schedule line)
// 2026-11-17 | Srilakshmi Sreevari | DFDK908431 | ALP: metadata extensions
//            |                     |            | allowed, UI annotations
//            |                     |            | and labels moved to DDLX
//            |                     |            | ZOTC_SCHEDULED_ORDERS,
//            |                     |            | new field DueWindow
//----------------------------------------------------------------------
// Consumer rules:
//  - filter the window on DueDate (EDATU); IsPastDue is relative to
//    $session.system_date;
//  - never sum OpenQuantity across OrderQuantityUnit; use
//    QuantityInGallons (null when no conversion exists) or group by unit;
//  - kits: header and components both carry quantity - count only one
//    level (IsKitHeader / IsKitComponent);
//  - one row per schedule line: at most one freight unit and one freight
//    order (tender copies and canceled TM documents excluded).
// Terminal: stock = shipping point (else plant); third-party = goods
// supplier partner WL, else PO goods supplier (EKKO-LLIEF), else
// 'Unsourced'. A dummy plant is never shown as terminal.
// Authorization: DCL ZOTC_SCHEDULED_ORDERS (V_VBAK_AAT / V_VBAK_VKO, as
// standard I_SalesDocumentItem).
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Scheduled orders by terminal/customer'
@ObjectModel.usageType: { serviceQuality: #D, sizeCategory: #XL, dataClass: #TRANSACTIONAL }
// >>> 2026-11-17 Srilakshmi Sreevari DFDK908431 - UI annotations in DDLX
//@UI.headerInfo: { typeName: 'Scheduled Order Line', typeNamePlural: 'Scheduled Order Lines' }
@Metadata.allowExtensions: true
// <<< 2026-11-17 Srilakshmi Sreevari DFDK908431
define view entity ZOTC_SCHEDULED_ORDERS
  as select from ZI_OTC_SCHED_LINE as l
{
      // >>> 2026-11-17 Srilakshmi Sreevari DFDK908431 - all @UI annotations
      // of this view are commented out and maintained in DDLX
      // ZOTC_SCHEDULED_ORDERS
      //@UI.lineItem: [{ position: 10 }]
      //@UI.selectionField: [{ position: 10 }]
  key l.SalesOrder,
      //@UI.lineItem: [{ position: 20 }]
  key l.SalesOrderItem,
      //@UI.lineItem: [{ position: 30 }]
  key l.ScheduleLine,

      // Organisation
      l.SalesOrderType,
      //@UI.selectionField: [{ position: 90 }]
      l.SalesOrganization,
      l.DistributionChannel,
      l.OrganizationDivision,

      // Supply
      //@UI.lineItem: [{ position: 40 }]
      //@UI.selectionField: [{ position: 30 }]
      l.SupplyType,
      l.SalesOrderItemCategory,
      l.ScheduleLineCategory,
      l.Product,

      // Terminal
      //@UI.selectionField: [{ position: 40 }]
      cast( case
              when l.SupplyType = 'Stock' and l.ShippingPoint <> ''
                then cast( l.ShippingPoint as abap.char(10) )
              when l.SupplyType = 'Stock'
                then cast( l.Plant as abap.char(10) )
              when l.GoodsSupplierPartner is not null and l.GoodsSupplierPartner <> ''
                then cast( l.GoodsSupplierPartner as abap.char(10) )
              when l.PurchaseOrderGoodsSupplier is not null and l.PurchaseOrderGoodsSupplier <> ''
                then cast( l.PurchaseOrderGoodsSupplier as abap.char(10) )
              else cast( 'UNSOURCED' as abap.char(10) )
            end as abap.char(10) )                         as TerminalID,
      //@UI.lineItem: [{ position: 50 }]
      cast( case
              when l.SupplyType = 'Stock' and l.ShippingPoint <> ''
                then cast( l.ShippingPointName as abap.char(80) )
              when l.SupplyType = 'Stock'
                then cast( l.PlantName as abap.char(80) )
              when l.GoodsSupplierPartner is not null and l.GoodsSupplierPartner <> ''
                then cast( l.GoodsSupplierPartnerName as abap.char(80) )
              when l.PurchaseOrderGoodsSupplier is not null and l.PurchaseOrderGoodsSupplier <> ''
                then cast( l.PurchaseOrderGoodsSupplierName as abap.char(80) )
              else cast( 'Unsourced' as abap.char(80) )
            end as abap.char(80) )                         as TerminalName,
      cast( case
              when l.SupplyType = 'Stock' and l.ShippingPoint <> ''
                then cast( 'Shipping Point' as abap.char(20) )
              when l.SupplyType = 'Stock'
                then cast( 'Plant' as abap.char(20) )
              when l.GoodsSupplierPartner is not null and l.GoodsSupplierPartner <> ''
                then cast( 'Goods Supplier (WL)' as abap.char(20) )
              when l.PurchaseOrderGoodsSupplier is not null and l.PurchaseOrderGoodsSupplier <> ''
                then cast( 'PO Goods Supplier' as abap.char(20) )
              else cast( 'Unsourced' as abap.char(20) )
            end as abap.char(20) )                         as TerminalType,
      cast( case
              when l.SupplyType = 'Stock'
                then cast( '' as abap.char(40) )
              when l.GoodsSupplierPartner is not null and l.GoodsSupplierPartner <> ''
                then cast( l.GoodsSupplierPartnerCity as abap.char(40) )
              when l.PurchaseOrderGoodsSupplier is not null and l.PurchaseOrderGoodsSupplier <> ''
                then cast( l.PurchaseOrderGoodsSupplierCity as abap.char(40) )
              else cast( '' as abap.char(40) )
            end as abap.char(40) )                         as TerminalCity,
      cast( case
              when l.SupplyType = 'Stock'
                then cast( '' as abap.char(3) )
              when l.GoodsSupplierPartner is not null and l.GoodsSupplierPartner <> ''
                then cast( l.GoodsSupplierPartnerRegion as abap.char(3) )
              when l.PurchaseOrderGoodsSupplier is not null and l.PurchaseOrderGoodsSupplier <> ''
                then cast( l.PurchaseOrderGoodsSupplierRgn as abap.char(3) )
              else cast( '' as abap.char(3) )
            end as abap.char(3) )                          as TerminalRegion,
      l.ShippingPoint,
      l.ShippingPointName,
      // Plant is the real plant for stock lines; for third-party lines it
      // is the dummy plant and must not be used as terminal
      l.Plant,
      l.PlantName,

      // Customer and destination
      //@UI.selectionField: [{ position: 50 }]
      l.SoldToParty,
      //@UI.lineItem: [{ position: 60 }]
      l.SoldToPartyName,
      l.ShipToParty,
      //@UI.lineItem: [{ position: 70 }]
      l.ShipToPartyName,
      //@UI.lineItem: [{ position: 80 }]
      l.ShipToCity,
      //@UI.lineItem: [{ position: 90 }]
      l.ShipToRegion,
      l.ShipToPostalCode,
      l.ShipToCountry,
      // safety check: 'X' = document-specific (manual) ship-to address,
      // the city/region/postal code above come from the customer master
      l.ShipToAddrIsDocSpecific,
      l.IncotermsClassification,
      l.IncotermsLocation1,

      // Date
      //@UI.lineItem: [{ position: 100 }]
      //@UI.selectionField: [{ position: 20 }]
      l.DueDate,
      cast( case when l.DueDate < $session.system_date then 'X' else '' end as abap.char(1) ) as IsPastDue,
      // >>> 2026-11-17 Srilakshmi Sreevari DFDK908431 - due window relative
      // to $session.system_date (today .. +6 = next 7 days, +7 .. +13)
      cast( case
              when l.DueDate < $session.system_date
                then 'Past due'
              when l.DueDate <= dats_add_days( $session.system_date, 6, 'INITIAL' )
                then 'Next 7 days'
              when l.DueDate <= dats_add_days( $session.system_date, 13, 'INITIAL' )
                then 'Days 8-14'
              else 'Later'
            end as abap.char(11) )                         as DueWindow,
      // <<< 2026-11-17 Srilakshmi Sreevari DFDK908431

      // Quantities
      //@UI.lineItem: [{ position: 110 }]
      @Semantics.quantity.unitOfMeasure: 'OrderQuantityUnit'
      l.OpenQuantity,
      @Semantics.quantity.unitOfMeasure: 'OrderQuantityUnit'
      l.OrderedQuantity,
      @Semantics.quantity.unitOfMeasure: 'OrderQuantityUnit'
      l.ConfirmedQuantity,
      l.OrderQuantityUnit,
      //@UI.lineItem: [{ position: 120 }]
      @Semantics.quantity.unitOfMeasure: 'GallonUnit'
      cast( case
              when l.OrderQuantityUnit = 'GLL'
                then cast( l.OpenQuantity as abap.dec(23,3) )
              when l.BaseUnit = 'GLL' and l.OrderToBaseQtyDenominator <> 0
                then cast( division( cast( l.OpenQuantity as abap.dec(15,3) ) * l.OrderToBaseQtyNumerator,
                                     l.OrderToBaseQtyDenominator, 3 ) as abap.dec(23,3) )
              when l.OrderToBaseQtyDenominator <> 0 and l.GallonToBaseQtyNumerator <> 0
                then cast( division( cast( l.OpenQuantity as abap.dec(15,3) ) * l.OrderToBaseQtyNumerator
                                       * cast( l.GallonToBaseQtyDenominator as abap.dec(5,0) ),
                                     l.OrderToBaseQtyDenominator * cast( l.GallonToBaseQtyNumerator as abap.dec(5,0) ), 3 ) as abap.dec(23,3) )
              else cast( unit_conversion( quantity       => l.OpenQuantity,
                                          source_unit    => l.OrderQuantityUnit,
                                          target_unit    => cast( 'GLL' as abap.unit(3) ),
                                          error_handling => 'SET_TO_NULL' ) as abap.dec(23,3) )
            end as abap.quan(23,3) )                       as QuantityInGallons,
      cast( 'GLL' as abap.unit(3) )                        as GallonUnit,

      // Kits
      l.HigherLevelItem,
      cast( case when l.IsKitHeader = 'X' then 'X' else '' end as abap.char(1) )                as IsKitHeader,
      cast( case when l.HigherLevelItem <> '000000' then 'X' else '' end as abap.char(1) )      as IsKitComponent,

      // Third-party purchasing
      l.PurchaseRequisition,
      l.PurchaseRequisitionItem,
      l.PurchaseOrder,
      l.PurchaseOrderItem,
      l.PurchaseOrderType,
      cast( case when l.PoIsAssignedToSalesOrder = 'X' then 'X' else '' end as abap.char(1) )   as PoIsAssignedToSalesOrder,
      l.GoodsSupplierPartner,
      l.GoodsSupplierPartnerName,
      l.PurchaseOrderGoodsSupplier,
      l.PurchaseOrderGoodsSupplierName,
      cast( case when l.HasGoodsReceipt = 'X' then 'X' else '' end as abap.char(1) )            as HasGoodsReceipt,
      l.OrderRelatedBillingStatus,

      // Delivery (open delivery first, else last delivery)
      cast( case when l.OpenDelivery is not null then l.OpenDelivery else l.LastDelivery end as vbeln_vl ) as Delivery,
      cast( case when l.HasDelivNotGoodsIssued = 'X' then 'X' else '' end as abap.char(1) )     as DeliveryNotGoodsIssued,

      // TM
      l.FreightUnit,
      l.FreightOrder,
      // TM planning status (PLAN_STATUS_ROOT) is maintained on the freight
      // unit; freight orders carry it blank (checked in DFD_120)
      cast( case when l.FreightUnitPlanningStatus is not null and l.FreightUnitPlanningStatus <> ''
                 then l.FreightUnitPlanningStatus
                 else l.FreightOrderPlanningStatus end as abap.char(2) )                         as TMPlanningStatus,
      l.FreightOrderLifecycleStatus,
      // UTC timestamp of the freight order's first outbound stop
      //@UI.lineItem: [{ position: 130 }]
      l.PlannedPickupDateTime,
      cast( case when l.FreightUnit is not null or l.FreightOrder is not null
                 then 'X' else '' end as abap.char(1) )                                          as HasTMDocument,

      // Status bucket
      //@UI.lineItem: [{ position: 140 }]
      //@UI.selectionField: [{ position: 60 }]
      // <<< 2026-11-17 Srilakshmi Sreevari DFDK908431
      cast( case
              when l.DueDate < $session.system_date
                then 'Past due'
              when l.SupplyType = 'Stock' and l.HasDelivNotGoodsIssued = 'X'
                then 'Delivery created, not loaded'
              when l.FreightOrder is not null
                then 'FO planned'
              when l.FreightUnit is not null
                then 'FU not planned'
              else 'No TM (FOB or DAP)'
            end as abap.char(30) )                         as StatusBucket,

      // Warnings
      cast( case when l.SupplyType = 'ThirdParty' and l.PurchaseOrder is null
                 then 'X' else '' end as abap.char(1) )                                          as ThirdPartyWithoutPO,
      cast( case when l.PurchaseOrder is not null and l.ConfirmedQuantity = 0
                 then 'X' else '' end as abap.char(1) )                                          as ConfirmedQtyZeroWithPO
}
