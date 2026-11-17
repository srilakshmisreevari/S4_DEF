"! Query provider for the read-only BRF+ viewer custom entities:
"!   ZI_BRF_CatalogNode   - catalog tree (lazy: filter ParentNodeId)
"!   ZI_BRF_DecisionTable - decision table header ("General" section)
"!   ZI_BRF_DTColumn      - column metadata (builds the grid and filter bar)
"!   ZI_BRF_DTRow         - table contents, one record per row, slots C01..C40
"! $filter, $search, $orderby, $top, $skip and $count are all handled here.
"! There is no behaviour definition, so the service is read-only by design.
CLASS zcl_brf_viewer_query DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_rap_query_provider.

  PROTECTED SECTION.
  PRIVATE SECTION.
    DATA mo_reader TYPE REF TO zcl_brf_viewer_reader.

    METHODS select_nodes
      IMPORTING io_request  TYPE REF TO if_rap_query_request
                io_response TYPE REF TO if_rap_query_response
      RAISING   cx_rap_query_provider.

    METHODS select_header
      IMPORTING io_request  TYPE REF TO if_rap_query_request
                io_response TYPE REF TO if_rap_query_response
      RAISING   cx_rap_query_provider.

    METHODS select_columns
      IMPORTING io_request  TYPE REF TO if_rap_query_request
                io_response TYPE REF TO if_rap_query_response
      RAISING   cx_rap_query_provider.

    METHODS select_rows
      IMPORTING io_request  TYPE REF TO if_rap_query_request
                io_response TYPE REF TO if_rap_query_response
      RAISING   cx_rap_query_provider.

    "! Filter, search, count, sort and page any result table, then send it
    METHODS respond
      IMPORTING io_request       TYPE REF TO if_rap_query_request
                io_response      TYPE REF TO if_rap_query_response
                it_search_fields TYPE string_table
      CHANGING  ct_data          TYPE STANDARD TABLE
      RAISING   cx_rap_query_provider.

    METHODS get_ranges
      IMPORTING io_request       TYPE REF TO if_rap_query_request
      RETURNING VALUE(rt_ranges) TYPE if_rap_query_filter=>tt_name_range_pairs
      RAISING   cx_rap_query_provider.

    "! Single EQ value of a filter field, e.g. DecisionTableId
    METHODS get_eq_value
      IMPORTING it_ranges       TYPE if_rap_query_filter=>tt_name_range_pairs
                iv_name         TYPE string
      EXPORTING ev_found        TYPE abap_bool
      RETURNING VALUE(rv_value) TYPE string.

    METHODS get_dt_id
      IMPORTING it_ranges   TYPE if_rap_query_filter=>tt_name_range_pairs
      RETURNING VALUE(rv_id) TYPE if_fdt_types=>id
      RAISING   cx_rap_query_provider.
ENDCLASS.



