//----------------------------------------------------------------------
// Change log
// Date       | Author              | Request    | Description
// 2026-11-17 | Srilakshmi Sreevari | DFDK908431 | Created - scheduled
//            |                     |            | orders: TM freight
//            |                     |            | unit / order per SO
//            |                     |            | schedule line
//----------------------------------------------------------------------
// Link (as in ZOTCR_009_OPERATIONAL_REP_CLS, base OR orig reference):
//  - stock: TM item references the sales order (BTD TCO 114), on
//    schedule line level (base) or item level (orig, after delivery);
//  - third-party: TM item references the PO (BTD TCO 001), only when the
//    PO is account-assigned to this sales order (EKKN) - inbound STO
//    POs (ZIB1) also have freight orders and must not match.
// Root data from released I_TransportationOrderAnalytics: only freight
// units (FU) and freight orders (TO); tender copies (TC) and canceled
// documents (lifecycle 10) excluded. Grouped to one row per schedule
// line (one FU / one FO at most, highest number wins).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Sched. orders: TM docs per sched. line'
@ObjectModel.usageType: { serviceQuality: #D, sizeCategory: #XL, dataClass: #TRANSACTIONAL }
define view entity ZI_OTC_SCHED_TM
  as select from    I_SalesDocumentScheduleLine    as sl
    left outer join ZI_OTC_SCHED_3P                as tp   on  tp.SalesDocument     = sl.SalesDocument
                                                           and tp.SalesDocumentItem = sl.SalesDocumentItem
                                                           and tp.ScheduleLine      = sl.ScheduleLine
    inner join      ZI_OTC_SCHED_TMREF             as ref  on(
                                                             ref.RefDocType           = 'SO'
                                                             and ref.RefDocument      = sl.SalesDocument
                                                             and ref.RefSalesDocItem  = sl.SalesDocumentItem
                                                             and(
                                                               ref.RefScheduleLine    = sl.ScheduleLine
                                                               or ref.RefScheduleLine = '0000'
                                                             )
                                                           )
                                                           or(
                                                             ref.RefDocType               = 'PO'
                                                             and ref.RefDocument          = tp.PurchaseOrder
                                                             and ref.RefPurchaseOrderItem = tp.PurchaseOrderItem
                                                             and tp.PoIsAssignedToSalesOrder = 'X'
                                                           )
    inner join      I_TransportationOrderAnalytics as tor  on  tor.TransportationOrderUUID = ref.TransportationOrderUUID
    left outer join ZI_OTC_SCHED_TMPICK            as pick on  pick.TransportationOrderUUID = tor.TransportationOrderUUID
{
  key sl.SalesDocument,
  key sl.SalesDocumentItem,
  key sl.ScheduleLine,
      max( case when tor.TransportationOrderCategory = 'FU' then tor.TransportationOrder end )      as FreightUnit,
      max( case when tor.TransportationOrderCategory = 'FU' then tor.TranspOrdPlanningStatus end )  as FreightUnitPlanningStatus,
      max( case when tor.TransportationOrderCategory = 'TO' then tor.TransportationOrder end )      as FreightOrder,
      max( case when tor.TransportationOrderCategory = 'TO' then tor.TranspOrdPlanningStatus end )  as FreightOrderPlanningStatus,
      max( case when tor.TransportationOrderCategory = 'TO' then tor.TranspOrdLifeCycleStatus end ) as FreightOrderLifecycleStatus,
      min( case when tor.TransportationOrderCategory = 'TO' then pick.PlannedPickupDateTime end )   as PlannedPickupDateTime
}
where
  (
       tor.TransportationOrderCategory = 'FU'
    or tor.TransportationOrderCategory = 'TO'
  )
  and  tor.TranspOrdLifeCycleStatus    <> '10'
group by
  sl.SalesDocument,
  sl.SalesDocumentItem,
  sl.ScheduleLine
