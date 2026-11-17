sap.ui.define([
  "sap/ui/core/format/DateFormat",
  "sap/ui/core/library"
], function (DateFormat, coreLibrary) {
  "use strict";

  var IconColor = coreLibrary.IconColor;
  var ValueState = coreLibrary.ValueState;
  var oDateTimeFormat = DateFormat.getDateTimeInstance({ style: "medium" });
  var oDateFormat = DateFormat.getDateInstance({ style: "medium" });

  return {
    /** Tree icon per node type */
    nodeIcon: function (sType) {
      switch (sType) {
        case "CA": return "sap-icon://course-book";
        case "FO": return "sap-icon://folder-blank";
        case "DT": return "sap-icon://table-view";
        case "LI": return "sap-icon://chain-link";
        case "PH": return "sap-icon://pending";
        default:   return "sap-icon://document";
      }
    },

    /** Status square colour: 3 = active (green), 2 = inactive (orange) */
    statusColor: function (iCriticality) {
      switch (Number(iCriticality)) {
        case 3: return IconColor.Positive;
        case 2: return IconColor.Critical;
        case 1: return IconColor.Negative;
        default: return IconColor.Neutral;
      }
    },

    valueState: function (iCriticality) {
      switch (Number(iCriticality)) {
        case 3: return ValueState.Success;
        case 2: return ValueState.Warning;
        case 1: return ValueState.Error;
        default: return ValueState.None;
      }
    },

    /** Edm.Date ("2024-01-31") + Edm.TimeOfDay ("13:05:00") -> locale text */
    dateTime: function (sDate, sTime) {
      if (!sDate) {
        return "";
      }
      var oDate = new Date(sDate + "T" + (sTime || "00:00:00"));
      if (isNaN(oDate.getTime())) {
        return sDate;
      }
      return sTime ? oDateTimeFormat.format(oDate) : oDateFormat.format(oDate);
    },

    /** True when the cell text contains the "Find" term (case-insensitive) */
    isFindHit: function (sValue, sTerm) {
      return !!(sTerm && sValue && String(sValue).toLowerCase().indexOf(String(sTerm).toLowerCase()) !== -1);
    }
  };
});