CLASS zcl_brf_viewer_query IMPLEMENTATION.

  METHOD if_rap_query_provider~select.
    mo_reader = NEW #( ).

    CASE io_request->get_entity_id( ).
      WHEN 'ZI_BRF_CATALOGNODE'.
        select_nodes( io_request = io_request io_response = io_response ).
      WHEN 'ZI_BRF_DECISIONTABLE'.
        select_header( io_request = io_request io_response = io_response ).
      WHEN 'ZI_BRF_DTCOLUMN'.
        select_columns( io_request = io_request io_response = io_response ).
      WHEN 'ZI_BRF_DTROW'.
        select_rows( io_request = io_request io_response = io_response ).
      WHEN OTHERS.
        RAISE EXCEPTION NEW zcx_brf_viewer( iv_text = |Entity { io_request->get_entity_id( ) } is not supported| ).
    ENDCASE.
  ENDMETHOD.


  METHOD select_nodes.
    DATA(lt_ranges) = get_ranges( io_request ).

    " Lazy loading: only read what the filter asks for
    "   ParentNodeId eq ''          -> catalog roots only
    "   ParentNodeId eq '<cat>...'  -> that catalog's nodes
    "   NodeId / CatalogId eq ...   -> that catalog's nodes
    DATA lv_found TYPE abap_bool.
    DATA lv_catalog TYPE if_fdt_types=>id.
    DATA lv_roots_only TYPE abap_bool.

    DATA(lv_parent) = get_eq_value( EXPORTING it_ranges = lt_ranges iv_name = 'PARENTNODEID'
                                    IMPORTING ev_found  = lv_found ).
    IF lv_found = abap_true.
      IF lv_parent IS INITIAL.
        lv_roots_only = abap_true.
      ELSE.
        lv_catalog = lv_parent.   " first 32 characters = catalog id
      ENDIF.
    ELSE.
      DATA(lv_node) = get_eq_value( EXPORTING it_ranges = lt_ranges iv_name = 'NODEID'
                                    IMPORTING ev_found  = lv_found ).
      IF lv_found = abap_true.
        lv_catalog = lv_node.
      ELSE.
        DATA(lv_cat) = get_eq_value( EXPORTING it_ranges = lt_ranges iv_name = 'CATALOGID'
                                     IMPORTING ev_found  = lv_found ).
        IF lv_found = abap_true.
          lv_catalog = lv_cat.
        ENDIF.
      ENDIF.
    ENDIF.

    DATA(lt_node) = mo_reader->get_catalog_nodes( iv_catalog_id = lv_catalog
                                                  iv_roots_only = lv_roots_only ).
    respond( EXPORTING io_request       = io_request
                       io_response      = io_response
                       it_search_fields = VALUE #( ( `NAME` ) ( `DESCRIPTION` ) )
             CHANGING  ct_data          = lt_node ).
  ENDMETHOD.


  METHOD select_header.
    DATA(lt_ranges) = get_ranges( io_request ).
    DATA lt_result TYPE STANDARD TABLE OF zi_brf_decisiontable WITH EMPTY KEY.
    APPEND mo_reader->get_decision_table( get_dt_id( lt_ranges ) ) TO lt_result.
    respond( EXPORTING io_request       = io_request
                       io_response      = io_response
                       it_search_fields = VALUE #( )
             CHANGING  ct_data          = lt_result ).
  ENDMETHOD.


  METHOD select_columns.
    DATA(lt_column) = mo_reader->get_columns( get_dt_id( get_ranges( io_request ) ) ).
    respond( EXPORTING io_request       = io_request
                       io_response      = io_response
*                       it_search_fields = VALUE #( ( `COLUMNNAME` ) ( `LABEL` ) )
                       it_search_fields = VALUE #( ( `COLUMNNAME` ) ( `COLUMNLABEL` ) )
             CHANGING  ct_data          = lt_column ).
  ENDMETHOD.


  METHOD select_rows.
    DATA(lt_row) = mo_reader->get_rows( get_dt_id( get_ranges( io_request ) ) ).

    DATA(lt_search) = VALUE string_table( ).
    DO zcl_brf_viewer_reader=>gc_max_slots TIMES.
      APPEND |C{ sy-index WIDTH = 2 ALIGN = RIGHT PAD = '0' }| TO lt_search.
    ENDDO.

    respond( EXPORTING io_request       = io_request
                       io_response      = io_response
                       it_search_fields = lt_search
             CHANGING  ct_data          = lt_row ).
  ENDMETHOD.


  METHOD respond.
    FIELD-SYMBOLS <ls_row>  TYPE any.
    FIELD-SYMBOLS <lt_page> TYPE STANDARD TABLE.

    " 1. $filter: every range must match (ranges from OData: eq, ne, gt, contains -> CP, ...)
    "    CP is case-insensitive in ABAP, so contains() filters ignore case.
    DATA(lt_ranges) = get_ranges( io_request ).
    IF lt_ranges IS NOT INITIAL.
      LOOP AT ct_data ASSIGNING <ls_row>.
        DATA(lv_tabix) = sy-tabix.
        LOOP AT lt_ranges INTO DATA(ls_range).
          ASSIGN COMPONENT ls_range-name OF STRUCTURE <ls_row> TO FIELD-SYMBOL(<lv_field>).
          IF sy-subrc = 0 AND NOT <lv_field> IN ls_range-range.
            DELETE ct_data INDEX lv_tabix.
            EXIT.
          ENDIF.
        ENDLOOP.
      ENDLOOP.
    ENDIF.

    " 2. $search: free text over the given fields, case-insensitive
    DATA(lv_search) = io_request->get_search_expression( ).
    REPLACE ALL OCCURRENCES OF `"` IN lv_search WITH ``.
    CONDENSE lv_search.
    IF lv_search IS NOT INITIAL AND it_search_fields IS NOT INITIAL.
      LOOP AT ct_data ASSIGNING <ls_row>.
        lv_tabix = sy-tabix.
        DATA(lv_hit) = abap_false.
        LOOP AT it_search_fields INTO DATA(lv_search_field).
          ASSIGN COMPONENT lv_search_field OF STRUCTURE <ls_row> TO FIELD-SYMBOL(<lv_text>).
          IF sy-subrc = 0 AND <lv_text> IS NOT INITIAL AND CONV string( <lv_text> ) CS lv_search.
            lv_hit = abap_true.
            EXIT.
          ENDIF.
        ENDLOOP.
        IF lv_hit = abap_false.
          DELETE ct_data INDEX lv_tabix.
        ENDIF.
      ENDLOOP.
    ENDIF.

    " 3. $count
    IF io_request->is_total_numb_of_rec_requested( ).
      io_response->set_total_number_of_records( lines( ct_data ) ).
    ENDIF.

    IF NOT io_request->is_data_requested( ).
      RETURN.
    ENDIF.

    " 4. $orderby
    DATA(lt_sort_elements) = io_request->get_sort_elements( ).
    IF lt_sort_elements IS NOT INITIAL.
      DATA(lt_order) = VALUE abap_sortorder_tab( ).
      LOOP AT lt_sort_elements INTO DATA(ls_sort).
        APPEND VALUE #( name = ls_sort-element_name descending = ls_sort-descending ) TO lt_order.
      ENDLOOP.
      SORT ct_data BY (lt_order).
    ENDIF.

    " 5. $skip / $top
    DATA(lv_offset)    = io_request->get_paging( )->get_offset( ).
    DATA(lv_page_size) = io_request->get_paging( )->get_page_size( ).
    IF lv_offset > 0 OR lv_page_size <> if_rap_query_paging=>page_size_unlimited.
      DATA lr_page TYPE REF TO data.
      CREATE DATA lr_page LIKE ct_data.
      ASSIGN lr_page->* TO <lt_page>.
      DATA(lv_to) = COND i( WHEN lv_page_size = if_rap_query_paging=>page_size_unlimited
                            THEN lines( ct_data )
                            ELSE nmin( val1 = lines( ct_data ) val2 = lv_offset + lv_page_size ) ).
      LOOP AT ct_data ASSIGNING <ls_row> FROM lv_offset + 1 TO lv_to.
        APPEND <ls_row> TO <lt_page>.
      ENDLOOP.
      io_response->set_data( <lt_page> ).
    ELSE.
      io_response->set_data( ct_data ).
    ENDIF.
  ENDMETHOD.


  METHOD get_ranges.
    TRY.
        rt_ranges = io_request->get_filter( )->get_as_ranges( ).
      CATCH cx_rap_query_filter_no_range INTO DATA(lx_no_range).
        " e.g. an OR across two different columns. The UI only sends ANDs
        " across columns, so this means a hand-written URL.
        RAISE EXCEPTION NEW zcx_brf_viewer(
          iv_text  = 'Filter too complex: use OR only within one column'(001)
          previous = lx_no_range ).
    ENDTRY.
  ENDMETHOD.


  METHOD get_eq_value.
    ev_found = abap_false.
    READ TABLE it_ranges INTO DATA(ls_range) WITH KEY name = iv_name.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.
    READ TABLE ls_range-range INTO DATA(ls_option) WITH KEY sign = 'I' option = 'EQ'.
    IF sy-subrc = 0 AND lines( ls_range-range ) = 1.
      ev_found = abap_true.
      rv_value = ls_option-low.
    ENDIF.
  ENDMETHOD.


  METHOD get_dt_id.
    DATA lv_found TYPE abap_bool.
    DATA(lv_value) = get_eq_value( EXPORTING it_ranges = it_ranges iv_name = 'DECISIONTABLEID'
                                   IMPORTING ev_found  = lv_found ).
    IF lv_found = abap_false OR lv_value IS INITIAL.
      RAISE EXCEPTION NEW zcx_brf_viewer( iv_text = 'Filter DecisionTableId eq ''<id>'' is required'(002) ).
    ENDIF.
    rv_id = lv_value.
  ENDMETHOD.

ENDCLASS.
