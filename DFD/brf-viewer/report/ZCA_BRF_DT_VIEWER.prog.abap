*&---------------------------------------------------------------------*
*& Report ZCA_BRF_DT_VIEWER
*&---------------------------------------------------------------------*
*& Read-only viewer for BRF+ catalogs and decision tables.
*&
*&  Left : catalog tree (CL_SALV_TREE) - Catalog Structure / H / Status
*&  Right: General data (CL_SALV_TABLE) and the decision table contents
*&         (CL_GUI_ALV_GRID, display only). Filter, sort, find, layouts,
*&         subtotals/grouping and export come from the standard ALV
*&         toolbar.
*&
*& All BRF+ access goes through the public FDT API (CL_FDT_FACTORY,
*& IF_FDT_CATALOG, IF_FDT_DECISION_TABLE). No FDT table is read
*& directly and no BRF+ object is locked, changed, saved or activated.
*& Authorization: standard BRF+ display check (IF_FDT_TRANSACTION~
*& AUTHORITY_CHECK, activity 3) for every catalog and object shown.
*&---------------------------------------------------------------------*
*& Change log
*&---------------------------------------------------------------------*
*& Date       | Author              | Transport  | Description
*&------------|---------------------|------------|----------------------
*& 2026-11-16 | Srilakshmi Sreevari | $TMP       | Initial version:
*&            |                     |            | catalog tree, General
*&            |                     |            | data, decision table
*&            |                     |            | contents in ALV grid
*& 2026-11-16 | Srilakshmi Sreevari | $TMP       | General section
*&            |                     |            | commented out: table
*&            |                     |            | contents use the full
*&            |                     |            | right side
*& 2026-11-16 | Srilakshmi Sreevari | $TMP       | Follow catalog links:
*&            |                     |            | linked catalogs (e.g.
*&            |                     |            | under ZDEF_TECHNICAL_
*&            |                     |            | CATALOG) now show
*&            |                     |            | their contents
*& 2026-11-17 | Srilakshmi Sreevari | DFDK903994 | Renamed from
*&            |                     |            | ZBRF_DT_VIEWER;
*&            |                     |            | package ZDEF
*&---------------------------------------------------------------------*
REPORT zca_brf_dt_viewer.

INCLUDE <icon>.

DATA gv_sel_name TYPE if_fdt_types=>name.

SELECTION-SCREEN BEGIN OF BLOCK b01 WITH FRAME TITLE TEXT-b01.
  SELECT-OPTIONS s_cat FOR gv_sel_name.          " Catalog name
  PARAMETERS     p_dt  TYPE if_fdt_types=>name.  " Open this decision table directly
SELECTION-SCREEN END OF BLOCK b01.

" Empty selection screen that hosts the controls, so no dynpro or GUI
" status has to be created by hand.
SELECTION-SCREEN BEGIN OF SCREEN 9000 TITLE TEXT-t01.
  SELECTION-SCREEN COMMENT /1(1) gv_dummy.
SELECTION-SCREEN END OF SCREEN 9000.


*----------------------------------------------------------------------*
* Exception
*----------------------------------------------------------------------*
CLASS lcx_error DEFINITION INHERITING FROM cx_static_check FINAL.
  PUBLIC SECTION.
    DATA mv_text TYPE string READ-ONLY.
    METHODS constructor
      IMPORTING iv_text  TYPE string OPTIONAL
                previous TYPE REF TO cx_root OPTIONAL.
    METHODS if_message~get_text REDEFINITION.
ENDCLASS.

CLASS lcx_error IMPLEMENTATION.
  METHOD constructor.
    super->constructor( previous = previous ).
    mv_text = iv_text.
    IF mv_text IS INITIAL AND previous IS BOUND.
      mv_text = previous->get_text( ).
    ENDIF.
  ENDMETHOD.

  METHOD if_message~get_text.
    result = mv_text.
  ENDMETHOD.
ENDCLASS.


*----------------------------------------------------------------------*
* Reader: wraps the FDT API, read only
*----------------------------------------------------------------------*
CLASS lcl_reader DEFINITION FINAL.
  PUBLIC SECTION.
    CONSTANTS:
      BEGIN OF gc_node_type,
        catalog        TYPE c LENGTH 2 VALUE 'CA',
        folder         TYPE c LENGTH 2 VALUE 'FO',
        decision_table TYPE c LENGTH 2 VALUE 'DT',
        other_object   TYPE c LENGTH 2 VALUE 'OB',
        link           TYPE c LENGTH 2 VALUE 'LI',
      END OF gc_node_type.

    TYPES ty_name_range TYPE RANGE OF if_fdt_types=>name.

    TYPES:
      BEGIN OF ty_node,
*        node_id      TYPE c LENGTH 70,   " too short once links are followed
*        parent_id    TYPE c LENGTH 70,
        node_id      TYPE string,
        parent_id    TYPE string,
        catalog_id   TYPE if_fdt_types=>id,
        node_type    TYPE c LENGTH 2,
        name         TYPE string,
        description  TYPE string,
        object_id    TYPE if_fdt_types=>id,
        object_type  TYPE if_fdt_types=>object_type,
        state        TYPE c LENGTH 1,
        is_technical TYPE abap_bool,
        seqnr        TYPE i,
      END OF ty_node,
      tt_node TYPE STANDARD TABLE OF ty_node WITH EMPTY KEY.

    TYPES:
      BEGIN OF ty_header,
        id             TYPE if_fdt_types=>id,
        name           TYPE string,
        description    TYPE string,
        application_id TYPE if_fdt_types=>id,
        application    TYPE string,
        package        TYPE devclass,
        created_by     TYPE string,
        created_on     TYPE d,
        created_time   TYPE t,
        changed_by     TYPE string,
        changed_on     TYPE d,
        changed_time   TYPE t,
        state          TYPE c LENGTH 1,
        row_count      TYPE i,
        column_count   TYPE i,
        multiple_match TYPE abap_bool,
        allow_no_match TYPE abap_bool,
      END OF ty_header.

    TYPES:
      BEGIN OF ty_column,
        col_no       TYPE i,
        fieldname    TYPE lvc_fname,      " C001, C002, ... in the output table
        name         TYPE string,         " BRF+ data object name
        label        TYPE string,
        data_element TYPE string,
        is_result    TYPE abap_bool,
      END OF ty_column,
      tt_column TYPE STANDARD TABLE OF ty_column WITH EMPTY KEY.

    TYPES:
      BEGIN OF ty_cell,
        row_no TYPE i,
        col_no TYPE i,
        text   TYPE string,
      END OF ty_cell,
      tt_cell TYPE STANDARD TABLE OF ty_cell WITH EMPTY KEY.

    METHODS constructor.

    METHODS get_catalog_nodes
      IMPORTING it_name        TYPE ty_name_range OPTIONAL
      RETURNING VALUE(rt_node) TYPE tt_node
      RAISING   lcx_error.

    "! Find a decision table by name (first active match the user may display)
    METHODS find_decision_table
      IMPORTING iv_name      TYPE if_fdt_types=>name
      RETURNING VALUE(rv_id) TYPE if_fdt_types=>id
      RAISING   lcx_error.

    METHODS get_header
      IMPORTING iv_id            TYPE if_fdt_types=>id
      RETURNING VALUE(rs_header) TYPE ty_header
      RAISING   lcx_error.

    METHODS get_contents
      IMPORTING iv_id     TYPE if_fdt_types=>id
      EXPORTING et_column TYPE tt_column
                et_cell   TYPE tt_cell
                ev_rows   TYPE i
      RAISING   lcx_error.

  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_object_info,
        id             TYPE if_fdt_types=>id,
        name           TYPE if_fdt_types=>name,
        text           TYPE if_fdt_types=>text,
        object_type    TYPE if_fdt_types=>object_type,
        node_type      TYPE c LENGTH 2,
        state          TYPE c LENGTH 1,
        application_id TYPE if_fdt_types=>id,
        system_object  TYPE abap_bool,
        authorized     TYPE abap_bool,
      END OF ty_object_info,
      tt_object_info TYPE HASHED TABLE OF ty_object_info WITH UNIQUE KEY id.

    TYPES:
      BEGIN OF ty_app,
        id      TYPE if_fdt_types=>id,
        name    TYPE if_fdt_types=>name,
        package TYPE devclass,
      END OF ty_app,
      tt_app TYPE HASHED TABLE OF ty_app WITH UNIQUE KEY id.

    DATA mo_factory TYPE REF TO if_fdt_factory.
    DATA mt_object  TYPE tt_object_info.
    DATA mt_app     TYPE tt_app.

    METHODS get_object_info
      IMPORTING iv_id          TYPE if_fdt_types=>id
      RETURNING VALUE(rs_info) TYPE ty_object_info.

    "! Adds the children of IV_PARENT_NODE (initial = catalog root).
    "! A link node is followed into the linked catalog (to the linked
    "! node, or the whole catalog), so its contents show under the link.
    "! IV_PATH holds the catalogs already on the way down (no loops).
    METHODS append_children
      IMPORTING io_catalog     TYPE REF TO if_fdt_catalog
                its_structure  TYPE if_fdt_catalog=>ts_catalog_structure
                iv_catalog_id  TYPE if_fdt_types=>id
                iv_parent_node TYPE if_fdt_catalog=>node_id
                iv_parent_id   TYPE string
                iv_path        TYPE string
                iv_depth       TYPE i
      CHANGING  ct_node        TYPE tt_node.

    METHODS get_app
      IMPORTING iv_id         TYPE if_fdt_types=>id
      RETURNING VALUE(rs_app) TYPE ty_app.

    METHODS get_state
      IMPORTING io_admin        TYPE REF TO if_fdt_admin_data
      RETURNING VALUE(rv_state) TYPE char1.

    METHODS is_authorized
      IMPORTING io_admin     TYPE REF TO if_fdt_admin_data
      RETURNING VALUE(rv_ok) TYPE abap_bool.

    METHODS get_dt
      IMPORTING iv_id        TYPE if_fdt_types=>id
      RETURNING VALUE(ro_dt) TYPE REF TO if_fdt_decision_table
      RAISING   lcx_error.

    METHODS range_to_text
      IMPORTING its_range      TYPE if_fdt_range=>ts_range
      RETURNING VALUE(rv_text) TYPE string.

    METHODS value_to_text
      IMPORTING ir_value       TYPE REF TO data
                iv_expr_id     TYPE if_fdt_types=>id OPTIONAL
      RETURNING VALUE(rv_text) TYPE string.

    METHODS option_to_text
      IMPORTING iv_option      TYPE if_fdt_range=>option
                iv_low         TYPE string
                iv_high        TYPE string
      RETURNING VALUE(rv_text) TYPE string.

    METHODS split_timestamp
      IMPORTING iv_ts   TYPE timestamp
      EXPORTING ev_date TYPE d
                ev_time TYPE t.
