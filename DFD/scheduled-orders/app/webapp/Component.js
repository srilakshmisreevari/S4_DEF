sap.ui.define(["sap/fe/core/AppComponent"], function (AppComponent) {
  "use strict";

  // Fiori Elements V4 Analytical List Page on service ZUI_OTC_SCHEDULED_ORDERS_O4.
  // Layout (charts, columns, filters, default "Next 7 days") comes from the
  // CDS metadata extensions in DFD; this app only wires the pages together.
  return AppComponent.extend("zotc.schedorders.Component", {
    metadata: { manifest: "json" }
  });
});
