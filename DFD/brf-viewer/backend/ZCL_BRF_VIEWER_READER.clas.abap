*----------------------------------------------------------------------*
* Change log
* Date       | Author              | Description
* 2026-11-16 | Srilakshmi Sreevari | Initial version
* 2026-11-16 | Srilakshmi Sreevari | Follow catalog links (as in report
*            |                     | ZBRF_DT_VIEWER); node IDs are now
*            |                     | <parent>/<node>, child counts computed
*----------------------------------------------------------------------*
"! Read-only access to BRF+ catalogs and decision tables through the
"! public FDT API (CL_FDT_FACTORY, IF_FDT_CATALOG, IF_FDT_DECISION_TABLE).
"! No FDT repository table is read directly and no FDT object is ever
"! locked, changed, saved or activated by this class.
CLASS zcl_brf_viewer_reader DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    "! Number of generic value slots in ZI_BRF_DTRow (C01..C40)
    CONSTANTS gc_max_slots TYPE i VALUE 40.

    CONSTANTS:
      BEGIN OF gc_node_type,
        catalog        TYPE c LENGTH 2 VALUE 'CA',
        folder         TYPE c LENGTH 2 VALUE 'FO',
        decision_table TYPE c LENGTH 2 VALUE 'DT',
        other_object   TYPE c LENGTH 2 VALUE 'OB',
        link           TYPE c LENGTH 2 VALUE 'LI',
      END OF gc_node_type.

    TYPES tt_node   TYPE STANDARD TABLE OF zi_brf_catalognode WITH EMPTY KEY.
    TYPES tt_column TYPE STANDARD TABLE OF zi_brf_dtcolumn WITH EMPTY KEY.
    TYPES tt_row    TYPE STANDARD TABLE OF zi_brf_dtrow WITH EMPTY KEY.

    METHODS constructor.

    "! Catalog tree nodes.
    "! @parameter iv_catalog_id | only this catalog (empty = all catalogs)
    "! @parameter iv_roots_only | only the catalog root nodes (fast first load)
    METHODS get_catalog_nodes
      IMPORTING iv_catalog_id  TYPE if_fdt_types=>id OPTIONAL
                iv_roots_only  TYPE abap_bool DEFAULT abap_false
      RETURNING VALUE(rt_node) TYPE tt_node
      RAISING   zcx_brf_viewer.

    METHODS get_decision_table
      IMPORTING iv_id            TYPE if_fdt_types=>id
      RETURNING VALUE(rs_header) TYPE zi_brf_decisiontable
      RAISING   zcx_brf_viewer.

    METHODS get_columns
      IMPORTING iv_id            TYPE if_fdt_types=>id
      RETURNING VALUE(rt_column) TYPE tt_column
      RAISING   zcx_brf_viewer.

    METHODS get_rows
      IMPORTING iv_id         TYPE if_fdt_types=>id
      RETURNING VALUE(rt_row) TYPE tt_row
      RAISING   zcx_brf_viewer.

  PROTECTED SECTION.
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

    DATA mo_factory    TYPE REF TO if_fdt_factory.
    DATA mt_object     TYPE tt_object_info.
    DATA mt_app        TYPE tt_app.

    METHODS get_object_info
      IMPORTING iv_id          TYPE if_fdt_types=>id
      RETURNING VALUE(rs_info) TYPE ty_object_info.

    "! Adds the children of IV_PARENT_NODE (initial = catalog root).
    "! A link node is followed into the linked catalog (to the linked
    "! node, or the whole catalog), so its contents show under the link.
    "! IV_PATH holds the catalogs already on the way down (no loops).
    METHODS append_children
      IMPORTING io_catalog           TYPE REF TO if_fdt_catalog
                its_structure        TYPE if_fdt_catalog=>ts_catalog_structure
                iv_parent_node       TYPE if_fdt_catalog=>node_id
                iv_parent_id         TYPE string
                iv_root_catalog_id   TYPE if_fdt_types=>id
                iv_root_catalog_name TYPE string
                iv_level             TYPE i
                iv_path              TYPE string
                iv_depth             TYPE i
      CHANGING  ct_node              TYPE tt_node.

    METHODS set_child_counts
      CHANGING ct_node TYPE tt_node.

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
      RAISING   zcx_brf_viewer.

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

    METHODS criticality
      IMPORTING iv_state       TYPE char1
      RETURNING VALUE(rv_crit) TYPE int1.