ENDCLASS.


CLASS lcl_reader IMPLEMENTATION.

  METHOD constructor.
    mo_factory = cl_fdt_factory=>if_fdt_factory~get_instance( ).
  ENDMETHOD.


  METHOD get_catalog_nodes.
    TYPES:
      BEGIN OF ty_catalog,
        id             TYPE if_fdt_types=>id,
        name           TYPE if_fdt_types=>name,
        application_id TYPE if_fdt_types=>id,
      END OF ty_catalog.
    DATA lt_catalog TYPE STANDARD TABLE OF ty_catalog WITH EMPTY KEY.

    " 1. Catalogs through the BRF+ query API
    TRY.
        DATA(lo_query) = mo_factory->get_query( iv_object_type = if_fdt_constants=>gc_object_type_catalog ).
        DATA(lts_selection) = VALUE if_fdt_query=>ts_selection(
          ( queryfield = if_fdt_admin_data_query=>gc_fn_object_type
            sign = 'I' option = 'EQ' low = if_fdt_constants=>gc_object_type_catalog ) ).
        LOOP AT it_name INTO DATA(ls_name).
          INSERT VALUE #( queryfield = if_fdt_admin_data_query=>gc_fn_name
                          sign = ls_name-sign option = ls_name-option
                          low = ls_name-low high = ls_name-high ) INTO TABLE lts_selection.
        ENDLOOP.
        DATA(lts_result_field) = VALUE if_fdt_query=>ts_queryfield(
          ( queryfield = if_fdt_admin_data_query=>gc_fn_id )
          ( queryfield = if_fdt_admin_data_query=>gc_fn_name )
          ( queryfield = if_fdt_admin_data_query=>gc_fn_application_id ) ).
        lo_query->select_data( EXPORTING its_selection    = lts_selection
                                         its_result_field = lts_result_field
                               IMPORTING eta_data         = lt_catalog ).
      CATCH cx_fdt_input INTO DATA(lx_query).
        RAISE EXCEPTION NEW lcx_error( previous = lx_query ).
    ENDTRY.

    SORT lt_catalog BY name.

    LOOP AT lt_catalog INTO DATA(ls_catalog).
      DATA(ls_cat_info) = get_object_info( ls_catalog-id ).
      IF ls_cat_info-authorized = abap_false.
        CONTINUE.   " user may not display this application: hide the catalog
      ENDIF.

      DATA lo_catalog TYPE REF TO if_fdt_catalog.
      DATA lts_structure TYPE if_fdt_catalog=>ts_catalog_structure.
      CLEAR: lo_catalog, lts_structure.
      TRY.
          lo_catalog = mo_factory->get_catalog( ls_catalog-id ).
          lo_catalog->get_catalog_structure( IMPORTING ets_structure = lts_structure ).
        CATCH cx_fdt_input.
          " Catalog cannot be read: still show the root, with no children
      ENDTRY.

      " Root node: the catalog itself
      DATA(lv_root_id) = CONV ty_node-node_id( ls_catalog-id ).
      APPEND VALUE #( node_id      = lv_root_id
                      catalog_id   = ls_catalog-id
                      node_type    = gc_node_type-catalog
                      name         = ls_catalog-name
                      description  = ls_cat_info-text
                      object_id    = ls_catalog-id
                      object_type  = if_fdt_constants=>gc_object_type_catalog
                      state        = ls_cat_info-state
                      is_technical = ls_cat_info-system_object
                      seqnr        = sy-tabix ) TO rt_node.

      IF lo_catalog IS NOT BOUND.
        CONTINUE.
      ENDIF.

