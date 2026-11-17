//----------------------------------------------------------------------
// Change log
// Date       | Author              | Request    | Description
// 2026-11-17 | Srilakshmi Sreevari | DFDK908431 | Created - scheduled
//            |                     |            | orders: open sales
//            |                     |            | order schedule lines
//            |                     |            | with partners, supply,
//            |                     |            | delivery and TM data
//----------------------------------------------------------------------
// One row per open schedule line (sales orders, SD category C only).
// Third-party = schedule line category ZT/YT, item category ZTAS/YTAS or
// dummy plant A999/A000/A998/A997 (YT/YTAS = "3rd Party CA" in DFD).
// Open:
//  - always: item not rejected (ABGRU initial) and line quantity > 0
//    (BMENG if the item has any confirmation, else WMENG);
//  - third-party: VBAP-FKSAA <> 'C' and no net PO goods receipt;
//  - stock: no outbound delivery yet, or a delivery item with goods
//    issue not posted (WBSTA A/B), or open delivery quantity left on
//    the schedule line (partial delivery).
// No date floor here: the consumer filters DueDate (EDATU).
// All sources are released views or ZI_OTC_SCHED_* helpers; partners on
// header level (I_SalesDocumentPartner), names/addresses from the
// customer / supplier master (I_Customer / I_Supplier).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Sched. orders: open schedule lines'
@ObjectModel.usageType: { serviceQuality: #D, sizeCategory: #XL, dataClass: #TRANSACTIONAL }
define view entity ZI_OTC_SCHED_LINE
  as select from    I_SalesDocumentScheduleLine as sl
    inner join      I_SalesDocumentItem         as itm on  itm.SalesDocument     = sl.SalesDocument
                                                       and itm.SalesDocumentItem = sl.SalesDocumentItem
    inner join      ZI_OTC_SCHED_CNF            as cnf on  cnf.SalesDocument     = sl.SalesDocument
                                                       and cnf.SalesDocumentItem = sl.SalesDocumentItem
    left outer join ZI_OTC_SCHED_KIT            as kit on  kit.SalesDocument     = sl.SalesDocument
                                                       and kit.SalesDocumentItem = sl.SalesDocumentItem
    left outer join ZI_OTC_SCHED_3P             as tp  on  tp.SalesDocument      = sl.SalesDocument
                                                       and tp.SalesDocumentItem  = sl.SalesDocumentItem
                                                       and tp.ScheduleLine       = sl.ScheduleLine
    left outer join ZI_OTC_SCHED_DLV            as dlv on  dlv.SalesDocument     = sl.SalesDocument
                                                       and dlv.SalesDocumentItem = sl.SalesDocumentItem
    left outer join ZI_OTC_SCHED_TM             as tm  on  tm.SalesDocument      = sl.SalesDocument
                                                       and tm.SalesDocumentItem  = sl.SalesDocumentItem
                                                       and tm.ScheduleLine       = sl.ScheduleLine
    left outer join I_SalesDocumentPartner      as ag  on  ag.SalesDocument      = sl.SalesDocument
                                                       and ag.PartnerFunction    = 'AG'
    left outer join I_SalesDocumentPartner      as we  on  we.SalesDocument      = sl.SalesDocument
                                                       and we.PartnerFunction    = 'WE'
    left outer join I_SalesDocumentPartner      as wl  on  wl.SalesDocument      = sl.SalesDocument
                                                       and wl.PartnerFunction    = 'WL'
    left outer join I_Customer                  as agc on  agc.Customer = ag.Customer
    left outer join I_Customer                  as wec on  wec.Customer = we.Customer
    left outer join I_Supplier                  as wls on  wls.Supplier = wl.Supplier
    left outer join I_Supplier                  as gss on  gss.Supplier = tp.PurchaseOrderGoodsSupplier
    left outer join I_ShippingPointText         as spt on  spt.ShippingPoint = itm.ShippingPoint
                                                       and spt.Language      = $session.system_language
    left outer join I_Plant                     as pl  on  pl.Plant = itm.Plant
    left outer join I_ProductUnitsOfMeasure     as uom on  uom.Product         = itm.Product
                                                       and uom.AlternativeUnit = 'GLL'
{
  key sl.SalesDocument                                     as SalesOrder,
  key sl.SalesDocumentItem                                 as SalesOrderItem,
  key sl.ScheduleLine,

      // Organisation (used by the access control of ZOTC_SCHEDULED_ORDERS)
      itm.SalesDocumentType                                as SalesOrderType,
      itm.SalesOrganization,
      itm.DistributionChannel,
      itm.OrganizationDivision,

      // Supply
      cast( case
              when sl.ScheduleLineCategory       = 'ZT'   or sl.ScheduleLineCategory       = 'YT'
                or itm.SalesDocumentItemCategory = 'ZTAS' or itm.SalesDocumentItemCategory = 'YTAS'
                or itm.Plant = 'A999' or itm.Plant = 'A000' or itm.Plant = 'A998' or itm.Plant = 'A997'
              then 'ThirdParty'
              else 'Stock'
            end as abap.char(10) )                         as SupplyType,
      itm.SalesDocumentItemCategory                        as SalesOrderItemCategory,
      sl.ScheduleLineCategory,
      itm.Product,
      itm.HigherLevelItem,
      kit.IsKitHeader,

      // Terminal sources
      itm.ShippingPoint,
      spt.ShippingPointName,
      itm.Plant,
      pl.PlantName,
      wl.Supplier                                          as GoodsSupplierPartner,
      wls.SupplierName                                     as GoodsSupplierPartnerName,
      wls.CityName                                         as GoodsSupplierPartnerCity,
      wls.Region                                           as GoodsSupplierPartnerRegion,
      tp.PurchaseOrderGoodsSupplier,
      gss.SupplierName                                     as PurchaseOrderGoodsSupplierName,
      gss.CityName                                         as PurchaseOrderGoodsSupplierCity,
      gss.Region                                           as PurchaseOrderGoodsSupplierRgn,

      // Customer and destination (header partners, master data address)
      ag.Customer                                          as SoldToParty,
      agc.CustomerName                                     as SoldToPartyName,
      we.Customer                                          as ShipToParty,
      wec.CustomerName                                     as ShipToPartyName,
      wec.CityName                                         as ShipToCity,
      wec.Region                                           as ShipToRegion,
      wec.PostalCode                                       as ShipToPostalCode,
      wec.Country                                          as ShipToCountry,
      we.SDDocPartnerAddrIsDocSpecific                     as ShipToAddrIsDocSpecific,

      itm.IncotermsClassification,
      itm.IncotermsLocation1,

      // Date and quantities
      sl.DeliveryDate                                      as DueDate,
      @Semantics.quantity.unitOfMeasure: 'OrderQuantityUnit'
      case when cnf.ItemHasConfirmedQty = 'X'
           then sl.ConfdOrderQtyByMatlAvailCheck
           else sl.ScheduleLineOrderQuantity
      end                                                  as OpenQuantity,
      @Semantics.quantity.unitOfMeasure: 'OrderQuantityUnit'
      sl.ScheduleLineOrderQuantity                         as OrderedQuantity,
      @Semantics.quantity.unitOfMeasure: 'OrderQuantityUnit'
      sl.ConfdOrderQtyByMatlAvailCheck                     as ConfirmedQuantity,
      sl.OrderQuantityUnit,
      sl.BaseUnit,
      sl.OrderToBaseQuantityNmrtr                          as OrderToBaseQtyNumerator,
      sl.OrderToBaseQuantityDnmntr                         as OrderToBaseQtyDenominator,
      uom.QuantityNumerator                                as GallonToBaseQtyNumerator,
      // QUAN in I_ProductUnitsOfMeasure (ref. AlternativeUnit) - plain factor here
      cast( uom.QuantityDenominator as abap.dec(5,0) )     as GallonToBaseQtyDenominator,

      // Third-party purchasing
      tp.PurchaseRequisition,
      tp.PurchaseRequisitionItem,
      tp.PurchaseOrder,
      tp.PurchaseOrderItem,
      tp.PurchaseOrderType,
      tp.PoIsAssignedToSalesOrder,
      tp.HasGoodsReceipt,
      itm.OrderRelatedBillingStatus,

      // Delivery
      dlv.LastDelivery,
      dlv.OpenDelivery,
      dlv.HasDelivNotGoodsIssued,

      // TM
      tm.FreightUnit,
      tm.FreightUnitPlanningStatus,
      tm.FreightOrder,
      tm.FreightOrderPlanningStatus,
      tm.FreightOrderLifecycleStatus,
      tm.PlannedPickupDateTime
}
where
      itm.SDDocumentCategory      = 'C'
  and itm.SalesDocumentRjcnReason = ''
  // line quantity > 0 (see ZI_OTC_SCHED_CNF)
  and(
    (
          cnf.ItemHasConfirmedQty           =  'X'
      and sl.ConfdOrderQtyByMatlAvailCheck  >  0
    )
    or(
          cnf.ItemHasConfirmedQty           <> 'X'
      and sl.ScheduleLineOrderQuantity      >  0
    )
  )
  and(
    // third-party: open while not fully billed and no goods receipt
    (
      (
           sl.ScheduleLineCategory       = 'ZT'   or sl.ScheduleLineCategory       = 'YT'
        or itm.SalesDocumentItemCategory = 'ZTAS' or itm.SalesDocumentItemCategory = 'YTAS'
        or itm.Plant = 'A999' or itm.Plant = 'A000' or itm.Plant = 'A998' or itm.Plant = 'A997'
      )
      and itm.OrderRelatedBillingStatus <> 'C'
      and(
           tp.HasGoodsReceipt is null
        or tp.HasGoodsReceipt = ''
      )
    )
    // stock: open until goods issue
    or(
          sl.ScheduleLineCategory       <> 'ZT'   and sl.ScheduleLineCategory       <> 'YT'
      and itm.SalesDocumentItemCategory <> 'ZTAS' and itm.SalesDocumentItemCategory <> 'YTAS'
      and itm.Plant <> 'A999' and itm.Plant <> 'A000' and itm.Plant <> 'A998' and itm.Plant <> 'A997'
      and(
           dlv.SalesDocument                 is null
        or dlv.HasDelivNotGoodsIssued        =  'X'
        or sl.OpenConfdDelivQtyInOrdQtyUnit  >  0
        or sl.OpenReqdDelivQtyInOrdQtyUnit   >  0
      )
    )
  )