ENDCLASS.



CLASS zcl_brf_viewer_reader IMPLEMENTATION.

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

    " 1. Find the catalogs through the BRF+ query API
    TRY.
        DATA(lo_query) = mo_factory->get_query( iv_object_type = if_fdt_constants=>gc_object_type_catalog ).
        DATA(lts_selection) = VALUE if_fdt_query=>ts_selection(
          ( queryfield = if_fdt_admin_data_query=>gc_fn_object_type
            sign = 'I' option = 'EQ' low = if_fdt_constants=>gc_object_type_catalog ) ).
        IF iv_catalog_id IS NOT INITIAL.
          INSERT VALUE #( queryfield = if_fdt_admin_data_query=>gc_fn_id
                          sign = 'I' option = 'EQ' low = iv_catalog_id ) INTO TABLE lts_selection.
        ENDIF.
        DATA(lts_result_field) = VALUE if_fdt_query=>ts_queryfield(
          ( queryfield = if_fdt_admin_data_query=>gc_fn_id )
          ( queryfield = if_fdt_admin_data_query=>gc_fn_name )
          ( queryfield = if_fdt_admin_data_query=>gc_fn_application_id ) ).
        lo_query->select_data( EXPORTING its_selection    = lts_selection
                                         its_result_field = lts_result_field
                               IMPORTING eta_data         = lt_catalog ).
      CATCH cx_fdt_input INTO DATA(lx_query).
        RAISE EXCEPTION NEW zcx_brf_viewer( previous = lx_query ).
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
      DATA(lv_root_id) = CONV zi_brf_catalognode-nodeid( ls_catalog-id ).
      DATA(lv_root_children) = 0.
      LOOP AT lts_structure TRANSPORTING NO FIELDS WHERE parent IS INITIAL.
        lv_root_children += 1.
      ENDLOOP.
      APPEND VALUE #( nodeid            = lv_root_id
                      catalogid         = ls_catalog-id
                      catalogname       = ls_catalog-name
                      nodetype          = gc_node_type-catalog
                      name              = ls_catalog-name
                      description       = ls_cat_info-text
                      objectid          = ls_catalog-id
                      objecttype        = if_fdt_constants=>gc_object_type_catalog
                      status            = ls_cat_info-state
                      statuscriticality = criticality( ls_cat_info-state )
                      hierarchylevel    = 0
                      childcount        = lv_root_children
                      seqnr             = sy-tabix
                      istechnical       = ls_cat_info-system_object ) TO rt_node.

      IF iv_roots_only = abap_true OR lo_catalog IS NOT BOUND.
        CONTINUE.
      ENDIF.

