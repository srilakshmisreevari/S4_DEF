//----------------------------------------------------------------------
// Change log
// Date       | Author              | Request    | Description
// 2026-11-17 | Srilakshmi Sreevari | DFDK908431 | Created - scheduled
//            |                     |            | orders: third-party
//            |                     |            | chain SO line -> PR ->
//            |                     |            | PO -> EKKN -> GR
//----------------------------------------------------------------------
// Chain: VBEP-BANFN/BNFPO -> EBAN-EBELN/EBELP -> EKKO/EKPO (LLIEF goods
// supplier) and EKKN (VBELN/VBELP) back to the sales order.
// All released views: I_SalesDocumentScheduleLine,
// I_PurchaseRequisitionItemAPI01, I_PurchaseOrderItemAPI01,
// I_PurchaseOrderAPI01 (SupplyingSupplier = EKKO-LLIEF),
// I_PurOrdAccountAssignmentAPI01; GR from ZI_OTC_SCHED_POGR.
// Deleted PO items are ignored. Grouped because a PO item can have more
// than one account assignment line.
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Sched. orders: 3rd-party PR/PO/GR'
@ObjectModel.usageType: { serviceQuality: #C, sizeCategory: #XL, dataClass: #TRANSACTIONAL }
define view entity ZI_OTC_SCHED_3P
  as select from    I_SalesDocumentScheduleLine    as sl
    inner join      I_PurchaseRequisitionItemAPI01 as pr  on  pr.PurchaseRequisition     = sl.PurchaseRequisition
                                                          and pr.PurchaseRequisitionItem = sl.PurchaseRequisitionItem
    left outer join I_PurchaseOrderItemAPI01       as poi on  poi.PurchaseOrder                  = pr.PurchasingDocument
                                                          and poi.PurchaseOrderItem              = pr.PurchasingDocumentItem
                                                          and poi.PurchasingDocumentDeletionCode = ''
    left outer join I_PurchaseOrderAPI01           as po  on  po.PurchaseOrder = poi.PurchaseOrder
    left outer join I_PurOrdAccountAssignmentAPI01 as aa  on  aa.PurchaseOrder     = poi.PurchaseOrder
                                                          and aa.PurchaseOrderItem = poi.PurchaseOrderItem
                                                          and aa.SalesOrder        = sl.SalesDocument
                                                          and aa.SalesOrderItem    = sl.SalesDocumentItem
                                                          and aa.IsDeleted         = ''
    left outer join ZI_OTC_SCHED_POGR              as gr  on  gr.PurchaseOrder     = poi.PurchaseOrder
                                                          and gr.PurchaseOrderItem = poi.PurchaseOrderItem
{
  key sl.SalesDocument,
  key sl.SalesDocumentItem,
  key sl.ScheduleLine,
      sl.PurchaseRequisition,
      sl.PurchaseRequisitionItem,
      poi.PurchaseOrder,
      poi.PurchaseOrderItem,
      po.PurchaseOrderType,
      po.Supplier                                                           as PurchaseOrderSupplier,
      po.SupplyingSupplier                                                  as PurchaseOrderGoodsSupplier,
      max( case when aa.PurchaseOrder is not null then 'X' else '' end )   as PoIsAssignedToSalesOrder,
      max( case when gr.NetGoodsReceiptQty > 0 then 'X' else '' end )      as HasGoodsReceipt
}
where
  sl.PurchaseRequisition <> ''
group by
  sl.SalesDocument,
  sl.SalesDocumentItem,
  sl.ScheduleLine,
  sl.PurchaseRequisition,
  sl.PurchaseRequisitionItem,
  poi.PurchaseOrder,
  poi.PurchaseOrderItem,
  po.PurchaseOrderType,
  po.Supplier,
  po.SupplyingSupplier
