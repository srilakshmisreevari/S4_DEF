@EndUserText.label: 'BRF+ Viewer: Decision Table Row'
@ObjectModel.query.implementedBy: 'ABAP:ZCL_BRF_VIEWER_QUERY'
@Search.searchable: true
// One record per decision-table row. Columns vary per table, so cell values are
// placed in generic slots C01..C40; ZI_BRF_DTColumn-Slot says which slot holds
// which column. Each slot holds the cell rendered as text (e.g. "=PTP",
// "[100..200]", "<> A998; = A999"). Filtering, sorting and paging run in ABAP.
define custom entity ZI_BRF_DTRow
{
      @EndUserText.label: 'Decision Table ID'
  key DecisionTableId : abap.char(32);
      @EndUserText.label: 'Row No.'
  key RowNo           : abap.int4;
      @EndUserText.label: 'Column 01'
      @Search.defaultSearchElement: true
      C01 : abap.char(255);
      @EndUserText.label: 'Column 02'
      @Search.defaultSearchElement: true
      C02 : abap.char(255);
      @EndUserText.label: 'Column 03'
      @Search.defaultSearchElement: true
      C03 : abap.char(255);
      @EndUserText.label: 'Column 04'
      @Search.defaultSearchElement: true
      C04 : abap.char(255);
      @EndUserText.label: 'Column 05'
      @Search.defaultSearchElement: true
      C05 : abap.char(255);
      @EndUserText.label: 'Column 06'
      @Search.defaultSearchElement: true
      C06 : abap.char(255);
      @EndUserText.label: 'Column 07'
      @Search.defaultSearchElement: true
      C07 : abap.char(255);
      @EndUserText.label: 'Column 08'
      @Search.defaultSearchElement: true
      C08 : abap.char(255);
      @EndUserText.label: 'Column 09'
      @Search.defaultSearchElement: true
      C09 : abap.char(255);
      @EndUserText.label: 'Column 10'
      @Search.defaultSearchElement: true
      C10 : abap.char(255);
      @EndUserText.label: 'Column 11'
      @Search.defaultSearchElement: true
      C11 : abap.char(255);
      @EndUserText.label: 'Column 12'
      @Search.defaultSearchElement: true
      C12 : abap.char(255);
      @EndUserText.label: 'Column 13'
      @Search.defaultSearchElement: true
      C13 : abap.char(255);
      @EndUserText.label: 'Column 14'
      @Search.defaultSearchElement: true
      C14 : abap.char(255);
      @EndUserText.label: 'Column 15'
      @Search.defaultSearchElement: true
      C15 : abap.char(255);
      @EndUserText.label: 'Column 16'
      @Search.defaultSearchElement: true
      C16 : abap.char(255);
      @EndUserText.label: 'Column 17'
      @Search.defaultSearchElement: true
      C17 : abap.char(255);
      @EndUserText.label: 'Column 18'
      @Search.defaultSearchElement: true
      C18 : abap.char(255);
      @EndUserText.label: 'Column 19'
      @Search.defaultSearchElement: true
      C19 : abap.char(255);
      @EndUserText.label: 'Column 20'
      @Search.defaultSearchElement: true
      C20 : abap.char(255);
      @EndUserText.label: 'Column 21'
      @Search.defaultSearchElement: true
      C21 : abap.char(255);
      @EndUserText.label: 'Column 22'
      @Search.defaultSearchElement: true
      C22 : abap.char(255);
      @EndUserText.label: 'Column 23'
      @Search.defaultSearchElement: true
      C23 : abap.char(255);
      @EndUserText.label: 'Column 24'
      @Search.defaultSearchElement: true
      C24 : abap.char(255);
      @EndUserText.label: 'Column 25'
      @Search.defaultSearchElement: true
      C25 : abap.char(255);
      @EndUserText.label: 'Column 26'
      @Search.defaultSearchElement: true
      C26 : abap.char(255);
      @EndUserText.label: 'Column 27'
      @Search.defaultSearchElement: true
      C27 : abap.char(255);
      @EndUserText.label: 'Column 28'
      @Search.defaultSearchElement: true
      C28 : abap.char(255);
      @EndUserText.label: 'Column 29'
      @Search.defaultSearchElement: true
      C29 : abap.char(255);
      @EndUserText.label: 'Column 30'
      @Search.defaultSearchElement: true
      C30 : abap.char(255);
      @EndUserText.label: 'Column 31'
      @Search.defaultSearchElement: true
      C31 : abap.char(255);
      @EndUserText.label: 'Column 32'
      @Search.defaultSearchElement: true
      C32 : abap.char(255);
      @EndUserText.label: 'Column 33'
      @Search.defaultSearchElement: true
      C33 : abap.char(255);
      @EndUserText.label: 'Column 34'
      @Search.defaultSearchElement: true
      C34 : abap.char(255);
      @EndUserText.label: 'Column 35'
      @Search.defaultSearchElement: true
      C35 : abap.char(255);
      @EndUserText.label: 'Column 36'
      @Search.defaultSearchElement: true
      C36 : abap.char(255);
      @EndUserText.label: 'Column 37'
      @Search.defaultSearchElement: true
      C37 : abap.char(255);
      @EndUserText.label: 'Column 38'
      @Search.defaultSearchElement: true
      C38 : abap.char(255);
      @EndUserText.label: 'Column 39'
      @Search.defaultSearchElement: true
      C39 : abap.char(255);
      @EndUserText.label: 'Column 40'
      @Search.defaultSearchElement: true
      C40 : abap.char(255);
}