*     Replaced: links were shown as end nodes, so linked catalogs had no children
*      " Child nodes: folders, leaves (objects) and links
*      LOOP AT lts_structure INTO DATA(ls_struct).
*        DATA(ls_node) = VALUE ty_node(
*          node_id    = |{ ls_catalog-id }:{ ls_struct-node }|
*          parent_id  = COND #( WHEN ls_struct-parent IS INITIAL THEN lv_root_id
*                               ELSE |{ ls_catalog-id }:{ ls_struct-parent }| )
*          catalog_id = ls_catalog-id
*          name       = ls_struct-node_name
*          seqnr      = ls_struct-seqnr ).
*
*        DATA lv_object_id TYPE if_fdt_types=>id.
*        DATA lv_node_text TYPE if_fdt_catalog=>s_node_text-text.
*        CLEAR: lv_object_id, lv_node_text.
*        TRY.
*            lo_catalog->get_node_properties( EXPORTING iv_node      = ls_struct-node
*                                             IMPORTING ev_object_id = lv_object_id
*                                                       ev_node_text = lv_node_text ).
*          CATCH cx_fdt_input.
*        ENDTRY.
*        ls_node-description = lv_node_text.
*
*        CASE ls_struct-node_type.
*          WHEN if_fdt_catalog=>gc_node_type_structure.
*            ls_node-node_type = gc_node_type-folder.
*
*          WHEN if_fdt_catalog=>gc_node_type_link.
*            ls_node-node_type    = gc_node_type-link.
*            ls_node-is_technical = abap_true.
*
*          WHEN OTHERS. " leaf = a BRF+ object
*            IF lv_object_id IS INITIAL.
*              ls_node-node_type = gc_node_type-other_object.
*            ELSE.
*              DATA(ls_obj) = get_object_info( lv_object_id ).
*              IF ls_obj-authorized = abap_false.
*                CONTINUE.   " hide objects the user may not display
*              ENDIF.
*              ls_node-node_type    = ls_obj-node_type.
*              ls_node-object_id    = ls_obj-id.
*              ls_node-object_type  = ls_obj-object_type.
*              ls_node-state        = ls_obj-state.
*              ls_node-is_technical = ls_obj-system_object.
*              IF ls_obj-name IS NOT INITIAL.
*                ls_node-name = ls_obj-name.
*              ENDIF.
*              IF ls_node-description IS INITIAL.
*                ls_node-description = ls_obj-text.
*              ENDIF.
*            ENDIF.
*        ENDCASE.
*
*        IF ls_node-name IS INITIAL.
*          ls_node-name = ls_node-description.
*        ENDIF.
*        APPEND ls_node TO rt_node.
*      ENDLOOP.
      " Child nodes: folders, leaves (objects) and links. Links are followed
      " into the linked catalog, so its contents show under the link node.
      append_children( EXPORTING io_catalog     = lo_catalog
                                 its_structure  = lts_structure
                                 iv_catalog_id  = ls_catalog-id
                                 iv_parent_node = VALUE #( )
                                 iv_parent_id   = lv_root_id
                                 iv_path        = CONV #( ls_catalog-id )
                                 iv_depth       = 0
                       CHANGING  ct_node        = rt_node ).
    ENDLOOP.
  ENDMETHOD.


  METHOD append_children.
    CONSTANTS lc_max_depth TYPE i VALUE 10.

    LOOP AT its_structure INTO DATA(ls_struct) WHERE parent = iv_parent_node.
      DATA(ls_node) = VALUE ty_node(
        node_id    = |{ iv_parent_id }/{ ls_struct-node }|
        parent_id  = iv_parent_id
        catalog_id = iv_catalog_id
        name       = ls_struct-node_name
        seqnr      = ls_struct-seqnr ).

      DATA lv_object_id TYPE if_fdt_types=>id.
      DATA lv_node_text TYPE if_fdt_catalog=>s_node_text-text.
      DATA ls_link      TYPE if_fdt_catalog=>s_link.
      CLEAR: lv_object_id, lv_node_text, ls_link.
      TRY.
          io_catalog->get_node_properties( EXPORTING iv_node      = ls_struct-node
                                           IMPORTING ev_object_id = lv_object_id
                                                     es_link      = ls_link
                                                     ev_node_text = lv_node_text ).
        CATCH cx_fdt_input.
      ENDTRY.
      ls_node-description = lv_node_text.

      DATA(lv_follow_link) = abap_false.
      CASE ls_struct-node_type.
        WHEN if_fdt_catalog=>gc_node_type_structure.
          ls_node-node_type = gc_node_type-folder.

        WHEN if_fdt_catalog=>gc_node_type_link.
          ls_node-node_type    = gc_node_type-link.
          ls_node-is_technical = abap_true.
          IF ls_link-catalog_id IS NOT INITIAL.
            DATA(ls_target) = get_object_info( ls_link-catalog_id ).
            ls_node-object_id   = ls_link-catalog_id.
            ls_node-object_type = if_fdt_constants=>gc_object_type_catalog.
            ls_node-state       = ls_target-state.
            IF ls_node-description IS INITIAL.
              ls_node-description = ls_target-name.
            ENDIF.
            " Follow only into catalogs the user may display, without loops
            lv_follow_link = xsdbool( ls_target-authorized = abap_true AND
                                      iv_depth < lc_max_depth AND
                                      iv_path NS ls_link-catalog_id ).
          ENDIF.

        WHEN OTHERS. " leaf = a BRF+ object
          IF lv_object_id IS INITIAL.
            ls_node-node_type = gc_node_type-other_object.
          ELSE.
            DATA(ls_obj) = get_object_info( lv_object_id ).
            IF ls_obj-authorized = abap_false.
              CONTINUE.   " hide objects the user may not display
            ENDIF.
            ls_node-node_type    = ls_obj-node_type.
            ls_node-object_id    = ls_obj-id.
            ls_node-object_type  = ls_obj-object_type.
            ls_node-state        = ls_obj-state.
            ls_node-is_technical = ls_obj-system_object.
            IF ls_obj-name IS NOT INITIAL.
              ls_node-name = ls_obj-name.
            ENDIF.
            IF ls_node-description IS INITIAL.
              ls_node-description = ls_obj-text.
            ENDIF.
          ENDIF.
      ENDCASE.

      IF ls_node-name IS INITIAL.
        ls_node-name = ls_node-description.
      ENDIF.
      APPEND ls_node TO ct_node.

      " Sub-nodes of a folder in the same catalog
      IF ls_struct-node_type = if_fdt_catalog=>gc_node_type_structure.
        append_children( EXPORTING io_catalog     = io_catalog
                                   its_structure  = its_structure
                                   iv_catalog_id  = iv_catalog_id
                                   iv_parent_node = ls_struct-node
                                   iv_parent_id   = ls_node-node_id
                                   iv_path        = iv_path
                                   iv_depth       = iv_depth
                         CHANGING  ct_node        = ct_node ).
      ENDIF.

      " Contents of the linked catalog
      IF lv_follow_link = abap_true.
        TRY.
            DATA(lo_target) = mo_factory->get_catalog( ls_link-catalog_id ).
            DATA lts_target TYPE if_fdt_catalog=>ts_catalog_structure.
            CLEAR lts_target.
            lo_target->get_catalog_structure( IMPORTING ets_structure = lts_target ).

            " The link points to a node of the target catalog (by UUID,
            " else by node number); node 0 means the whole catalog.
            DATA(lv_start) = ls_link-node.
            IF ls_link-node_uuid IS NOT INITIAL.
              DATA lv_uuid_node    TYPE if_fdt_catalog=>node_id.
              DATA lv_uuid_unknown TYPE abap_bool.
              CLEAR: lv_uuid_node, lv_uuid_unknown.
              lo_target->get_node_id( EXPORTING iv_node_uuid    = ls_link-node_uuid
                                      IMPORTING ev_node_id      = lv_uuid_node
                                                ev_uuid_unknown = lv_uuid_unknown ).
              IF lv_uuid_unknown = abap_false AND lv_uuid_node IS NOT INITIAL.
                lv_start = lv_uuid_node.
              ENDIF.
            ENDIF.

            append_children( EXPORTING io_catalog     = lo_target
                                       its_structure  = lts_target
                                       iv_catalog_id  = ls_link-catalog_id
                                       iv_parent_node = lv_start
                                       iv_parent_id   = ls_node-node_id
                                       iv_path        = |{ iv_path },{ ls_link-catalog_id }|
                                       iv_depth       = iv_depth + 1
                             CHANGING  ct_node        = ct_node ).
          CATCH cx_fdt_input.
            " Linked catalog cannot be read: link shows without children
        ENDTRY.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD find_decision_table.
    TYPES:
      BEGIN OF ty_hit,
        id TYPE if_fdt_types=>id,
      END OF ty_hit.
    DATA lt_hit TYPE STANDARD TABLE OF ty_hit WITH EMPTY KEY.

    TRY.
        DATA(lo_query) = mo_factory->get_query( iv_object_type = if_fdt_constants=>gc_object_type_expression ).
        lo_query->select_data(
          EXPORTING its_selection    = VALUE #(
                      ( queryfield = if_fdt_admin_data_query=>gc_fn_object_type
                        sign = 'I' option = 'EQ' low = if_fdt_constants=>gc_object_type_expression )
                      ( queryfield = if_fdt_admin_data_query=>gc_fn_name
                        sign = 'I' option = 'EQ' low = iv_name ) )
                    its_result_field = VALUE #( ( queryfield = if_fdt_admin_data_query=>gc_fn_id ) )
          IMPORTING eta_data         = lt_hit ).
      CATCH cx_fdt_input INTO DATA(lx_query).
        RAISE EXCEPTION NEW lcx_error( previous = lx_query ).
    ENDTRY.

    LOOP AT lt_hit INTO DATA(ls_hit).
      DATA(ls_info) = get_object_info( ls_hit-id ).
      IF ls_info-node_type = gc_node_type-decision_table AND ls_info-authorized = abap_true.
        rv_id = ls_hit-id.
        RETURN.
      ENDIF.
    ENDLOOP.

    RAISE EXCEPTION NEW lcx_error(
      iv_text = |{ 'No decision table found that you may display:'(e01) } { iv_name }| ).
  ENDMETHOD.


  METHOD get_header.
    DATA(lo_dt)   = get_dt( iv_id ).
    DATA(ls_info) = get_object_info( iv_id ).
    DATA(ls_app)  = get_app( ls_info-application_id ).

    rs_header = VALUE #( id             = iv_id
                         name           = ls_info-name
                         description    = ls_info-text
                         application_id = ls_info-application_id
                         application    = ls_app-name
                         package        = ls_app-package
                         state          = ls_info-state ).

    TRY.
        DATA lv_change_ts   TYPE timestamp.
        DATA lv_creation_ts TYPE timestamp.
        lo_dt->if_fdt_admin_data~get_change_info(
          IMPORTING ev_change_user        = DATA(lv_change_user)
                    ev_change_timestamp   = lv_change_ts
                    ev_creation_user      = DATA(lv_creation_user)
                    ev_creation_timestamp = lv_creation_ts ).
        rs_header-changed_by = lv_change_user.
        rs_header-created_by = lv_creation_user.
        split_timestamp( EXPORTING iv_ts = lv_creation_ts
                         IMPORTING ev_date = rs_header-created_on ev_time = rs_header-created_time ).
        split_timestamp( EXPORTING iv_ts = lv_change_ts
                         IMPORTING ev_date = rs_header-changed_on ev_time = rs_header-changed_time ).

        lo_dt->get_table_property( IMPORTING ev_multiple_match = DATA(lv_multiple)
                                             ev_allow_no_match = DATA(lv_no_match) ).
        rs_header-multiple_match = lv_multiple.
        rs_header-allow_no_match = lv_no_match.

        DATA lts_column TYPE if_fdt_decision_table=>ts_column.
        DATA lts_data   TYPE if_fdt_decision_table=>ts_table_data.
        lo_dt->get_columns( IMPORTING ets_column = lts_column ).
        lo_dt->get_table_data( IMPORTING ets_data = lts_data ).
        rs_header-column_count = lines( lts_column ).
        LOOP AT lts_data INTO DATA(ls_data).
          rs_header-row_count = nmax( val1 = rs_header-row_count val2 = ls_data-row_no ).
        ENDLOOP.
      CATCH cx_fdt_input INTO DATA(lx_fdt).
        RAISE EXCEPTION NEW lcx_error( previous = lx_fdt ).
    ENDTRY.
  ENDMETHOD.


  METHOD get_contents.
    CLEAR: et_column, et_cell, ev_rows.

    DATA(lo_dt) = get_dt( iv_id ).
    DATA lts_column TYPE if_fdt_decision_table=>ts_column.
    DATA lts_data   TYPE if_fdt_decision_table=>ts_table_data.
    TRY.
        lo_dt->get_columns( IMPORTING ets_column = lts_column ).
        lo_dt->get_table_data( IMPORTING ets_data = lts_data ).
      CATCH cx_fdt_input INTO DATA(lx_fdt).
        RAISE EXCEPTION NEW lcx_error( previous = lx_fdt ).
    ENDTRY.

    " Columns: no limit on the number of columns
    LOOP AT lts_column INTO DATA(ls_column).
      DATA(ls_out) = VALUE ty_column(
        col_no    = ls_column-col_no
        fieldname = |C{ sy-tabix WIDTH = 3 ALIGN = RIGHT PAD = '0' }|
        is_result = ls_column-is_result ).

      TRY.
          DATA lo_instance TYPE REF TO if_fdt_admin_data.
          CLEAR lo_instance.
          cl_fdt_factory=>get_instance_generic( EXPORTING iv_id       = ls_column-object_id
                                                IMPORTING eo_instance = lo_instance ).
          IF lo_instance IS BOUND.
            ls_out-name = lo_instance->get_name( ).
            DATA lv_text TYPE if_fdt_types=>text.
            CLEAR lv_text.
            lo_instance->get_texts( IMPORTING ev_text = lv_text ).
            ls_out-label = COND #( WHEN lv_text IS NOT INITIAL THEN lv_text ELSE ls_out-name ).
            IF lo_instance IS INSTANCE OF if_fdt_data_object.
              ls_out-data_element = CAST if_fdt_data_object( lo_instance )->get_ddic_binding( ).
            ENDIF.
          ENDIF.
        CATCH cx_fdt_input.
          " Keep what we have; the column still shows
      ENDTRY.

      IF ls_out-name IS INITIAL.
        ls_out-name  = |COLUMN_{ ls_column-col_no }|.
        ls_out-label = ls_out-name.
      ENDIF.
      APPEND ls_out TO et_column.
    ENDLOOP.

    " Cells, as text in the same notation as the BRF+ workbench
    LOOP AT lts_data INTO DATA(ls_data).
      ev_rows = nmax( val1 = ev_rows val2 = ls_data-row_no ).
      DATA(lv_cell) = VALUE string( ).
      IF ls_data-ts_range IS NOT INITIAL.
        lv_cell = range_to_text( ls_data-ts_range ).            " condition column
      ELSEIF ls_data-r_value IS BOUND OR ls_data-expression_id IS NOT INITIAL.
        lv_cell = value_to_text( ir_value   = ls_data-r_value    " result column
                                 iv_expr_id = ls_data-expression_id ).
      ENDIF.
      APPEND VALUE #( row_no = ls_data-row_no col_no = ls_data-col_no text = lv_cell ) TO et_cell.
    ENDLOOP.
  ENDMETHOD.


  METHOD get_dt.
    DATA lo_instance TYPE REF TO if_fdt_admin_data.
    DATA lv_unknown  TYPE abap_bool.

    TRY.
        cl_fdt_factory=>get_instance_generic( EXPORTING iv_id         = iv_id
                                              IMPORTING eo_instance   = lo_instance
                                                        ev_id_unknown = lv_unknown ).
      CATCH cx_fdt_input INTO DATA(lx_fdt).
        RAISE EXCEPTION NEW lcx_error( previous = lx_fdt ).
    ENDTRY.

    IF lv_unknown = abap_true OR lo_instance IS NOT BOUND OR
       lo_instance IS NOT INSTANCE OF if_fdt_decision_table.
      RAISE EXCEPTION NEW lcx_error( iv_text = |{ 'Object is not a decision table:'(e02) } { iv_id }| ).
    ENDIF.

    DATA(ls_info) = get_object_info( iv_id ).
    IF ls_info-authorized = abap_false.
      RAISE EXCEPTION NEW lcx_error( iv_text = |{ 'No display authorization for'(e03) } { ls_info-name }| ).
    ENDIF.

    ro_dt = CAST #( lo_instance ).
  ENDMETHOD.


  METHOD get_object_info.
    READ TABLE mt_object INTO rs_info WITH TABLE KEY id = iv_id.
    IF sy-subrc = 0.
      RETURN.
    ENDIF.

    rs_info-id = iv_id.
    DATA lo_instance TYPE REF TO if_fdt_admin_data.
    TRY.
        cl_fdt_factory=>get_instance_generic( EXPORTING iv_id       = iv_id
                                              IMPORTING eo_instance = lo_instance ).
        IF lo_instance IS BOUND.
          rs_info-name           = lo_instance->get_name( ).
          rs_info-object_type    = lo_instance->mv_object_type.
          rs_info-system_object  = lo_instance->mv_system_object.
          rs_info-application_id = lo_instance->get_application( ).
          lo_instance->get_texts( IMPORTING ev_text = rs_info-text ).
          rs_info-state          = get_state( lo_instance ).
          rs_info-node_type      = COND #( WHEN lo_instance IS INSTANCE OF if_fdt_decision_table
                                           THEN gc_node_type-decision_table
                                           ELSE gc_node_type-other_object ).
          rs_info-authorized     = is_authorized( lo_instance ).
        ENDIF.
      CATCH cx_fdt_input.
        rs_info-authorized = abap_false.
    ENDTRY.

    INSERT rs_info INTO TABLE mt_object.
  ENDMETHOD.


  METHOD get_app.
    READ TABLE mt_app INTO rs_app WITH TABLE KEY id = iv_id.
    IF sy-subrc = 0.
      RETURN.
    ENDIF.

    rs_app-id = iv_id.
    TRY.
        DATA(lo_app) = mo_factory->get_application( iv_id ).
        rs_app-name    = lo_app->if_fdt_admin_data~get_name( ).
        rs_app-package = lo_app->get_development_package( ).
      CATCH cx_fdt_input.
    ENDTRY.
    INSERT rs_app INTO TABLE mt_app.
  ENDMETHOD.


  METHOD get_state.
    DATA lv_state      TYPE if_fdt_types=>state.
    DATA lv_no_version TYPE abap_bool.

    io_admin->get_versions( IMPORTING ev_last_db_version_state = lv_state ).
    IF lv_state IS INITIAL.
      " Object without versioning: active if an active version exists
      io_admin->get_active_version( IMPORTING ev_no_version = lv_no_version ).
      lv_state = COND #( WHEN lv_no_version = abap_true THEN if_fdt_constants=>gc_state_inactive
                         ELSE if_fdt_constants=>gc_state_active ).
    ENDIF.
    rv_state = lv_state.
  ENDMETHOD.


  METHOD is_authorized.
    " Standard BRF+ display check (activity 3): application exit, then
    " FDT_OBJECT, or S_DEVELOP for Y/Z applications - same as the workbench.
    TRY.
        rv_ok = io_admin->if_fdt_transaction~authority_check(
                  iv_activity = if_fdt_constants=>gc_activity_display ).
      CATCH cx_fdt_input.
        rv_ok = abap_false.
    ENDTRY.
  ENDMETHOD.


  METHOD range_to_text.
    DATA lt_part TYPE string_table.

    LOOP AT its_range INTO DATA(ls_range) USING KEY position.
      DATA(lv_low)  = value_to_text( ir_value = ls_range-r_low_value  iv_expr_id = ls_range-low ).
      DATA(lv_high) = value_to_text( ir_value = ls_range-r_high_value iv_expr_id = ls_range-high ).
      DATA(lv_part) = option_to_text( iv_option = ls_range-option iv_low = lv_low iv_high = lv_high ).
      IF ls_range-sign = if_fdt_element=>gc_sign_exclude.
        lv_part = |NOT ( { lv_part } )|.
      ENDIF.
      APPEND lv_part TO lt_part.
    ENDLOOP.

    rv_text = concat_lines_of( table = lt_part sep = `; ` ).
  ENDMETHOD.


  METHOD option_to_text.
    rv_text = SWITCH #( iv_option
      WHEN 'EQ' THEN |={ iv_low }|
      WHEN 'NE' THEN |<>{ iv_low }|
      WHEN 'GT' THEN |>{ iv_low }|
      WHEN 'GE' THEN |>={ iv_low }|
      WHEN 'LT' THEN |<{ iv_low }|
      WHEN 'LE' THEN |<={ iv_low }|
      WHEN 'BT' THEN |[{ iv_low }..{ iv_high }]|
      WHEN 'NB' THEN |not [{ iv_low }..{ iv_high }]|
      WHEN 'CP' THEN |matches { iv_low }|
      WHEN 'NP' THEN |not matches { iv_low }|
      WHEN 'CS' THEN |contains { iv_low }|
      WHEN 'NS' THEN |not contains { iv_low }|
      WHEN 'CA' THEN |contains any { iv_low }|
      WHEN 'NA' THEN |contains not any { iv_low }|
      WHEN 'CO' THEN |contains only { iv_low }|
      WHEN 'CN' THEN |contains not only { iv_low }|
      WHEN 'SW' THEN |starts with { iv_low }|
      WHEN 'US' THEN |not starts with { iv_low }|
      WHEN 'EW' THEN |ends with { iv_low }|
      WHEN 'DE' THEN |not ends with { iv_low }|
      WHEN 'I1' THEN `is initial`
      WHEN 'I2' THEN `is not initial`
      WHEN 'S1' THEN `is supplied`
      WHEN 'S2' THEN `is not supplied`
      WHEN 'IV' THEN `is valid`
      WHEN 'NV' THEN `is not valid`
      WHEN 'CE' THEN |currency = { iv_low }|
      WHEN 'CD' THEN |currency <> { iv_low }|
      WHEN 'UE' THEN |unit = { iv_low }|
      WHEN 'UD' THEN |unit <> { iv_low }|
      ELSE           |{ iv_option } { iv_low }| ).
  ENDMETHOD.


  METHOD value_to_text.
    IF ir_value IS BOUND.
      ASSIGN ir_value->* TO FIELD-SYMBOL(<lv_value>).
      IF sy-subrc = 0.
        DATA(lo_type) = cl_abap_typedescr=>describe_by_data( <lv_value> ).
        IF lo_type->kind = cl_abap_typedescr=>kind_struct.
          " Amount, quantity, timepoint: join the non-initial components
          DATA lt_part TYPE string_table.
          DO.
            ASSIGN COMPONENT sy-index OF STRUCTURE <lv_value> TO FIELD-SYMBOL(<lv_comp>).
            IF sy-subrc <> 0.
              EXIT.
            ENDIF.
            IF <lv_comp> IS NOT INITIAL.
              APPEND condense( CONV string( <lv_comp> ) ) TO lt_part.
            ENDIF.
          ENDDO.
          rv_text = concat_lines_of( table = lt_part sep = ` ` ).
        ELSEIF lo_type->kind = cl_abap_typedescr=>kind_elem.
          rv_text = condense( |{ <lv_value> }| ).
        ENDIF.
      ENDIF.
      RETURN.
    ENDIF.

    " No literal value: the cell refers to another BRF+ object
    IF iv_expr_id IS NOT INITIAL.
      DATA(ls_ref) = get_object_info( iv_expr_id ).
      rv_text = |[{ COND string( WHEN ls_ref-name IS NOT INITIAL THEN ls_ref-name ELSE iv_expr_id ) }]|.
    ENDIF.
  ENDMETHOD.


  METHOD split_timestamp.
    CLEAR: ev_date, ev_time.
    IF iv_ts IS INITIAL.
      RETURN.
    ENDIF.
    DATA(lv_tz) = COND tznzone( WHEN sy-zonlo IS NOT INITIAL THEN sy-zonlo ELSE 'UTC' ).
    CONVERT TIME STAMP iv_ts TIME ZONE lv_tz INTO DATE ev_date TIME ev_time.
  ENDMETHOD.

