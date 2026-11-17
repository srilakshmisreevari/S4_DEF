//----------------------------------------------------------------------
// Change log
// Date       | Author              | Request    | Description
// 2026-11-17 | Srilakshmi Sreevari | DFDK908431 | Created - scheduled
//            |                     |            | orders: outbound
//            |                     |            | delivery status per
//            |                     |            | sales order item
//----------------------------------------------------------------------
// Stock lines stay open until goods issue: a delivery item with goods
// movement status (LIPS-WBSTA) A or B means "delivery created, not
// loaded". Blank WBSTA (not relevant for goods movement) is not treated
// as open. Source: released view I_DeliveryDocumentItem
// (ReferenceSDDocument/Item = LIPS-VGBEL/VGPOS, category C = order).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Sched. orders: delivery per SO item'
@ObjectModel.usageType: { serviceQuality: #C, sizeCategory: #XL, dataClass: #TRANSACTIONAL }
define view entity ZI_OTC_SCHED_DLV
  as select from I_DeliveryDocumentItem as di
{
  key di.ReferenceSDDocument                     as SalesDocument,
  key di.ReferenceSDDocumentItem                 as SalesDocumentItem,
      max( di.DeliveryDocument )                 as LastDelivery,
      max( case when di.GoodsMovementStatus = 'A' or di.GoodsMovementStatus = 'B'
                then di.DeliveryDocument end )   as OpenDelivery,
      max( case when di.GoodsMovementStatus = 'A' or di.GoodsMovementStatus = 'B'
                then 'X' else '' end )           as HasDelivNotGoodsIssued
}
where
  di.ReferenceSDDocumentCategory = 'C'
group by
  di.ReferenceSDDocument,
  di.ReferenceSDDocumentItem