*     Replaced: links were shown as end nodes, so linked catalogs had no children
*      " Child nodes: folders, leaves (objects) and links
*      LOOP AT lts_structure INTO DATA(ls_struct).
*        DATA(ls_node) = VALUE zi_brf_catalognode(
*          nodeid       = |{ ls_catalog-id }:{ ls_struct-node }|
*          parentnodeid = COND #( WHEN ls_struct-parent IS INITIAL THEN lv_root_id
*                                 ELSE |{ ls_catalog-id }:{ ls_struct-parent }| )
*          catalogid    = ls_catalog-id
*          catalogname  = ls_catalog-name
*          name         = ls_struct-node_name
*          seqnr        = ls_struct-seqnr ).
*
*        " Hierarchy level: walk up the parent chain
*        DATA(lv_parent) = ls_struct-parent.
*        ls_node-hierarchylevel = 1.
*        WHILE lv_parent IS NOT INITIAL AND ls_node-hierarchylevel < 50.
*          READ TABLE lts_structure INTO DATA(ls_up) WITH KEY node = lv_parent.
*          IF sy-subrc <> 0.
*            EXIT.
*          ENDIF.
*          lv_parent = ls_up-parent.
*          ls_node-hierarchylevel += 1.
*        ENDWHILE.
*
*        " Number of direct children
*        LOOP AT lts_structure TRANSPORTING NO FIELDS WHERE parent = ls_struct-node.
*          ls_node-childcount += 1.
*        ENDLOOP.
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
*            ls_node-nodetype = gc_node_type-folder.
*
*          WHEN if_fdt_catalog=>gc_node_type_link.
*            ls_node-nodetype    = gc_node_type-link.
*            ls_node-istechnical = abap_true.
*
*          WHEN OTHERS. " leaf = a BRF+ object
*            IF lv_object_id IS INITIAL.
*              ls_node-nodetype = gc_node_type-other_object.
*            ELSE.
*              DATA(ls_obj) = get_object_info( lv_object_id ).
*              IF ls_obj-authorized = abap_false.
*                CONTINUE.   " hide objects the user may not display
*              ENDIF.
*              ls_node-nodetype          = ls_obj-node_type.
*              ls_node-objectid          = ls_obj-id.
*              ls_node-objecttype        = ls_obj-object_type.
*              ls_node-status            = ls_obj-state.
*              ls_node-statuscriticality = criticality( ls_obj-state ).
*              ls_node-istechnical       = ls_obj-system_object.
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
      append_children( EXPORTING io_catalog           = lo_catalog
                                 its_structure        = lts_structure
                                 iv_parent_node       = VALUE #( )
                                 iv_parent_id         = CONV #( lv_root_id )
                                 iv_root_catalog_id   = ls_catalog-id
                                 iv_root_catalog_name = CONV #( ls_catalog-name )
                                 iv_level             = 1
                                 iv_path              = CONV #( ls_catalog-id )
                                 iv_depth             = 0
                       CHANGING  ct_node              = rt_node ).
    ENDLOOP.

    IF iv_roots_only = abap_false.
      set_child_counts( CHANGING ct_node = rt_node ).
    ENDIF.
  ENDMETHOD.


  METHOD append_children.
    CONSTANTS lc_max_depth TYPE i VALUE 10.

    LOOP AT its_structure INTO DATA(ls_struct) WHERE parent = iv_parent_node.
      DATA(ls_node) = VALUE zi_brf_catalognode(
        nodeid         = |{ iv_parent_id }/{ ls_struct-node }|
        parentnodeid   = iv_parent_id
        catalogid      = iv_root_catalog_id     " the tree root, used for lazy loading
        catalogname    = iv_root_catalog_name
        name           = ls_struct-node_name
        seqnr          = ls_struct-seqnr
        hierarchylevel = iv_level ).

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
          ls_node-nodetype = gc_node_type-folder.

        WHEN if_fdt_catalog=>gc_node_type_link.
          ls_node-nodetype    = gc_node_type-link.
          ls_node-istechnical = abap_true.
          IF ls_link-catalog_id IS NOT INITIAL.
            DATA(ls_target) = get_object_info( ls_link-catalog_id ).
            ls_node-objectid          = ls_link-catalog_id.
            ls_node-objecttype        = if_fdt_constants=>gc_object_type_catalog.
            ls_node-status            = ls_target-state.
            ls_node-statuscriticality = criticality( ls_target-state ).
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
            ls_node-nodetype = gc_node_type-other_object.
          ELSE.
            DATA(ls_obj) = get_object_info( lv_object_id ).
            IF ls_obj-authorized = abap_false.
              CONTINUE.   " hide objects the user may not display
            ENDIF.
            ls_node-nodetype          = ls_obj-node_type.
            ls_node-objectid          = ls_obj-id.
            ls_node-objecttype        = ls_obj-object_type.
            ls_node-status            = ls_obj-state.
            ls_node-statuscriticality = criticality( ls_obj-state ).
            ls_node-istechnical       = ls_obj-system_object.
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
        append_children( EXPORTING io_catalog           = io_catalog
                                   its_structure        = its_structure
                                   iv_parent_node       = ls_struct-node
                                   iv_parent_id         = CONV #( ls_node-nodeid )
                                   iv_root_catalog_id   = iv_root_catalog_id
                                   iv_root_catalog_name = iv_root_catalog_name
                                   iv_level             = iv_level + 1
                                   iv_path              = iv_path
                                   iv_depth             = iv_depth
                         CHANGING  ct_node              = ct_node ).
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

            append_children( EXPORTING io_catalog           = lo_target
                                       its_structure        = lts_target
                                       iv_parent_node       = lv_start
                                       iv_parent_id         = CONV #( ls_node-nodeid )
                                       iv_root_catalog_id   = iv_root_catalog_id
                                       iv_root_catalog_name = iv_root_catalog_name
                                       iv_level             = iv_level + 1
                                       iv_path              = |{ iv_path },{ ls_link-catalog_id }|
                                       iv_depth             = iv_depth + 1
                             CHANGING  ct_node              = ct_node ).
          CATCH cx_fdt_input.
            " Linked catalog cannot be read: link shows without children
        ENDTRY.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD set_child_counts.
    " Number of direct children of every node, from the parent links
    TYPES: BEGIN OF ty_count,
             id    TYPE zi_brf_catalognode-nodeid,
             count TYPE i,
           END OF ty_count.
    DATA lt_count TYPE HASHED TABLE OF ty_count WITH UNIQUE KEY id.

    LOOP AT ct_node INTO DATA(ls_node) WHERE parentnodeid IS NOT INITIAL.
      READ TABLE lt_count ASSIGNING FIELD-SYMBOL(<ls_count>) WITH TABLE KEY id = ls_node-parentnodeid.
      IF sy-subrc <> 0.
        INSERT VALUE #( id = ls_node-parentnodeid ) INTO TABLE lt_count ASSIGNING <ls_count>.
      ENDIF.
      <ls_count>-count += 1.
    ENDLOOP.

    LOOP AT ct_node ASSIGNING FIELD-SYMBOL(<ls_node>).
      READ TABLE lt_count INTO DATA(ls_count) WITH TABLE KEY id = <ls_node>-nodeid.
      IF sy-subrc = 0.
        <ls_node>-childcount = ls_count-count.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD get_decision_table.
    DATA(lo_dt) = get_dt( iv_id ).
    DATA(ls_info) = get_object_info( iv_id ).
    DATA(ls_app) = get_app( ls_info-application_id ).

    rs_header = VALUE #( decisiontableid   = iv_id
                         name              = ls_info-name
                         description       = ls_info-text
                         objecttypetext    = 'Decision Table'(001)
                         applicationid     = ls_info-application_id
                         applicationname   = ls_app-name
                         devpackage        = ls_app-package
                         status            = ls_info-state
                         statustext        = COND #( WHEN ls_info-state = if_fdt_constants=>gc_state_active
                                                     THEN 'Active'(002) ELSE 'Inactive'(003) )
                         statuscriticality = criticality( ls_info-state ) ).

    TRY.
        DATA lv_change_ts   TYPE timestamp.
        DATA lv_creation_ts TYPE timestamp.
        lo_dt->if_fdt_admin_data~get_change_info(
          IMPORTING ev_change_user        = rs_header-changedby
                    ev_change_timestamp   = lv_change_ts
                    ev_creation_user      = rs_header-createdby
                    ev_creation_timestamp = lv_creation_ts ).
        split_timestamp( EXPORTING iv_ts = lv_creation_ts
                         IMPORTING ev_date = rs_header-createdon ev_time = rs_header-createdtime ).
        split_timestamp( EXPORTING iv_ts = lv_change_ts
                         IMPORTING ev_date = rs_header-changedon ev_time = rs_header-changedtime ).

        lo_dt->get_table_property( IMPORTING ev_multiple_match = rs_header-multiplematch
                                             ev_allow_no_match = rs_header-allownomatch ).

        DATA lts_column TYPE if_fdt_decision_table=>ts_column.
        lo_dt->get_columns( IMPORTING ets_column = lts_column ).
        rs_header-columncount      = lines( lts_column ).
        rs_header-columnstruncated = xsdbool( rs_header-columncount > gc_max_slots ).

        DATA lts_data TYPE if_fdt_decision_table=>ts_table_data.
        lo_dt->get_table_data( IMPORTING ets_data = lts_data ).
        LOOP AT lts_data INTO DATA(ls_data).
