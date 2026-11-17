//----------------------------------------------------------------------
// Change log
// Date       | Author              | Request    | Description
// 2026-11-17 | Srilakshmi Sreevari | DFDK908431 | Created - scheduled
//            |                     |            | orders: kit header
//            |                     |            | indicator (items that
//            |                     |            | have sub-items)
//----------------------------------------------------------------------
// Kit header and components both carry quantity. An item is a kit header
// when another item of the same order points to it via HigherLevelItem
// (VBAP-UEPOS). Source: released view I_SalesDocumentItem.
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Sched. orders: kit header items'
@ObjectModel.usageType: { serviceQuality: #C, sizeCategory: #XL, dataClass: #TRANSACTIONAL }
define view entity ZI_OTC_SCHED_KIT
  as select from I_SalesDocumentItem as itm
{
  key itm.SalesDocument,
  key itm.HigherLevelItem                         as SalesDocumentItem,
      max( cast( 'X' as abap.char(1) ) )          as IsKitHeader
}
where
  itm.HigherLevelItem <> '000000'
group by
  itm.SalesDocument,
  itm.HigherLevelItem