ENDCLASS.


*----------------------------------------------------------------------*
* Screen: tree on the left, General + contents on the right
*----------------------------------------------------------------------*
CLASS lcl_app DEFINITION FINAL.
  PUBLIC SECTION.
    CONSTANTS gc_cell_length TYPE i VALUE 255.

    METHODS constructor
      IMPORTING it_catalog TYPE lcl_reader=>ty_name_range
                iv_dt_name TYPE if_fdt_types=>name.
    METHODS build_ui.
    METHODS free_ui.

  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_tree_out,
        tech        TYPE icon_d,
        status      TYPE icon_d,
        status_text TYPE c LENGTH 10,
        object_type TYPE c LENGTH 20,
        description TYPE c LENGTH 80,
      END OF ty_tree_out,
      tt_tree_out TYPE STANDARD TABLE OF ty_tree_out WITH EMPTY KEY.

    TYPES:
      BEGIN OF ty_key_map,
        node_key  TYPE salv_de_node_key,
        node_type TYPE c LENGTH 2,
        object_id TYPE if_fdt_types=>id,
      END OF ty_key_map,
      tt_key_map TYPE HASHED TABLE OF ty_key_map WITH UNIQUE KEY node_key.

    TYPES:
      BEGIN OF ty_general,
        field TYPE c LENGTH 30,
        value TYPE c LENGTH 132,
      END OF ty_general,
      tt_general TYPE STANDARD TABLE OF ty_general WITH EMPTY KEY.

    CONSTANTS gc_fc_refresh TYPE ui_func VALUE 'ZREFRESH'.

    DATA mt_catalog    TYPE lcl_reader=>ty_name_range.
    DATA mv_dt_name    TYPE if_fdt_types=>name.
    DATA mo_reader     TYPE REF TO lcl_reader.
    DATA mt_node       TYPE lcl_reader=>tt_node.
    DATA mt_key_map    TYPE tt_key_map.
    DATA mv_current_dt TYPE if_fdt_types=>id.

    DATA mo_dock       TYPE REF TO cl_gui_docking_container.
    DATA mo_split_main TYPE REF TO cl_gui_splitter_container.
    DATA mo_split_right TYPE REF TO cl_gui_splitter_container.
    DATA mo_cont_gen   TYPE REF TO cl_gui_container.
    DATA mo_cont_grid  TYPE REF TO cl_gui_container.

    DATA mo_tree       TYPE REF TO cl_salv_tree.
    DATA mt_tree_out   TYPE tt_tree_out.
    DATA mo_general    TYPE REF TO cl_salv_table.
    DATA mt_general    TYPE tt_general.
    DATA mo_grid       TYPE REF TO cl_gui_alv_grid.
    DATA mr_contents   TYPE REF TO data.

    METHODS build_tree
      IMPORTING io_container TYPE REF TO cl_gui_container.
    METHODS add_children
      IMPORTING iv_parent_id  TYPE lcl_reader=>ty_node-node_id
                iv_parent_key TYPE salv_de_node_key
                io_nodes      TYPE REF TO cl_salv_nodes
      RAISING   cx_salv_msg.
    METHODS build_general
      IMPORTING io_container TYPE REF TO cl_gui_container.
    METHODS show_decision_table
      IMPORTING iv_id TYPE if_fdt_types=>id.
    METHODS fill_general
      IMPORTING is_header TYPE lcl_reader=>ty_header.
    METHODS show_contents
      IMPORTING is_header TYPE lcl_reader=>ty_header
      RAISING   lcx_error.

    METHODS on_tree_double_click FOR EVENT double_click OF cl_salv_events_tree
      IMPORTING node_key.
    METHODS on_grid_toolbar FOR EVENT toolbar OF cl_gui_alv_grid
      IMPORTING e_object.
    METHODS on_grid_command FOR EVENT user_command OF cl_gui_alv_grid
      IMPORTING e_ucomm.