*          rs_header-rowcount = nmax( val1 = rs_header-rowcount val2 = ls_data-row_no ).
          rs_header-totalrows = nmax( val1 = rs_header-totalrows val2 = ls_data-row_no ).
        ENDLOOP.
      CATCH cx_fdt_input INTO DATA(lx_fdt).
        RAISE EXCEPTION NEW zcx_brf_viewer( previous = lx_fdt ).
    ENDTRY.
  ENDMETHOD.


  METHOD get_columns.
    DATA(lo_dt) = get_dt( iv_id ).
    DATA lts_column TYPE if_fdt_decision_table=>ts_column.

    TRY.
        lo_dt->get_columns( IMPORTING ets_column = lts_column ).
      CATCH cx_fdt_input INTO DATA(lx_fdt).
        RAISE EXCEPTION NEW zcx_brf_viewer( previous = lx_fdt ).
    ENDTRY.

    LOOP AT lts_column INTO DATA(ls_column).
      DATA(lv_index) = sy-tabix.
      IF lv_index > gc_max_slots.
        EXIT.   " header flag ColumnsTruncated tells the UI
      ENDIF.

      DATA(ls_out) = VALUE zi_brf_dtcolumn(
        decisiontableid = iv_id
        columnno        = ls_column-col_no
        slot            = |C{ lv_index WIDTH = 2 ALIGN = RIGHT PAD = '0' }|
        dataobjectid    = ls_column-object_id
        isresult        = ls_column-is_result
        isoptional      = ls_column-is_optional ).

      TRY.
          DATA lo_instance TYPE REF TO if_fdt_admin_data.
          CLEAR lo_instance.
          cl_fdt_factory=>get_instance_generic( EXPORTING iv_id       = ls_column-object_id
                                                IMPORTING eo_instance = lo_instance ).
          IF lo_instance IS BOUND.
            ls_out-columnname = lo_instance->get_name( ).
            DATA lv_text TYPE if_fdt_types=>text.
            CLEAR lv_text.
            lo_instance->get_texts( IMPORTING ev_text = lv_text ).
