//----------------------------------------------------------------------
// Change log
// Date       | Author              | Request    | Description
// 2026-11-17 | Srilakshmi Sreevari | DFDK908431 | Created - summary of
//            |                     |            | scheduled order lines per
//            |                     |            | terminal / customer /
//            |                     |            | ship-to for the analytical
//            |                     |            | list page (charts, table)
// 2026-11-17 | Srilakshmi Sreevari | DFDK908431 | Sales area (order type,
//            |                     |            | sales org, distribution
//            |                     |            | channel, division) added
//            |                     |            | to keys, GROUP BY and
//            |                     |            | _Orders for exact DCL
//            |                     |            | ZC_OTC_SCHED_TERMINAL_SUM
//----------------------------------------------------------------------
// >>> 2026-11-17 Srilakshmi Sreevari DFDK908431 - sales area
// (old) One row per SupplyType / terminal / sold-to / ship-to / status bucket /
// (old) order unit / due window (on ZOTC_SCHEDULED_ORDERS).
// One row per SupplyType / terminal / sold-to / ship-to / status bucket /
// order unit / due window / order type / sales area
// (on ZOTC_SCHEDULED_ORDERS).
// <<< 2026-11-17 Srilakshmi Sreevari DFDK908431
// Measures (@Aggregation.default #SUM for OData V4 $apply):
//  - NumberOfOrders = distinct sales orders within the row; summing it
//    over rows counts an order once per row it appears in;
//  - NumberOfLines  = schedule lines;
//  - OpenQuantity in OrderQuantityUnit - never total it across units;
//  - QuantityInGallons in GLL (lines without conversion are ignored).
// _Orders: the order lines of the row.
// UI annotations and labels: metadata extension ZC_OTC_SCHED_TERMINAL_SUM.
// >>> 2026-11-17 Srilakshmi Sreevari DFDK908431 - sales area
// (old) Authorization: no access control of its own yet - the order lines
// (old) read via _Orders are protected by DCL ZOTC_SCHEDULED_ORDERS.
// Authorization: DCL ZC_OTC_SCHED_TERMINAL_SUM on the sales area fields
// (V_VBAK_AAT, V_VBAK_VKO, ACTVT 03); the order lines read via _Orders
// are protected by DCL ZOTC_SCHEDULED_ORDERS.
// <<< 2026-11-17 Srilakshmi Sreevari DFDK908431
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Scheduled orders summary by terminal'
@Metadata.allowExtensions: true
@ObjectModel.usageType: { serviceQuality: #D, sizeCategory: #L, dataClass: #TRANSACTIONAL }
define view entity ZC_OTC_SCHED_TERMINAL_SUM
  as select from ZOTC_SCHEDULED_ORDERS as o
  association [0..*] to ZOTC_SCHEDULED_ORDERS as _Orders on  $projection.SupplyType        = _Orders.SupplyType
                                                         and $projection.TerminalID        = _Orders.TerminalID
                                                         and $projection.SoldToParty       = _Orders.SoldToParty
                                                         and $projection.ShipToParty       = _Orders.ShipToParty
                                                         and $projection.StatusBucket      = _Orders.StatusBucket
                                                         and $projection.OrderQuantityUnit = _Orders.OrderQuantityUnit
                                                         and $projection.DueWindow         = _Orders.DueWindow
                                                         // >>> 2026-11-17 Srilakshmi Sreevari DFDK908431 - sales area
                                                         and $projection.SalesOrderType       = _Orders.SalesOrderType
                                                         and $projection.SalesOrganization    = _Orders.SalesOrganization
                                                         and $projection.DistributionChannel  = _Orders.DistributionChannel
                                                         and $projection.OrganizationDivision = _Orders.OrganizationDivision
                                                         // <<< 2026-11-17 Srilakshmi Sreevari DFDK908431
{
      // Keys = grouping identifiers (TerminalName, customer name and the
      // ship-to address depend on them)
  key o.SupplyType,
      @ObjectModel.text.element: ['TerminalName']
  key o.TerminalID,
      @ObjectModel.text.element: ['SoldToPartyName']
  key cast( coalesce( o.SoldToParty, '' ) as kunnr )       as SoldToParty,
      @ObjectModel.text.element: ['ShipToPartyName']
  key cast( coalesce( o.ShipToParty, '' ) as kunnr )       as ShipToParty,
  key o.StatusBucket,
  key o.DueWindow,
  key o.OrderQuantityUnit,
      // >>> 2026-11-17 Srilakshmi Sreevari DFDK908431 - sales area (DCL)
  key o.SalesOrderType,
  key o.SalesOrganization,
  key o.DistributionChannel,
  key o.OrganizationDivision,
      // <<< 2026-11-17 Srilakshmi Sreevari DFDK908431

      cast( coalesce( o.TerminalName, '' ) as abap.char(80) ) as TerminalName,
      o.SoldToPartyName,
      o.ShipToPartyName,
      o.ShipToCity,
      o.ShipToRegion,
      // Destination = 'City, Region'
      cast( case
              when o.ShipToCity is null or o.ShipToCity = ''
                then cast( coalesce( o.ShipToRegion, '' ) as abap.char(50) )
              else cast( concat_with_space( concat( o.ShipToCity, ',' ),
                                            coalesce( o.ShipToRegion, '' ), 1 ) as abap.char(50) )
            end as abap.char(50) )                         as Destination,
      o.GallonUnit,

      // Measures
      @Aggregation.default: #SUM
      count( distinct o.SalesOrder )                       as NumberOfOrders,
      @Aggregation.default: #SUM
      count( * )                                           as NumberOfLines,
      @Aggregation.default: #SUM
      @Semantics.quantity.unitOfMeasure: 'OrderQuantityUnit'
      sum( o.OpenQuantity )                                as OpenQuantity,
      @Aggregation.default: #SUM
      @Semantics.quantity.unitOfMeasure: 'GallonUnit'
      sum( o.QuantityInGallons )                           as QuantityInGallons,

      _Orders
}
group by
  o.SupplyType,
  o.TerminalID,
  o.TerminalName,
  o.SoldToParty,
  o.SoldToPartyName,
  o.ShipToParty,
  o.ShipToPartyName,
  o.ShipToCity,
  o.ShipToRegion,
  o.StatusBucket,
  o.OrderQuantityUnit,
  o.DueWindow,
  o.GallonUnit,
  // >>> 2026-11-17 Srilakshmi Sreevari DFDK908431 - sales area
  o.SalesOrderType,
  o.SalesOrganization,
  o.DistributionChannel,
  o.OrganizationDivision
  // <<< 2026-11-17 Srilakshmi Sreevari DFDK908431