ENDCLASS.


CLASS lcl_app IMPLEMENTATION.

  METHOD constructor.
    mt_catalog = it_catalog.
    mv_dt_name = iv_dt_name.
    mo_reader  = NEW #( ).
  ENDMETHOD.


  METHOD build_ui.
    IF mo_dock IS BOUND.
      RETURN.
    ENDIF.

    " Docking container that fills the whole screen 9000
    mo_dock = NEW #( repid     = sy-repid
                     dynnr     = '9000'
                     side      = cl_gui_docking_container=>dock_at_left
                     extension = 5000 ).

    mo_split_main = NEW #( parent = mo_dock rows = 1 columns = 2 ).
    mo_split_main->set_column_width( id = 1 width = 30 ).

*   General section switched off for now: the table contents use the
*   whole right side. Uncomment these lines (and FILL_GENERAL in
*   SHOW_DECISION_TABLE) to bring it back.
*    mo_split_right = NEW #( parent = mo_split_main->get_container( row = 1 column = 2 )
*                            rows = 2 columns = 1 ).
*    mo_split_right->set_row_height( id = 1 height = 30 ).   " General section; drag the bar to resize
*    mo_cont_gen  = mo_split_right->get_container( row = 1 column = 1 ).
*    mo_cont_grid = mo_split_right->get_container( row = 2 column = 1 ).
    mo_cont_grid = mo_split_main->get_container( row = 1 column = 2 ).

    build_tree( mo_split_main->get_container( row = 1 column = 1 ) ).
