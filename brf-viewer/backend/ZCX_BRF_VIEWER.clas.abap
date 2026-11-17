"! Error raised by the read-only BRF+ viewer service.
"! Uses the generic message 00/001 (&1&2&3&4) so no message class is needed.
CLASS zcx_brf_viewer DEFINITION
  PUBLIC
  INHERITING FROM cx_rap_query_provider
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    CONSTANTS:
      BEGIN OF gc_free_text,
        msgid TYPE symsgid VALUE '00',
        msgno TYPE symsgno VALUE '001',
        attr1 TYPE scx_attrname VALUE 'MV_TEXT1',
        attr2 TYPE scx_attrname VALUE 'MV_TEXT2',
        attr3 TYPE scx_attrname VALUE 'MV_TEXT3',
        attr4 TYPE scx_attrname VALUE 'MV_TEXT4',
      END OF gc_free_text.

    DATA mv_text1 TYPE symsgv READ-ONLY.
    DATA mv_text2 TYPE symsgv READ-ONLY.
    DATA mv_text3 TYPE symsgv READ-ONLY.
    DATA mv_text4 TYPE symsgv READ-ONLY.

    METHODS constructor
      IMPORTING
        iv_text  TYPE csequence OPTIONAL
        previous LIKE previous OPTIONAL.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcx_brf_viewer IMPLEMENTATION.

  METHOD constructor ##ADT_SUPPRESS_GENERATION.
    super->constructor( textid = gc_free_text previous = previous ).

    DATA(lv_text) = CONV string( iv_text ).
    IF lv_text IS INITIAL AND previous IS BOUND.
      lv_text = previous->get_text( ).
    ENDIF.

    " Split the text over the four 50-character message variables
    mv_text1 = substring( val = lv_text off = 0   len = nmin( val1 = 50 val2 = strlen( lv_text ) ) ).
    IF strlen( lv_text ) > 50.
      mv_text2 = substring( val = lv_text off = 50  len = nmin( val1 = 50 val2 = strlen( lv_text ) - 50 ) ).
    ENDIF.
    IF strlen( lv_text ) > 100.
      mv_text3 = substring( val = lv_text off = 100 len = nmin( val1 = 50 val2 = strlen( lv_text ) - 100 ) ).
    ENDIF.
    IF strlen( lv_text ) > 150.
      mv_text4 = substring( val = lv_text off = 150 len = nmin( val1 = 50 val2 = strlen( lv_text ) - 150 ) ).
    ENDIF.
  ENDMETHOD.

ENDCLASS.
