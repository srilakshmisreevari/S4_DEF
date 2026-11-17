@EndUserText.label: 'BRF+ Viewer: Decision Table Header'
@ObjectModel.query.implementedBy: 'ABAP:ZCL_BRF_VIEWER_QUERY'
define custom entity ZI_BRF_DecisionTable
{
      @EndUserText.label: 'Decision Table ID'
  key DecisionTableId : abap.char(32);
      @EndUserText.label: 'Name'
      Name            : abap.char(30);
      @EndUserText.label: 'Description'
      Description     : abap.char(255);
      @EndUserText.label: 'Object Type'
      ObjectTypeText  : abap.char(40);
      @EndUserText.label: 'Application ID'
      ApplicationId   : abap.char(32);
      @EndUserText.label: 'Application'
      ApplicationName : abap.char(30);
      @EndUserText.label: 'Package'
      DevPackage      : abap.char(30);
      @EndUserText.label: 'Created By'
      CreatedBy       : abap.char(12);
      @EndUserText.label: 'Created On'
      CreatedOn       : abap.dats;
      @EndUserText.label: 'Created At'
      CreatedTime     : abap.tims;
      @EndUserText.label: 'Changed By'
      ChangedBy       : abap.char(12);
      @EndUserText.label: 'Changed On'
      ChangedOn       : abap.dats;
      @EndUserText.label: 'Changed At'
      ChangedTime     : abap.tims;
      @EndUserText.label: 'Status'
      Status          : abap.char(1);
      @EndUserText.label: 'Status Text'
      StatusText      : abap.char(20);
      @EndUserText.label: 'Status Criticality'
      StatusCriticality : abap.int1;
      @EndUserText.label: 'Rows'
//      RowCount        : abap.int4;   // ROWCOUNT is a reserved word
      TotalRows       : abap.int4;
      @EndUserText.label: 'Columns'
      ColumnCount     : abap.int4;
      @EndUserText.label: 'Multiple Match'
      MultipleMatch   : abap_boolean;
      @EndUserText.label: 'Allow No Match'
      AllowNoMatch    : abap_boolean;
      @EndUserText.label: 'Columns Truncated'
      ColumnsTruncated : abap_boolean;  // true if the table has more columns than ZI_BRF_DTRow slots
}
