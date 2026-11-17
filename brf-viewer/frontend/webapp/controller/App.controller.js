sap.ui.define([
  "sap/ui/core/mvc/Controller",
  "sap/ui/model/json/JSONModel",
  "sap/ui/model/Filter",
  "sap/ui/model/FilterOperator",
  "sap/ui/model/Sorter",
  "sap/ui/Device",
  "sap/m/Column",
  "sap/m/ColumnListItem",
  "sap/m/Text",
  "sap/m/ObjectStatus",
  "sap/m/MultiInput",
  "sap/m/Token",
  "sap/m/Input",
  "sap/m/HBox",
  "sap/m/SearchField",
  "sap/m/Dialog",
  "sap/m/Button",
  "sap/m/Label",
  "sap/m/MessageToast",
  "sap/m/MessageBox",
  "sap/m/ViewSettingsDialog",
  "sap/m/ViewSettingsItem",
  "sap/m/p13n/Popup",
  "sap/m/p13n/SelectionPanel",
  "sap/ui/comp/filterbar/FilterGroupItem",
  "sap/ui/core/Item",
  "sap/ui/core/util/File",
  "../model/formatter"
], function (Controller, JSONModel, Filter, FilterOperator, Sorter, Device,
             Column, ColumnListItem, Text, ObjectStatus, MultiInput, Token, Input, HBox,
             SearchField, Dialog, Button, Label, MessageToast, MessageBox,
             ViewSettingsDialog, ViewSettingsItem, P13nPopup, SelectionPanel,
             FilterGroupItem, Item, File, formatter) {
  "use strict";

  var STANDARD_VARIANT = "standard";
  var FB_GROUP = "__$INTERNAL$";
  var SEARCH_ITEM = "__search";

  return Controller.extend("zbrf.viewer.controller.App", {
    formatter: formatter,

    /* =========================================================== */
    /* Lifecycle                                                   */
    /* =========================================================== */

    onInit: function () {
      this.getView().setModel(new JSONModel({
        layout: Device.system.phone ? "OneColumn" : "TwoColumnsBeginExpanded",
        mode: "none",            // none | folder | dt
        treeBusy: false,
        dtBusy: false,
        selected: {},
        tableTitle: "",
        findTerm: "",
        variants: [],
        variantKey: STANDARD_VARIANT
      }), "view");
      this.getView().setModel(new JSONModel({ nodes: [] }), "tree");
      this.getView().setModel(new JSONModel({}), "dt");

      this.getView().addStyleClass(this.getOwnerComponent().getContentDensityClass());

      this._oCatalogs = {};     // CatalogId -> { root, loaded, promise }
      this._aColumns = [];      // column metadata of the open decision table
      this._aHidden = [];       // slots hidden through Table Settings
      this._aSorters = [];      // sorters from the sort/group dialog
      this._mFilterCtrls = {};  // slot -> { multi | from/to }
      this._iFindIndex = -1;

      this._loadRoots();
    },

    _text: function (sKey, aArgs) {
      return this.getOwnerComponent().getModel("i18n").getResourceBundle().getText(sKey, aArgs);
    },

    _view: function () {
      return this.getView().getModel("view");
    },

    /** Read a whole entity set once (no binding to a control) */
    _readList: function (sPath, aFilters, mParameters, aSorters) {
      var oBinding = this.getView().getModel().bindList(sPath, undefined, aSorters || [], aFilters || [], mParameters);
      return oBinding.requestContexts(0, Infinity).then(function (aContexts) {
        return aContexts.map(function (oCtx) { return oCtx.getObject(); });
      });
    },

    _showError: function (oError) {
      this._view().setProperty("/treeBusy", false);
      this._view().setProperty("/dtBusy", false);
      MessageBox.error((oError && oError.message) || this._text("genericError"));
    },

    /* =========================================================== */
    /* Catalog tree                                                */
    /* =========================================================== */

    _loadRoots: function () {
      var oViewModel = this._view();
      oViewModel.setProperty("/treeBusy", true);
      this._oCatalogs = {};

      return this._readList("/CatalogTree", [new Filter("ParentNodeId", FilterOperator.EQ, "")])
        .then(function (aRoots) {
          aRoots.sort(function (a, b) { return a.Seqnr - b.Seqnr; });
          aRoots.forEach(function (oRoot) {
            oRoot.children = oRoot.ChildCount > 0 ? [this._placeholder()] : [];
            this._oCatalogs[oRoot.CatalogId] = { root: oRoot, loaded: false, promise: null };
          }.bind(this));
          this.getView().getModel("tree").setData({ nodes: aRoots });
          oViewModel.setProperty("/treeBusy", false);
        }.bind(this))
        .catch(this._showError.bind(this));
    },

    _placeholder: function () {
      return { Name: this._text("loading"), NodeType: "PH", _placeholder: true, children: [] };
    },

    /** Load one catalog completely and hang its nodes under the root */
    _loadCatalog: function (sCatalogId) {
      var oEntry = this._oCatalogs[sCatalogId];
      if (!oEntry) {
        return Promise.resolve();
      }
      if (oEntry.loaded) {
        return Promise.resolve(oEntry.root);
      }
      if (oEntry.promise) {
        return oEntry.promise;
      }

      oEntry.promise = this._readList("/CatalogTree", [new Filter("CatalogId", FilterOperator.EQ, sCatalogId)])
        .then(function (aNodes) {
          var mById = {};
          aNodes.forEach(function (oNode) { oNode.children = []; mById[oNode.NodeId] = oNode; });
          var aTop = [];
          aNodes.forEach(function (oNode) {
            if (oNode.NodeType === "CA") {
              return;  // the root itself
            }
            var oParent = mById[oNode.ParentNodeId];
            if (oParent && oParent.NodeType !== "CA") {
              oParent.children.push(oNode);
            } else {
              aTop.push(oNode);
            }
          });
          var fnSort = function (aList) {
            aList.sort(function (a, b) { return a.Seqnr - b.Seqnr; });
            aList.forEach(function (o) { fnSort(o.children); });
          };
          fnSort(aTop);

          oEntry.root.children = aTop;
          oEntry.loaded = true;
          this.getView().getModel("tree").refresh(true);
          return oEntry.root;
        }.bind(this))
        .catch(function (oError) {
          oEntry.promise = null;
          throw oError;
        });
      return oEntry.promise;
    },

    _loadAllCatalogs: function () {
      this._view().setProperty("/treeBusy", true);
      return Promise.all(Object.keys(this._oCatalogs).map(this._loadCatalog.bind(this)))
        .then(function () { this._view().setProperty("/treeBusy", false); }.bind(this))
        .catch(this._showError.bind(this));
    },

    onTreeToggle: function (oEvent) {
      if (!oEvent.getParameter("expanded")) {
        return;
      }
      var oNode = oEvent.getParameter("rowContext").getObject();
      if (oNode.NodeType === "CA") {
        this._loadCatalog(oNode.CatalogId).catch(this._showError.bind(this));
      }
    },

    onExpandAll: function () {
      var oTree = this.byId("treeTable");
      this._loadAllCatalogs().then(function () { oTree.expandToLevel(20); });
    },

    onCollapseAll: function () {
      this.byId("treeTable").collapseAll();
    },

    onRefreshTree: function () {
      this.byId("treeTable").clearSelection();
      this.byId("treeSearch").setValue("");
      this._loadRoots();
    },

    onTreeSearchLive: function (oEvent) {
      if (!oEvent.getParameter("newValue")) {
        this._filterTree("");
      }
    },

    onTreeSearch: function (oEvent) {
      this._filterTree(oEvent.getParameter("query") || "");
    },

    _filterTree: function (sQuery) {
      var oTree = this.byId("treeTable");
      var oBinding = oTree.getBinding("rows");
      if (!sQuery) {
        oBinding.filter([]);
        return;
      }
      // Search needs the whole tree, so load every catalog first
      this._loadAllCatalogs().then(function () {
        oBinding.filter(new Filter({
          filters: [
            new Filter("Name", FilterOperator.Contains, sQuery),
            new Filter("Description", FilterOperator.Contains, sQuery)
          ],
          and: false
        }));
        oTree.expandToLevel(20);
      });
    },

    onTreeSelect: function () {
      var oTree = this.byId("treeTable");
      var iIndex = oTree.getSelectedIndex();
      if (iIndex < 0) {
        return;
      }
      var oContext = oTree.getContextByIndex(iIndex);
      var oNode = oContext && oContext.getObject();
      if (!oNode || oNode._placeholder) {
        return;
      }
      this._showNode(oNode);
    },

    onChildPress: function (oEvent) {
      var oNode = oEvent.getSource().getBindingContext("view").getObject();
      if (oNode.NodeType === "DT") {
        this._showNode(oNode);
      }
    },

    _showNode: function (oNode) {
      var oViewModel = this._view();
      oViewModel.setProperty("/layout", Device.system.phone ? "MidColumnFullScreen" : "TwoColumnsMidExpanded");

      if (oNode.NodeType === "DT") {
        this._openDecisionTable(oNode);
        return;
      }

      // Catalog or folder: summary and child list, no table content
      var fnShow = function () {
        oViewModel.setProperty("/selected", Object.assign({}, oNode, {
          children: (oNode.children || []).filter(function (o) { return !o._placeholder; })
        }));
        oViewModel.setProperty("/mode", "folder");
      };
      if (oNode.NodeType === "CA") {
        this._loadCatalog(oNode.CatalogId).then(fnShow).catch(this._showError.bind(this));
      } else {
        fnShow();
      }
    },

    onNavBack: function () {
      this._view().setProperty("/layout", "OneColumn");
    },

    /* =========================================================== */
    /* Decision table                                              */
    /* =========================================================== */

    _openDecisionTable: function (oNode) {
      var oViewModel = this._view();
      var sId = oNode.ObjectId;
      this._sDtId = sId;
      this._aHidden = [];
      this._aSorters = [];
      this._iFindIndex = -1;

      oViewModel.setProperty("/selected", oNode);
      oViewModel.setProperty("/mode", "dt");
      oViewModel.setProperty("/dtBusy", true);
      oViewModel.setProperty("/findTerm", "");

      var oModel = this.getView().getModel();
      var pHeader = oModel.bindContext("/DecisionTable('" + encodeURIComponent(sId) + "')").requestObject();
      var pColumns = this._readList("/DecisionTableMeta",
        [new Filter("DecisionTableId", FilterOperator.EQ, sId)], undefined, [new Sorter("ColumnNo")]);

      return Promise.all([pHeader, pColumns]).then(function (aResult) {
        if (this._sDtId !== sId) {
          return;  // user already selected another table
        }
        this.getView().getModel("dt").setData(aResult[0] || {});
        this._aColumns = aResult[1];
        this._buildFilterBar();
        this._loadVariants();
        this._buildTable();
        oViewModel.setProperty("/dtBusy", false);
      }.bind(this)).catch(this._showError.bind(this));
    },

    formatDtTitle: function (sName, sDescription) {
      if (!sName) {
        return "";
      }
      return this._text("dtTitle", [sName]) + (sDescription ? ", " + sDescription : "");
    },

    formatNodeTypeText: function (sType) {
      return sType ? this._text("nodeType_" + sType) : "";
    },

    formatStatusText: function (sStatus) {
      return sStatus === "A" ? this._text("statusActive") : (sStatus === "I" ? this._text("statusInactive") : "");
    },

    formatYesNo: function (bValue) {
      return this._text(bValue ? "yes" : "no");
    },

    _visibleColumns: function () {
      var aHidden = this._aHidden;
      return this._aColumns.filter(function (c) { return aHidden.indexOf(c.Slot) === -1; });
    },

    /** Columns and cells are generated from DecisionTableMeta */
    _buildTable: function () {
      var oTable = this.byId("contentTable");
      var aCols = this._visibleColumns();
      var aCells = [];

      oTable.unbindItems();
      oTable.destroyColumns();

      oTable.addColumn(new Column({
        width: "4rem",
        header: new Text({ text: this._text("rowNo") })
      }));
      aCells.push(new Text({ text: "{RowNo}" }));

      aCols.forEach(function (oCol, i) {
        oTable.addColumn(new Column({
          header: new Text({
            text: oCol.ColumnLabel || oCol.ColumnName,
            tooltip: oCol.ColumnName + (oCol.DataElement ? " (" + oCol.DataElement + ")" : "") +
              (oCol.IsResult ? " - " + this._text("resultColumn") : "")
          }),
          importance: i < 3 ? "High" : "Medium",
          styleClass: oCol.IsResult ? "brfResultColumn" : ""
        }));

        var oCell = new ObjectStatus({
          text: "{" + oCol.Slot + "}",
          tooltip: "{" + oCol.Slot + "}",
          inverted: { parts: [oCol.Slot, "view>/findTerm"], formatter: formatter.isFindHit },
          state: {
            parts: [oCol.Slot, "view>/findTerm"],
            formatter: function (sValue, sTerm) {
              return formatter.isFindHit(sValue, sTerm) ? "Warning" : "None";
            }
          }
        });
        oCell.addStyleClass(oCol.IsResult ? "brfCell brfResultCell" : "brfCell");
        aCells.push(oCell);
      }, this);

      oTable.bindItems({
        path: "/DecisionTableContent",
        template: new ColumnListItem({ cells: aCells }),
        templateShareable: false,
        filters: this._collectFilters(),
        sorter: this._aSorters,
        parameters: this._collectParameters()
      });
    },

    onTableUpdated: function (oEvent) {
      var oBinding = this.byId("contentTable").getBinding("items");
      var iCount = oBinding && oBinding.getCount ? oBinding.getCount() : oEvent.getParameter("total");
      this._view().setProperty("/tableTitle", this._text("tableTitleCount", [iCount === undefined ? "…" : iCount]));
      this._highlightFindCurrent();
    },

    onRefreshTable: function () {
      if (this._sDtId) {
        this._openDecisionTable(this._view().getProperty("/selected"));
      }
    },

    /* =========================================================== */
    /* Filter bar                                                  */
    /* =========================================================== */

    _isRangeColumn: function (oCol) {
      // LOW/HIGH style columns and numeric/date elements get a from-to range
      return /(^|_)(LOW|HIGH|FROM|TO)$/i.test(oCol.ColumnName) ||
        ["N", "D", "A", "Q"].indexOf(oCol.DataType) !== -1;
    },

    _buildFilterBar: function () {
      var oFilterBar = this.byId("filterBar");
      oFilterBar.destroyFilterGroupItems();
      this._mFilterCtrls = {};

      // Free text over all columns ($search)
      this._oSearchField = new SearchField({
        placeholder: this._text("freeTextSearch"),
        search: this.onFilterGo.bind(this)
      });
      oFilterBar.addFilterGroupItem(new FilterGroupItem({
        groupName: FB_GROUP, name: SEARCH_ITEM, label: this._text("freeTextSearch"),
        visibleInFilterBar: true, control: this._oSearchField
      }));

      this._aColumns.forEach(function (oCol) {
        var oControl;
        var sLabel = oCol.ColumnLabel || oCol.ColumnName;
        if (this._isRangeColumn(oCol)) {
          var oFrom = new Input({ placeholder: this._text("from"), submit: this.onFilterGo.bind(this) });
          var oTo = new Input({ placeholder: this._text("to"), submit: this.onFilterGo.bind(this) });
          oFrom.setTooltip(sLabel + " " + this._text("from"));
          oTo.setTooltip(sLabel + " " + this._text("to"));
          oControl = new HBox({ items: [oFrom, oTo], renderType: "Bare" });
          oFrom.addStyleClass("sapUiTinyMarginEnd");
          this._mFilterCtrls[oCol.Slot] = { from: oFrom, to: oTo };
        } else {
          var oMulti = new MultiInput({
            showValueHelp: false,
            showSuggestion: true,
            placeholder: this._text("multiPlaceholder"),
            tooltip: sLabel,
            suggest: this._onFilterSuggest.bind(this, oCol.Slot)
          });
          oMulti.addValidator(function (mArgs) {
            return new Token({ key: mArgs.text, text: mArgs.text });
          });
          oControl = oMulti;
          this._mFilterCtrls[oCol.Slot] = { multi: oMulti };
        }
        oFilterBar.addFilterGroupItem(new FilterGroupItem({
          groupName: FB_GROUP, name: oCol.Slot, label: sLabel,
          visibleInFilterBar: true, control: oControl
        }));
      }, this);
    },

    /** Suggestions = distinct values in the rows loaded so far */
    _onFilterSuggest: function (sSlot, oEvent) {
      var oMulti = oEvent.getSource();
      var sTyped = (oEvent.getParameter("suggestValue") || "").toLowerCase();
      var mSeen = {};
      oMulti.destroySuggestionItems();
      this.byId("contentTable").getItems().forEach(function (oItem) {
        var oCtx = oItem.getBindingContext();
        var sValue = oCtx && oCtx.getProperty(sSlot);
        if (sValue && !mSeen[sValue] && sValue.toLowerCase().indexOf(sTyped) !== -1) {
          mSeen[sValue] = true;
          oMulti.addSuggestionItem(new Item({ key: sValue, text: sValue }));
        }
      });
    },

    _collectFilters: function () {
      var aFilters = [new Filter("DecisionTableId", FilterOperator.EQ, this._sDtId)];
      Object.keys(this._mFilterCtrls).forEach(function (sSlot) {
        var oCtrl = this._mFilterCtrls[sSlot];
        if (oCtrl.multi) {
          var aValues = oCtrl.multi.getTokens().map(function (t) { return t.getKey(); });
          if (oCtrl.multi.getValue()) {
            aValues.push(oCtrl.multi.getValue());
          }
          if (aValues.length) {
            // Several values in one column = OR; contains() is case-insensitive on the backend
            aFilters.push(new Filter({
              filters: aValues.map(function (v) { return new Filter(sSlot, FilterOperator.Contains, v); }),
              and: false
            }));
          }
        } else {
          if (oCtrl.from.getValue()) {
            aFilters.push(new Filter(sSlot, FilterOperator.GE, oCtrl.from.getValue()));
          }
          if (oCtrl.to.getValue()) {
            aFilters.push(new Filter(sSlot, FilterOperator.LE, oCtrl.to.getValue()));
          }
        }
      }, this);
      return aFilters;
    },

    _collectParameters: function () {
      var sSearch = this._oSearchField ? this._oSearchField.getValue().trim() : "";
      var mParams = { $count: true };
      if (sSearch) {
        mParams.$search = sSearch;
      }
      return mParams;
    },

    onFilterGo: function () {
      var oBinding = this.byId("contentTable").getBinding("items");
      if (!oBinding) {
        return;
      }
      this._iFindIndex = -1;
      var mParams = this._collectParameters();
      oBinding.changeParameters({ $search: mParams.$search });
      oBinding.filter(this._collectFilters());
    },

    onFilterClear: function () {
      this._applyFilterState({});
      this._view().setProperty("/variantKey", STANDARD_VARIANT);
      this.onFilterGo();
    },

    _getFilterState: function () {
      var oState = { search: this._oSearchField ? this._oSearchField.getValue() : "", columns: {} };
      Object.keys(this._mFilterCtrls).forEach(function (sSlot) {
        var oCtrl = this._mFilterCtrls[sSlot];
        oState.columns[sSlot] = oCtrl.multi
          ? { tokens: oCtrl.multi.getTokens().map(function (t) { return t.getKey(); }) }
          : { from: oCtrl.from.getValue(), to: oCtrl.to.getValue() };
      }, this);
      return oState;
    },

    _applyFilterState: function (oState) {
      var mColumns = (oState && oState.columns) || {};
      if (this._oSearchField) {
        this._oSearchField.setValue((oState && oState.search) || "");
      }
      Object.keys(this._mFilterCtrls).forEach(function (sSlot) {
        var oCtrl = this._mFilterCtrls[sSlot];
        var oSaved = mColumns[sSlot] || {};
        if (oCtrl.multi) {
          oCtrl.multi.removeAllTokens();
          oCtrl.multi.setValue("");
          (oSaved.tokens || []).forEach(function (v) {
            oCtrl.multi.addToken(new Token({ key: v, text: v }));
          });
        } else {
          oCtrl.from.setValue(oSaved.from || "");
          oCtrl.to.setValue(oSaved.to || "");
        }
      }, this);
    },

    /* =========================================================== */
    /* Variants (per decision table, kept in this browser)          */
    /* =========================================================== */

    _variantStorageKey: function () {
      return "zbrf.viewer.variants." + this._sDtId;
    },

    _readVariants: function () {
      try {
        return JSON.parse(window.localStorage.getItem(this._variantStorageKey()) || "[]");
      } catch (e) {
        return [];
      }
    },

    _writeVariants: function (aVariants) {
      try {
        window.localStorage.setItem(this._variantStorageKey(), JSON.stringify(aVariants));
        return true;
      } catch (e) {
        MessageToast.show(this._text("variantStorageUnavailable"));
        return false;
      }
    },

    _loadVariants: function () {
      var aList = [{ key: STANDARD_VARIANT, name: this._text("standardVariant") }]
        .concat(this._readVariants().map(function (v) { return { key: v.key, name: v.name }; }));
      this._view().setProperty("/variants", aList);
      this._view().setProperty("/variantKey", STANDARD_VARIANT);
    },

    onVariantSelect: function (oEvent) {
      var sKey = oEvent.getParameter("selectedItem").getKey();
      var oVariant = this._readVariants().filter(function (v) { return v.key === sKey; })[0];
      this._applyFilterState(oVariant ? oVariant.state : {});
      this.onFilterGo();
    },

    onSaveVariant: function () {
      var oInput = new Input({ placeholder: this._text("variantName") });
      var oDialog = new Dialog({
        title: this._text("saveVariant"),
        content: [new Label({ text: this._text("variantName"), labelFor: oInput }), oInput],
        beginButton: new Button({
          text: this._text("save"),
          type: "Emphasized",
          press: function () {
            var sName = oInput.getValue().trim();
            if (!sName) {
              oInput.setValueState("Error");
              return;
            }
            var aVariants = this._readVariants();
            var sKey = "v" + Date.now();
            aVariants.push({ key: sKey, name: sName, state: this._getFilterState() });
            if (this._writeVariants(aVariants)) {
              this._loadVariants();
              this._view().setProperty("/variantKey", sKey);
              MessageToast.show(this._text("variantSaved", [sName]));
            }
            oDialog.close();
          }.bind(this)
        }),
        endButton: new Button({ text: this._text("cancel"), press: function () { oDialog.close(); } }),
        afterClose: function () { oDialog.destroy(); }
      });
      oDialog.addStyleClass("sapUiContentPadding");
      this.getView().addDependent(oDialog);
      oDialog.open();
    },

    onDeleteVariant: function () {
      var sKey = this._view().getProperty("/variantKey");
      this._writeVariants(this._readVariants().filter(function (v) { return v.key !== sKey; }));
      this._loadVariants();
      this.onFilterClear();
    },

    /* =========================================================== */
    /* Find (Next / Previous) in the loaded rows                    */
    /* =========================================================== */

    onFindLive: function () {
      this._iFindIndex = -1;
      this._highlightFindCurrent();
    },

    onFindNext: function () {
      this._find(1);
    },

    onFindPrevious: function () {
      this._find(-1);
    },

    _rowMatches: function (oItem, sTerm) {
      var oCtx = oItem.getBindingContext();
      if (!oCtx) {
        return false;
      }
      return this._visibleColumns().some(function (oCol) {
        return formatter.isFindHit(oCtx.getProperty(oCol.Slot), sTerm);
      });
    },

    _find: function (iDirection) {
      var sTerm = this._view().getProperty("/findTerm");
      var aItems = this.byId("contentTable").getItems().filter(function (o) { return o.isA("sap.m.ColumnListItem"); });
      if (!sTerm || !aItems.length) {
        return;
      }
      var iCount = aItems.length;
      for (var i = 1; i <= iCount; i++) {
        var iIndex = (this._iFindIndex + iDirection * i + iCount) % iCount;
        if (this._rowMatches(aItems[iIndex], sTerm)) {
          this._iFindIndex = iIndex;
          this._highlightFindCurrent();
          aItems[iIndex].focus();
          return;
        }
      }
      MessageToast.show(this._text("findNoMatch", [iCount]));
    },

    _highlightFindCurrent: function () {
      var aItems = this.byId("contentTable").getItems().filter(function (o) { return o.isA("sap.m.ColumnListItem"); });
      aItems.forEach(function (oItem, i) {
        oItem.toggleStyleClass("brfFindCurrent", i === this._iFindIndex);
        oItem.setHighlight(i === this._iFindIndex ? "Information" : "None");
      }, this);
    },

    /* =========================================================== */
    /* Sort / group, column settings                                */
    /* =========================================================== */

    onOpenViewSettings: function () {
      var aCols = this._visibleColumns();
      var oDialog = new ViewSettingsDialog({
        title: this._text("sortGroup"),
        sortItems: [new ViewSettingsItem({ key: "RowNo", text: this._text("rowNo"), selected: true })]
          .concat(aCols.map(function (c) { return new ViewSettingsItem({ key: c.Slot, text: c.ColumnLabel || c.ColumnName }); })),
        groupItems: aCols.map(function (c) { return new ViewSettingsItem({ key: c.Slot, text: c.ColumnLabel || c.ColumnName }); }),
        confirm: function (oEvent) {
          var aSorters = [];
          var oGroup = oEvent.getParameter("groupItem");
          if (oGroup) {
            var sLabel = oGroup.getText();
            aSorters.push(new Sorter(oGroup.getKey(), oEvent.getParameter("groupDescending"), function (oCtx) {
              var sValue = oCtx.getProperty(oGroup.getKey()) || "";
              return { key: sValue, text: sLabel + ": " + (sValue || "–") };
            }));
          }
          var oSort = oEvent.getParameter("sortItem");
          if (oSort) {
            aSorters.push(new Sorter(oSort.getKey(), oEvent.getParameter("sortDescending")));
          }
          this._aSorters = aSorters;
          this._iFindIndex = -1;
          this.byId("contentTable").getBinding("items").sort(aSorters);
        }.bind(this),
        afterClose: function () { oDialog.destroy(); }
      });
      this.getView().addDependent(oDialog);
      oDialog.open();
    },

    onOpenColumnSettings: function (oEvent) {
      var oSource = oEvent.getSource();
      var aHidden = this._aHidden;
      var oPanel = new SelectionPanel({ title: this._text("columns"), showHeader: true });
      oPanel.setP13nData(this._aColumns.map(function (c) {
        return { key: c.Slot, label: c.ColumnLabel || c.ColumnName, visible: aHidden.indexOf(c.Slot) === -1 };
      }));

      var oPopup = new P13nPopup({
        title: this._text("tableSettings"),
        panels: [oPanel],
        close: function (oCloseEvent) {
          if (oCloseEvent.getParameter("reason") === "Ok") {
            var aData = oPanel.getP13nData();
            var mOrder = {};
            aData.forEach(function (d, i) { mOrder[d.key] = i; });
            this._aColumns.sort(function (a, b) { return mOrder[a.Slot] - mOrder[b.Slot]; });
            this._aHidden = aData.filter(function (d) { return !d.visible; }).map(function (d) { return d.key; });
            this._buildTable();
          }
          oPopup.destroy();
        }.bind(this)
      });
      this.getView().addDependent(oPopup);
      oPopup.open(oSource);
    },

    /* =========================================================== */
    /* Export                                                      */
    /* =========================================================== */

    /** All rows with the current filters/sort, read separately from the table */
    _readAllRows: function () {
      var mParams = this._collectParameters();
      delete mParams.$count;
      var aSorters = this._aSorters.map(function (s) { return new Sorter(s.sPath, s.bDescending); });
      return this._readList("/DecisionTableContent", this._collectFilters(), mParams, aSorters);
    },

    _exportFileName: function (sExtension) {
      return (this.getView().getModel("dt").getProperty("/Name") || "decision_table") + "." + sExtension;
    },

    onExportExcel: function () {
      var aCols = this._visibleColumns();
      this._view().setProperty("/dtBusy", true);
      Promise.all([this._readAllRows(), new Promise(function (resolve, reject) {
        sap.ui.require(["sap/ui/export/Spreadsheet"], resolve, reject);
      })]).then(function (aResult) {
        var Spreadsheet = aResult[1];
        var oSheet = new Spreadsheet({
          workbook: {
            columns: [{ label: this._text("rowNo"), property: "RowNo", type: "Number" }].concat(
              aCols.map(function (c) { return { label: c.ColumnLabel || c.ColumnName, property: c.Slot, type: "String" }; }))
          },
          dataSource: aResult[0],
          fileName: this._exportFileName("xlsx"),
          worker: false
        });
        this._view().setProperty("/dtBusy", false);
        return oSheet.build().finally(function () { oSheet.destroy(); });
      }.bind(this)).catch(this._showError.bind(this));
    },

    onExportCsv: function () {
      var aCols = this._visibleColumns();
      var fnQuote = function (v) {
        var s = v === undefined || v === null ? "" : String(v);
        return /[",;\n\r]/.test(s) ? "\"" + s.replace(/"/g, "\"\"") + "\"" : s;
      };
      this._view().setProperty("/dtBusy", true);
      this._readAllRows().then(function (aRows) {
        var aLines = [[this._text("rowNo")].concat(aCols.map(function (c) { return c.ColumnLabel || c.ColumnName; }))
          .map(fnQuote).join(",")];
        aRows.forEach(function (oRow) {
          aLines.push([oRow.RowNo].concat(aCols.map(function (c) { return oRow[c.Slot]; })).map(fnQuote).join(","));
        });
        File.save(aLines.join("\r\n"), this._exportFileName("csv").replace(/\.csv$/, ""), "csv", "text/csv", "utf-8", true);
        this._view().setProperty("/dtBusy", false);
      }.bind(this)).catch(this._showError.bind(this));
    }
  });
});
