//----------------------------------------------------------------------
// Change log
// Date       | Author              | Request    | Description
// 2026-11-17 | Srilakshmi Sreevari | DFDK908431 | Created - scheduled
//            |                     |            | orders: TM item to
//            |                     |            | SO / PO reference
//----------------------------------------------------------------------
// TABLE USE: /SCMTMS/D_TORITE is read directly because the released item
// views (I_TransportationOrderItem / I_TranspOrdItemAnalytics) only expose
// BASE_BTD_* . Once the outbound (73) or inbound (58) delivery is created,
// TM re-bases the item to the delivery and the sales order / purchase
// order survives only in ORIG_BTD_* (same logic as the BASE OR ORIG match
// in ZOTCR_009_OPERATIONAL_REP_CLS). Only product items (ITEM_CAT = PRD).
// Reference formats (checked in DFD_120):
//  SO base  114: BASE_BTD_ID = VBELN (35, zero padded),
//                BASE_BTDITEM_ID = POSNR(6) + ETENR(4), e.g. '0000100001'
//  SO orig  114: ORIG_BTDITEM_ID = POSNR (10, zero padded), no ETENR
//  PO base  001: BASE_BTDITEM_ID = EBELP + ETENR without leading zeros,
//                e.g. '100001' = item 00010, line 0001
//  PO orig  001: ORIG_BTDITEM_ID = EBELP (10, zero padded)
// RefScheduleLine '0000' = reference on item level (any schedule line).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Sched. orders: TM item ref to SO/PO'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #D, sizeCategory: #XL, dataClass: #TRANSACTIONAL }
define view entity ZI_OTC_SCHED_TMREF
  as select from /scmtms/d_torite as itm
{
  key itm.parent_key                                                                 as TransportationOrderUUID,
  key cast( 'SO' as abap.char(2) )                                                   as RefDocType,
  key cast( right( itm.base_btd_id, 10 ) as abap.char(10) )                          as RefDocument,
  key cast( substring( lpad( itm.base_btditem_id, 10, '0' ), 1, 6 ) as abap.numc(6) ) as RefSalesDocItem,
  key cast( '00000' as abap.numc(5) )                                                as RefPurchaseOrderItem,
  key cast( substring( lpad( itm.base_btditem_id, 10, '0' ), 7, 4 ) as abap.numc(4) ) as RefScheduleLine
}
where
      itm.item_cat     = 'PRD'
  and itm.base_btd_tco = '114'

union

select from /scmtms/d_torite as itm
{
  key itm.parent_key                                                                 as TransportationOrderUUID,
  key cast( 'SO' as abap.char(2) )                                                   as RefDocType,
  key cast( right( itm.orig_btd_id, 10 ) as abap.char(10) )                          as RefDocument,
  key cast( right( itm.orig_btditem_id, 6 ) as abap.numc(6) )                        as RefSalesDocItem,
  key cast( '00000' as abap.numc(5) )                                                as RefPurchaseOrderItem,
  key cast( '0000' as abap.numc(4) )                                                 as RefScheduleLine
}
where
      itm.item_cat     = 'PRD'
  and itm.orig_btd_tco = '114'

union

select from /scmtms/d_torite as itm
{
  key itm.parent_key                                                                 as TransportationOrderUUID,
  key cast( 'PO' as abap.char(2) )                                                   as RefDocType,
  key cast( right( itm.base_btd_id, 10 ) as abap.char(10) )                          as RefDocument,
  key cast( '000000' as abap.numc(6) )                                               as RefSalesDocItem,
  key cast( substring( lpad( itm.base_btditem_id, 9, '0' ), 1, 5 ) as abap.numc(5) ) as RefPurchaseOrderItem,
  key cast( '0000' as abap.numc(4) )                                                 as RefScheduleLine
}
where
      itm.item_cat     = 'PRD'
  and itm.base_btd_tco = '001'

union

select from /scmtms/d_torite as itm
{
  key itm.parent_key                                                                 as TransportationOrderUUID,
  key cast( 'PO' as abap.char(2) )                                                   as RefDocType,
  key cast( right( itm.orig_btd_id, 10 ) as abap.char(10) )                          as RefDocument,
  key cast( '000000' as abap.numc(6) )                                               as RefSalesDocItem,
  key cast( right( itm.orig_btditem_id, 5 ) as abap.numc(5) )                        as RefPurchaseOrderItem,
  key cast( '0000' as abap.numc(4) )                                                 as RefScheduleLine
}
where
      itm.item_cat     = 'PRD'
  and itm.orig_btd_tco = '001'