*            ls_out-label = COND #( WHEN lv_text IS NOT INITIAL THEN lv_text ELSE ls_out-columnname ).
            ls_out-columnlabel = COND #( WHEN lv_text IS NOT INITIAL THEN lv_text ELSE ls_out-columnname ).

            IF lo_instance IS INSTANCE OF if_fdt_data_object.
              DATA(lo_data_object) = CAST if_fdt_data_object( lo_instance ).
              ls_out-dataelement = lo_data_object->get_ddic_binding( ).
            ENDIF.
            IF lo_instance IS INSTANCE OF if_fdt_element.
              DATA(lo_element) = CAST if_fdt_element( lo_instance ).
              ls_out-datatype = lo_element->get_element_type( ).
              lo_element->get_element_type_attributes( IMPORTING ev_length   = DATA(lv_length)
                                                                 ev_decimals = DATA(lv_decimals) ).
              ls_out-fieldlength = lv_length.
              ls_out-decimals    = lv_decimals.
            ENDIF.
          ENDIF.
        CATCH cx_fdt_input.
          " Keep whatever we have; the column still shows with its slot
      ENDTRY.

      IF ls_out-columnname IS INITIAL.
        ls_out-columnname = |COLUMN_{ ls_column-col_no }|.
*        ls_out-label      = ls_out-columnname.
        ls_out-columnlabel = ls_out-columnname.
      ENDIF.
      APPEND ls_out TO rt_column.
    ENDLOOP.
  ENDMETHOD.


  METHOD get_rows.
    DATA(lo_dt) = get_dt( iv_id ).
    DATA lts_column TYPE if_fdt_decision_table=>ts_column.
    DATA lts_data   TYPE if_fdt_decision_table=>ts_table_data.

    TRY.
        lo_dt->get_columns( IMPORTING ets_column = lts_column ).
        lo_dt->get_table_data( IMPORTING ets_data = lts_data ).
      CATCH cx_fdt_input INTO DATA(lx_fdt).
        RAISE EXCEPTION NEW zcx_brf_viewer( previous = lx_fdt ).
    ENDTRY.

    " Column number -> slot name (C01..C40), same order as get_columns
    TYPES: BEGIN OF ty_slot,
             col_no TYPE i,
             slot   TYPE c LENGTH 3,
           END OF ty_slot.
    DATA lt_slot TYPE HASHED TABLE OF ty_slot WITH UNIQUE KEY col_no.
    LOOP AT lts_column INTO DATA(ls_column).
      IF sy-tabix > gc_max_slots.
        EXIT.
      ENDIF.
      INSERT VALUE #( col_no = ls_column-col_no
                      slot   = |C{ sy-tabix WIDTH = 2 ALIGN = RIGHT PAD = '0' }| ) INTO TABLE lt_slot.
    ENDLOOP.

    " One output row for every row number 1..max (rows with only empty cells included)
    DATA(lv_max_row) = 0.
    LOOP AT lts_data INTO DATA(ls_data).
      lv_max_row = nmax( val1 = lv_max_row val2 = ls_data-row_no ).
    ENDLOOP.
    DO lv_max_row TIMES.
      APPEND VALUE #( decisiontableid = iv_id rowno = sy-index ) TO rt_row.
    ENDDO.

    LOOP AT lts_data INTO ls_data.
      READ TABLE lt_slot INTO DATA(ls_slot) WITH TABLE KEY col_no = ls_data-col_no.
      IF sy-subrc <> 0.
        CONTINUE.   " column beyond the slot limit
      ENDIF.
      READ TABLE rt_row ASSIGNING FIELD-SYMBOL(<ls_row>) INDEX ls_data-row_no.
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.
      ASSIGN COMPONENT ls_slot-slot OF STRUCTURE <ls_row> TO FIELD-SYMBOL(<lv_cell>).
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.

      DATA(lv_text) = VALUE string( ).
      IF ls_data-ts_range IS NOT INITIAL.
        lv_text = range_to_text( ls_data-ts_range ).            " condition column
      ELSEIF ls_data-r_value IS BOUND OR ls_data-expression_id IS NOT INITIAL.
        lv_text = value_to_text( ir_value   = ls_data-r_value    " result column
                                 iv_expr_id = ls_data-expression_id ).
      ENDIF.
      <lv_cell> = lv_text.
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
        RAISE EXCEPTION NEW zcx_brf_viewer( previous = lx_fdt ).
    ENDTRY.

    IF lv_unknown = abap_true OR lo_instance IS NOT BOUND OR
       lo_instance IS NOT INSTANCE OF if_fdt_decision_table.
      RAISE EXCEPTION NEW zcx_brf_viewer( iv_text = |BRF+ object { iv_id } is not a decision table| ).
    ENDIF.

    DATA(ls_info) = get_object_info( iv_id ).
    IF ls_info-authorized = abap_false.
      RAISE EXCEPTION NEW zcx_brf_viewer( iv_text = |No display authorization for decision table { ls_info-name }| ).
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

          rs_info-node_type = gc_node_type-other_object.
          IF lo_instance IS INSTANCE OF if_fdt_decision_table.
            rs_info-node_type = gc_node_type-decision_table.
          ENDIF.

          rs_info-authorized = is_authorized( lo_instance ).
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
    " Standard BRF+ display check (activity 3). Internally this runs the
    " application exit check, then FDT_OBJECT, or S_DEVELOP for Y/Z
    " applications, exactly as the BRF+ workbench does.
    TRY.
        rv_ok = io_admin->if_fdt_transaction~authority_check(
                  iv_activity = if_fdt_constants=>gc_activity_display ).
      CATCH cx_fdt_input.
        rv_ok = abap_false.
    ENDTRY.

    " Optional extra gate for this app, e.g. a custom object ZBRF_VIEW:
    " IF rv_ok = abap_true.
    "   AUTHORITY-CHECK OBJECT 'ZBRF_VIEW' ID 'ACTVT' FIELD '03'.
    "   rv_ok = xsdbool( sy-subrc = 0 ).
    " ENDIF.
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

    " No literal value: the cell refers to another BRF+ object (expression or data object)
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


  METHOD criticality.
    rv_crit = SWITCH #( iv_state
      WHEN if_fdt_constants=>gc_state_active   THEN 3     " green
      WHEN if_fdt_constants=>gc_state_inactive THEN 2     " yellow
      ELSE 0 ).
  ENDMETHOD.

ENDCLASS.
