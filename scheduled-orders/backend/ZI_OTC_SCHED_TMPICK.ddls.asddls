//----------------------------------------------------------------------
// Change log
// Date       | Author              | Request    | Description
// 2026-11-17 | Srilakshmi Sreevari | DFDK908431 | Created - scheduled
//            |                     |            | orders: planned pickup
//            |                     |            | per TM document
//----------------------------------------------------------------------
// Planned pickup = earliest outbound stop (STOP_CAT = 'O') planned
// transportation time (/SCMTMS/D_TORSTP-PLAN_TRANS_TIME, UTC timestamp).
// Source: released view I_TranspOrdStopAnalytics.
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Sched. orders: planned pickup per TOR'
@ObjectModel.usageType: { serviceQuality: #D, sizeCategory: #XL, dataClass: #TRANSACTIONAL }
define view entity ZI_OTC_SCHED_TMPICK
  as select from I_TranspOrdStopAnalytics as stp
{
  key stp.TransportationOrderUUID,
      min( stp.TranspOrdStopPlanTranspDteTme ) as PlannedPickupDateTime
}
where
      stp.TranspOrdStopCategory         = 'O'
  and stp.TranspOrdStopPlanTranspDteTme > 0
group by
  stp.TransportationOrderUUID
