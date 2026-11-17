//----------------------------------------------------------------------
// Change log
// Date       | Author              | Request    | Description
// 2026-11-17 | Srilakshmi Sreevari | DFDK908431 | Created - scheduled
//            |                     |            | orders: net goods
//            |                     |            | receipt per PO item
//----------------------------------------------------------------------
// Goods receipts on the third-party PO (EKBE VGABE = '1', BWART 101/109).
// Reversals 102/110 (credit 'H') are netted so that a reversed GR does
// not close the sales order line.
// Source: released view I_PurchaseOrderHistoryAPI01
// (PurchasingHistoryDocumentType = EKBE-VGABE).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Sched. orders: net GR per PO item'
@ObjectModel.usageType: { serviceQuality: #C, sizeCategory: #XL, dataClass: #TRANSACTIONAL }
define view entity ZI_OTC_SCHED_POGR
  as select from I_PurchaseOrderHistoryAPI01 as hist
{
  key hist.PurchaseOrder,
  key hist.PurchaseOrderItem,
      sum( case hist.DebitCreditCode
             when 'H' then cast( 0 as abap.dec(15,3) ) - cast( hist.Quantity as abap.dec(15,3) )
             else cast( hist.Quantity as abap.dec(15,3) )
           end )                                  as NetGoodsReceiptQty
}
where
       hist.PurchasingHistoryDocumentType = '1'
  and(
       hist.GoodsMovementType             = '101'
    or hist.GoodsMovementType             = '102'
    or hist.GoodsMovementType             = '109'
    or hist.GoodsMovementType             = '110'
  )
group by
  hist.PurchaseOrder,
  hist.PurchaseOrderItem
