//----------------------------------------------------------------------
// Change log
// Date       | Author              | Request    | Description
// 2026-11-17 | Srilakshmi Sreevari | DFDK908431 | Created - scheduled
//            |                     |            | orders: flags SO items
//            |                     |            | that have any confirmed
//            |                     |            | schedule line quantity
//----------------------------------------------------------------------
// Purpose: stock items split into a requested line (WMENG > 0, BMENG = 0)
// and confirmed line(s) (WMENG = 0, BMENG > 0). To avoid double counting,
// ZI_OTC_SCHED_LINE takes BMENG when the item has any confirmation and
// WMENG otherwise (third-party ZT/YT lines copy WMENG into BMENG).
// Source: released view I_SalesDocumentScheduleLine.
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Sched. orders: item confirmed flag'
@ObjectModel.usageType: { serviceQuality: #C, sizeCategory: #XL, dataClass: #TRANSACTIONAL }
define view entity ZI_OTC_SCHED_CNF
  as select from I_SalesDocumentScheduleLine as sl
{
  key sl.SalesDocument,
  key sl.SalesDocumentItem,
      max( case when sl.ConfdOrderQtyByMatlAvailCheck > 0 then 'X' else '' end ) as ItemHasConfirmedQty
}
group by
  sl.SalesDocument,
  sl.SalesDocumentItem