*    build_general( mo_cont_gen ).

    " Optional: open a decision table straight away
    IF mv_dt_name IS NOT INITIAL.
      TRY.
          show_decision_table( mo_reader->find_decision_table( mv_dt_name ) ).
        CATCH lcx_error INTO DATA(lx_error).
          DATA(lv_msg_error) = lx_error->get_text( ).
        MESSAGE lv_msg_error TYPE 'S' DISPLAY LIKE 'E'.
      ENDTRY.
    ENDIF.
  ENDMETHOD.


  METHOD free_ui.
    IF mo_grid IS BOUND.
      mo_grid->free( ).
    ENDIF.
    IF mo_dock IS BOUND.
      mo_dock->free( ).
    ENDIF.
    CLEAR: mo_grid, mo_tree, mo_general, mo_dock, mo_split_main, mo_split_right,
           mo_cont_gen, mo_cont_grid, mt_key_map, mt_tree_out, mt_general, mv_current_dt.
  ENDMETHOD.


  METHOD build_tree.
    TRY.
        mt_node = mo_reader->get_catalog_nodes( mt_catalog ).
      CATCH lcx_error INTO DATA(lx_error).
        DATA(lv_msg_error) = lx_error->get_text( ).
        MESSAGE lv_msg_error TYPE 'S' DISPLAY LIKE 'E'.
    ENDTRY.

    TRY.
        CLEAR mt_tree_out.
        cl_salv_tree=>factory( EXPORTING r_container = io_container
                               IMPORTING r_salv_tree = mo_tree
                               CHANGING  t_table     = mt_tree_out ).

        DATA(lo_settings) = mo_tree->get_tree_settings( ).
        lo_settings->set_hierarchy_header( CONV #( 'Catalog Structure'(h01) ) ).
        lo_settings->set_hierarchy_size( 40 ).

        DATA(lo_columns) = mo_tree->get_columns( ).
        lo_columns->set_optimize( abap_true ).

        DATA(lo_col) = CAST cl_salv_column_tree( lo_columns->get_column( 'TECH' ) ).
        lo_col->set_icon( if_salv_c_bool_sap=>true ).
        lo_col->set_short_text( CONV #( 'H'(h02) ) ).
        lo_col->set_medium_text( CONV #( 'Technical'(h03) ) ).
        lo_col->set_long_text( CONV #( 'Technical (link / system object)'(h04) ) ).
        lo_col->set_output_length( 3 ).

        lo_col = CAST cl_salv_column_tree( lo_columns->get_column( 'STATUS' ) ).
        lo_col->set_icon( if_salv_c_bool_sap=>true ).
        lo_col->set_short_text( CONV #( 'Status'(h05) ) ).
        lo_col->set_medium_text( CONV #( 'Status'(h05) ) ).
        lo_col->set_long_text( CONV #( 'Status'(h05) ) ).
        lo_col->set_output_length( 4 ).

        lo_col = CAST cl_salv_column_tree( lo_columns->get_column( 'STATUS_TEXT' ) ).
        lo_col->set_short_text( CONV #( 'State'(h06) ) ).
        lo_col->set_medium_text( CONV #( 'State'(h06) ) ).
        lo_col->set_long_text( CONV #( 'State'(h06) ) ).

        lo_col = CAST cl_salv_column_tree( lo_columns->get_column( 'OBJECT_TYPE' ) ).
        lo_col->set_short_text( CONV #( 'Type'(h07) ) ).
        lo_col->set_medium_text( CONV #( 'Type'(h07) ) ).
        lo_col->set_long_text( CONV #( 'Type'(h07) ) ).

        lo_col = CAST cl_salv_column_tree( lo_columns->get_column( 'DESCRIPTION' ) ).
        lo_col->set_short_text( CONV #( 'Descr.'(h08) ) ).
        lo_col->set_medium_text( CONV #( 'Description'(h09) ) ).
        lo_col->set_long_text( CONV #( 'Description'(h09) ) ).

        " Standard functions: expand/collapse, find, print, layout ...
        mo_tree->get_functions( )->set_all( abap_true ).

        DATA(lo_nodes) = mo_tree->get_nodes( ).
        add_children( iv_parent_id = '' iv_parent_key = '' io_nodes = lo_nodes ).

        SET HANDLER on_tree_double_click FOR mo_tree->get_event( ).

        mo_tree->display( ).
      CATCH cx_salv_error INTO DATA(lx_salv).
        MESSAGE lx_salv TYPE 'S' DISPLAY LIKE 'E'.
    ENDTRY.

    IF mt_node IS INITIAL.
      MESSAGE 'No catalogs found or no display authorization'(m01) TYPE 'S' DISPLAY LIKE 'W'.
    ENDIF.
  ENDMETHOD.


  METHOD add_children.
    " Recursive, so a parent is always added before its children,
    " whatever order GET_CATALOG_STRUCTURE returns.
    DATA(lt_children) = VALUE lcl_reader=>tt_node(
      FOR ls IN mt_node WHERE ( parent_id = iv_parent_id ) ( ls ) ).
    SORT lt_children BY seqnr.

    LOOP AT lt_children INTO DATA(ls_node).
      DATA(lv_folder) = xsdbool( ls_node-node_type = lcl_reader=>gc_node_type-catalog OR
                                 ls_node-node_type = lcl_reader=>gc_node_type-folder ).
      DATA(lv_icon) = SWITCH salv_de_tree_image( ls_node-node_type
                        WHEN lcl_reader=>gc_node_type-catalog        THEN icon_catalog
                        WHEN lcl_reader=>gc_node_type-decision_table THEN icon_list
                        WHEN lcl_reader=>gc_node_type-link           THEN icon_link
                        WHEN lcl_reader=>gc_node_type-other_object   THEN icon_document ).

      DATA(ls_out) = VALUE ty_tree_out(
        tech        = COND #( WHEN ls_node-is_technical = abap_true THEN icon_link )
        status      = SWITCH #( ls_node-state
                        WHEN if_fdt_constants=>gc_state_active   THEN icon_led_green
                        WHEN if_fdt_constants=>gc_state_inactive THEN icon_led_yellow )
        status_text = SWITCH #( ls_node-state
                        WHEN if_fdt_constants=>gc_state_active   THEN 'Active'(s01)
                        WHEN if_fdt_constants=>gc_state_inactive THEN 'Inactive'(s02) )
        object_type = SWITCH #( ls_node-node_type
                        WHEN lcl_reader=>gc_node_type-catalog        THEN 'Catalog'(t02)
                        WHEN lcl_reader=>gc_node_type-folder         THEN 'Folder'(t03)
                        WHEN lcl_reader=>gc_node_type-decision_table THEN 'Decision Table'(t04)
                        WHEN lcl_reader=>gc_node_type-link           THEN 'Link'(t05)
                        ELSE                                              'BRF+ Object'(t06) )
        description = ls_node-description ).

      DATA(lo_node) = io_nodes->add_node(
        related_node   = iv_parent_key
        relationship   = cl_gui_column_tree=>relat_last_child
        data_row       = ls_out
        text           = CONV #( ls_node-name )
        folder         = lv_folder
        collapsed_icon = lv_icon
        expanded_icon  = lv_icon ).

      DATA(lv_key) = lo_node->get_key( ).
      INSERT VALUE #( node_key  = lv_key
                      node_type = ls_node-node_type
                      object_id = ls_node-object_id ) INTO TABLE mt_key_map.

      add_children( iv_parent_id = ls_node-node_id iv_parent_key = lv_key io_nodes = io_nodes ).
    ENDLOOP.
  ENDMETHOD.


  METHOD build_general.
    TRY.
        CLEAR mt_general.
        cl_salv_table=>factory( EXPORTING r_container  = io_container
                                IMPORTING r_salv_table = mo_general
                                CHANGING  t_table      = mt_general ).
        mo_general->get_display_settings( )->set_list_header( CONV #( 'General'(g00) ) ).
        mo_general->get_display_settings( )->set_striped_pattern( abap_true ).

        DATA(lo_columns) = mo_general->get_columns( ).
        DATA(lo_col) = lo_columns->get_column( 'FIELD' ).
        lo_col->set_short_text( CONV #( 'Field'(g01) ) ).
        lo_col->set_medium_text( CONV #( 'Field'(g01) ) ).
        lo_col->set_long_text( CONV #( 'Field'(g01) ) ).
        lo_col->set_output_length( 22 ).
        lo_col = lo_columns->get_column( 'VALUE' ).
        lo_col->set_short_text( CONV #( 'Value'(g02) ) ).
        lo_col->set_medium_text( CONV #( 'Value'(g02) ) ).
        lo_col->set_long_text( CONV #( 'Value'(g02) ) ).
        lo_col->set_output_length( 80 ).

        mo_general->display( ).
      CATCH cx_salv_error INTO DATA(lx_salv).
        MESSAGE lx_salv TYPE 'S' DISPLAY LIKE 'E'.
    ENDTRY.
  ENDMETHOD.


  METHOD on_tree_double_click.
    READ TABLE mt_key_map INTO DATA(ls_map) WITH TABLE KEY node_key = node_key.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.
    IF ls_map-node_type <> lcl_reader=>gc_node_type-decision_table.
      MESSAGE 'Double-click a decision table to see its contents'(m02) TYPE 'S'.
      RETURN.
    ENDIF.
    show_decision_table( ls_map-object_id ).
    cl_gui_cfw=>flush( ).
  ENDMETHOD.


  METHOD show_decision_table.
    TRY.
        DATA(ls_header) = mo_reader->get_header( iv_id ).
*        fill_general( ls_header ).      " General section switched off for now
        show_contents( ls_header ).
        mv_current_dt = iv_id.
      CATCH lcx_error INTO DATA(lx_error).
        DATA(lv_msg_error) = lx_error->get_text( ).
        MESSAGE lv_msg_error TYPE 'S' DISPLAY LIKE 'E'.
    ENDTRY.
  ENDMETHOD.


  METHOD fill_general.
    DATA(lv_yes) = CONV string( 'Yes'(y01) ).
    DATA(lv_no)  = CONV string( 'No'(y02) ).

    mt_general = VALUE #(
      ( field = 'Decision Table'(f01)  value = is_header-name )
      ( field = 'Description'(f02)     value = is_header-description )
      ( field = 'ID'(f03)              value = is_header-id )
      ( field = 'Application'(f04)     value = is_header-application )
      ( field = 'Package'(f05)         value = is_header-package )
      ( field = 'Created by'(f06)      value = is_header-created_by )
      ( field = 'Created on'(f07)      value = |{ is_header-created_on DATE = USER } { is_header-created_time TIME = USER }| )
      ( field = 'Changed by'(f08)      value = is_header-changed_by )
      ( field = 'Changed on'(f09)      value = |{ is_header-changed_on DATE = USER } { is_header-changed_time TIME = USER }| )
      ( field = 'Status'(f10)          value = SWITCH #( is_header-state
                                                   WHEN if_fdt_constants=>gc_state_active THEN 'Active'(s01)
                                                   ELSE 'Inactive'(s02) ) )
      ( field = 'Rows / Columns'(f11)  value = |{ is_header-row_count } / { is_header-column_count }| )
      ( field = 'Multiple match'(f12)  value = COND #( WHEN is_header-multiple_match = abap_true THEN lv_yes ELSE lv_no ) )
      ( field = 'Allow no match'(f13)  value = COND #( WHEN is_header-allow_no_match = abap_true THEN lv_yes ELSE lv_no ) ) ).

    mo_general->refresh( refresh_mode = if_salv_c_refresh=>full ).
  ENDMETHOD.


  METHOD show_contents.
    DATA lt_column TYPE lcl_reader=>tt_column.
    DATA lt_cell   TYPE lcl_reader=>tt_cell.
    DATA lv_rows   TYPE i.

    mo_reader->get_contents( EXPORTING iv_id     = is_header-id
                             IMPORTING et_column = lt_column
                                       et_cell   = lt_cell
                                       ev_rows   = lv_rows ).

    " 1. Output table built at runtime: ROW_NO + one text field per column
    DATA(lt_comp) = VALUE cl_abap_structdescr=>component_table(
      ( name = 'ROW_NO' type = cl_abap_elemdescr=>get_i( ) ) ).
    DATA(lo_cell_type) = cl_abap_elemdescr=>get_c( gc_cell_length ).
    LOOP AT lt_column INTO DATA(ls_column).
      APPEND VALUE #( name = ls_column-fieldname type = lo_cell_type ) TO lt_comp.
    ENDLOOP.
    DATA(lo_table_type) = cl_abap_tabledescr=>create(
      p_line_type = cl_abap_structdescr=>create( lt_comp ) ).

    FIELD-SYMBOLS <lt_contents> TYPE STANDARD TABLE.
    FIELD-SYMBOLS <ls_row>      TYPE any.
    FIELD-SYMBOLS <lv_row_no>   TYPE any.
    FIELD-SYMBOLS <lv_cell>     TYPE any.

    CREATE DATA mr_contents TYPE HANDLE lo_table_type.
    ASSIGN mr_contents->* TO <lt_contents>.

    DO lv_rows TIMES.
      APPEND INITIAL LINE TO <lt_contents> ASSIGNING <ls_row>.
      ASSIGN COMPONENT 'ROW_NO' OF STRUCTURE <ls_row> TO <lv_row_no>.
      <lv_row_no> = sy-index.
    ENDDO.

    TYPES: BEGIN OF ty_col_map,
             col_no    TYPE i,
             fieldname TYPE lvc_fname,
           END OF ty_col_map.
    DATA lt_col_map TYPE HASHED TABLE OF ty_col_map WITH UNIQUE KEY col_no.
    lt_col_map = CORRESPONDING #( lt_column ).

    LOOP AT lt_cell INTO DATA(ls_cell).
      READ TABLE lt_col_map INTO DATA(ls_map) WITH TABLE KEY col_no = ls_cell-col_no.
      CHECK sy-subrc = 0.
      READ TABLE <lt_contents> ASSIGNING <ls_row> INDEX ls_cell-row_no.
      CHECK sy-subrc = 0.
      ASSIGN COMPONENT ls_map-fieldname OF STRUCTURE <ls_row> TO <lv_cell>.
      CHECK sy-subrc = 0.
      <lv_cell> = ls_cell-text.
    ENDLOOP.

    " 2. Field catalog from the decision table columns
    DATA lt_fcat TYPE lvc_t_fcat.
    APPEND VALUE #( fieldname = 'ROW_NO' inttype = 'I' intlen = 10 outputlen = 5 key = abap_true
                    coltext = 'Row'(c01) scrtext_s = 'Row'(c01) scrtext_m = 'Row'(c01) scrtext_l = 'Row'(c01) )
           TO lt_fcat.
    LOOP AT lt_column INTO ls_column.
      DATA(lv_label) = CONV lvc_txtcol( ls_column-label ).
      APPEND VALUE #( fieldname = ls_column-fieldname
                      inttype   = 'C'
                      intlen    = gc_cell_length
                      outputlen = 25
                      coltext   = lv_label
                      scrtext_s = lv_label
                      scrtext_m = lv_label
                      scrtext_l = lv_label
                      reptext   = lv_label
                      tooltip   = |{ ls_column-name }{ COND #( WHEN ls_column-data_element IS NOT INITIAL
                                                               THEN | ({ ls_column-data_element })| ) }|
                      emphasize = COND #( WHEN ls_column-is_result = abap_true THEN 'C510' ) )  " green = result
             TO lt_fcat.
    ENDLOOP.

    " 3. Layout: read only, zebra, optimised widths, title with the table name
    DATA(ls_layout) = VALUE lvc_s_layo(
      zebra      = abap_true
      cwidth_opt = abap_true
      sel_mode   = 'A'
      no_rowmark = abap_false
      grid_title = |{ 'Table Contents'(c02) }: { is_header-name } - { is_header-description }| ).

    " Layouts (variants) are saved per decision table
    " (DISVARIANT-REPORT is 40 characters: short prefix + 30-character BRF+ name)
    DATA(ls_variant) = VALUE disvariant( report = |ZBRFDT:{ is_header-name }| ).

    " Columns differ per decision table: rebuild the grid each time
    IF mo_grid IS BOUND.
      mo_grid->free( ).
      CLEAR mo_grid.
    ENDIF.
    mo_grid = NEW #( i_parent = mo_cont_grid ).
    SET HANDLER on_grid_toolbar on_grid_command FOR mo_grid.

    " Display only: no editing functions offered
    DATA(lt_exclude) = VALUE ui_functions(
      ( cl_gui_alv_grid=>mc_fc_loc_append_row ) ( cl_gui_alv_grid=>mc_fc_loc_copy )
      ( cl_gui_alv_grid=>mc_fc_loc_copy_row )   ( cl_gui_alv_grid=>mc_fc_loc_cut )
      ( cl_gui_alv_grid=>mc_fc_loc_delete_row ) ( cl_gui_alv_grid=>mc_fc_loc_insert_row )
      ( cl_gui_alv_grid=>mc_fc_loc_move_row )   ( cl_gui_alv_grid=>mc_fc_loc_paste )
      ( cl_gui_alv_grid=>mc_fc_loc_paste_new_row ) ( cl_gui_alv_grid=>mc_fc_loc_undo )
      ( cl_gui_alv_grid=>mc_fc_check )          ( cl_gui_alv_grid=>mc_fc_refresh ) ).

    mo_grid->set_table_for_first_display(
      EXPORTING is_layout            = ls_layout
                is_variant           = ls_variant
                i_save               = 'A'
                it_toolbar_excluding = lt_exclude
      CHANGING  it_outtab            = <lt_contents>
                it_fieldcatalog      = lt_fcat
      EXCEPTIONS OTHERS              = 1 ).
    IF sy-subrc <> 0.
      RAISE EXCEPTION NEW lcx_error( iv_text = CONV #( 'The table could not be displayed'(m03) ) ).
    ENDIF.
  ENDMETHOD.


  METHOD on_grid_toolbar.
    " Own Refresh button: reads the decision table again from BRF+
    APPEND VALUE #( butn_type = 3 ) TO e_object->mt_toolbar.
    APPEND VALUE #( function  = gc_fc_refresh
                    icon      = icon_refresh
                    quickinfo = 'Read the decision table again'(q01) ) TO e_object->mt_toolbar.
  ENDMETHOD.


  METHOD on_grid_command.
    IF e_ucomm = gc_fc_refresh AND mv_current_dt IS NOT INITIAL.
      show_decision_table( mv_current_dt ).
    ENDIF.
  ENDMETHOD.

ENDCLASS.


*----------------------------------------------------------------------*
* Events
*----------------------------------------------------------------------*
DATA go_app  TYPE REF TO lcl_app.
DATA gt_excl TYPE STANDARD TABLE OF sy-ucomm WITH EMPTY KEY.

AT SELECTION-SCREEN OUTPUT.
  IF sy-dynnr = '9000'.
    " Hide Execute/Print/Background on the viewer screen; only Back/Exit/Cancel stay
    gt_excl = VALUE #( ( 'ONLI' ) ( 'PRIN' ) ( 'SJOB' ) ( 'SPOS' ) ).
    CALL FUNCTION 'RS_SET_SELSCREEN_STATUS'
      EXPORTING p_status  = '%_00'
                p_program = 'RSSYSTDB'
      TABLES    p_exclude = gt_excl.
    LOOP AT SCREEN.
      screen-active = '0'.   " hide the dummy comment line
      MODIFY SCREEN.
    ENDLOOP.
    IF go_app IS BOUND.
      go_app->build_ui( ).
    ENDIF.
  ENDIF.

AT SELECTION-SCREEN.
  IF sy-dynnr = '9000'.
    cl_gui_cfw=>dispatch( ).
  ENDIF.

START-OF-SELECTION.
  go_app = NEW #( it_catalog = s_cat[] iv_dt_name = p_dt ).
  CALL SELECTION-SCREEN 9000.
  " Back from the viewer: release the controls, return to the selection screen
  go_app->free_ui( ).
  FREE go_app.
