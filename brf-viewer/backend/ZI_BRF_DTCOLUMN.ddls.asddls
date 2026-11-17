@EndUserText.label: 'BRF+ Viewer: Decision Table Column'
@ObjectModel.query.implementedBy: 'ABAP:ZCL_BRF_VIEWER_QUERY'
define custom entity ZI_BRF_DTColumn
{
      @EndUserText.label: 'Decision Table ID'
  key DecisionTableId : abap.char(32);
      @EndUserText.label: 'Column No.'
  key ColumnNo        : abap.int4;
      @EndUserText.label: 'Row Slot'
      Slot            : abap.char(3);   // name of the generic field in ZI_BRF_DTRow (C01..C40)
      @EndUserText.label: 'Column Name'
      ColumnName      : abap.char(30);
      @EndUserText.label: 'Label'
//      Label           : abap.char(80);   // LABEL is a reserved word
      ColumnLabel     : abap.char(80);
      @EndUserText.label: 'Data Object ID'
      DataObjectId    : abap.char(32);
      @EndUserText.label: 'Data Element'
      DataElement     : abap.char(30);
      @EndUserText.label: 'Data Type'
      DataType        : abap.char(30);
      @EndUserText.label: 'Length'
      FieldLength     : abap.int4;
      @EndUserText.label: 'Decimals'
      Decimals        : abap.int4;
      @EndUserText.label: 'Result Column'
      IsResult        : abap_boolean;
      @EndUserText.label: 'Optional'
      IsOptional      : abap_boolean;
}
