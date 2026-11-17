@EndUserText.label: 'BRF+ Viewer: Catalog Tree Node'
@ObjectModel.query.implementedBy: 'ABAP:ZCL_BRF_VIEWER_QUERY'
@Search.searchable: true
define custom entity ZI_BRF_CatalogNode
{
      @EndUserText.label: 'Node ID'
//  key NodeId         : abap.char(70);   // too short once links are followed
  key NodeId         : abap.char(255);  // <catalog id> for roots, <parent node id>/<node> below
      @EndUserText.label: 'Parent Node ID'
//      ParentNodeId   : abap.char(70);
      ParentNodeId   : abap.char(255);  // initial for catalog roots
      @EndUserText.label: 'Catalog ID'
      CatalogId      : abap.char(32);
      @EndUserText.label: 'Catalog'
      CatalogName    : abap.char(30);
      @EndUserText.label: 'Node Type'
      NodeType       : abap.char(2);    // CA = catalog, FO = folder, DT = decision table, OB = other object, LI = link
      @EndUserText.label: 'Name'
      @Search.defaultSearchElement: true
      Name           : abap.char(80);
      @EndUserText.label: 'Description'
      @Search.defaultSearchElement: true
      Description    : abap.char(255);
      @EndUserText.label: 'BRF+ Object ID'
      ObjectId       : abap.char(32);
      @EndUserText.label: 'BRF+ Object Type'
      ObjectType     : abap.char(2);
      @EndUserText.label: 'Status'
      Status         : abap.char(1);    // A = active, I = inactive, blank = not applicable
      @EndUserText.label: 'Status Criticality'
      StatusCriticality : abap.int1;    // 3 = green, 2 = yellow, 0 = neutral
      @EndUserText.label: 'Hierarchy Level'
      HierarchyLevel : abap.int4;
      @EndUserText.label: 'Child Count'
      ChildCount     : abap.int4;
      @EndUserText.label: 'Sequence'
      Seqnr          : abap.int4;
      @EndUserText.label: 'Technical/Link'
      IsTechnical    : abap_boolean;    // link node or system object (the "H..." column)
}
