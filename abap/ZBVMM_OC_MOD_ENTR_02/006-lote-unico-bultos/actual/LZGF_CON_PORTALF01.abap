*----------------------------------------------------------------------*
***INCLUDE LZGF_CON_PORTALF01.
*----------------------------------------------------------------------*
*&---------------------------------------------------------------------*
*& Form f_agrupa_no_hu
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*&      --> T_ENTR_DET
*&      --> <F_T001L>_XHUPF
*&---------------------------------------------------------------------*
FORM f_agrupa_no_hu  TABLES it_entr_det STRUCTURE zbvmm_st_guardar_entrega_det
*                      USING i_xhupf. "-@001
                      USING i_lgort.  "+@001

*  IF i_xhupf EQ ''. "-@001
  IF i_lgort NE '0230'. "+@001

    g_marc_nohu = abap_true.
    CLEAR: g_pesototal.

    DATA: lt_entr_det TYPE STANDARD TABLE OF  zbvmm_st_guardar_entrega_det.

    lt_entr_det =  it_entr_det[].
    SORT lt_entr_det BY vhilm_ku ASCENDING brgew ASCENDING.
    DELETE ADJACENT DUPLICATES FROM lt_entr_det COMPARING vhilm_ku.

    LOOP AT lt_entr_det ASSIGNING FIELD-SYMBOL(<fs_det>).
      ADD <fs_det>-brgew TO g_pesototal.
    ENDLOOP.

    lt_entr_det = it_entr_det[].
    SORT it_entr_det BY ebeln ebelp matnr. "vhilm_ku.
    DELETE ADJACENT DUPLICATES FROM it_entr_det COMPARING ebeln ebelp matnr. "vhilm_ku.

    LOOP AT it_entr_det ASSIGNING FIELD-SYMBOL(<fs_itdet>).

      CLEAR: <fs_itdet>-menge.
      LOOP AT lt_entr_det ASSIGNING <fs_det> WHERE ebeln EQ <fs_itdet>-ebeln
                                                             AND ebelp EQ <fs_itdet>-ebelp
                                                             AND matnr EQ <fs_itdet>-matnr.
        ADD <fs_det>-menge TO <fs_itdet>-menge.
      ENDLOOP.

    ENDLOOP.


  ENDIF.
ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  VERIF_CLAVE_CONFIRMACION
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*      <--P_CH_ERROR  text
*----------------------------------------------------------------------*
FORM verif_clave_confirmacion  CHANGING ch_error.

  DATA: is_msg TYPE bapiret2.

*  LOOP AT gt_final ASSIGNING FIELD-SYMBOL(<fs_final>).
  LOOP AT gt_pedpos ASSIGNING FIELD-SYMBOL(<fs_pedpos>).

    CLEAR: g_msg.

    READ TABLE gt_ekpo ASSIGNING FIELD-SYMBOL(<fs_ekpo>) WITH KEY ebeln = <fs_pedpos>-ebeln
                                                                  ebelp = <fs_pedpos>-ebelp.

    IF sy-subrc EQ 0.
      "Posición sin clave de confirmación.
      IF <fs_ekpo>-bstae EQ space.
        ch_error = abap_true.

        is_msg-id = 'ME'.
        is_msg-number = '285'.
        "Lectura del mensaje.
        PERFORM f_read_msg_error
                USING
                   is_msg
                CHANGING
                   g_msg
                       .

        APPEND INITIAL LINE TO gt_mensajes ASSIGNING FIELD-SYMBOL(<fs_mensajes>).
        <fs_mensajes>-codigo = is_msg-number.
        <fs_mensajes>-type = 'E' .
        CONCATENATE g_msg <fs_pedpos>-ebeln <fs_pedpos>-ebelp INTO <fs_mensajes>-msg SEPARATED BY space.

      ENDIF.
    ENDIF.

  ENDLOOP.
ENDFORM.
FORM f_read_msg_error USING i_msgs STRUCTURE bapiret2
                      CHANGING ch_msg.

  DATA: lv_msg TYPE bapi_msg.

  CALL FUNCTION 'BAPI_MESSAGE_GETDETAIL'
    EXPORTING
      id         = i_msgs-id
      number     = i_msgs-number
      language   = 'S'
      textformat = 'ASC'
*     linkpattern        =
      message_v1 = i_msgs-message_v1
      message_v2 = i_msgs-message_v2
      message_v3 = i_msgs-message_v3
      message_v4 = i_msgs-message_v4
*     language_iso       =
    IMPORTING
      message    = lv_msg
*     RETURN     =
*                      TABLES
*     TEXT       =
    .

  ch_msg = lv_msg.


ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  COMMIT_WAIT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*  -->  p1        text
*  <--  p2        text
*----------------------------------------------------------------------*
FORM commit_wait .

  CALL FUNCTION 'BAPI_TRANSACTION_COMMIT'
    EXPORTING
      wait = 'X'.

ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  f_actualiza_entrega_cab
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*  -->  p1        text
*  <--  p2        text
*----------------------------------------------------------------------*
FORM f_actualiza_entrega_cab TABLES t_return STRUCTURE bapiret2
                              USING us_entr_cab TYPE zbvmm_st_i_entr_cab
                                    u_param  TYPE zge_e_fromvalue
                                    u_status   TYPE ze_lfstk. "@DL MEJORAS.

  DATA: lwa_h_data      LIKE bapiibdlvhdrchg,
        lwa_h_control   LIKE bapiibdlvhdrctrlchg,
        it_item_data    LIKE TABLE OF bapiibdlvitemchg WITH HEADER LINE,
        it_item_control LIKE TABLE OF bapiibdlvitemctrlchg WITH HEADER LINE,
        it_extension2   LIKE TABLE OF bapiext WITH HEADER LINE.

  CLEAR: lwa_h_data,lwa_h_control .
  lwa_h_data-deliv_numb     = us_entr_cab-vbeln.
  lwa_h_control-deliv_numb  = us_entr_cab-vbeln.

  IF  us_entr_cab-bolnr NE ''.
    CLEAR it_extension2.
    it_extension2-param = u_param.
    it_extension2-field = 'BOLNR'. " text-c11.   "'BOLNR'.    "@DL PT  -+
    it_extension2-value = us_entr_cab-bolnr.
    APPEND it_extension2.
  ENDIF.

  IF us_entr_cab-brgew IS NOT INITIAL.
    it_extension2-param = u_param.
    it_extension2-field = 'BRGEW'. "text-c10.   "'BRGEW'.    "@DL PT  -+
    it_extension2-value = us_entr_cab-brgew.
    APPEND it_extension2.
  ENDIF.

  IF us_entr_cab-anzpk IS NOT INITIAL.
    it_extension2-param = u_param.
    it_extension2-field = 'ANZPK'.
    it_extension2-value = us_entr_cab-anzpk.
    APPEND it_extension2.
  ENDIF.


  it_extension2-param = u_param.
  it_extension2-field = 'ZZLFSTK'. " text-c12.   "'ZZLFSTK'.   "@DL PT  -+
  it_extension2-value = u_status.
  u_status = it_extension2-value.
  APPEND it_extension2.

  "Cambiar status ´por contabilización fallida.
  REFRESH: t_return.

  CALL FUNCTION 'BAPI_INB_DELIVERY_CHANGE'
    EXPORTING
      header_data    = lwa_h_data
      header_control = lwa_h_control
      delivery       = us_entr_cab-vbeln
    TABLES
      extension2     = it_extension2
      return         = t_return.

  IF sy-subrc EQ 0.
    PERFORM commit_wait.
    "Actualiza entregas en tabla z
***    PERFORM f_actualiza_entrega_z
***       USING
***          us_entr_cab-vbeln
***          u_status
***          .

  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  f_textos_dimensiones_likp
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*  -->  p1        text
*  <--  p2        text
*----------------------------------------------------------------------*
FORM f_textos_dimensiones_likp TABLES t_line STRUCTURE tline
                              USING u_vbeln TYPE vbeln_vl
                                     u_save   TYPE abap_bool
                                     u_laeng  TYPE laeng
                                     u_breit  TYPE breit
                                     u_hoehe  TYPE hoehe
                               .

  CONSTANTS: c_object TYPE thead-tdobject VALUE 'VBBK',
             c_id     TYPE thead-tdid VALUE 'Z011'.

  DATA: ls_head     TYPE thead,
        lt_tline    TYPE tlinet,
        ls_tline    LIKE LINE OF lt_tline,
        l_tdname_st TYPE string,
        l_tdline    TYPE string,
        l_laeng     TYPE string,
        l_breit     TYPE string,
        l_hoehe     TYPE string.

  l_tdname_st = u_vbeln.
  l_laeng = u_laeng. l_breit = u_breit. l_hoehe = u_hoehe.

  ls_head-tdid     = c_id.
  ls_head-tdname   = l_tdname_st.
  ls_head-tdobject = c_object.
  ls_head-tdspras  = sy-langu.

  IF u_save EQ abap_true.
    "Longitud.
    CLEAR: ls_tline.
    CONCATENATE TEXT-036 l_laeng INTO l_tdline SEPARATED BY space.
    ls_tline-tdformat   = '*'.
    ls_tline-tdline   = l_tdline.
    APPEND ls_tline TO lt_tline.

    "Ancho.
    CLEAR: ls_tline.
    CONCATENATE TEXT-037 l_breit INTO l_tdline SEPARATED BY space.
    ls_tline-tdformat   = '*'.
    ls_tline-tdline   = l_tdline.
    APPEND ls_tline TO lt_tline.

    "Altura.
    CLEAR: ls_tline.
    CONCATENATE TEXT-038 l_hoehe INTO l_tdline SEPARATED BY space.
    ls_tline-tdformat   = '*'.
    ls_tline-tdline   = l_tdline.
    APPEND ls_tline TO lt_tline.

    "Guardar texto nuevo.
    CALL FUNCTION 'SAVE_TEXT'
      EXPORTING
        client          = sy-mandt
        header          = ls_head
        insert          = 'X'
        savemode_direct = 'X'
      TABLES
        lines           = lt_tline
      EXCEPTIONS
        id              = 1
        language        = 2
        name            = 3
        object          = 4
        OTHERS          = 5.
    IF sy-subrc EQ 0.

      CALL FUNCTION 'BAPI_TRANSACTION_COMMIT'
        EXPORTING
          wait = 'X'.
    ENDIF.

  ELSE.

    REFRESH lt_tline.
    CALL FUNCTION 'READ_TEXT'
      EXPORTING
        client                  = sy-mandt
        id                      = ls_head-tdid
        language                = ls_head-tdspras
        name                    = ls_head-tdname
        object                  = ls_head-tdobject
        archive_handle          = 0
*       LOCAL_CAT               = ' '
*            IMPORTING
*       HEADER                  =
*       OLD_LINE_COUNTER        =
      TABLES
        lines                   = t_line
      EXCEPTIONS
        id                      = 1
        language                = 2
        name                    = 3
        not_found               = 4
        object                  = 5
        reference_check         = 6
        wrong_access_to_archive = 7
        OTHERS                  = 8.
    IF sy-subrc <> 0.
      " Implement suitable error handling here
    ENDIF.

  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  F_ACT_ZBVMM_ENTRENOHU
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*      -->P_T_ENTR_DET  text
*----------------------------------------------------------------------*
FORM f_act_entre_nohu_compl TABLES it_entr_det STRUCTURE zbvmm_st_guardar_entrega_det
                                   it_entrega_detalle STRUCTURE bbp_inbd_d
                             USING i_delivery TYPE vbeln_vl
                                   lv_status   TYPE ze_lfstk. "INSERT @JGRS.
  TYPES: BEGIN OF gty_hucomple,
           vhilm_ku TYPE vhilm_ku,
           exidv    TYPE exidv,
         END OF gty_hucomple,
*{INSERT @JGRS
         BEGIN OF gty_zzlug_ent,
           ebeln     TYPE ekpo-ebeln,
           ebelp     TYPE ekpo-ebelp,
           zzlug_ent TYPE ekpo-zzlug_ent,
           inco1     TYPE ekpo-inco1, "+@001
         END OF gty_zzlug_ent.
*}INSERT @JGRS

  DATA: lt_hu_fict   TYPE STANDARD TABLE OF gty_hucomple,
        lt_zzlug_ent TYPE STANDARD TABLE OF gty_zzlug_ent,    "INSERT @JGRS
        lv_corre     TYPE i.

  FIELD-SYMBOLS:<fs_zzlug_ent> LIKE LINE OF lt_zzlug_ent.     "INSERT @JGRS

  "Correlativo para embalaje complementario.
  IF g_marc_nohu EQ abap_true.

    "Ordena embalajes principales.
    LOOP AT it_entr_det ASSIGNING FIELD-SYMBOL(<fs_entr>).
      APPEND INITIAL LINE TO lt_hu_fict ASSIGNING FIELD-SYMBOL(<fs_hu_fict>).
      MOVE-CORRESPONDING <fs_entr> TO <fs_hu_fict>.
    ENDLOOP.

    SORT lt_hu_fict BY vhilm_ku.
    DELETE ADJACENT DUPLICATES FROM lt_hu_fict COMPARING vhilm_ku.

    LOOP AT lt_hu_fict ASSIGNING <fs_hu_fict>.
      PERFORM get_hucomp_correlativo CHANGING lv_corre.
      <fs_hu_fict>-exidv = lv_corre.
    ENDLOOP.

  ENDIF.

  "No HU
  IF g_marc_nohu EQ abap_true.
    LOOP AT it_entr_det ASSIGNING <fs_entr>.
      APPEND INITIAL LINE TO gt_entrenohu ASSIGNING FIELD-SYMBOL(<fs_nohu>).
      MOVE-CORRESPONDING <fs_entr> TO <fs_nohu>.
      "detalle de la entrega.
      READ TABLE it_entrega_detalle ASSIGNING FIELD-SYMBOL(<fs_detalle>)
                                    WITH KEY po_number = <fs_entr>-ebeln
                                             po_item = <fs_entr>-ebelp.
      IF sy-subrc EQ 0.
        "Entrega, posición y fecha de creación.
        <fs_nohu>-vbeln = <fs_detalle>-delivery.
        <fs_nohu>-posnr = <fs_detalle>-deliv_item.
        <fs_nohu>-lfdat = sy-datum.
        <fs_nohu>-lfuhr = sy-uzeit.
      ENDIF.

      "Asigna embalaje fict.
      READ TABLE lt_hu_fict ASSIGNING <fs_hu_fict> WITH KEY vhilm_ku = <fs_entr>-vhilm_ku.
      IF sy-subrc EQ 0.
        <fs_nohu>-exidv = <fs_hu_fict>-exidv.
        PERFORM agrega_ceros CHANGING <fs_nohu>-exidv.
*      CONDENSE <fs_nohu>-exidv NO-GAPS.
      ENDIF.

    ENDLOOP.
  ENDIF.
*{INSERT @JGRS
  SELECT ebeln ebelp zzlug_ent
    inco1 "+@001
  INTO TABLE lt_zzlug_ent
  FROM ekpo
  FOR ALL ENTRIES IN it_entr_det
  WHERE ebeln EQ it_entr_det-ebeln
    AND ebelp EQ it_entr_det-ebelp+1(5).
  IF sy-subrc EQ '0'.
  ENDIF.
*}INSERT @JGRS
  "Verificar embalajes complementarios.
  LOOP AT gt_emb_compl ASSIGNING FIELD-SYMBOL(<fs_emb_compl>).

    APPEND INITIAL LINE TO gt_embcomp ASSIGNING FIELD-SYMBOL(<fs_embcomp>).
    MOVE-CORRESPONDING <fs_emb_compl> TO <fs_embcomp>. " <fs_nohu> TO <fs_embcomp>
    <fs_embcomp>-vbeln = i_delivery.
*      <fs_embcomp>-posnr = <fs_detalle>-deliv_item.
*      <fs_embcomp>-ebeln = <fs_entr>-ebeln.
*      <fs_embcomp>-ebelp = <fs_entr>-ebelp
    <fs_embcomp>-vhilm_ku = <fs_emb_compl>-vhilm_ku_p.
    <fs_embcomp>-vhilm_ku_sub = <fs_emb_compl>-vhilm_ku.  "Emb. complemantario.
    <fs_embcomp>-lfdat = sy-datum.
    <fs_embcomp>-lfuhr = sy-uzeit.
*{INSERT @JGRS
    READ TABLE it_entr_det ASSIGNING <fs_entr> WITH KEY vhilm_ku = <fs_emb_compl>-vhilm_ku_p.
    IF sy-subrc EQ 0.
      READ TABLE lt_zzlug_ent ASSIGNING <fs_zzlug_ent> WITH KEY ebeln = <fs_entr>-ebeln
                                                                ebelp = <fs_entr>-ebelp+1(5).
      IF sy-subrc EQ 0.
*        <fs_embcomp>-zzlug_ent = <fs_zzlug_ent>-zzlug_ent. "-@001
        <fs_embcomp>-zzlug_ent = <fs_zzlug_ent>-inco1.  "+@001
      ENDIF.
    ENDIF.
    <fs_embcomp>-zzlfstk = lv_status.
*}INSERT @JGRS
    "NO HU
    IF g_marc_nohu EQ abap_true.
      "Asigna embalaje fict.
      READ TABLE lt_hu_fict ASSIGNING <fs_hu_fict> WITH KEY vhilm_ku = <fs_embcomp>-vhilm_ku.
      IF sy-subrc EQ 0.
        <fs_embcomp>-exidv = <fs_hu_fict>-exidv.
        PERFORM agrega_ceros CHANGING <fs_embcomp>-exidv.
      ENDIF.
      "HU OBL.
    ELSE.
      READ TABLE gt_hucomple ASSIGNING <fs_hu_fict> WITH KEY vhilm_ku = <fs_embcomp>-vhilm_ku.
      IF sy-subrc EQ 0.
        <fs_embcomp>-exidv = <fs_hu_fict>-exidv.
      ENDIF.
    ENDIF.
  ENDLOOP.
  "Actualiza tabla de entrega sin HU.
  IF gt_entrenohu IS NOT INITIAL AND g_marc_nohu EQ abap_true.
    MODIFY zbvmm_entrenohu FROM TABLE gt_entrenohu.
    IF sy-subrc EQ 0.
      COMMIT WORK.
    ENDIF.
  ENDIF.
  "Actualiza tabla de embalajes complementarios.
  IF gt_embcomp IS NOT INITIAL.
    MODIFY zbvmm_emb_comp FROM TABLE gt_embcomp.
    IF sy-subrc EQ 0.
      COMMIT WORK.
    ENDIF.
  ENDIF.
ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  GET_HUCOMP_CORRELATIVO
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*  -->  p1        text
*  <--  p2        text
*----------------------------------------------------------------------*
FORM get_hucomp_correlativo CHANGING ch_corre TYPE i.


*data: lv_cont TYPE i.


  CALL FUNCTION 'NUMBER_RANGE_ENQUEUE'
    EXPORTING
      object = 'ZR_HUCOPLE'.

  CALL FUNCTION 'NUMBER_GET_NEXT'
    EXPORTING
      nr_range_nr = '01'
      object      = 'ZR_HUCOPLE'
    IMPORTING
      number      = ch_corre.

  CALL FUNCTION 'NUMBER_RANGE_DEQUEUE'
    EXPORTING
      object = 'ZR_HUCOPLE'.

* ch_corre = lv_cont.

ENDFORM.
FORM agrega_ceros  CHANGING ch_valor.

  CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
    EXPORTING
      input  = ch_valor
    IMPORTING
      output = ch_valor.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form act_venum
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*&      --> LS_HUHEADER_HU_EXID
*&      --> <FS_ENTR_DET3>_BRGEW
*&---------------------------------------------------------------------*
FORM act_venum  USING  i_exidv TYPE exidv
                       i_brgew TYPE brgew.
  DATA: it_venum     TYPE STANDARD TABLE OF hum_venum,
        it_messages  TYPE STANDARD TABLE OF huitem_messages,
        it_newvalues TYPE STANDARD TABLE OF hum_update_header
        .


  SELECT SINGLE venum,exidv INTO @DATA(ls_vekp)
    FROM vekp
    WHERE exidv EQ @i_exidv.

  IF sy-subrc EQ 0.

    APPEND INITIAL LINE TO it_venum ASSIGNING FIELD-SYMBOL(<fs_venum>).
    <fs_venum>-venum = ls_vekp-venum.

    CALL FUNCTION 'V51P_FILL_GT'
      EXPORTING
        it_venum    = it_venum
      IMPORTING
        et_messages = it_messages
      EXCEPTIONS
        hu_locked   = 1
        no_hu_found = 2
        fatal_error = 3
        OTHERS      = 4.

    APPEND INITIAL LINE TO it_newvalues ASSIGNING FIELD-SYMBOL(<ls_newvalues>).
    <ls_newvalues>-hdl_unit_itid = ls_vekp-venum.
    <ls_newvalues>-hdl_unit_exid = ls_vekp-exidv.
    <ls_newvalues>-field_name = 'BRGEW'.
    <ls_newvalues>-field_value = i_brgew.


    CALL FUNCTION 'HU_HEADER_UPDATE'
      EXPORTING
        it_new_values = it_newvalues
      IMPORTING
        et_messages   = it_messages
      EXCEPTIONS
        not_possible  = 1
        OTHERS        = 2.

    IF sy-subrc <> 0.
      MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
      WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
    ELSE.
      CALL FUNCTION 'HU_PACKING_UPDATE'
        EXPORTING
          if_synchron = 'X'.
    ENDIF.

  ENDIF.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form f_save_text
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*&      --> T_PEDIDOTEXT
*&      --> <FS_ENTREGA_DETALLE>
*&---------------------------------------------------------------------*
FORM f_save_text  TABLES it_textos TYPE zbvmm_tt_txtposicionpedido
                 USING i_detalle TYPE bbp_inbd_d.
  DATA: lt_line   TYPE TABLE OF tline,
        wa_line   TYPE tline,
        wa_header TYPE thead.

  LOOP AT it_textos ASSIGNING FIELD-SYMBOL(<fs_textos>) WHERE ebeln EQ i_detalle-po_number
                                                          AND ebelp EQ i_detalle-po_item.

    APPEND INITIAL LINE TO lt_line ASSIGNING FIELD-SYMBOL(<fs_line>).
    <fs_line>-tdline = <fs_textos>-tdline.

  ENDLOOP.

  IF lt_line IS NOT INITIAL.

    CONCATENATE i_detalle-delivery
                i_detalle-deliv_item
     INTO wa_header-tdname.

    wa_header-tdobject = 'VBBP'.
    wa_header-tdid     = 'Z003'.
    wa_header-tdspras  = sy-langu.

    CALL FUNCTION 'SAVE_TEXT'
      EXPORTING
        client          = sy-mandt
        header          = wa_header
        insert          = 'X'
        savemode_direct = 'X'
      TABLES
        lines           = lt_line
      EXCEPTIONS
        id              = 1
        language        = 2
        name            = 3
        object          = 4
        OTHERS          = 5.

  ENDIF.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form conversion_cunit
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*&      --> <FS_ENTRENOHU>_MEINS
*&      <-- <FS_ENTR_DET>_VRKME
*&---------------------------------------------------------------------*
FORM conversion_cunit  USING    i_vrkme TYPE vrkme
                       CHANGING ch_meins TYPE meins.
  CALL FUNCTION 'CONVERSION_EXIT_CUNIT_OUTPUT'
    EXPORTING
      input          = i_vrkme "<fs_lips>-meins
      language       = 'S' "sy-langu
    IMPORTING
      output         = ch_meins
    EXCEPTIONS
      unit_not_found = 1
      OTHERS         = 2.
  IF sy-subrc <> 0.
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form f_fechas
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*&      --> <FS_PROV_DET>_EINDTP
*&      --> <FS_PROV_DET>_DIASXVEN
*&---------------------------------------------------------------------*
FORM f_fechas  USING u_eindtp TYPE bbein
                    u_diasxven TYPE udm_contact_no_of_days.

  DATA: lv_datediff TYPE p.
  DATA: lv_time     TYPE uzeit VALUE '010000'.
  DATA: lv_diasxvencer TYPE p.
  DATA: lv_fecha TYPE datum.
  DATA: lv_fecha2 TYPE datum.

  CALL FUNCTION 'SD_DATETIME_DIFFERENCE'
    EXPORTING
      date1            = sy-datum
      time1            = lv_time
      date2            = u_eindtp
      time2            = lv_time
    IMPORTING
      datediff         = lv_datediff
    EXCEPTIONS
      invalid_datetime = 1
      OTHERS           = 2.
  IF sy-subrc EQ 0.
    lv_fecha  = u_eindtp.
    lv_diasxvencer = lv_datediff.
    DO lv_datediff  TIMES.
      CALL FUNCTION 'DATE_CONVERT_TO_FACTORYDATE'
        EXPORTING
          correct_option               = '+'
          date                         = lv_fecha
          factory_calendar_id          = 'PE'
        IMPORTING
          date                         = lv_fecha2
*         FACTORYDATE                  =
*         WORKINGDAY_INDICATOR         =
        EXCEPTIONS
          calendar_buffer_not_loadable = 1
          correct_option_invalid       = 2
          date_after_range             = 3
          date_before_range            = 4
          date_invalid                 = 5
          factory_calendar_not_found   = 6
          OTHERS                       = 7.
      .
      IF sy-subrc EQ 0.
        IF lv_fecha NE lv_fecha2.
          lv_diasxvencer = lv_diasxvencer - 1 .
        ENDIF.
      ENDIF.
      lv_fecha = lv_fecha + 1 .
    ENDDO.
    u_diasxven = lv_diasxvencer.
  ENDIF.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form quitar_ceros
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*&      <-- <FS_DETALLE>_ZVBELN
*&---------------------------------------------------------------------*
FORM quitar_ceros  CHANGING ch_valor.
  CALL FUNCTION 'CONVERSION_EXIT_ALPHA_OUTPUT'
    EXPORTING
      input  = ch_valor
    IMPORTING
      output = ch_valor.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form limpiar_campos
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*&      <-- <FS_DETALLE>
*&---------------------------------------------------------------------*
FORM limpiar_campos  CHANGING p_detalle TYPE zbvmm_st_entrega_re_02.
  CLEAR: p_detalle-zvhilm_ku,
         p_detalle-zbrgew_b,
         p_detalle-zvegr1,
         p_detalle-zvegr2,
         p_detalle-zbezei,
         p_detalle-zlaeng,
         p_detalle-zbreit,
         p_detalle-zhoehe,
         p_detalle-zebeln,
         p_detalle-zsmtp_addr,
         p_detalle-zname_text,
         p_detalle-zmatnr,
         p_detalle-zmaktx,
         p_detalle-zvemng,
         p_detalle-zgewei,
         p_detalle-zbrgew_m,
         p_detalle-zecri.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form agrega_embcomp
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*&      --> LV_VBELN
*&      <-- T_DATOS_IMP
*&---------------------------------------------------------------------*
FORM agrega_embcomp  USING    u_vbeln        TYPE vbeln
                    CHANGING t_datos_etiq   TYPE zbvmm_tt_etiqueta_qr.


  DATA(lt_datos_aux) = t_datos_etiq[].


  SELECT vegr1,bezei
   INTO TABLE @DATA(t_tve1t)
   FROM tve1t
   FOR ALL ENTRIES IN @gt_emb_compl_re
   WHERE vegr1 EQ @gt_emb_compl_re-zvegr1
     AND spras EQ 'S'.

  LOOP AT lt_datos_aux ASSIGNING FIELD-SYMBOL(<fs_datos_aux>).
    LOOP AT gt_emb_compl_re ASSIGNING FIELD-SYMBOL(<fs_compl>) WHERE "vbeln EQ <fs_datos_aux>-vbeln
                                                                     vhilm_ku_p EQ <fs_datos_aux>-vhilm_ku.

      APPEND INITIAL LINE TO t_datos_etiq ASSIGNING FIELD-SYMBOL(<fs_dato>).
      MOVE-CORRESPONDING <fs_datos_aux> TO <fs_dato>. "Data de embalje principal.
      MOVE-CORRESPONDING <fs_compl> TO <fs_dato>.     "Data de embalaje secundario.
      "MP{
      READ TABLE t_tve1t ASSIGNING FIELD-SYMBOL(<fs_tv>) WITH KEY vegr1 = <fs_compl>-zvegr1.
      IF sy-subrc = 0.
        <fs_dato>-bezei = <fs_tv>-bezei.
      ENDIF.
      <fs_dato>-btgew = <fs_compl>-brgew.
      <fs_dato>-vegr2 = <fs_compl>-vegr2.
      <fs_dato>-vhilm_ku = <fs_compl>-vhilm_ku_p.
      "MP}
      MOVE <fs_compl>-zvegr1 TO <fs_dato>-vegr1.
      MOVE <fs_datos_aux>-printer TO <fs_dato>-printer.
      PERFORM quitar_ceros CHANGING <fs_datos_aux>-exidv.
      CONCATENATE <fs_datos_aux>-exidv <fs_compl>-vhilm_ku INTO <fs_dato>-exidv SEPARATED BY '-'.
      "
    ENDLOOP.

  ENDLOOP.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form obtener_nombre_smartforms
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*&      --> LS_FORM
*&      <-- LW_FM_NAME
*&      <-- LW_ERROR
*&---------------------------------------------------------------------*
FORM obtener_nombre_smartforms  USING pi_formname TYPE tdsfname
                            CHANGING po_fm_name  TYPE rs38l_fnam
                                     po_error    TYPE char01.

  DATA: lwa_formname TYPE tdsfname.

  CLEAR po_error.
  lwa_formname = pi_formname.
  IF lwa_formname IS NOT INITIAL.
    CALL FUNCTION 'SSF_FUNCTION_MODULE_NAME'
      EXPORTING
        formname           = lwa_formname
      IMPORTING
        fm_name            = po_fm_name
      EXCEPTIONS
        no_form            = 1
        no_function_module = 2
        OTHERS             = 3.
    IF sy-subrc NE 0.
      po_error = '1'.
    ENDIF.
  ELSE.
    po_error = '2'.
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form cargar_param_print
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*&      --> I_VBELN
*&      <-- LS_OUTPUT_OPTIONS
*&      <-- LS_CONTROL_PARAMETERS
*&      <-- LW_ERROR
*&---------------------------------------------------------------------*
FORM cargar_param_print  USING    pi_vbeln             TYPE vbeln
                        CHANGING po_output_options     TYPE ssfcompop
                                 po_control_parameters TYPE ssfctrlop
*                                 pi_pda                TYPE char1
                                 po_error              TYPE char1.

  DATA: ls_spld TYPE usr01-spld.

  CHECK po_error IS INITIAL.

* Opciones de Impresión
  po_control_parameters-no_dialog = abap_true.
  po_control_parameters-device  = 'PRINTER'.

  po_output_options-tdimmed     = abap_true.
  po_output_options-tdnewid     = abap_true.
  po_output_options-tdnoprev    = abap_true.

*  IF sy-mandt EQ '250' OR sy-mandt EQ '300'.
*
*     po_output_options-tdimmed     = abap_false. "Sin salida inmediata.
*     po_output_options-tdnewid     = abap_true.  "Nueva orden spool.
*     po_output_options-tdnoprint   = abap_true.  "No imprimir.
*     po_output_options-tdnoprev    = abap_true.  "Sin visualización previa.
*
*  ELSE.
*
*     po_output_options-tdimmed     = abap_true.
*     po_output_options-tdnewid     = abap_true.
*     po_output_options-tdnoprev    = abap_true.
*  ENDIF.

  CONCATENATE TEXT-001 '-' pi_vbeln INTO po_output_options-tdcovtitle SEPARATED BY space.
  SELECT SINGLE spld INTO ls_spld FROM usr01
    WHERE bname EQ sy-uname.
  IF sy-subrc EQ 0.
*    po_output_options-tddest    = ls_spld.
  ENDIF.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form cargar_imp_sin_hu
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*&      --> I_ENTR_DET
*&      --> I_ENTR_CAB
*&      --> LV_VBELN
*&      <-- T_DATOS_IMP
*&---------------------------------------------------------------------*
FORM cargar_imp_sin_hu  TABLES   t_entregas_det STRUCTURE zbvmm_st_i_entr_det
                                 t_entr_cab     STRUCTURE zbvmm_st_i_entr_cab
                        USING    u_vbeln        TYPE vbeln
                        CHANGING t_datos_etiq   TYPE zbvmm_tt_etiqueta_qr.

  DATA: l_cont TYPE i.

  SELECT vbeln,btgew,gewei,bolnr
    FROM likp
    INTO TABLE @DATA(t_likp)
    WHERE vbeln EQ @u_vbeln.

  SELECT vbeln,posnr,werks,lgort,vgbel,vgpos,charg,lfimg,vrkme,umvkz
   INTO TABLE @DATA(t_lips)
   FROM lips
   WHERE vbeln EQ @u_vbeln.
  IF sy-subrc EQ 0.
    SELECT werks,lgort,xhupf,lgobe
     INTO TABLE @DATA(t_t001l)
     FROM t001l
     FOR ALL ENTRIES IN @t_lips
     WHERE lgort EQ @t_lips-lgort
      AND werks  EQ @t_lips-werks.
  ENDIF.

  SORT t_entregas_det BY vhilm_ku.
  DELETE ADJACENT DUPLICATES FROM t_entregas_det COMPARING vhilm_ku.

  SELECT vegr1,bezei
   INTO TABLE @DATA(t_tve1t)
   FROM tve1t
   FOR ALL ENTRIES IN @t_entregas_det
   WHERE vegr1 EQ @t_entregas_det-zvegr1
     AND spras EQ 'S'.

  LOOP AT t_entregas_det ASSIGNING FIELD-SYMBOL(<entregas>).
    CLEAR: l_cont.
    ADD 1 TO l_cont.

    APPEND INITIAL LINE TO t_datos_etiq ASSIGNING FIELD-SYMBOL(<etiq>).
    "+@DL MEJORAS DEVK991747 {
    READ TABLE gt_entrenohu ASSIGNING FIELD-SYMBOL(<fs_nohu>)
                                      WITH KEY vbeln = <entregas>-vbeln
                                               ebeln = <entregas>-ebeln
                                               ebelp = <entregas>-ebelp
                                               vhilm_ku = <entregas>-vhilm_ku.
    IF sy-subrc EQ 0.
***
      <etiq>-exidv  = <fs_nohu>-exidv.
***       <etiq>-vegr2  = <fs_nohu>-vegr2.
***
***       <etiq>-inhalt = <fs_nohu>-inhalt.
***       <etiq>-vegr1  = <fs_nohu>-vegr1.
***       <etiq>-btgew = <fs_nohu>-brgew.
***
    ENDIF.
    "+@DL MEJORAS DEVK991747 }
****
    <etiq>-vhilm_ku  = <entregas>-vhilm_ku. "+@DL MEJORAS    Número de embalaje.
*    <etiq>-exidv  = <entregas>-vhilm_ku.
    <etiq>-vegr2  = <entregas>-vegr2.

    <etiq>-inhalt = <entregas>-inhalt.
    <etiq>-vegr1  = <entregas>-zvegr1.
    <etiq>-btgew = <entregas>-brgew.

    <etiq>-vbeln  = u_vbeln.
    <etiq>-aenam  = sy-uname.
    <etiq>-erdat  = sy-datum.


    READ TABLE t_likp ASSIGNING FIELD-SYMBOL(<likp>) WITH KEY vbeln = <entregas>-vbeln.
    IF sy-subrc EQ 0.
*      <etiq>-btgew = <likp>-btgew.
      <etiq>-gewei = <likp>-gewei.
      <etiq>-bolnr = <likp>-bolnr.
    ENDIF.

    READ TABLE t_lips ASSIGNING FIELD-SYMBOL(<lips>) WITH KEY vgbel = <entregas>-ebeln
                                                              vgpos = <entregas>-ebelp.
    IF sy-subrc EQ 0.
      <etiq>-lgort = <lips>-lgort.
      READ TABLE t_t001l ASSIGNING FIELD-SYMBOL(<t01l>) WITH KEY lgort = <lips>-lgort.
      IF sy-subrc EQ 0.
        <etiq>-lgobe = <t01l>-lgobe.
      ENDIF.
    ENDIF.

    READ TABLE t_tve1t ASSIGNING FIELD-SYMBOL(<bulto>) WITH KEY vegr1 = <etiq>-vegr1.
    IF sy-subrc EQ 0.
      <etiq>-bezei = <bulto>-bezei.
    ENDIF.

    READ TABLE t_entr_cab  ASSIGNING FIELD-SYMBOL(<fs_cab>) WITH KEY vbeln = <entregas>-vbeln.
    IF sy-subrc = 0.
      <etiq>-printer = <fs_cab>-printer.
    ENDIF.
  ENDLOOP.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form f_actualiza_camposcab
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*&      --> I_ENTR_DET
*&      --> LS_ENTR_CAB
*&---------------------------------------------------------------------*
FORM f_actualiza_camposcab  TABLES i_entr_det STRUCTURE zbvmm_st_i_entr_det
                            USING  ls_entr_cab TYPE zbvmm_st_i_entr_cab.


  SELECT  spras, vegr2, bezei
    FROM tve2t
    INTO TABLE @DATA(lt_tve2t)
    FOR ALL ENTRIES IN @i_entr_det
    WHERE vegr2 = @i_entr_det-vegr2.


  SELECT * INTO TABLE @DATA(lt_entregas)
    FROM zbvmm_entrega_re
    WHERE zvbeln EQ @ls_entr_cab-vbeln.
  IF sy-subrc EQ 0.
    LOOP AT lt_entregas ASSIGNING FIELD-SYMBOL(<fs_entregas>).
      <fs_entregas>-zbolnr =  ls_entr_cab-bolnr.
      <fs_entregas>-zbtgew = ls_entr_cab-brgew.
      "MP{
      <fs_entregas>-zanzpk = ls_entr_cab-anzpk.
      "MP}
*      READ TABLE i_entr_det ASSIGNING FIELD-SYMBOL(<fs_det>) WITH  KEY ebelp = <fs_entregas>-zvgpos
      READ TABLE gt_entrega_det ASSIGNING FIELD-SYMBOL(<fs_det>) WITH KEY ebelp = <fs_entregas>-zvgpos
                                                                       vbeln = <fs_entregas>-zvbeln
                                                                       ebeln = <fs_entregas>-zebeln
                                                                       matnr = <fs_entregas>-zmatnr
                                                                       vhilm_ku = <fs_entregas>-zvhilm_ku.
      IF sy-subrc = 0.
        <fs_entregas>-zbrgew_b = <fs_det>-brgew.
        <fs_entregas>-zvegr1  = <fs_det>-zvegr1.
        <fs_entregas>-zvegr2  = <fs_det>-vegr2.

        READ TABLE lt_tve2t ASSIGNING FIELD-SYMBOL(<fs_tve2t>) WITH KEY vegr2 = <fs_det>-vegr2.
        IF sy-subrc = 0.
          <fs_entregas>-zbezei = <fs_tve2t>-bezei.
        ENDIF.

        <fs_entregas>-zobservacion = <fs_det>-zobservacion.
        <fs_entregas>-zvemng =  <fs_det>-menge.
      ENDIF.
      MODIFY zbvmm_entrega_re FROM <fs_entregas>.
      COMMIT WORK.
    ENDLOOP.

    DELETE lt_entregas[] WHERE zvemng IS NOT INITIAL.
    IF lt_entregas[] IS NOT INITIAL.
      DELETE zbvmm_entrega_re FROM TABLE lt_entregas.
      COMMIT WORK.
    ENDIF.

  ENDIF.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form f_actualiza_entrega_z
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*&      --> LS_ENTR_CAB_VBELN
*&      --> LV_STATUS
*&---------------------------------------------------------------------*
FORM f_actualiza_entrega_z  USING u_vbeln TYPE vbeln_vl
                                 u_zzlfstk TYPE ze_lfstk.


  DATA:lt_status TYPE STANDARD TABLE OF zbvmm_estatus.
*  seleccionamos los status
  SELECT *
    FROM zbvmm_estatus
    INTO TABLE lt_status.

  SELECT * INTO TABLE @DATA(lt_entregas)
    FROM zbvmm_entrega_re
    WHERE zvbeln EQ @u_vbeln.
  IF sy-subrc EQ 0.
    LOOP AT lt_entregas ASSIGNING FIELD-SYMBOL(<fs_entregas>).
      <fs_entregas>-zzlfstk = u_zzlfstk.
      READ TABLE lt_status ASSIGNING FIELD-SYMBOL(<fs_status>) WITH KEY cod = <fs_entregas>-zzlfstk.
      IF sy-subrc = 0.
        <fs_entregas>-zzlfstkdesc = <fs_status>-descrip.
      ENDIF.
      MODIFY zbvmm_entrega_re FROM <fs_entregas>.
      COMMIT WORK.
    ENDLOOP.
  ENDIF.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form f_act_zbvmmemb_compr
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*&      --> I_ENTR_DET
*&      --> I_ENTR_CAB
*&      --> LV_STATUS
*&---------------------------------------------------------------------*
FORM f_act_zbvmmemb_compr  TABLES it_entr_det STRUCTURE zbvmm_st_i_entr_det
                                  it_entr_cab STRUCTURE zbvmm_st_i_entr_cab
                           USING lv_status    TYPE      ze_lfstk.           "INSERT @JGRS.

  TYPES: BEGIN OF gty_hucomple,
           vhilm_ku TYPE vhilm_ku,
           exidv    TYPE exidv,
         END OF gty_hucomple.

  TYPES: BEGIN OF lty_lips,
           vbeln TYPE lips-vbeln,
           posnr TYPE lips-posnr,
           matnr TYPE lips-matnr,
           werks TYPE lips-werks,
           lgort TYPE lips-lgort,
           vgbel TYPE lips-vgbel,
           vgpos TYPE lips-vgpos,
           charg TYPE lips-charg,
           lfimg TYPE lips-lfimg,
           vrkme TYPE lips-vrkme,
           umvkz TYPE lips-umvkz,
         END OF lty_lips.

  DATA: lt_hu_fict TYPE STANDARD TABLE OF gty_hucomple,
        lv_corre   TYPE i.

  DATA:ltd_lips    TYPE STANDARD TABLE OF lty_lips,
       ls_entr_cab TYPE zbvmm_st_i_entr_cab.
  DATA: lt_entr_detaux TYPE STANDARD TABLE OF zbvmm_st_i_entr_det.

  DATA:lv_vbeln         TYPE likp-vbeln.
  DATA: lv_vbeln_aux TYPE zbvmm_st_i_entr_cab-vbeln.

*{INSERT @JGRS
  TYPES: BEGIN OF gty_zzlug_ent,
           ebeln     TYPE ekpo-ebeln,
           ebelp     TYPE ekpo-ebelp,
           zzlug_ent TYPE ekpo-zzlug_ent,
           inco1     TYPE ekpo-inco1, "+@001
         END OF gty_zzlug_ent.
  DATA: lt_zzlug_ent TYPE STANDARD TABLE OF gty_zzlug_ent.
  FIELD-SYMBOLS:<fs_zzlug_ent> LIKE LINE OF lt_zzlug_ent.
  SELECT ebeln ebelp zzlug_ent
    inco1 "+@001
  INTO TABLE lt_zzlug_ent
  FROM ekpo
  FOR ALL ENTRIES IN it_entr_det
  WHERE ebeln EQ it_entr_det-ebeln
    AND ebelp EQ it_entr_det-ebelp+1(5).
  IF sy-subrc EQ '0'.
  ENDIF.
*}INSERT @JGRS
  REFRESH: gt_embcomp,lt_entr_detaux .

  READ TABLE it_entr_cab INTO ls_entr_cab INDEX 1.
  SELECT SINGLE vbeln
    INTO  lv_vbeln
    FROM likp
    WHERE vbeln = ls_entr_cab-vbeln.
  IF sy-subrc = 0.
    SELECT vbeln posnr matnr werks lgort vgbel vgpos charg lfimg vrkme umvkz
     INTO TABLE ltd_lips
     FROM lips
     WHERE vbeln = lv_vbeln.
  ENDIF.
  IF ltd_lips IS NOT INITIAL.
    SORT ltd_lips BY vbeln.
  ENDIF.


  IF gt_entrega_det[] IS NOT INITIAL.
    SELECT * INTO TABLE gt_embcomp_aux2 FROM zbvmm_emb_comp
      FOR ALL ENTRIES IN gt_entrega_det
        WHERE vbeln EQ gt_entrega_det-vbeln.
  ENDIF.


  IF it_entr_det[] IS NOT INITIAL.
    DATA(lt_entr_det_aux) = it_entr_det[].
    SORT lt_entr_det_aux BY vhilm_ku ASCENDING.
    DELETE ADJACENT DUPLICATES FROM lt_entr_det_aux COMPARING vhilm_ku.
    LOOP AT lt_entr_det_aux ASSIGNING FIELD-SYMBOL(<fs_entr>). "it_entr_det ASSIGNING <fs_entr>.
      APPEND INITIAL LINE TO gt_entrenohu ASSIGNING FIELD-SYMBOL(<fs_nohu>).
      MOVE-CORRESPONDING <fs_entr> TO <fs_nohu>.

      "cant - Menge = 0
      CLEAR: <fs_entr>-borrar.
      IF <fs_entr>-menge = 0.
        APPEND INITIAL LINE TO lt_entr_detaux ASSIGNING FIELD-SYMBOL(<fs_entaux>).
        MOVE-CORRESPONDING <fs_entr> TO <fs_entaux>.
        <fs_entr>-borrar =  abap_true.
      ENDIF.

      "Verificar embalajes complementarios.
      LOOP AT gt_emb_compl_re ASSIGNING FIELD-SYMBOL(<fs_emb_compl_re>)
                                     WHERE vhilm_ku_p EQ <fs_entr>-vhilm_ku.

        APPEND INITIAL LINE TO gt_embcomp ASSIGNING FIELD-SYMBOL(<fs_embcomp>).
        MOVE-CORRESPONDING <fs_emb_compl_re> TO <fs_embcomp>.
        MOVE <fs_emb_compl_re>-zvegr1 TO <fs_embcomp>-vegr1.


        READ TABLE ltd_lips ASSIGNING FIELD-SYMBOL(<fs_lips02>) WITH KEY vgbel  = <fs_entr>-ebeln
                                                                          vgpos = <fs_entr>-ebelp.

        IF sy-subrc = 0.
          <fs_embcomp>-vbeln = <fs_lips02>-vbeln.
*          <fs_embcomp>-posnr = <fs_lips02>-posnr. "Comentado porque el campo ya no existe en la tabla
          <fs_nohu>-vbeln = <fs_lips02>-vbeln.
          <fs_nohu>-posnr = <fs_lips02>-posnr.
          <fs_nohu>-lfdat = sy-datum.
          <fs_nohu>-lfuhr = sy-uzeit.
        ENDIF.
*        <fs_embcomp>-ebeln = <fs_entr>-ebeln. "Comentado porque el campo ya no existe en la tabla
*        <fs_embcomp>-ebelp = <fs_entr>-ebelp. "Comentado porque el campo ya no existe en la tabla
        <fs_embcomp>-vhilm_ku = <fs_emb_compl_re>-vhilm_ku_p.
        <fs_embcomp>-vhilm_ku_sub = <fs_emb_compl_re>-vhilm_ku.  "Emb. complemantario.
        <fs_embcomp>-lfdat = sy-datum.
        <fs_embcomp>-lfuhr = sy-uzeit.
*{INSERT @JGRS
        READ TABLE it_entr_det ASSIGNING FIELD-SYMBOL(<fs_entr_1>) WITH KEY vhilm_ku = <fs_emb_compl_re>-vhilm_ku_p.
        IF sy-subrc EQ 0.
          READ TABLE lt_zzlug_ent ASSIGNING <fs_zzlug_ent> WITH KEY ebeln = <fs_entr_1>-ebeln
                                                                    ebelp = <fs_entr_1>-ebelp+1(5).
          IF sy-subrc EQ 0.
*            <fs_embcomp>-zzlug_ent = <fs_zzlug_ent>-zzlug_ent. "-@001
            <fs_embcomp>-zzlug_ent = <fs_zzlug_ent>-inco1. "+@001
          ENDIF.
        ENDIF.
        <fs_embcomp>-zzlfstk = lv_status.
*}INSERT @JGRS
        READ TABLE gt_embcomp_aux2 ASSIGNING FIELD-SYMBOL(<fs_embcomp2>) WITH KEY vbeln = <fs_emb_compl_re>-vbeln
                                                                                  vhilm_ku  = <fs_emb_compl_re>-vhilm_ku_p
                                                                                  vhilm_ku_sub = <fs_emb_compl_re>-vhilm_ku.
        IF sy-subrc  = 0.
          <fs_embcomp>-exidv = <fs_embcomp2>-exidv.
        ENDIF.
      ENDLOOP.
    ENDLOOP.
    DELETE lt_entr_det_aux WHERE borrar EQ 'X'.



    CLEAR: lv_vbeln_aux.

    READ TABLE it_entr_cab[] ASSIGNING FIELD-SYMBOL(<fs_entr_cab>) INDEX 1.
    IF sy-subrc = 0.
      lv_vbeln_aux = <fs_entr_cab>-vbeln.
    ENDIF.

    "Actualiza tabla de embalajes complementarios.
    IF gt_embcomp IS NOT INITIAL.
      "Borrar todos embalajes.
      IF lv_vbeln_aux IS NOT INITIAL.
        DELETE FROM zbvmm_emb_comp WHERE vbeln EQ lv_vbeln_aux.
        COMMIT WORK.
      ENDIF.

      "Borrar complementarios con Cant-Menge 0
      LOOP AT gt_embcomp ASSIGNING <fs_embcomp>.
        READ TABLE lt_entr_detaux  ASSIGNING <fs_entaux> WITH KEY vhilm_ku = <fs_embcomp>-vhilm_ku.
        IF sy-subrc = 0.
          DELETE TABLE gt_embcomp FROM <fs_embcomp>.
        ENDIF.
      ENDLOOP.

      MODIFY zbvmm_emb_comp FROM TABLE gt_embcomp.
      IF sy-subrc EQ 0.
        COMMIT WORK.
      ENDIF.

      it_entr_det[] = lt_entr_det_aux[].
    ENDIF.
  ENDIF.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form f_agrupa_no_hu_modif
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*&      --> LTD_I_ENTR_DET
*&---------------------------------------------------------------------*
FORM f_agrupa_no_hu_modif  TABLES it_entr_det STRUCTURE zbvmm_st_i_entr_det.

  g_marc_nohu = abap_true.

  DATA: lt_entr_det TYPE STANDARD TABLE OF zbvmm_st_i_entr_det.

  lt_entr_det =  it_entr_det[].

*  SORT it_entr_det BY vhilm_ku ASCENDING. "brgew ASCENDING.
*  DELETE ADJACENT DUPLICATES FROM it_entr_det COMPARING vhilm_ku.

  SORT it_entr_det BY ebeln ebelp matnr. "vhilm_ku.
  DELETE ADJACENT DUPLICATES FROM it_entr_det COMPARING ebeln ebelp matnr. " vhilm_ku.

*  IF sy-subrc EQ 0. "Si se borró algún duplicado se cargan cantidades por pedido, pos, mat.
  LOOP AT it_entr_det ASSIGNING FIELD-SYMBOL(<fs_itdet>).

    CLEAR: <fs_itdet>-menge.
    LOOP AT lt_entr_det ASSIGNING FIELD-SYMBOL(<fs_det>) WHERE ebeln EQ <fs_itdet>-ebeln
                                                           AND ebelp EQ <fs_itdet>-ebelp
                                                           AND matnr EQ <fs_itdet>-matnr.
      "AND vhilm_ku EQ <fs_itdet>-vhilm_ku. "Bulto
      ADD <fs_det>-menge TO <fs_itdet>-menge.
    ENDLOOP.

  ENDLOOP.
*  ENDIF.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form f_bdc
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*&      --> P_
*&      --> P_
*&      --> P_
*&---------------------------------------------------------------------*
FORM f_bdc  USING    us_program  TYPE any
                     us_dynpro   TYPE any
                     us_dynbegin TYPE any.

  CLEAR: gs_bdc.

  IF us_dynbegin EQ 'X'.

    MOVE us_program TO gs_bdc-program.

    MOVE us_dynpro TO gs_bdc-dynpro.

    MOVE us_dynbegin TO gs_bdc-dynbegin.

    APPEND gs_bdc TO gt_bdc.

  ELSE.

    CLEAR:gs_bdc.

    MOVE us_program TO gs_bdc-fnam.

    MOVE us_dynpro TO gs_bdc-fval.

    APPEND gs_bdc TO gt_bdc.

  ENDIF.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form f_modif_zbvmm_entrenohu
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*&      --> I_ENTR_DET
*&      --> LV_STATUS
*&---------------------------------------------------------------------*
FORM f_modif_zbvmm_entrenohu  TABLES it_entr_det STRUCTURE zbvmm_st_i_entr_det
                              USING lv_status    TYPE      ze_lfstk.           "INSERT @JGRS.
*{INSERT @JGRS
  TYPES: BEGIN OF gty_zzlug_ent,
           ebeln     TYPE ekpo-ebeln,
           ebelp     TYPE ekpo-ebelp,
           zzlug_ent TYPE ekpo-zzlug_ent,
           inco1     TYPE ekpo-inco1, "+@001
         END OF gty_zzlug_ent.
  DATA:lt_zzlug_ent TYPE STANDARD TABLE OF gty_zzlug_ent.
  FIELD-SYMBOLS:<fs_zzlug_ent> LIKE LINE OF lt_zzlug_ent.

  SELECT ebeln ebelp zzlug_ent
         inco1 "+@001
  INTO TABLE lt_zzlug_ent
  FROM ekpo
  FOR ALL ENTRIES IN it_entr_det
  WHERE ebeln EQ it_entr_det-ebeln
    AND ebelp EQ it_entr_det-ebelp+1(5).
  IF sy-subrc EQ '0'.
  ENDIF.
*}INSERT @JGRS

  SELECT * INTO TABLE gt_entrenohu FROM zbvmm_entrenohu
  FOR ALL ENTRIES IN it_entr_det
    WHERE vbeln EQ it_entr_det-vbeln
*    AND posnr EQ it_entr_det-posnr
      AND ebeln EQ it_entr_det-ebeln
      AND ebelp EQ it_entr_det-ebelp.

  IF sy-subrc EQ 0.
    LOOP AT  it_entr_det ASSIGNING FIELD-SYMBOL(<fs_det>).
      IF <fs_det>-menge EQ 0.
        "Borrar pos.
        <fs_det>-borrar = 'X'.
        DELETE FROM  zbvmm_entrenohu WHERE vhilm_ku EQ <fs_det>-vhilm_ku
                                       AND ebeln EQ <fs_det>-ebeln
                                       AND ebelp EQ <fs_det>-ebelp
                                       AND matnr EQ <fs_det>-matnr.
        IF sy-subrc EQ 0.
          PERFORM commit_wait.
          "Eliminar complementarios relacionados.
          DELETE FROM zbvmm_emb_comp WHERE vbeln EQ  <fs_det>-vbeln
                                     AND vhilm_ku EQ <fs_det>-vhilm_ku.
          IF sy-subrc EQ 0.
            PERFORM commit_wait.
          ENDIF.
          DELETE gt_emb_compl_re WHERE  vhilm_ku_p EQ <fs_det>-vhilm_ku.
        ENDIF.
      ELSE.
        "Modificar pos.
        READ TABLE gt_entrenohu ASSIGNING FIELD-SYMBOL(<fs_entrenohu>)
                                WITH KEY vbeln    = <fs_det>-vbeln
*                                           posnr = <fs_det>-posnr
                                         ebeln    = <fs_det>-ebeln
                                         ebelp    = <fs_det>-ebelp
                                         vhilm_ku = <fs_det>-vhilm_ku
                                         .
        IF sy-subrc EQ 0.
          <fs_entrenohu>-menge = <fs_det>-menge.
          <fs_entrenohu>-vegr1 = <fs_det>-zvegr1.
          <fs_entrenohu>-vegr2 = <fs_det>-vegr2.
          <fs_entrenohu>-inhalt = <fs_det>-inhalt.
          <fs_entrenohu>-brgew = <fs_det>-brgew.

          MODIFY zbvmm_entrenohu FROM <fs_entrenohu>.
          IF sy-subrc EQ 0.

            PERFORM commit_wait.

            "Agrega emb. complementarios relacionados.
            LOOP AT  gt_emb_compl_re ASSIGNING FIELD-SYMBOL(<fs_emb_compl_re>)
                                     WHERE vhilm_ku_p EQ <fs_det>-vhilm_ku
                                       AND marca_agre EQ abap_false.  "Sólo los subembalajes que aun no han sido agregados

              APPEND INITIAL LINE TO gt_embcomp ASSIGNING FIELD-SYMBOL(<fs_embcomp>).
              MOVE-CORRESPONDING <fs_emb_compl_re> TO <fs_embcomp>.
*                   <fs_embcomp>-vbeln = <fs_entrenohu>-vbeln.
*                   <fs_embcomp>-posnr = <fs_entrenohu>-posnr.
*                   <fs_embcomp>-ebeln = <fs_entrenohu>-ebeln.
*                   <fs_embcomp>-ebelp = <fs_entrenohu>-ebelp.
              <fs_embcomp>-vhilm_ku = <fs_emb_compl_re>-vhilm_ku_p.
              <fs_embcomp>-vhilm_ku_sub = <fs_emb_compl_re>-vhilm_ku.  "Emb. complemantario.
              <fs_embcomp>-lfdat = sy-datum.
              <fs_embcomp>-lfuhr = sy-uzeit.
              <fs_embcomp>-exidv = <fs_entrenohu>-exidv. "HU principal.
              <fs_embcomp>-vegr1 = <fs_emb_compl_re>-zvegr1.
              <fs_emb_compl_re>-marca_agre = abap_true. "Indicador de sub embalaje agregado
*{INSERT @JGRS
              READ TABLE lt_zzlug_ent ASSIGNING <fs_zzlug_ent> WITH KEY ebeln = <fs_det>-ebeln
                                                                        ebelp = <fs_det>-ebelp+1(5).
              IF sy-subrc EQ 0.
*                <fs_embcomp>-zzlug_ent = <fs_zzlug_ent>-zzlug_ent. "-@001
                <fs_embcomp>-zzlug_ent = <fs_zzlug_ent>-inco1.  "+@001
              ENDIF.
              <fs_embcomp>-zzlfstk = lv_status.
*}INSERT @JGRS
            ENDLOOP.

            IF gt_emb_compl_re[] IS NOT INITIAL.

              MODIFY zbvmm_emb_comp FROM TABLE gt_embcomp.
              IF sy-subrc EQ 0.
                PERFORM commit_wait.
              ENDIF.
            ENDIF.
          ENDIF.
        ENDIF.
      ENDIF.
    ENDLOOP.
  ENDIF.
  DELETE gt_emb_compl_re WHERE borrar EQ 'X'.
  DELETE it_entr_det WHERE borrar EQ 'X'.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form f_read_e
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*&      --> IT_RETURN
*&      --> T_RESULT
*&---------------------------------------------------------------------*
FORM f_read_e  TABLES t_return STRUCTURE bapiret2
                     t_result STRUCTURE zbvmm_st_i_resultado.

  DATA: i_msg   TYPE natxt,
        l_msgid TYPE symsgid,
        l_msgno TYPE symsgno,
        l_msgv1 TYPE syst_msgv,
        l_msgv2 TYPE syst_msgv,
        l_msgv3 TYPE syst_msgv,
        l_msgv4 TYPE syst_msgv.

  LOOP AT t_return ASSIGNING FIELD-SYMBOL(<fs_ret>) WHERE type EQ 'E'.
    CLEAR: l_msgid, l_msgno, l_msgv1, l_msgv2, l_msgv3, l_msgv4.
    l_msgid  = <fs_ret>-id.
    l_msgno  = <fs_ret>-number.
    l_msgv1 = <fs_ret>-message_v1.
    l_msgv2 = <fs_ret>-message_v2.
    l_msgv3 = <fs_ret>-message_v3.
    l_msgv4 = <fs_ret>-message_v4.

    CALL FUNCTION '/SAPTRX/GET_MESSAGE_TEXT'
      EXPORTING
        msgid                = l_msgid
        msgno                = l_msgno
        msgv1                = l_msgv1
        msgv2                = l_msgv2
        msgv3                = l_msgv3
        msgv4                = l_msgv4
      IMPORTING
        messagetext          = i_msg
      EXCEPTIONS
        no_message_retrieved = 1
        OTHERS               = 2.

    APPEND INITIAL LINE TO t_result ASSIGNING FIELD-SYMBOL(<fs_result>).
*                <fs_result>-vbeln = lv_vbeln.
    <fs_result>-codigo = <fs_ret>-number.
    <fs_result>-msg = i_msg.
    <fs_result>-msgtyp = <fs_ret>-type.

  ENDLOOP.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form load_table
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*&      --> I_ENTR_DET
*&      --> I_ENTR_CAB
*&      --> LV_VBELN
*&      <-- T_DATOS_IMP
*&---------------------------------------------------------------------*
FORM load_table  TABLES t_entregas_det STRUCTURE zbvmm_st_i_entr_det
                       t_entr_cab STRUCTURE zbvmm_st_i_entr_cab
                 USING u_vbeln TYPE vbeln
                CHANGING t_datos_etiq TYPE zbvmm_tt_etiqueta_qr.

  DATA: lv_part1 TYPE string, "+@JY
        lv_part2 TYPE string. "+@JY

  DATA: l_cont TYPE i.

  "Determinar bultos.
  SELECT venum,exidv,vhilm_ku,erdat,eruhr
         INTO TABLE @DATA(ldt_vekp)
          FROM vekp
          WHERE vpobjkey EQ @u_vbeln.
  IF sy-subrc EQ 0.
    SORT ldt_vekp BY erdat DESCENDING eruhr DESCENDING.
  ENDIF.

  "Determinar almacen.
  SELECT SINGLE bolnr
   INTO @DATA(l_bolnr)
   FROM likp
   WHERE vbeln = @u_vbeln.

  "Determinar almacen.
  SELECT vbeln, posnr, werks, lgort, vgbel, vgpos, charg, lfimg, vrkme, umvkz
   INTO TABLE @DATA(t_lips)
   FROM lips
   WHERE vbeln = @u_vbeln.

  IF sy-subrc EQ 0.
    SELECT werks, lgort, xhupf, lgobe
     INTO TABLE @DATA(t_t001l)
     FROM t001l
     FOR ALL ENTRIES IN @t_lips
     WHERE lgort = @t_lips-lgort
      AND werks = @t_lips-werks."MP
    IF sy-subrc EQ 0.
*+{@JY
***      LOOP AT t_t001l ASSIGNING FIELD-SYMBOL(<f_t001l>).
***        SPLIT <f_t001l>-lgobe AT space INTO lv_part1 lv_part2.
***        IF lv_part2 IS NOT INITIAL.
***          <f_t001l>-lgobe = lv_part2.
***        ELSE.
***          <f_t001l>-lgobe = lv_part1.
***        ENDIF.
****    TRANSLATE <f_t001l>-lgobe TO UPPER CASE.
***        CONDENSE <f_t001l>-lgobe.
***      ENDLOOP.
*+}@JY
    ENDIF.
  ENDIF.

  SELECT vegr1, bezei INTO TABLE @DATA(t_bulto)
       FROM tve1t
       WHERE spras EQ 'S'.


  "borrar duplicados bultos.
  SORT t_entregas_det BY vhilm_ku.
  DELETE ADJACENT DUPLICATES FROM t_entregas_det COMPARING vhilm_ku.

  LOOP AT t_entregas_det ASSIGNING FIELD-SYMBOL(<entregas>).

    CLEAR: l_cont.
*    DO <entregas>-zul_aufl TIMES.
    ADD 1 TO l_cont.
    APPEND INITIAL LINE TO t_datos_etiq ASSIGNING FIELD-SYMBOL(<etiq>).

    READ TABLE ldt_vekp ASSIGNING FIELD-SYMBOL(<vekp>)
                        WITH KEY vhilm_ku = <entregas>-vhilm_ku.
    IF sy-subrc EQ 0.
      <etiq>-exidv = <vekp>-exidv.
      <etiq>-cod_qr = <vekp>-exidv.
    ENDIF.

    READ TABLE t_lips ASSIGNING FIELD-SYMBOL(<lips>)
                      WITH KEY vgbel = <entregas>-ebeln
                               vgpos = <entregas>-ebelp.
    IF sy-subrc EQ 0.
      <etiq>-lgort = <lips>-lgort.

      READ TABLE t_t001l ASSIGNING FIELD-SYMBOL(<t01l>)
                         WITH KEY lgort = <lips>-lgort.

      IF sy-subrc EQ 0.
        <etiq>-lgobe = <t01l>-lgobe.
      ENDIF.

    ENDIF.

    <etiq>-inhalt = <entregas>-zobservacion.
    <etiq>-vegr1 = <entregas>-zvegr1.

    "Se asigna descripción de vegr1.
    IF t_bulto IS NOT INITIAL.
      READ TABLE t_bulto ASSIGNING FIELD-SYMBOL(<bulto>)
                         WITH KEY vegr1 = <etiq>-vegr1.

      IF sy-subrc EQ 0.
        <etiq>-bezei = <bulto>-bezei.
      ENDIF.

    ENDIF.
    <etiq>-bolnr = l_bolnr.
    <etiq>-vegr2 = <entregas>-vegr2.
    <etiq>-vbeln = u_vbeln.
    <etiq>-aenam = sy-uname.
    <etiq>-erdat = sy-datum.
    <etiq>-zul_aufl = <entregas>-zul_aufl.
    <etiq>-zul_aufl_cant = l_cont.
    <etiq>-vhilm_ku  = <entregas>-vhilm_ku. "MP
    READ TABLE t_entr_cab  ASSIGNING FIELD-SYMBOL(<fs_cab>) WITH KEY vbeln = <entregas>-vbeln.
    IF sy-subrc = 0.
      <etiq>-printer = <fs_cab>-printer.   "Impresora por vegr1
    ENDIF.

*    ENDDO.

  ENDLOOP.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form f_cambio_fechas
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*&      --> GS_ENTREGA_CHANGE
*&---------------------------------------------------------------------*
FORM f_cambio_fechas  USING  i_entrega TYPE gty_entrega_change.

  DATA: lv_fecha TYPE string,
        lv_hora  TYPE string.

  CLEAR: gwa_params, gv_msg.
  REFRESH: gt_messtab[], gt_result[], gt_bdc[] .

  CONCATENATE i_entrega-lfdat+6(2) '.' i_entrega-lfdat+4(2) '.' i_entrega-lfdat+0(4) INTO lv_fecha.
  CONDENSE lv_fecha NO-GAPS.
  CONCATENATE i_entrega-lfuhr+0(2) ':' i_entrega-lfuhr+2(2) INTO lv_hora.
  CONDENSE lv_hora NO-GAPS.

  gwa_params-dismode  = 'N'.
  gwa_params-updmode  = 'S'.
  gwa_params-racommit = 'X'.

  PERFORM f_bdc USING 'SAPMV50A' '4104' 'X'.
  PERFORM f_bdc USING 'BDC_CURSOR' 'LIKP-VBELN' ''.
  PERFORM f_bdc USING 'BDC_OKCODE' '/00' ''.
  PERFORM f_bdc USING 'LIKP-VBELN' i_entrega-vbeln ''.

  PERFORM f_bdc USING 'SAPMV50A' '1000' 'X'.
  PERFORM f_bdc USING 'BDC_OKCODE' '=SICH_T' ''.
  PERFORM f_bdc USING 'BDC_SUBSCR' 'SAPMV50A' ''.
  PERFORM f_bdc USING 'BDC_SUBSCR' 'SAPMV50A' ''.
  PERFORM f_bdc USING 'BDC_CURSOR' 'RV50A-WADAT_IST_LA' ''.
  PERFORM f_bdc USING 'RV50A-LFDAT_LA' lv_fecha ''.
  PERFORM f_bdc USING 'RV50A-LFUHR_LA' lv_hora ''.
  PERFORM f_bdc USING 'BDC_SUBSCR' 'SAPMV50A' ''.
  PERFORM f_bdc USING 'BDC_SUBSCR' 'SAPMV50A' ''.

  CALL TRANSACTION 'VL32N' USING gt_bdc
       OPTIONS FROM gwa_params
       MESSAGES INTO gt_messtab.

  LOOP AT gt_messtab ASSIGNING FIELD-SYMBOL(<fs_messtab>) WHERE msgtyp EQ 'E'.
    PERFORM f_read_msg_e USING <fs_messtab>
                         .

    IF gv_msg NE ''.
      APPEND INITIAL LINE TO gt_result ASSIGNING FIELD-SYMBOL(<fs_result>).
      <fs_result>-vbeln = i_entrega-vbeln.
      <fs_result>-codigo = <fs_messtab>-msgnr.
      <fs_result>-msg = gv_msg.
      <fs_result>-type = <fs_messtab>-msgtyp.

    ENDIF.
  ENDLOOP.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form f_read_msg_e
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*&      --> <FS_MESSTAB>
*&---------------------------------------------------------------------*
FORM f_read_msg_e  USING is_messtab TYPE bdcmsgcoll
                   .
  DATA:
    l_msgid TYPE symsgid,
    l_msgno TYPE symsgno,
    l_msgv1 TYPE syst_msgv,
    l_msgv2 TYPE syst_msgv,
    l_msgv3 TYPE syst_msgv,
    l_msgv4 TYPE syst_msgv.

  l_msgid  = is_messtab-msgid.
  l_msgno  = is_messtab-msgnr.
  l_msgv1 = is_messtab-msgv1.
  l_msgv2 = is_messtab-msgv2.
  l_msgv3 = is_messtab-msgv3.
  l_msgv4 = is_messtab-msgv4.

  CLEAR: gv_msg.

  CALL FUNCTION '/SAPTRX/GET_MESSAGE_TEXT'
    EXPORTING
      msgid                = l_msgid
      msgno                = l_msgno
      msgv1                = l_msgv1
      msgv2                = l_msgv2
      msgv3                = l_msgv3
      msgv4                = l_msgv4
    IMPORTING
      messagetext          = gv_msg
    EXCEPTIONS
      no_message_retrieved = 1
      OTHERS               = 2.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form f_bapi_delivery_change1
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*&      --> LT_RETURN
*&      --> GS_ENTREGA_CHANGE
*&      --> G_OK
*&---------------------------------------------------------------------*
FORM f_bapi_delivery_change1  TABLES t_return STRUCTURE bapiret2
                              USING  i_entrega TYPE gty_entrega_change
                                     i_ok TYPE abap_bool.

  DATA: ls_header_data    TYPE bapiibdlvhdrchg,
        ls_header_control TYPE bapiibdlvhdrctrlchg,
        ls_result         TYPE zbvmm_st_result_planificacion.

  DATA: lt_extension2  TYPE STANDARD TABLE OF bapiext,
        lwa_extension2 TYPE bapiext.
  DATA: lv_param TYPE zge_t_constantes-low,
        i_msg    TYPE natxt,
        l_msgid  TYPE sy-msgid, "symsgid,
        l_msgno  TYPE sy-msgno, "symsgno,
        l_m1     TYPE sy-msgv1,
        l_m2     TYPE sy-msgv2,
        l_m3     TYPE sy-msgv3,
        l_m4     TYPE sy-msgv4.

  CLEAR: ls_header_data, ls_header_control, g_msg.

  g_syno0 = abap_false.

  REFRESH: lt_extension2, t_return.
  ls_header_data-deliv_numb    = i_entrega-vbeln.
  ls_header_control-deliv_numb = i_entrega-vbeln.

  IF  i_entrega-bolnrx EQ abap_true. "Carta porte.

    CLEAR lwa_extension2.
    lwa_extension2-param = 'INT_WEB'.
    lwa_extension2-field = 'BOLNR'.
    lwa_extension2-value =  i_entrega-bolnr.
    APPEND lwa_extension2 TO lt_extension2.

  ELSEIF i_entrega-datex EQ abap_true.  "Fechas.
*   Fecha de Entrega
    CLEAR lwa_extension2.
    lwa_extension2-param = i_entrega-param.  " 'INT_WEB'.
    lwa_extension2-field = 'LFDAT'. "text-c07. "'LFDAT'.     "-+@DL PT
    lwa_extension2-value = i_entrega-lfdat.
    APPEND lwa_extension2 TO lt_extension2.

    CLEAR lwa_extension2.
    lwa_extension2-param = i_entrega-param.  " 'INT_WEB'.
    lwa_extension2-field = 'LFUHR'. " text-c08. "'LFUHR'.      "-+@DL PT
    lwa_extension2-value = i_entrega-lfuhr.
    APPEND lwa_extension2 TO lt_extension2.

    CLEAR lwa_extension2.
    lwa_extension2-param = i_entrega-param.  " 'INT_WEB'.
    lwa_extension2-field = 'KZLFD'.  "text-c09.  "'KZLFD'.     "-+@DL PT
    lwa_extension2-value = 'X'.
    APPEND lwa_extension2 TO lt_extension2.

*   Fecha de planificación
    CLEAR lwa_extension2.
    lwa_extension2-param = i_entrega-param.  " 'INT_WEB'.
    lwa_extension2-field = 'TDDAT'. "text-c15. "'TDDAT'.     "-+@DL PT
    lwa_extension2-value = i_entrega-lfdat.
    APPEND lwa_extension2 TO lt_extension2.

    CLEAR lwa_extension2.
    lwa_extension2-param = i_entrega-param.  " 'INT_WEB'.
    lwa_extension2-field = 'TDUHR'. "text-c16. "'TDUHR'.  "-+@DL PT
    lwa_extension2-value = i_entrega-lfuhr.
    APPEND lwa_extension2 TO lt_extension2.

    CLEAR lwa_extension2.
    lwa_extension2-param = i_entrega-param.  " 'INT_WEB'.
    lwa_extension2-field = 'KZTDDAT'. ".text-c17.  "'KZTDDAT'.    "-+@DL PT
    lwa_extension2-value = 'X'.
    APPEND lwa_extension2 TO lt_extension2.


  ELSEIF i_entrega-statusx EQ abap_true.  "Status

    CLEAR lwa_extension2.
    lwa_extension2-param = 'INT_WEB'.
    lwa_extension2-field = 'ZZLFSTK' ."text-c12.  "'ZZLFSTK'.   "-+@DL PT
    lwa_extension2-value = <fs_final>-zzlfstk.
    APPEND lwa_extension2 TO lt_extension2.

  ENDIF.

  CALL FUNCTION 'BAPI_INB_DELIVERY_CHANGE'
    EXPORTING
      header_data    = ls_header_data
      header_control = ls_header_control
      delivery       = i_entrega-vbeln
    TABLES
      extension2     = lt_extension2
      return         = t_return.

  IF sy-subrc EQ 0.

  ELSE.
    MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
    INTO DATA(mtext)
    WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.

    g_msg = mtext.
    g_syno0 = abap_true.

  ENDIF.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form clear
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM clear .

  FREE: gt_adr6[], gt_bdc[], gt_const[], gt_ekko[], gt_ekpo[], gt_final[], gt_lfa1[], gt_marc[], gt_t001w[],
        gt_final_vepo[].
  FREE: gt_tve2t[], gt_vekp[], gt_vepo[], gt_zadr[], gt_likp[], gt_lips[], gt_lips[], gt_makt[], gt_reg_ent[],
        gt_reg_ent[].
  FREE: gr_vpobjkey[], gr_matnr[], gr_crit[], gr_regu[], gr_irre[], gr_estr[], gr_lifnr[], gr_werks[], gr_ernam[],
        gr_vgbel[], gr_venum[], gt_likps[], gt_likps_aux[], gt_t001l[], gt_t001wadr[], gt_ekko_p[], gt_adrp[],
        gt_const_portal[], gt_status[], gt_condicion[], gt_mensajes[], gt_entrenohu[].


  CLEAR: gv_crit, gv_regu, gv_irre, gv_estr, g_ok, g_marc_nohu.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form GET_CONT_VALIDACION
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM get_cont_validacion .

  SELECT *
    INTO TABLE @DATA(lt_cont)
    FROM zge_t_constantes "zostb_constantes
    WHERE modulo EQ 'MM'
    AND   programa EQ 'LZGF_CON_PORTALF01'
    AND   campo EQ 'DISPO'.

  SORT lt_cont BY aplicacion ASCENDING.

  LOOP AT lt_cont INTO DATA(ls_cont).
    APPEND INITIAL LINE TO gtr_vali ASSIGNING FIELD-SYMBOL(<fs_vali>).
    <fs_vali>-sign    = ls_cont-sign.        "SIGNO DE COMPARACION
    <fs_vali>-option  = ls_cont-opt.       "OPCION DE COMPARACION
    <fs_vali>-compar  = ls_cont-low.       "VALOR A COMPARAR
    <fs_vali>-posici  = ls_cont-high.       "POSICION DEL VALOR A COMPARAR
    <fs_vali>-criter  = ls_cont-aplicacion.   "CRITERIO
  ENDLOOP.

ENDFORM.

*&---------------------------------------------------------------------*
*&      Form  lotes_modif
*&---------------------------------------------------------------------*
*&  Crea, actualiza y elimina las subposiciones de lote (9000xx) de las
*&  posiciones que llegan con lotes desde el portal.          "+@LOTE
*&---------------------------------------------------------------------*
FORM lotes_modif TABLES it_lot          STRUCTURE zbvmm_st_guardar_entrega_det_m
                        it_result       STRUCTURE zbvmm_st_result
                        ct_item_data    STRUCTURE bapiibdlvitemchg
                        ct_item_control STRUCTURE bapiibdlvitemctrlchg
                 USING  is_cabecera     TYPE zbvmm_st_modificar_entrega
                 CHANGING e_error       TYPE abap_bool.

  TYPES: BEGIN OF lty_pos,
           vgbel TYPE lips-vgbel,
           vgpos TYPE lips-vgpos,
           posnr TYPE lips-posnr,      "posición padre en la entrega
         END OF lty_pos.

  DATA: lt_pos         TYPE STANDARD TABLE OF lty_pos,
        ls_pos         TYPE lty_pos,
        lv_posnrlt     TYPE lips-posnr,
        lv_matnr_batch TYPE matnr18,
        lv_charg       TYPE charg_d,
        lwa_batchattr  TYPE bapibatchatt,
        lt_return      TYPE STANDARD TABLE OF bapiret2,
        lv_hay_lotes   TYPE abap_bool,
        lv_hay_splits  TYPE abap_bool,
        lv_n_lotes     TYPE i,                    "+@004
        lv_unidad      TYPE vrkme.                "+@004

  "+@004 Una sola vez por llamada: proce_hu llama dos veces a modif_entrega
  "y la segunda no debe volver a crear lotes ni subposiciones.
  CHECK gv_lotes_mod_hechos EQ abap_false.

  "Sin posiciones de entrega no hay nada que hacer. Además el FOR ALL
  "ENTRIES de abajo leería EKPO entero si gt_lips02 llegara vacía.
  CHECK gt_lips02[] IS NOT INITIAL.

  SELECT ebeln, ebelp, werks, lgort, umren, bwtar
    INTO TABLE @DATA(lt_ekpo_lot)
    FROM ekpo
    FOR ALL ENTRIES IN @gt_lips02
    WHERE ebeln EQ @gt_lips02-vgbel.

  "Correlativo: arranca en el máximo existente, NO en 900000,
  "o se pisan subposiciones ya creadas en la entrega.
  lv_posnrlt = '900000'.
  LOOP AT gt_lips02 ASSIGNING FIELD-SYMBOL(<fs_max>).
    IF <fs_max>-posnr GT lv_posnrlt.
      lv_posnrlt = <fs_max>-posnr.
    ENDIF.
  ENDLOOP.

  "Posición padre de cada posición de pedido: la de menor POSNR del grupo.
  "+@004 Solo líneas sin UECHA: una subposición de lote nunca es la padre.
  DATA(lt_lips_ord) = gt_lips02[].
  DELETE lt_lips_ord WHERE uecha IS NOT INITIAL.   "+@004
  SORT lt_lips_ord BY vgbel vgpos posnr.

  LOOP AT lt_lips_ord ASSIGNING FIELD-SYMBOL(<fs_l>).
    READ TABLE lt_pos TRANSPORTING NO FIELDS
         WITH KEY vgbel = <fs_l>-vgbel
                  vgpos = <fs_l>-vgpos.
    CHECK sy-subrc NE 0.
    CLEAR ls_pos.
    ls_pos-vgbel = <fs_l>-vgbel.
    ls_pos-vgpos = <fs_l>-vgpos.
    ls_pos-posnr = <fs_l>-posnr.
    APPEND ls_pos TO lt_pos.
  ENDLOOP.

  LOOP AT lt_pos ASSIGNING FIELD-SYMBOL(<fs_pos>).

    CLEAR: lv_hay_lotes, lv_hay_splits, lv_n_lotes.

    LOOP AT it_lot ASSIGNING FIELD-SYMBOL(<fs_lot>)
                   WHERE ebeln EQ <fs_pos>-vgbel
                     AND ebelp EQ <fs_pos>-vgpos.
      lv_hay_lotes = abap_true.
      lv_n_lotes = lv_n_lotes + 1.                "+@004
    ENDLOOP.

*    LOOP AT gt_lips02 ASSIGNING FIELD-SYMBOL(<fs_split>)   "-@004
*                      WHERE vgbel EQ <fs_pos>-vgbel
*                        AND vgpos EQ <fs_pos>-vgpos
*                        AND posnr NE <fs_pos>-posnr.
    "+@004 Subposiciones de lote = líneas cuya superior (UECHA) es la padre.
    "Otra línea del mismo pedido/posición sin UECHA no es una partición.
    LOOP AT gt_lips02 ASSIGNING FIELD-SYMBOL(<fs_split>)
                      WHERE uecha EQ <fs_pos>-posnr.
      lv_hay_splits = abap_true.
    ENDLOOP.

    CHECK lv_hay_lotes EQ abap_true OR lv_hay_splits EQ abap_true.

    READ TABLE gt_lips02 ASSIGNING FIELD-SYMBOL(<fs_lips_p>)
         WITH KEY vbeln = is_cabecera-vbeln
                  posnr = <fs_pos>-posnr.
    CHECK sy-subrc EQ 0.

    READ TABLE lt_ekpo_lot ASSIGNING FIELD-SYMBOL(<fs_ekpo_l>)
         WITH KEY ebeln = <fs_pos>-vgbel
                  ebelp = <fs_pos>-vgpos+1(5).
    CHECK sy-subrc EQ 0.

    "+@004 LTMENGE viene en la unidad del pedido, que es la unidad de venta
    "de la entrega (VRKME). MEINS es la unidad base: solo como respaldo.
    lv_unidad = COND #( WHEN <fs_lips_p>-vrkme IS NOT INITIAL
                        THEN <fs_lips_p>-vrkme ELSE <fs_lips_p>-meins ).

*--- 1. Lotes que ya existen: sólo cambia la cantidad -------------------
    LOOP AT it_lot ASSIGNING <fs_lot>
                   WHERE ebeln EQ <fs_pos>-vgbel
                     AND ebelp EQ <fs_pos>-vgpos
                     AND posnr IS NOT INITIAL.

      APPEND INITIAL LINE TO ct_item_data    ASSIGNING FIELD-SYMBOL(<fs_id>).
      APPEND INITIAL LINE TO ct_item_control ASSIGNING FIELD-SYMBOL(<fs_ic>).

      <fs_id>-deliv_numb  = is_cabecera-vbeln.
      <fs_id>-deliv_item  = <fs_lot>-posnr.
      <fs_id>-material    = <fs_lips_p>-matnr.
      <fs_id>-batch       = <fs_lot>-charg.
      <fs_id>-dlv_qty     = <fs_lot>-ltmenge.
*      <fs_id>-sales_unit  = <fs_lips_p>-meins.   "-@004
      <fs_id>-sales_unit  = lv_unidad.             "+@004
      <fs_id>-dlv_qty_imunit  = 0.
      <fs_id>-fact_unit_denom = <fs_ekpo_l>-umren.
      <fs_id>-fact_unit_nom   = <fs_lips_p>-umvkz.

      <fs_ic>-deliv_numb  = is_cabecera-vbeln.
      <fs_ic>-deliv_item  = <fs_lot>-posnr.
      "+@004 Cantidad 0 en un lote existente = quitarlo (se elimina la línea).
      IF <fs_lot>-ltmenge IS INITIAL.
        <fs_ic>-del_item  = abap_true.
        CONTINUE.
      ENDIF.
      <fs_ic>-chg_delqty  = abap_true.
      "+@004 Si el portal cambió el vencimiento de un lote existente.
      IF <fs_lot>-ltvfdat IS NOT INITIAL.
        <fs_id>-expirydate     = <fs_lot>-ltvfdat.
        <fs_ic>-expirydate_flg = abap_true.
      ENDIF.
    ENDLOOP.

*--- 2. Lotes nuevos: crear lote y subposición --------------------------
    LOOP AT it_lot ASSIGNING <fs_lot>
                   WHERE ebeln EQ <fs_pos>-vgbel
                     AND ebelp EQ <fs_pos>-vgpos
                     AND posnr IS INITIAL.

      CLEAR: lwa_batchattr, lv_charg.
      REFRESH lt_return.
      lv_matnr_batch = <fs_lips_p>-matnr.
      lwa_batchattr-val_type   = <fs_ekpo_l>-bwtar.
      lwa_batchattr-expirydate = <fs_lot>-ltvfdat.

      CALL FUNCTION 'BAPI_BATCH_CREATE'
        EXPORTING
          material        = lv_matnr_batch
          plant           = <fs_ekpo_l>-werks
          batchattributes = lwa_batchattr
        IMPORTING
          batch           = lv_charg
        TABLES
          return          = lt_return.

      READ TABLE lt_return TRANSPORTING NO FIELDS WITH KEY type = 'E'.
      IF sy-subrc EQ 0.
        CALL FUNCTION 'BAPI_TRANSACTION_ROLLBACK'.   "+@004
        e_error = abap_true.
        PERFORM carga_errores TABLES lt_return it_result.
        EXIT.
      ENDIF.

      PERFORM commit_wait.
      "+@004 Registro para marcarlo para borrado si la llamada falla después.
      APPEND VALUE #( material = lv_matnr_batch
                      batch    = lv_charg
                      plant    = <fs_ekpo_l>-werks ) TO gt_lotes_mod_creados.

      "El lote tarda en estar disponible; sin esta espera el
      "BAPI_INB_DELIVERY_CHANGE falla de forma intermitente.
      DO 5 TIMES.
        SELECT SINGLE charg FROM mcha INTO @DATA(lv_charg_ok)
          WHERE matnr EQ @lv_matnr_batch
            AND werks EQ @<fs_ekpo_l>-werks
            AND charg EQ @lv_charg.
        IF sy-subrc EQ 0.
          EXIT.
        ELSE.
          WAIT UP TO 1 SECONDS.
        ENDIF.
      ENDDO.

      <fs_lot>-charg = lv_charg.

      APPEND INITIAL LINE TO ct_item_data    ASSIGNING <fs_id>.
      APPEND INITIAL LINE TO ct_item_control ASSIGNING <fs_ic>.

      <fs_id>-deliv_numb = is_cabecera-vbeln.
      <fs_id>-material   = <fs_lips_p>-matnr.
      <fs_id>-batch      = lv_charg.
      <fs_id>-expirydate = <fs_lot>-ltvfdat.
      <fs_id>-dlv_qty    = <fs_lot>-ltmenge.
*      <fs_id>-sales_unit = <fs_lips_p>-meins.    "-@004
      <fs_id>-sales_unit = lv_unidad.              "+@004
      <fs_id>-dlv_qty_imunit  = 0.
      <fs_id>-fact_unit_denom = <fs_ekpo_l>-umren.
      <fs_id>-fact_unit_nom   = <fs_lips_p>-umvkz.

      <fs_ic>-deliv_numb     = is_cabecera-vbeln.
      <fs_ic>-chg_delqty     = abap_true.
      <fs_ic>-expirydate_flg = abap_true.

      "Un único lote por la cantidad total y sin splits previos:
      "no se parte nada, el lote va en la posición padre.
      "+@004 Se compara con el número de lotes, no con LFIMG: LFIMG es la
      "cantidad anterior y en una modificación la cantidad puede cambiar.
*      IF lv_hay_splits EQ abap_false
*         AND <fs_lot>-ltmenge EQ <fs_lips_p>-lfimg.   "-@004
      IF lv_hay_splits EQ abap_false AND lv_n_lotes EQ 1.
        <fs_id>-deliv_item = <fs_pos>-posnr.
        <fs_ic>-deliv_item = <fs_pos>-posnr.
      ELSE.
        ADD 1 TO lv_posnrlt.
        <fs_id>-deliv_item = lv_posnrlt.
        <fs_ic>-deliv_item = lv_posnrlt.
        <fs_id>-hieraritem = <fs_pos>-posnr.
        <fs_id>-usehieritm = '1'.
      ENDIF.

      <fs_lot>-posnr = <fs_id>-deliv_item.
      "+@004 Reparto lote -> bulto para el embalaje (el lote viene anidado en
      "su bulto; el DPC rellena VHILMLT si el portal no lo envía).
      IF <fs_lot>-vhilmlt IS NOT INITIAL.
        APPEND VALUE #( posnr    = <fs_lot>-posnr
                        vhilm_ku = <fs_lot>-vhilmlt
                        cant     = <fs_lot>-ltmenge ) TO gt_lote_bulto.
      ENDIF.
    ENDLOOP.

*    CHECK e_error EQ abap_false.   "-@004 seguía con las demás posiciones
    IF e_error EQ abap_true.        "+@004 un lote fallido corta todo
      EXIT.
    ENDIF.

*--- 3. Subposiciones que ya no vienen en la trama: eliminar ------------

    CHECK lv_hay_lotes EQ abap_true.
*    LOOP AT gt_lips02 ASSIGNING <fs_split>      "-@004
*                      WHERE vgbel EQ <fs_pos>-vgbel
*                        AND vgpos EQ <fs_pos>-vgpos
*                        AND posnr NE <fs_pos>-posnr.
    LOOP AT gt_lips02 ASSIGNING <fs_split>        "+@004 solo subposiciones de lote
                      WHERE uecha EQ <fs_pos>-posnr.

      READ TABLE it_lot TRANSPORTING NO FIELDS
           WITH KEY ebeln = <fs_pos>-vgbel
                    ebelp = <fs_pos>-vgpos
                    posnr = <fs_split>-posnr.
      CHECK sy-subrc NE 0.

      APPEND INITIAL LINE TO ct_item_data    ASSIGNING <fs_id>.
      APPEND INITIAL LINE TO ct_item_control ASSIGNING <fs_ic>.

      <fs_id>-deliv_numb = is_cabecera-vbeln.
      <fs_id>-deliv_item = <fs_split>-posnr.
      <fs_id>-material   = <fs_split>-matnr.
      <fs_id>-batch      = <fs_split>-charg.
      <fs_id>-dlv_qty    = <fs_split>-lfimg.
*      <fs_id>-sales_unit = <fs_split>-meins.     "-@004
      <fs_id>-sales_unit = COND #( WHEN <fs_split>-vrkme IS NOT INITIAL     "+@004
                                   THEN <fs_split>-vrkme ELSE <fs_split>-meins ).

      <fs_ic>-deliv_numb = is_cabecera-vbeln.
      <fs_ic>-deliv_item = <fs_split>-posnr.
      <fs_ic>-del_item   = abap_true.
    ENDLOOP.

  ENDLOOP.

ENDFORM.


*&---------------------------------------------------------------------*
*& Form get_constantes_entrega
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM get_constantes_entrega .

  SELECT campo sign opt correlativo  low high
    FROM zge_t_constantes "ztconstantes
    INTO TABLE gt_const_portal
    WHERE modulo   EQ 'MM'
      AND programa EQ 'SAPLZGF_CON_PORTAL'.

  IF sy-subrc NE 0.

  ENDIF.
  LOOP AT gt_const_portal ASSIGNING FIELD-SYMBOL(<fs_portal>).
    CASE <fs_portal>-campo.
      WHEN 'E_BSART'.
        gv_e_bsart = <fs_portal>-low.

      WHEN OTHERS.
    ENDCASE.
  ENDLOOP.
*  SELECT campo signo opcion secuencia valor_low valor_high
  SELECT campo sign opt correlativo  low high
    FROM zge_t_constantes "ztconstantes
    INTO TABLE gt_const
    WHERE modulo   EQ 'MM'
      AND programa EQ 'ZBVMM_OC_REGISTRO_ENTR02'.

  IF sy-subrc EQ 0.

    SORT gt_const BY campo.

    LOOP AT gt_const ASSIGNING <fs_const>.
      CASE <fs_const>-campo.
        WHEN: 'DESC_DISPO'.
          IF <fs_const>-correlativo EQ '0001'.
            MOVE <fs_const>-low TO gv_crit.
          ELSEIF <fs_const>-correlativo EQ '0002'.
            MOVE <fs_const>-low TO gv_regu.
          ELSEIF <fs_const>-correlativo EQ '0003'.
            MOVE <fs_const>-low TO gv_irre.
          ELSEIF <fs_const>-correlativo EQ '0004'.
            MOVE <fs_const>-low TO gv_estr.
          ENDIF.
        WHEN: 'DISPO_C'.
          APPEND INITIAL LINE TO gr_crit ASSIGNING <fs_crit>.
          MOVE 'I'                   TO <fs_crit>-sign.
          MOVE 'EQ'                  TO <fs_crit>-option.
          MOVE <fs_const>-low  TO <fs_crit>-low.
        WHEN: 'DISPO_R'.
          APPEND INITIAL LINE TO gr_regu ASSIGNING <fs_regu>.
          MOVE 'I'                   TO <fs_regu>-sign.
          MOVE 'EQ'                  TO <fs_regu>-option.
          MOVE <fs_const>-low  TO <fs_regu>-low.
        WHEN: 'DISPO_I'.
          APPEND INITIAL LINE TO gr_irre ASSIGNING <fs_irre>.
          MOVE 'I'                   TO <fs_irre>-sign.
          MOVE 'EQ'                  TO <fs_irre>-option.
          MOVE <fs_const>-low  TO <fs_irre>-low.
        WHEN: 'DISPO_E'.
          APPEND INITIAL LINE TO gr_estr ASSIGNING <fs_estr>.
          MOVE 'I'                   TO <fs_estr>-sign.
          MOVE 'EQ'                  TO <fs_estr>-option.
          MOVE <fs_const>-low  TO <fs_estr>-low.
        WHEN: 'PESO'.
          MOVE <fs_const>-low TO gv_peso.
        WHEN: 'ZONA'.
          IF <fs_const>-correlativo EQ '0001'.
            MOVE <fs_const>-low TO gv_a.
          ELSEIF <fs_const>-correlativo EQ '0002'.
            MOVE <fs_const>-low TO gv_b.
          ENDIF.
        WHEN: 'ENTREGA'.
          IF <fs_const>-correlativo EQ '0001'.
            MOVE <fs_const>-low TO gv_envio.
          ELSEIF <fs_const>-correlativo EQ '0002'.
            MOVE <fs_const>-low TO gv_recojo.
          ENDIF.
* {+@001
        WHEN: 'LGORT_TRANSITO'.
          APPEND INITIAL LINE TO gr_lgort_tr ASSIGNING FIELD-SYMBOL(<fs_lgort_tr>).
          MOVE 'I'                   TO <fs_lgort_tr>-sign.
          MOVE 'EQ'                  TO <fs_lgort_tr>-option.
          MOVE <fs_const>-low  TO <fs_lgort_tr>-low.

* }+@001
      ENDCASE.
    ENDLOOP.
  ENDIF.


  "Busqueda Descripcion de condicion de entrega movido de la linea 694 @clh
*  SELECT cod_cond desc_cond  "{-@001
*   FROM zbvmm_cond_entr
*   INTO CORRESPONDING FIELDS OF TABLE gt_condicion
*    WHERE cod_cond NE ''. "}-@001
*{+@001
  SELECT inco1 bezei
   FROM tinct
   INTO TABLE gt_condicion
    WHERE inco1 NE ''
      AND spras = 'S'.
*}+@001
  "busqueda descripcion y codigos de status
  SELECT cod descrip
   FROM zbvmm_estatus
   INTO CORRESPONDING FIELDS OF TABLE gt_status
    WHERE cod NE ''.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form prepare_data
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*&      <-- G_ERROR
*&---------------------------------------------------------------------*
FORM prepare_data  CHANGING ch_error TYPE abap_bool.
  DATA: lv_pos       TYPE string,
        lv_xhupf     TYPE t001l-xhupf,
        lv_lgobe     TYPE t001l-lgobe,
        lv_lgort     TYPE t001l-lgort,
        lv_laeng     TYPE char10,
        lv_breit     TYPE char10,
        lv_hoehe     TYPE char10,
        lv_tabix     TYPE sy-tabix,
        l_tabix      TYPE sy-tabix,
        lv_n1        TYPE string,
        lv_n2        TYPE string,
        lv_imenge    TYPE ekpo-menge,
        lv_emenge    TYPE ekpo-menge,
        l_save       TYPE abap_bool,
        t_line       TYPE tlinet,
        lv_cont_vepo TYPE i,
        lv_marc      TYPE abap_bool,
        ls_final     TYPE gty_final.


  CLEAR: lv_pos, gv_zadr, gv_meins.

  LOOP AT gt_likps ASSIGNING <fs_likps>.
    CLEAR: gv_meins, lv_xhupf, lv_lgobe, lv_lgort.

    READ TABLE gt_t001l ASSIGNING FIELD-SYMBOL(<fs_t001l>) WITH KEY werks = <fs_likps>-werks
                                                                      lgort = <fs_likps>-lgort
                                                                      BINARY SEARCH.
    IF sy-subrc EQ 0.
      lv_xhupf = <fs_t001l>-xhupf.
      lv_lgort = <fs_t001l>-lgort.
*+@clh{
      CLEAR:lv_n1, lv_n2.
      SPLIT <fs_t001l>-lgobe AT space INTO lv_n1 lv_n2.
      IF lv_n2 IS NOT INITIAL.
        lv_lgobe = lv_n2.
      ELSE.
        lv_lgobe = lv_n1.
      ENDIF.
      CONDENSE lv_lgobe.
*}+@clh
    ENDIF.

    ADD 1 TO lv_pos.

    "{NO HU********************
*    IF lv_xhupf = abap_false.  "-@001
    IF lv_lgort NOT IN gr_lgort_tr. " '0230'.  "+@001
      PERFORM carga_nohu USING lv_lgobe
                               lv_lgort.

    ELSE.
*{+@001
      READ TABLE gt_ekko_p ASSIGNING FIELD-SYMBOL(<fs_ekko_rep>)
                                         WITH KEY ebeln = <fs_likps>-vgbel
                                                  bsart = gv_e_bsart. "Ped reparacion
      IF sy-subrc NE 0.
*}+@001
        APPEND INITIAL LINE TO gt_final ASSIGNING <fs_final>.
        MOVE <fs_likps>-vbeln TO <fs_final>-zvbeln.
        MOVE <fs_likps>-vgpos TO <fs_final>-zvgpos.
        MOVE lv_pos          TO <fs_final>-zseqnr.
        MOVE lv_xhupf        TO <fs_final>-xhupf.
        MOVE <fs_likps>-werks TO <fs_final>-zwerks.
        MOVE <fs_likps>-vgbel TO <fs_final>-zebeln.
        MOVE <fs_likps>-gewei TO <fs_final>-zgewei.
        <fs_final>-zlgobe = lv_lgobe.
        <fs_final>-zlgort = lv_lgort.

        SORT gt_reg_ent BY zvbeln.

        READ TABLE gt_reg_ent ASSIGNING <fs_rege>
        WITH KEY zvbeln = <fs_likps>-vbeln
        BINARY SEARCH.

        IF sy-subrc EQ 0.
          MOVE <fs_rege>-zcita  TO <fs_final>-zcita.
          MOVE <fs_rege>-zplaca TO <fs_final>-zplaca.
          MOVE <fs_rege>-zplaca2 TO <fs_final>-zplaca2.
          MOVE <fs_rege>-zplaca3 TO <fs_final>-zplaca3.
          MOVE <fs_rege>-zplaca4 TO <fs_final>-zplaca4.
          MOVE <fs_rege>-zndni  TO <fs_final>-zdni.
          MOVE <fs_rege>-zndni2 TO <fs_final>-zdni2.
          MOVE <fs_rege>-zndni3 TO <fs_final>-zdni3.
          MOVE <fs_rege>-zndni4 TO <fs_final>-zdni4.
          MOVE <fs_rege>-zcita_np TO <fs_final>-zcita_np.
          MOVE <fs_rege>-zzlfstk TO <fs_final>-zzlfstk.

          READ TABLE gt_status ASSIGNING FIELD-SYMBOL(<fs_stts>) WITH KEY cod = <fs_final>-zzlfstk.
          IF sy-subrc = 0.
            <fs_final>-zzlfstkdesc = <fs_stts>-descrip.
          ENDIF.

          MOVE <fs_rege>-zcorreo_re_pl TO <fs_final>-zcorreo_re_pl.
          MOVE <fs_rege>-ztelefono TO <fs_final>-ztelefono.
        ENDIF.

        "Convertir unidad según unidad de medida.
        PERFORM conversion_cunit USING <fs_likps>-vrkme
                                 CHANGING gv_meins.

        MOVE gv_meins        TO <fs_final>-zunmed.

        "Datos cabecera.
        MOVE <fs_likps>-lfdat TO <fs_final>-zlfdat.
        MOVE <fs_likps>-lfuhr TO <fs_final>-zlfuhr.
        MOVE <fs_likps>-brgew TO <fs_final>-zbrgew_m.
        MOVE <fs_likps>-btgew TO <fs_final>-zbtgew.
        MOVE <fs_likps>-bolnr TO <fs_final>-zbolnr.

        IF <fs_likps>-btgew LE gv_peso.
          MOVE gv_a TO <fs_final>-zzona.
        ELSE.
          MOVE gv_b TO <fs_final>-zzona.
        ENDIF.

        PERFORM quitar_ceros CHANGING <fs_likps>-anzpk.

        MOVE <fs_likps>-anzpk TO <fs_final>-zanzpk.
        MOVE <fs_likps>-lifnr TO <fs_final>-zlifnr.
        MOVE <fs_likps>-lfimg TO <fs_final>-zvemng.

        CLEAR lv_cont_vepo.
        REFRESH: gt_final_vepo[].

        LOOP AT gt_vepo ASSIGNING <fs_vepo> WHERE posnr = <fs_likps>-posnr
                                              AND matnr = <fs_likps>-matnr
                                              AND vbeln = <fs_likps>-vbeln
                                              .
          CLEAR:lv_imenge,lv_emenge."+@JY
          ADD 1 TO lv_cont_vepo.

          IF lv_cont_vepo EQ 1.

            MOVE <fs_vepo>-matnr TO <fs_final>-zmatnr.
            lv_imenge = <fs_vepo>-vemng."+@JY

            PERFORM get_material_unit  USING  <fs_vepo>
                                       CHANGING lv_emenge.



**               PERFORM convert_material_unit USING  <fs_vepo>
**                                                    lv_imenge
**                                           CHANGING lv_emenge
**                                                    ch_error.

            IF ch_error EQ abap_true.
              EXIT.
            ENDIF.

            <fs_final>-zvemng = lv_emenge. "+@JY

            lv_marc = abap_false.
            PERFORM lee_mat_hu_bezei USING <fs_vepo>
                                           <fs_final>
                                           lv_marc.

            APPEND INITIAL LINE TO gt_final_vepo ASSIGNING FIELD-SYMBOL(<fs_final_vepo>).
            MOVE-CORRESPONDING <fs_final> TO <fs_final_vepo>."+@JY

          ELSEIF lv_cont_vepo GT  1.
            ADD 1 TO lv_pos.

            APPEND INITIAL LINE TO gt_final_vepo ASSIGNING <fs_final_vepo>.
            MOVE-CORRESPONDING <fs_final> TO <fs_final_vepo>.
            MOVE lv_pos TO <fs_final_vepo>-zseqnr. "+@JY
            MOVE <fs_vepo>-matnr TO <fs_final_vepo>-zmatnr.
            lv_imenge = <fs_vepo>-vemng."+@JY

            PERFORM get_material_unit  USING  <fs_vepo>
                                       CHANGING lv_emenge.

*              PERFORM convert_material_unit USING  <fs_vepo>
*                                                    lv_imenge
*                                           CHANGING lv_emenge
*                                                    ch_error.
            IF ch_error EQ abap_true.
              EXIT.
            ENDIF.

            <fs_final_vepo>-zvemng = <fs_final>-zvemng = lv_emenge. "+@JY

            lv_marc = abap_true.
            PERFORM lee_mat_hu_bezei USING <fs_vepo>
                                           <fs_final_vepo>
                                           lv_marc.
          ENDIF.

          PERFORM complete_final USING <fs_final>.

        ENDLOOP.
*{+@001
      ELSE.

        PERFORM carga_nohu USING lv_lgobe
                                 lv_lgort.
      ENDIF.
*}+@001



      "Se agregan los materiales por psición(lips) que han sido divididos en varios bultos.
      IF gt_final_vepo[] IS NOT INITIAL.
        PERFORM agregar_mat.
      ENDIF.

    ENDIF. "Cierre condición HU.




  ENDLOOP.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form carga_nohu
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*&      --> LV_LGOBE
*&      --> LV_LGORT
*&---------------------------------------------------------------------*
FORM carga_nohu  USING i_lgobe TYPE lgobe
                      i_lgort TYPE lgort_d.

  DATA: lv_tabix TYPE sy-tabix,
        lv_seqnr TYPE ld_takts.


  LOOP AT gt_entrenohu ASSIGNING FIELD-SYMBOL(<fs_entreganohu>)
                                        WHERE vbeln EQ <fs_likps>-vbeln
                                          AND ebelp EQ <fs_likps>-vgpos
                                        .

    ADD 1 TO lv_seqnr.


    APPEND INITIAL LINE TO gt_final ASSIGNING <fs_final>.
    MOVE <fs_entreganohu>-vbeln TO <fs_final>-zvbeln.
    MOVE <fs_entreganohu>-ebeln TO <fs_final>-zebeln.
    MOVE <fs_entreganohu>-ebelp TO <fs_final>-zvgpos.
    MOVE <fs_entreganohu>-menge TO <fs_final>-zvemng.
*   MOVE <fs_entreganohu>-meins  TO <fs_final>-zunmed.
    "Convertir unidad según unidad de medida.
    PERFORM conversion_cunit USING <fs_entreganohu>-meins
                             CHANGING gv_meins.

    MOVE gv_meins        TO <fs_final>-zunmed.

***   MOVE <fs_entreganohu>-lfdat TO <fs_final>-zlfdat.
***   MOVE <fs_entreganohu>-lfuhr TO <fs_final>-zlfuhr.
    MOVE  <fs_entreganohu>-brgew TO <fs_final>-zbrgew_b.
    MOVE <fs_entreganohu>-laeng TO <fs_final>-zlaeng.
    MOVE <fs_entreganohu>-breit TO <fs_final>-zbreit.
    MOVE <fs_entreganohu>-hoehe TO <fs_final>-zhoehe.
    MOVE <fs_entreganohu>-vegr1   TO <fs_final>-zvegr1.
    MOVE <fs_entreganohu>-vegr2    TO <fs_final>-zvegr2.
    MOVE <fs_entreganohu>-inhalt   TO <fs_final>-zobservacion.
    MOVE <fs_entreganohu>-matnr  TO <fs_final>-zmatnr.
    MOVE <fs_entreganohu>-vhilm_ku  TO <fs_final>-zvhilm_ku.
    MOVE <fs_entreganohu>-exidv  TO <fs_final>-exidv.
    READ TABLE gt_makt ASSIGNING <fs_makt>
                       WITH KEY matnr = <fs_likps>-matnr
                       BINARY SEARCH.
    IF sy-subrc EQ 0.
      MOVE <fs_makt>-maktx TO <fs_final>-zmaktx.
    ENDIF.


    MOVE lv_seqnr          TO <fs_final>-zseqnr.
    MOVE <fs_likps>-werks TO <fs_final>-zwerks.

    MOVE <fs_likps>-gewei TO <fs_final>-zgewei.
    <fs_final>-zlgobe = i_lgobe.
    <fs_final>-zlgort = i_lgort.

    MOVE <fs_likps>-btgew TO <fs_final>-zbtgew.
    MOVE <fs_likps>-bolnr TO <fs_final>-zbolnr.
    MOVE <fs_likps>-lfdat TO <fs_final>-zlfdat.
    MOVE <fs_likps>-lfuhr TO <fs_final>-zlfuhr.


    IF <fs_likps>-btgew LE gv_peso.
      MOVE gv_a TO <fs_final>-zzona.
    ELSE.
      MOVE gv_b TO <fs_final>-zzona.
    ENDIF.

    PERFORM quitar_ceros CHANGING <fs_likps>-anzpk.
    MOVE <fs_likps>-anzpk TO <fs_final>-zanzpk.
    MOVE <fs_likps>-lifnr TO <fs_final>-zlifnr.
    MOVE <fs_likps>-zul_aufl  TO <fs_final>-zul_aufl.

    READ TABLE gt_reg_ent ASSIGNING <fs_rege>
                          WITH KEY zvbeln = <fs_likps>-vbeln
                          BINARY SEARCH.

    IF sy-subrc EQ 0.
      MOVE <fs_rege>-zcita  TO <fs_final>-zcita.
      MOVE <fs_rege>-zplaca TO <fs_final>-zplaca.
      MOVE <fs_rege>-zplaca2 TO <fs_final>-zplaca2.
      MOVE <fs_rege>-zplaca3 TO <fs_final>-zplaca3.
      MOVE <fs_rege>-zplaca4 TO <fs_final>-zplaca4.
      MOVE <fs_rege>-zndni  TO <fs_final>-zdni.
      MOVE <fs_rege>-zndni2 TO <fs_final>-zdni2.
      MOVE <fs_rege>-zndni3 TO <fs_final>-zdni3.
      MOVE <fs_rege>-zndni4 TO <fs_final>-zdni4.
      MOVE <fs_rege>-zcita_np TO <fs_final>-zcita_np.
      MOVE <fs_rege>-zcorreo_re_pl TO <fs_final>-zcorreo_re_pl.
      MOVE <fs_rege>-ztelefono TO <fs_final>-ztelefono.
    ENDIF.
*

    READ TABLE gt_tve2t_2 ASSIGNING FIELD-SYMBOL(<fs_tve2t_2>)
                                          WITH KEY vegr2 = <fs_likps>-vegr2
                                          BINARY SEARCH.
    IF sy-subrc EQ 0.
      MOVE <fs_tve2t_2>-bezei TO <fs_final>-zbezei.
    ENDIF.

    PERFORM complete_final USING <fs_final>.

  ENDLOOP.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form complete_final
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*&      --> <FS_FINAL>
*&---------------------------------------------------------------------*
FORM complete_final  USING is_final TYPE gty_final.

  DATA: lv_zz_lugar TYPE ze_lug_ent.        "INSERT - @PMPD001 - 04.03.2022

*name1
  READ TABLE gt_t001wadr ASSIGNING FIELD-SYMBOL(<fs_t001wadr>)
         WITH KEY werks = <fs_likps>-werks
         BINARY SEARCH.

  IF sy-subrc EQ 0.
    MOVE <fs_t001wadr>-name1 TO <fs_final>-zgort.
  ENDIF.

  READ TABLE gt_ekpo ASSIGNING <fs_ekpo>
                     WITH KEY ebeln = <fs_likps>-vgbel
                              ebelp = <fs_likps>-vgpos
                              BINARY SEARCH.
  IF sy-subrc EQ 0.
*{-@001
*    MOVE <fs_ekpo>-zzlug_ent TO lv_zz_lugar.            "INSERT - @PMPD001 - 04.03.2022
*    MOVE <fs_ekpo>-zzlug_ent TO <fs_final>-zzlug_ent.
*}-@001
*{+@001
    MOVE <fs_ekpo>-inco1 TO lv_zz_lugar.
    MOVE <fs_ekpo>-inco1 TO <fs_final>-zzlug_ent.
*}+@001
    MOVE <fs_ekpo>-bukrs TO <fs_final>-zbukrs.

    MOVE <fs_ekpo>-afnam TO <fs_final>-afnam. "INSERT @PM

    "descripcion de consdicion de entrega
*    READ TABLE gt_condicion ASSIGNING FIELD-SYMBOL(<fs_condic>)  "{-@001
*                                      WITH KEY cod_cond = <fs_ekpo>-zzlug_ent.
*    IF sy-subrc = 0.
*      <fs_final>-zdesc_cond = <fs_condic>-desc_cond.
*    ENDIF.  "}-@001
*{+@001
    READ TABLE gt_condicion ASSIGNING FIELD-SYMBOL(<fs_condic>)
                                      WITH KEY inco1 = <fs_ekpo>-inco1.
    IF sy-subrc = 0.
      <fs_final>-zdesc_cond = <fs_condic>-bezei.
    ENDIF.
*}+@001
*     usuario de la entrega
    READ TABLE gt_ekko ASSIGNING FIELD-SYMBOL(<fs_ekko_p>)
                                 WITH KEY ebeln = <fs_ekpo>-ebeln.
    IF sy-subrc = 0.
      <fs_final>-ernam = <fs_ekko_p>-ernam.
    ENDIF.


*         status de la entrega

    IF  <fs_final>-zzlfstk EQ ''.

*      CASE <fs_ekpo>-zzlug_ent. "-@001
      CASE <fs_ekpo>-inco1.  "+@001
        WHEN '01'.
          IF <fs_final>-zcita_np = 'PROGRAMADA'.
            READ TABLE gt_status ASSIGNING FIELD-SYMBOL(<fs_status>) WITH KEY cod = '05'.
            IF sy-subrc = 0.
              <fs_final>-zzlfstk = <fs_status>-cod.
              <fs_final>-zzlfstkdesc = <fs_status>-descrip.
            ENDIF.
          ELSEIF <fs_final>-zcita_np = 'NO PROGRAMADA'.
            READ TABLE gt_status ASSIGNING <fs_status> WITH KEY cod = '02'.
            IF sy-subrc = 0.
              <fs_final>-zzlfstk = <fs_status>-cod.
              <fs_final>-zzlfstkdesc = <fs_status>-descrip.
            ENDIF.
          ENDIF.
        WHEN '02'.
          READ TABLE gt_status ASSIGNING <fs_status> WITH KEY cod = '03'.
          IF sy-subrc = 0.
            <fs_final>-zzlfstk = <fs_status>-cod.
            <fs_final>-zzlfstkdesc = <fs_status>-descrip.
          ENDIF.
        WHEN '03'.
          READ TABLE gt_status ASSIGNING <fs_status> WITH KEY cod = '05'.
          IF sy-subrc = 0.
            <fs_final>-zzlfstk = <fs_status>-cod.
            <fs_final>-zzlfstkdesc = <fs_status>-descrip.
          ENDIF.
      ENDCASE.
    ELSE.
      READ TABLE gt_status ASSIGNING <fs_status> WITH KEY cod = <fs_final>-zzlfstk.
      IF sy-subrc EQ 0.
        <fs_final>-zzlfstkdesc = <fs_status>-descrip.
      ENDIF.

    ENDIF.

*    READ TABLE gt_condicion ASSIGNING <fs_condic> WITH KEY cod_cond = <fs_ekpo>-zzlug_ent.  "{-@001
*    IF sy-subrc EQ 0.
*      IF <fs_t001wadr> IS ASSIGNED.
*
*        IF <fs_condic>-cod_cond = '01' OR <fs_condic>-cod_cond = '02' .
*
*          CONCATENATE <fs_t001wadr>-street <fs_t001wadr>-str_suppl1 <fs_t001wadr>-city2
*          <fs_t001wadr>-city1 INTO <fs_final>-zdireccion SEPARATED BY space.
*
*        ELSE.
*
*          IF <fs_rege> IS ASSIGNED.
*            <fs_final>-zdireccion = <fs_rege>-zdireccion.
*          ENDIF.
*
*        ENDIF.
*
*      ENDIF.
*    ENDIF.  "}-@001
*{+@001
    READ TABLE gt_condicion ASSIGNING <fs_condic> WITH KEY inco1 = <fs_ekpo>-inco1.
    IF sy-subrc EQ 0.
      IF <fs_t001wadr> IS ASSIGNED.

*        IF <fs_condic>-inco1 = '01' OR <fs_condic>-inco1 = '02' . "-@001
        IF <fs_condic>-inco1 = '01'.
          SELECT SINGLE adrnr FROM twlad
            INTO @DATA(lv_adrnr)
            WHERE werks EQ @<fs_likps>-werks
              AND lgort EQ @<fs_likps>-lgort.
          IF lv_adrnr IS NOT INITIAL.
            SELECT SINGLE city1, city2, street, str_suppl1
              FROM adrc
              INTO @DATA(lwa_adrc)
              WHERE addrnumber EQ @lv_adrnr.
             IF sy-subrc EQ 0.
               <fs_final>-zdireccion = |{ lwa_adrc-street } { lwa_adrc-str_suppl1 } { lwa_adrc-city2 } { lwa_adrc-city1 }|.
             ENDIF.
          ENDIF.
        ELSEIF <fs_condic>-inco1 = '02'.

          CONCATENATE <fs_t001wadr>-street <fs_t001wadr>-str_suppl1 <fs_t001wadr>-city2
          <fs_t001wadr>-city1 INTO <fs_final>-zdireccion SEPARATED BY space.

        ELSE.

          IF <fs_rege> IS ASSIGNED.
            <fs_final>-zdireccion = <fs_rege>-zdireccion.
          ENDIF.

        ENDIF.

      ENDIF.
    ENDIF.
*}+@001
  ENDIF.


  READ TABLE gt_lfa1 ASSIGNING <fs_lfa1>
       WITH KEY lifnr = <fs_likps>-lifnr
       BINARY SEARCH.

  IF sy-subrc EQ 0.
    MOVE <fs_lfa1>-name1 TO <fs_final>-zname1.
    MOVE <fs_lfa1>-stcd1 TO <fs_final>-stcd1. "@DL MEJORAS
  ENDIF.
*dispo (zecri)

*BEGIN OF INSERT - @PMPD001 - 04.03.2022 12:03:09
  SELECT SINGLE *
    INTO @DATA(ls_centro)
    FROM zbvmm_centro_alm
    WHERE cod_cond EQ @lv_zz_lugar
    AND   werks    EQ @<fs_likps>-werks
    AND   lgort    EQ @<fs_likps>-lgort.
  IF sy-subrc EQ 0 .
    READ TABLE gt_marc ASSIGNING <fs_marc> WITH KEY matnr = <fs_likps>-matnr
                                                    werks = ls_centro-werks_f BINARY SEARCH.
  ELSE.
    READ TABLE gt_marc ASSIGNING <fs_marc> WITH KEY matnr = <fs_likps>-matnr
                                                    werks = <fs_likps>-werks BINARY SEARCH.
  ENDIF.
*END OF INSERT - @PMPD001 - 04.03.2022 12:03:09

*BEGIN OF COMMENT - @PMPD001 - 04.03.2022
*  READ TABLE gt_marc ASSIGNING <fs_marc>
*  WITH KEY matnr = <fs_likps>-matnr
*           werks = <fs_likps>-werks
*  BINARY SEARCH.
*END OF COMMENT - @PMPD001 - 04.03.2022

  IF sy-subrc EQ 0.

*BEGIN OF INSERT - @PMPD002 - 22.03.2022 17:02:34
    DATA: lv_comparacion TYPE c LENGTH 50,
          lv_indicador   TYPE c LENGTH 1,
          lv_cond        TYPE c LENGTH 1.
    CLEAR: lv_cond.

    LOOP AT gtr_vali INTO DATA(ls_validacion).
      CASE ls_validacion-posici.
        WHEN 1.
          IF <fs_marc>-dispo(1) EQ ls_validacion-compar.
            CASE ls_validacion-criter(1).
              WHEN gc_estr.
                <fs_final>-zecri = gc_testr.
              WHEN gc_crit.
                <fs_final>-zecri = gc_tcrit.
              WHEN gc_regu.
                <fs_final>-zecri = gc_tregu.
              WHEN gc_irre.
                <fs_final>-zecri = gc_tirre.
            ENDCASE.
            lv_cond = abap_true.
            EXIT.
          ENDIF.

        WHEN 2.
          IF <fs_marc>-dispo+1(1) EQ ls_validacion-compar.
            CASE ls_validacion-criter(1).
              WHEN gc_estr.
                <fs_final>-zecri = gc_testr.
              WHEN gc_crit.
                <fs_final>-zecri = gc_tcrit.
              WHEN gc_regu.
                <fs_final>-zecri = gc_tregu.
              WHEN gc_irre.
                <fs_final>-zecri = gc_tirre.
            ENDCASE.
            lv_cond = abap_true.
            EXIT.
          ENDIF.

        WHEN OTHERS.
          IF <fs_marc>-dispo+2(1) EQ ls_validacion-compar.
            CASE ls_validacion-criter(1).
              WHEN gc_estr.
                <fs_final>-zecri = gc_testr.
              WHEN gc_crit.
                <fs_final>-zecri = gc_tcrit.
              WHEN gc_regu.
                <fs_final>-zecri = gc_tregu.
              WHEN gc_irre.
                <fs_final>-zecri = gc_tirre.
            ENDCASE.
            lv_cond = abap_true.
            EXIT.
          ENDIF.
      ENDCASE.
    ENDLOOP.

    IF lv_cond NE abap_true.
      <fs_final>-zecri = gc_tirre.
    ENDIF.
*END OF INSERT - @PMPD002 - 22.03.2022 17:02:34

*BEGIN OF COMMENT - @PMPD002 - 22.03.2022 17:02:16
*    IF <fs_marc>-dispo IN gr_crit.
*      MOVE gv_crit TO <fs_final>-zecri.
*
*    ELSEIF <fs_marc>-dispo IN gr_regu.
*      MOVE gv_regu TO <fs_final>-zecri
*      .
*    ELSEIF <fs_marc>-dispo IN gr_irre.
*      MOVE gv_irre TO <fs_final>-zecri.
*
*    ELSEIF <fs_marc>-dispo IN gr_estr.
*      MOVE gv_estr TO <fs_final>-zecri.
*    ENDIF.
*END OF COMMENT - @PMPD002 - 22.03.2022 17:02:16

  ENDIF.

  READ TABLE gt_ekko ASSIGNING FIELD-SYMBOL(<fs_ekko>)
   WITH KEY ebeln = <fs_likps>-vgbel
   BINARY SEARCH.
  IF sy-subrc EQ 0.

*smtp_addr
    READ TABLE gt_adr6 ASSIGNING <fs_adr6>
    WITH KEY bname = <fs_ekko>-ernam
    BINARY SEARCH.
    IF sy-subrc EQ 0.
      MOVE <fs_adr6>-smtp_addr TO <fs_final>-zsmtp_addr.
    ENDIF.
*name_text (comprador)
    READ TABLE gt_adrp ASSIGNING FIELD-SYMBOL(<fs_adrp>) WITH KEY bname = <fs_ekko>-ernam.
    IF sy-subrc EQ 0.
      MOVE <fs_adrp>-name_text TO <fs_final>-zname_text.
    ENDIF.
*
  ENDIF.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form lee_mat_hu_bezei
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*&      --> <FS_VEPO>
*&      --> <FS_FINAL>
*&      --> LV_MARC
*&---------------------------------------------------------------------*
FORM lee_mat_hu_bezei  USING is_vepo TYPE  gty_vepo
                             is_final TYPE gty_final
                             i_marc_final_vepo TYPE abap_bool.

  READ TABLE gt_makt ASSIGNING FIELD-SYMBOL(<f_makt>)
                      WITH KEY matnr = is_vepo-matnr
                      BINARY SEARCH.
  IF sy-subrc EQ 0.
    MOVE <f_makt>-maktx TO is_final-zmaktx.
  ENDIF.

*vhilm_ku, brgew, vegr2, laeng, breit, hoehe, inhalt
  READ TABLE gt_vekp ASSIGNING FIELD-SYMBOL(<f_vekp>)
                      WITH KEY venum    = is_vepo-venum
                      BINARY SEARCH.
  IF sy-subrc EQ 0.
*bezei
    READ TABLE gt_tve2t ASSIGNING FIELD-SYMBOL(<fs_tve2t>)
                         WITH KEY vegr2 = <f_vekp>-vegr2
                         BINARY SEARCH.
    IF sy-subrc EQ 0.
      MOVE <fs_tve2t>-bezei TO is_final-zbezei.
    ENDIF.

    MOVE <f_vekp>-vhilm_ku TO is_final-zvhilm_ku.
    MOVE <f_vekp>-brgew    TO is_final-zbrgew_b.
    MOVE <f_vekp>-vegr2    TO is_final-zvegr2.
    MOVE <f_vekp>-laeng    TO is_final-zlaeng.
    MOVE <f_vekp>-breit    TO is_final-zbreit.
    MOVE <f_vekp>-hoehe    TO is_final-zhoehe.
    MOVE <f_vekp>-inhalt   TO is_final-zobservacion.
    " - @DL  DEVK991747 {
***{INSERT @PM
**    CALL FUNCTION 'CONVERSION_EXIT_ALPHA_OUTPUT'
**      EXPORTING
**        input  = <f_vekp>-exidv
**      IMPORTING
**        output = <f_vekp>-exidv.
**
    MOVE <f_vekp>-exidv    TO is_final-exidv.
**
***}INSERT @PM
    " - @DL  DEVK991747 }
    IF i_marc_final_vepo EQ abap_true.
      MOVE <f_vekp>-zul_aufl   TO is_final-zul_aufl.
    ENDIF.


  ENDIF.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form get_material_unit
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*&      --> <FS_VEPO>
*&      <-- LV_EMENGE
*&---------------------------------------------------------------------*
FORM get_material_unit USING i_vepo TYPE gty_vepo
                        CHANGING ch_menge.

  READ TABLE gt_likps ASSIGNING FIELD-SYMBOL(<fl_likps>) WITH KEY vbeln = i_vepo-vbeln
                                                                  posnr = i_vepo-posnr.

  IF sy-subrc EQ 0.

    READ TABLE gt_ekpo ASSIGNING FIELD-SYMBOL(<fl_ekpo>) WITH KEY  ebeln = <fl_likps>-vgbel
                                                                   ebelp = <fl_likps>-vgpos.
    IF sy-subrc EQ 0.
      ch_menge = ( i_vepo-vemng / <fl_ekpo>-umrez ) * <fl_ekpo>-umren.

    ENDIF.

  ENDIF.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form agregar_mat
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM agregar_mat .
  DATA: lv_tabix TYPE sy-tabix.

  LOOP AT gt_final_vepo ASSIGNING FIELD-SYMBOL(<fs_final_vepo>).
    READ TABLE gt_final ASSIGNING <fs_final> WITH KEY zvbeln = <fs_final_vepo>-zvbeln
                                                      zvgpos = <fs_final_vepo>-zvgpos
                                                      zebeln = <fs_final_vepo>-zebeln
                                                      zmatnr = <fs_final_vepo>-zmatnr.
    IF sy-subrc EQ 0.

      <fs_final_vepo>-afnam = <fs_final>-afnam. "INSERT @PM
      lv_tabix = sy-tabix.
*          ADD 1 TO <fs_final_vepo>-zseqnr."-@JY
      <fs_final_vepo>-zgort = <fs_final>-zgort.
      <fs_final_vepo>-zzlug_ent = <fs_final>-zzlug_ent.
      "MP{
*      READ TABLE gt_condicion ASSIGNING FIELD-SYMBOL(<fs_condic>) "{-@001
*                                        WITH KEY cod_cond = <fs_final_vepo>-zzlug_ent.
*      IF sy-subrc = 0.
*        <fs_final_vepo>-zdesc_cond = <fs_condic>-desc_cond.
*      ENDIF. "}-@001
*{+@001
      READ TABLE gt_condicion ASSIGNING FIELD-SYMBOL(<fs_condic>)
                                        WITH KEY inco1 = <fs_final_vepo>-zzlug_ent.
      IF sy-subrc = 0.
        <fs_final_vepo>-zdesc_cond = <fs_condic>-bezei.
      ENDIF.
*}@001
      READ TABLE gt_ekko ASSIGNING <fs_ekko> WITH KEY ebeln = <fs_final_vepo>-zebeln.
      IF sy-subrc = 0.
        <fs_final_vepo>-ernam = <fs_ekko>-ernam.
      ENDIF.
      "MP}
      "clh{
*          status de la entrega
      IF <fs_final>-zzlfstk EQ ''.

        CASE <fs_final_vepo>-zzlug_ent.
          WHEN '01'.
            IF <fs_final_vepo>-zcita_np = 'PROGRAMADA'.
              READ TABLE gt_status ASSIGNING FIELD-SYMBOL(<fs_status>) WITH KEY cod = '05'.
              IF sy-subrc = 0.
                <fs_final_vepo>-zzlfstk = <fs_status>-cod.
                <fs_final_vepo>-zzlfstkdesc = <fs_status>-descrip.
              ENDIF.
            ELSEIF <fs_final_vepo>-zcita_np = 'NO PROGRAMADA'.
              READ TABLE gt_status ASSIGNING <fs_status> WITH KEY cod = '02'.
              IF sy-subrc = 0.
                <fs_final_vepo>-zzlfstk = <fs_status>-cod.
                <fs_final_vepo>-zzlfstkdesc = <fs_status>-descrip.
              ENDIF.
            ENDIF.
          WHEN '02'.
            READ TABLE gt_status ASSIGNING <fs_status> WITH KEY cod = '03'.
            IF sy-subrc = 0.
              <fs_final_vepo>-zzlfstk = <fs_status>-cod.
              <fs_final_vepo>-zzlfstkdesc = <fs_status>-descrip.
            ENDIF.
          WHEN '03'.
            READ TABLE gt_status ASSIGNING <fs_status> WITH KEY cod = '05'.
            IF sy-subrc = 0.
              <fs_final_vepo>-zzlfstk = <fs_status>-cod.
              <fs_final_vepo>-zzlfstkdesc = <fs_status>-descrip.
            ENDIF.
        ENDCASE.
      ENDIF.
      "}clh
      <fs_final_vepo>-zbukrs = <fs_final>-zbukrs.
      <fs_final_vepo>-zdireccion = <fs_final>-zdireccion.
      <fs_final_vepo>-zname1 = <fs_final>-zname1.
      <fs_final_vepo>-stcd1 = <fs_final>-stcd1.
      <fs_final_vepo>-zecri = <fs_final>-zecri.
      <fs_final_vepo>-zsmtp_addr = <fs_final>-zsmtp_addr.
      <fs_final_vepo>-zname_text = <fs_final>-zname_text.

      "Ya tiene status asignado.
      IF <fs_final>-zzlfstk NE''.
        <fs_final_vepo>-zzlfstk = <fs_final>-zzlfstk.
        <fs_final_vepo>-zzlfstkdesc = <fs_final>-zzlfstkdesc.

      ENDIF.

    ENDIF.
    APPEND <fs_final_vepo> TO gt_final.
  ENDLOOP.

  DELETE gt_final INDEX lv_tabix.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form ejec_bapi
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*&      <-- G_ERROR
*&---------------------------------------------------------------------*
FORM ejec_bapi  CHANGING ch_error TYPE abap_bool.

  DATA: it_return TYPE STANDARD TABLE OF bapiret2.

  LOOP AT gt_final ASSIGNING <fs_final>.
    APPEND INITIAL LINE TO gt_pedpos ASSIGNING FIELD-SYMBOL(<fs_pedpos>).
    <fs_pedpos>-ebeln = <fs_final>-zebeln.
    <fs_pedpos>-ebelp = <fs_final>-zvgpos.

  ENDLOOP.

  PERFORM verif_clave_confirmacion CHANGING ch_error.

  IF ch_error EQ abap_false.

    DO 2  TIMES.
      ch_error = abap_false.

      LOOP AT gt_final ASSIGNING <fs_final> .
        CLEAR: gs_entrega_change.
        MOVE-CORRESPONDING <fs_final> TO gs_entrega_change.
*      MP{
        gs_entrega_change-vbeln = <fs_final>-zvbeln.
        gs_entrega_change-bolnr = <fs_final>-zbolnr.
        gs_entrega_change-lfdat = <fs_final>-zlfdat.
        gs_entrega_change-lfuhr = <fs_final>-zlfuhr.
*      MP}
        gs_entrega_change-statusx = abap_true.

        PERFORM f_bapi_delivery_change1
          TABLES
            it_return
          USING
            gs_entrega_change
            g_ok.

        "Verifica si hubo errores.
        LOOP AT it_return ASSIGNING FIELD-SYMBOL(<fs_return>) WHERE type EQ 'E'.
          CLEAR: g_msg.
          g_error = abap_true.
          "Lectura del mensaje.
          PERFORM f_read_msg_error
             USING
               <fs_return>
             CHANGING
               g_msg.

          APPEND INITIAL LINE TO gt_mensajes ASSIGNING FIELD-SYMBOL(<fs_mensajes>).
          MOVE-CORRESPONDING <fs_return> TO <fs_mensajes>.
          CONCATENATE  g_msg <fs_final>-zvbeln INTO <fs_mensajes>-msg SEPARATED BY space.
        ENDLOOP.

        "Correcto
        IF ch_error EQ abap_false AND g_ok EQ abap_true.

          APPEND INITIAL LINE TO gt_mensajes ASSIGNING <fs_mensajes>."i_resultado ASSIGNING <fs_resul>.
          MOVE '111' TO <fs_mensajes>-codigo.
          CONCATENATE 'Datos grabados con éxito' <fs_final>-zvbeln
          INTO  <fs_mensajes>-msg SEPARATED BY space.

          CALL FUNCTION 'BAPI_TRANSACTION_COMMIT'
            EXPORTING
              wait = 'X'.
        ENDIF.

      ENDLOOP.
      "FIN Modo test.

      "Indicador NO FALLÓ el modo test.
      IF  ch_error EQ abap_false.
        g_ok = abap_true.
        CALL FUNCTION 'BAPI_TRANSACTION_ROLLBACK'. "+@001
      ELSE.
        EXIT.
      ENDIF.

    ENDDO.
  ENDIF.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form get_data_tablas
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*&      <-- G_ERROR
*&---------------------------------------------------------------------*
FORM get_data_tablas  CHANGING ch_error TYPE abap_bool.

  "Datos de entrega.
  SELECT a~vbeln a~lfdat a~btgew a~anzpk a~lfuhr a~bolnr
         a~lifnr a~verur a~vegr2 a~inhalt a~zul_aufl
         b~posnr b~matnr b~werks b~lgort b~vgbel b~brgew b~gewei
         b~vgpos b~lfimg b~meins b~vrkme
      FROM likp AS a INNER JOIN lips AS b
        ON a~vbeln EQ b~vbeln
      INTO CORRESPONDING FIELDS OF TABLE gt_likps
      FOR ALL ENTRIES IN gt_reg_ent
      WHERE a~vbeln EQ gt_reg_ent-zvbeln.

  IF sy-subrc EQ 0.
    "Entregas almacén no HU.
    SELECT * FROM zbvmm_entrenohu INTO TABLE gt_entrenohu
      FOR ALL ENTRIES IN gt_reg_ent
      WHERE vbeln EQ gt_reg_ent-zvbeln.

    IF sy-subrc EQ 0.
      g_marc_nohu = abap_true.
    ENDIF.

    "carga rangos principales.
    PERFORM prepara_likp_rangos.

    "Datos acreedor, centro y material.
    PERFORM get_acreedor_centro_mat.

    "Datos pedido.
    PERFORM get_data_pedido CHANGING ch_error.

    IF ch_error EQ abap_false.
      "Datos HU.
      PERFORM get_data_hu CHANGING ch_error.
    ENDIF.


  ENDIF.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form prepara_likp_rangos
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM prepara_likp_rangos .

  REFRESH: gr_lifnr, gr_werks, gr_matnr, gr_vgbel, gr_vpobjkey.

  LOOP AT gt_likps ASSIGNING FIELD-SYMBOL(<fs_likps>).
    MOVE <fs_likps>-vgpos TO <fs_likps>-ebelp.
    MOVE <fs_likps>-vbeln TO <fs_likps>-vpobjkey.
    "Llenas rango de acreedores.
    APPEND VALUE #( sign = 'I' option  = 'EQ' low = <fs_likps>-lifnr ) TO gr_lifnr.
    "Llenar rango centro
    APPEND VALUE #( sign = 'I' option  = 'EQ' low = <fs_likps>-werks ) TO gr_werks.
    "Llenar rango material
    APPEND VALUE #( sign = 'I' option  = 'EQ' low = <fs_likps>-matnr ) TO gr_matnr.
    "llenar rango posición docmodelo.
    APPEND VALUE #( sign = 'I' option  = 'EQ' low = <fs_likps>-vgbel ) TO gr_vgbel.
    "llenar rango vpobjkey.
    APPEND VALUE #( sign = 'I' option  = 'EQ' low = <fs_likps>-vpobjkey ) TO gr_vpobjkey.
  ENDLOOP.

  mac_sort_range gr_lifnr.
  mac_sort_range gr_werks.
  mac_sort_range gr_matnr.
  mac_sort_range gr_vgbel.
  mac_sort_range gr_vpobjkey.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form get_acreedor_centro_mat
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM get_acreedor_centro_mat .
  "Descripción del material.
  IF gr_matnr IS NOT INITIAL.
    PERFORM descrip_material.
  ENDIF.
  "Datos acreedor.
  IF gr_lifnr IS NOT INITIAL.

    SELECT lifnr ort01 ort02 stras name1 stcd1
      FROM lfa1
       INTO TABLE gt_lfa1
       WHERE lifnr IN gr_lifnr.

    IF sy-subrc EQ 0.
      SORT gt_lfa1 BY lifnr.
    ENDIF.

  ENDIF.

  "Datos centro.
  IF gr_werks IS NOT INITIAL.

    SELECT a~werks a~name1 a~lifnr a~stras a~ort01 a~adrnr
           b~street b~str_suppl1 b~city1 b~city2
    FROM t001w AS a LEFT JOIN
         adrc AS b
      ON a~adrnr EQ b~addrnumber
    INTO CORRESPONDING FIELDS OF TABLE gt_t001wadr
    WHERE werks IN gr_werks.

    IF sy-subrc EQ 0.
      SORT gt_t001wadr BY werks.
    ENDIF.

  ENDIF.

  "Datos material.
  SELECT matnr werks dispo
     FROM marc
     INTO TABLE gt_marc
     FOR ALL ENTRIES IN gt_likps
     WHERE matnr EQ gt_likps-matnr.
*       AND werks EQ gt_likps-werks.    "COMMENT - @PMPD001 - 10.03.2022

  IF sy-subrc EQ 0.
    SORT gt_marc BY matnr werks.
    DELETE ADJACENT DUPLICATES FROM  gt_marc COMPARING matnr werks.
  ENDIF.

  "Bezei
  SELECT spras vegr2 bezei
     FROM tve2t
     INTO TABLE gt_tve2t_2
     FOR ALL ENTRIES IN gt_likps
     WHERE vegr2 EQ gt_likps-vegr2.

  IF sy-subrc EQ 0.
    SORT gt_tve2t_2 BY vegr2.
    DELETE ADJACENT DUPLICATES FROM gt_tve2t_2 COMPARING vegr2.
  ENDIF..


  "Datos HU obligatorio
  SELECT werks lgort lgobe xhupf
    INTO TABLE gt_t001l
    FROM t001l
    FOR ALL ENTRIES IN gt_likps
    WHERE werks EQ gt_likps-werks
      AND lgort EQ gt_likps-lgort.
  IF sy-subrc EQ 0.
    SORT gt_t001l BY werks lgort.
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form descrip_material
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM descrip_material .
  IF gr_matnr IS NOT INITIAL.

    SELECT matnr maktx
      FROM makt
      INTO TABLE gt_makt
      WHERE matnr IN gr_matnr.

    IF sy-subrc EQ 0.
      SORT gt_makt BY matnr.
    ENDIF.

  ENDIF.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form get_data_pedido
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*&      <-- CH_ERROR
*&---------------------------------------------------------------------*
FORM get_data_pedido  CHANGING ch_error TYPE abap_bool.

  gt_likps_aux = gt_likps.
  SORT gt_likps_aux BY vgbel ebelp.
  DELETE ADJACENT DUPLICATES FROM gt_likps_aux COMPARING vgbel ebelp.

  IF gt_likps_aux IS NOT INITIAL.

*      SELECT ebeln ebelp bukrs bstae bpumz bpumn umrez umren zzlug_ent "DELETE @PM
    SELECT ebeln ebelp bukrs bstae bpumz bpumn umrez umren zzlug_ent afnam "INSERT @PM
           inco1 "+@001
      FROM ekpo
      INTO TABLE gt_ekpo
      FOR ALL ENTRIES IN gt_likps_aux
      WHERE ebeln EQ gt_likps_aux-vgbel
      AND ebelp EQ gt_likps_aux-ebelp.

    IF sy-subrc EQ 0.
      SORT gt_ekpo BY ebeln ebelp.

      SELECT ebeln ernam bsart
        FROM ekko
        INTO TABLE gt_ekko_p
        FOR ALL ENTRIES IN gt_ekpo
        WHERE ebeln = gt_ekpo-ebeln.
      IF sy-subrc EQ 0.
        SORT gt_ekko_p BY ebeln.
      ENDIF.

    ENDIF.

    IF gr_vgbel IS NOT INITIAL.

      SELECT ebeln ernam
      FROM ekko
      INTO TABLE gt_ekko
      WHERE ebeln IN gr_vgbel.

      IF sy-subrc EQ 0.

        SORT gt_ekko BY ebeln.
        LOOP AT gt_ekko ASSIGNING FIELD-SYMBOL(<fs_ekko>).
          APPEND VALUE #( sign = 'I' option  = 'EQ' low = <fs_ekko>-ernam ) TO gr_ernam.
        ENDLOOP.

        mac_sort_range gr_ernam.

        IF gr_ernam IS NOT INITIAL.

          SELECT b~smtp_addr a~bname
            INTO TABLE gt_adr6 FROM usr21 AS a
            INNER JOIN adr6 AS b
            ON b~addrnumber EQ a~addrnumber AND
               b~persnumber EQ a~persnumber
            WHERE bname IN gr_ernam.
          IF sy-subrc EQ 0.
            SORT gt_adr6 BY bname.
          ENDIF.

          "Nombre del comprador.
          SELECT a~bname b~name_text INTO TABLE  gt_adrp
            FROM usr21 AS a INNER JOIN
            adrp AS b ON
            a~persnumber EQ b~persnumber
            WHERE a~bname IN gr_ernam.
          IF sy-subrc EQ 0.
            SORT gt_adrp BY bname.
          ENDIF.

        ENDIF.
      ENDIF.
    ENDIF.

  ENDIF.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form get_data_hu
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*&      <-- CH_ERROR
*&---------------------------------------------------------------------*
FORM get_data_hu  CHANGING p_g_error.

  gt_likps_aux = gt_likps.

  IF gr_vpobjkey IS NOT INITIAL.

    SELECT venum brgew vegr1 vegr2 laeng breit
*               hoehe inhalt vhilm_ku vpobjkey zul_aufl "DELETE @PM
           hoehe inhalt vhilm_ku vpobjkey zul_aufl exidv "INSERT @PM
      FROM vekp
      INTO TABLE gt_vekp
      WHERE vpobjkey IN gr_vpobjkey.

    SORT gt_vekp BY venum.

    IF sy-subrc EQ 0.

      LOOP AT gt_vekp ASSIGNING FIELD-SYMBOL(<fs_vekp>).
        "Llenas rango de venum.
        APPEND VALUE #( sign = 'I' option  = 'EQ' low = <fs_vekp>-venum ) TO gr_venum.
        APPEND VALUE #( sign = 'I' option  = 'EQ' low = <fs_vekp>-vegr2 ) TO gr_vegr2.
      ENDLOOP.

      mac_sort_range gr_venum.
      mac_sort_range gr_vegr2.

      IF gr_venum IS NOT INITIAL.

        SELECT venum vepos vbeln posnr vemng matnr vemeh altme
          FROM vepo
          INTO TABLE gt_vepo
           WHERE venum IN gr_venum.

        IF sy-subrc EQ 0.

***                      SORT gt_vepo BY venum posnr matnr.
***                      LOOP AT gt_vepo ASSIGNING FIELD-SYMBOL(<fs_vepo>).
***                           "Llenas rango de venum.
***                           APPEND VALUE #( sign = 'I' option  = 'EQ' low = <fs_vekp>-venum ) TO gr_matnr.
***                      ENDLOOP.
***
***                      MAC_SORT_RANGE gr_matnr.
***                      "Descripción del material.
***                      PERFORM descrip_material.

          IF gr_vegr2 IS NOT INITIAL.

            SELECT spras vegr2 bezei
             FROM tve2t
             INTO TABLE gt_tve2t
             WHERE vegr2 IN gr_vegr2.

            IF sy-subrc EQ 0.
              SORT gt_tve2t BY vegr2.
            ENDIF.

          ENDIF.
        ENDIF.
      ENDIF.
    ENDIF.
  ENDIF.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form del_entrega
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*&      --> I_VBELN
*&---------------------------------------------------------------------*
FORM del_entrega  USING i_vbeln TYPE vbeln_vl.

  DELETE FROM zbvmm_entrenohu WHERE vbeln EQ i_vbeln.
  DELETE FROM zbvmm_entrega_re WHERE zvbeln EQ i_vbeln.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form INB_DELIVERY_CREATE
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*&      --> IT_INB_DELIVERY_DETAIL[]
*&      --> RETURN[]
*&      --> IS_INB_DELIVERY_HEADER
*&      --> EF_DELIVERY
*&---------------------------------------------------------------------*
FORM inb_delivery_create  TABLES   it_inb_delivery_detail TYPE inbdelivdetail_type
                     return  TYPE return_type
            USING    is_inb_delivery_header STRUCTURE bbp_inbd_l
                     i_bsart TYPE esart
                     ef_delivery LIKE likp-vbeln.

*** Local Variables
  DATA lt_vbsk LIKE vbsk OCCURS 0 WITH HEADER LINE.
  DATA lt_komdlgn LIKE komdlgn OCCURS 0 WITH HEADER LINE.
  DATA lt_vbfs LIKE vbfs OCCURS 0 WITH HEADER LINE.
  DATA lt_vbls LIKE vbls OCCURS 0 WITH HEADER LINE.
  DATA lf_h-ind LIKE sy-tabix.         "Hilfsfeld Index
  DATA lf_v_vbeln LIKE likp-vbeln.     "From delivery Number
  DATA lf_b_vbeln LIKE likp-vbeln.     "To delivery Number
  DATA lt_prop LIKE wuebs OCCURS 100 WITH HEADER LINE.

**** Loading the lt_komdlgn
  IF i_bsart EQ 'ZBIM'.
    lt_komdlgn-lfart = 'ZEL2'.
  ENDIF.
  lt_komdlgn-lifex = is_inb_delivery_header-deliv_ext.
  lt_komdlgn-verur = is_inb_delivery_header-deliv_ext.
  lt_komdlgn-lfdat = is_inb_delivery_header-deliv_date.
  lt_komdlgn-lfuhr = is_inb_delivery_header-deliv_time.
*  lt_komdlgn-lifnr = 'Lear_03'. "if_vendor

  LOOP AT it_inb_delivery_detail. "into et_po_detail.

    lt_komdlgn-matnr = it_inb_delivery_detail-material.
    lt_komdlgn-lfimg = it_inb_delivery_detail-deliv_qty.
    lt_komdlgn-vrkme = it_inb_delivery_detail-unit.
    lt_komdlgn-meins = it_inb_delivery_detail-unit.
*    lt_komdlgn-umvkz = 1.
*    lt_komdlgn-umvkn = 1.
*    lt_komdlgn-werks = '0001'.
    lt_komdlgn-vgbel = it_inb_delivery_detail-po_number.
    lt_komdlgn-vgpos = it_inb_delivery_detail-po_item.

    APPEND lt_komdlgn.
  ENDLOOP.


*** Code from IDOC_INPUT_DESADV1
*** Not Available in 3.1
  CALL FUNCTION 'ME_CONFIRMATION_VIA_EDI'
    TABLES
      t_kom  = lt_komdlgn
      errors = lt_prop
    EXCEPTIONS
      OTHERS = 1.

  IF sy-subrc NE 0.
    WRITE / 'Error Coccured in ME_CONFIRMATION_VIA_EDI'.
  ENDIF.


  LOOP AT lt_komdlgn.
* set default parameter
    lt_komdlgn-vgtyp = 'V'.
    lt_komdlgn-kzazu = 'X'.
    IF lt_komdlgn-lfart IS INITIAL.
      lt_komdlgn-lfart = 'EL'.
    ENDIF.
    MODIFY lt_komdlgn.
  ENDLOOP.

***** Create
  DATA: nrnr LIKE inri-nrrangenr.
  TABLES: tvsa.

* Sammelgangsnummer vergeben
  lt_vbsk-mandt = sy-mandt.
  lt_vbsk-ernam = sy-uname.
  lt_vbsk-erdat = sy-datum.
  lt_vbsk-uzeit = sy-uzeit.
  lt_vbsk-smart = 'L'.

  SELECT SINGLE * FROM tvsa WHERE smart = lt_vbsk-smart.
  IF sy-subrc <> 0.
*** Error Handling To be Done
*   Meldung ins Protokoll
  ENDIF.


  nrnr = tvsa-numki.
  CALL FUNCTION 'NUMBER_GET_NEXT'
    EXPORTING
      nr_range_nr = nrnr
      object      = 'RV_SAMMG'
    IMPORTING
      number      = lt_vbsk-sammg
    EXCEPTIONS
      OTHERS      = 1.
  IF sy-subrc <> 0.
*** Error Hadling TBD
*   Meldung ins Protokoll
  ENDIF.

**** Call Core Function GN_DELIVERY_CREATE.
  CALL FUNCTION 'GN_DELIVERY_CREATE'
    EXPORTING
      vbsk_i   = lt_vbsk
    IMPORTING
      vbsk_e   = lt_vbsk
    TABLES
      xkomdlgn = lt_komdlgn
      xvbfs    = lt_vbfs
      xvbls    = lt_vbls
    EXCEPTIONS
      OTHERS   = 1.

*** Error Handling
  IF sy-subrc NE 0.
    ROLLBACK WORK.
    PERFORM fill_bapireturn TABLES return
                            USING  sy-msgty sy-msgid sy-msgno
                                   sy-msgv1 sy-msgv2
                                   sy-msgv3 sy-msgv4.
  ELSE.

    IF lt_vbsk-ernum EQ 0 AND
       lt_vbsk-vbnum GT 0.
      DESCRIBE TABLE lt_vbls LINES lf_h-ind.
      READ TABLE lt_vbls INDEX 1.
      lf_v_vbeln = lt_vbls-vbeln_lif.
      READ TABLE lt_vbls INDEX lf_h-ind.
      lf_b_vbeln = lt_vbls-vbeln_lif.
      CLEAR lf_h-ind.

      ef_delivery = lf_v_vbeln.
      PERFORM fill_bapireturn TABLES return
                              USING  'S'   "msgType
                                     'ME'  "msgid
                                     '780' "msgno
                                     lt_vbsk-vbnum "sy-msgv1
                                     lf_v_vbeln    "sy-msgv1
                                     lf_b_vbeln    "sy-msgv2
                                     sy-msgv4.

    ENDIF.
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form FILL_BAPIRETURN
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*&      --> RETURN
*&      --> P_
*&      --> P_
*&      --> P_
*&      --> LT_VBSK_VBNUM
*&      --> LF_V_VBELN
*&      --> LF_B_VBELN
*&      --> SY_MSGV4
*&---------------------------------------------------------------------*
FORM fill_bapireturn  TABLES return STRUCTURE bapireturn
                 USING fbr_mstyp
                       fbr_msgid
                       fbr_msgno
                       fbr_msgv1
                       fbr_msgv2
                       fbr_msgv3
                       fbr_msgv4.

  DATA: h_return LIKE bapireturn.
  DATA: BEGIN OF msg,
          ty LIKE syst-msgty,
          id LIKE syst-msgid,
          no LIKE syst-msgno,
          v1 LIKE syst-msgv1,
          v2 LIKE syst-msgv2,
          v3 LIKE syst-msgv3,
          v4 LIKE syst-msgv4,
        END OF msg.


  CLEAR h_return.
  CLEAR msg.
  MOVE: fbr_mstyp TO msg-ty,
        fbr_msgid TO msg-id,
        fbr_msgno TO msg-no,
        fbr_msgv1 TO msg-v1,
        fbr_msgv2 TO msg-v2,
        fbr_msgv3 TO msg-v3,
        fbr_msgv4 TO msg-v4.

  CALL FUNCTION 'BALW_BAPIRETURN_GET'
    EXPORTING
      type       = msg-ty
      cl         = msg-id
      number     = msg-no
      par1       = msg-v1
      par2       = msg-v2
      par3       = msg-v3
      par4       = msg-v4
    IMPORTING
      bapireturn = h_return.

  CLEAR return.
  MOVE h_return TO return.
  APPEND return.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form carga_errores
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*&      --> LT_RETURN
*&      --> IT_RESULT
*&---------------------------------------------------------------------*
FORM carga_errores  TABLES   it_return STRUCTURE bapiret2
                           it_result STRUCTURE zbvmm_st_result
                           .

  LOOP AT it_return ASSIGNING FIELD-SYMBOL(<fs_return>) WHERE type EQ 'E'.
    CLEAR: g_msg.
    APPEND INITIAL LINE TO it_result ASSIGNING FIELD-SYMBOL(<fs_result>).
    "Lectura del mensaje.
    PERFORM f_read_msg_error
       USING
         <fs_return>
       CHANGING
          g_msg.

    MOVE-CORRESPONDING <fs_return> TO <fs_result>.
    <fs_result>-msg = g_msg.
  ENDLOOP.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form proce_hu_no
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*&      --> LTD_ENTR_DET
*&      --> T_RESULT
*&      --> <FS_ENTR_CAB>
*&      <-- L_ERROR
*&---------------------------------------------------------------------*
FORM proce_hu_no  TABLES it_detalle STRUCTURE zbvmm_st_modificar_entrega_det
                         it_result  STRUCTURE zbvmm_st_result
                 USING is_cabecera TYPE zbvmm_st_modificar_entrega
                  CHANGING e_error TYPE abap_bool.

  DATA: lv_message        TYPE bapi_msg,
        lv_type           TYPE bapi_mtype,
        lw_hukey          TYPE bapihukey-hu_exid,
        lw_hu_id          TYPE rlmob-clenum,
        ls_header_data    TYPE bapiibdlvhdrchg,
        ls_header_control TYPE bapiibdlvhdrctrlchg,
        ls_headerproposal TYPE bapihuhdrproposal,
        ls_huheader       TYPE bapihuheader,
        ls_ref_object     TYPE hum_object,
        ls_hu_header_main TYPE huhdr_proposal,
        ls_mm_data        TYPE hum_plant_stloc,
        ls_item_proposal  TYPE huitm_proposal,
        lt_return         TYPE STANDARD TABLE OF bapiret2,
        lw_btgew          TYPE likp-btgew,    "Peso total
        lw_brgew          TYPE vekp-brgew.     "Peso por bulto


  DATA(lt_detalle) = it_detalle[].

  PERFORM agrupa_nohu_mod TABLES it_detalle.

  "Modificar entrega.
  PERFORM modif_entrega TABLES it_detalle
                               it_result
                         USING is_cabecera
                         CHANGING e_error.


  CHECK e_error EQ abap_false. "Continúa si no hay error.

  PERFORM act_entrega_nohu TABLES lt_detalle"it_detalle
                               it_result
                         USING is_cabecera
                         CHANGING e_error.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form agrupa_nohu_mod
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*&      --> IT_DETALLE
*&---------------------------------------------------------------------*
FORM agrupa_nohu_mod  TABLES it_detalle STRUCTURE zbvmm_st_modificar_entrega_det
                                                 .

  DATA lt_detalle TYPE STANDARD TABLE OF zbvmm_st_modificar_entrega_det.

  g_marc_nohu = abap_true.
  CLEAR: g_pesototal.

  lt_detalle =  it_detalle[].
  SORT lt_detalle BY vhilm_ku ASCENDING brgew ASCENDING.
  DELETE ADJACENT DUPLICATES FROM lt_detalle COMPARING vhilm_ku.

  LOOP AT lt_detalle ASSIGNING FIELD-SYMBOL(<fs_det>).
    ADD <fs_det>-brgew TO g_pesototal.
  ENDLOOP.

  lt_detalle = it_detalle[].
  SORT it_detalle BY ebeln ebelp matnr. "vhilm_ku.
  DELETE ADJACENT DUPLICATES FROM it_detalle COMPARING ebeln ebelp matnr. "vhilm_ku.

  LOOP AT it_detalle ASSIGNING FIELD-SYMBOL(<fs_itdet>).

    CLEAR: <fs_itdet>-menge.
    LOOP AT lt_detalle ASSIGNING <fs_det> WHERE ebeln EQ <fs_itdet>-ebeln
                                            AND ebelp EQ <fs_itdet>-ebelp
                                            AND matnr EQ <fs_itdet>-matnr.

      ADD <fs_det>-menge TO <fs_itdet>-menge.
    ENDLOOP.

  ENDLOOP.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form modif_entrega
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*&      --> IT_DETALLE
*&      --> IT_RESULT
*&      --> IS_CABECERA
*&      <-- E_ERROR
*&---------------------------------------------------------------------*
FORM modif_entrega  TABLES it_detalle STRUCTURE zbvmm_st_modificar_entrega_det
                          it_result  STRUCTURE zbvmm_st_result
                   USING is_cabecera TYPE zbvmm_st_modificar_entrega
                   CHANGING e_error TYPE abap_bool.

  TYPES: BEGIN OF lty_detalle,
           vbeln TYPE vbeln,
           ebeln TYPE vbelv,
           ebelp TYPE c LENGTH 6,
           menge TYPE bstmg,
           meins TYPE bstme,
         END OF lty_detalle.

  DATA: lt_item_data      TYPE STANDARD TABLE OF bapiibdlvitemchg,
        ls_item_data      LIKE LINE OF lt_item_data,
        lt_item_control   TYPE STANDARD TABLE OF bapiibdlvitemctrlchg,
        ls_header_data    TYPE bapiibdlvhdrchg,
        ls_header_control TYPE bapiibdlvhdrctrlchg,
        lt_extension2     TYPE STANDARD TABLE OF  bapiext,
        lt_return         TYPE STANDARD TABLE OF bapiret2,
        ls_return         TYPE bapireturn,
        ls_return2        TYPE bapiret2,
        lt_uekes          TYPE TABLE OF uekes,
        ls_uekes          LIKE LINE OF  lt_uekes,
        lw_etens          TYPE ekes-etens,
        lt_detalle_aux    TYPE STANDARD TABLE OF lty_detalle,
        ls_detalle        LIKE LINE OF lt_detalle_aux,

        lv_param          TYPE zge_t_constantes-low, "ztconstantes-valor_low,
        lv_field1         TYPE zge_t_constantes-low, "ztconstantes-valor_low,
        lv_field2         TYPE zge_t_constantes-low, "ztconstantes-valor_low,
        lv_field3         TYPE zge_t_constantes-low, "ztconstantes-valor_low,
        lv_field4         TYPE zge_t_constantes-low, "ztconstantes-valor_low,
        lv_field5         TYPE zge_t_constantes-low, "ztconstantes-valor_low,
        lv_field6         TYPE zge_t_constantes-low, "ztconstantes-valor_low,
        lv_field7         TYPE zge_t_constantes-low, "ztconstantes-valor_low,
        lv_status         TYPE zge_t_constantes-low, "ztconstantes-valor_low,
        lv_packmt         TYPE zge_t_constantes-low, "ztconstantes-valor_low,
        lv_matobj         TYPE zge_t_constantes-low, "ztconstantes-valor_low,
        lv_objct1         TYPE zge_t_constantes-low, "ztconstantes-valor_low,
        lv_svstep         TYPE zge_t_constantes-low, "ztconstantes-valor_low,
        lv_packm2         TYPE zge_t_constantes-low, "ztconstantes-valor_low,
        lv_dlvryt         TYPE likp-vbtyp,  "ztconstantes-valor_low,
        lv_packat         TYPE zge_t_constantes-low, "ztconstantes-valor_low,,
        lv_packty         TYPE zge_t_constantes-low, "ztconstantes-valor_low,
        lv_categ          TYPE zge_t_constantes-low, "ztconstantes-valor_low,
        lv_del            TYPE abap_bool,
        lv_tiene_split    TYPE abap_bool,            "+@LOTE
        lv_n_lin          TYPE i,                    "+@004 líneas LIPS de la posición
        lv_cant_sub       TYPE lfimg,                "+@004 total en subposiciones

        lw_btgew          TYPE likp-btgew,    "Peso total
        lw_brgew          TYPE vekp-brgew,    "Peso por bulto
        lw_anzpk          TYPE likp-anzpk,    "Nro. de bultos
        lw_um             TYPE char01,        "Gestion de unidades
        lw_borgr_grp      TYPE likp-borgr_grp,
        lw_texto1         TYPE char10,
        lw_texto2         TYPE char10,
        lw_texto3         TYPE char10,
        lw_menge          TYPE ekes-menge,
        lw_flagekes       TYPE c,
        lw_message        TYPE string
        .

  PERFORM get_constantes USING lv_param lv_field1 lv_field2 lv_field3 lv_field4 lv_field5
                               lv_field6 lv_field7 lv_status lv_packmt lv_matobj lv_objct1
                               lv_svstep lv_packm2 lv_dlvryt lv_packat lv_packty lv_categ.


  "Datos del pedido.
  SELECT p~ebeln, p~ebelp, p~werks, p~lgort, p~umren, p~bstae, b~eindt, b~menge, b~wamng, b~nodisp, p~bwtar
    INTO TABLE @DATA(lt_ekpo)
    FROM ekpo AS p INNER JOIN eket AS b
         ON p~ebeln = b~ebeln
        AND p~ebelp = b~ebelp
      FOR ALL ENTRIES IN @it_detalle
      WHERE p~ebeln EQ @it_detalle-ebeln
        AND p~ebelp EQ @it_detalle-ebelp+1(5).

    LOOP AT it_detalle ASSIGNING FIELD-SYMBOL(<fs_detalle>).
    MOVE-CORRESPONDING <fs_detalle> TO ls_detalle.
    COLLECT ls_detalle INTO lt_detalle_aux.
  ENDLOOP.

*{+@LOTE
  "Lotes: crea, actualiza y elimina las subposiciones 9000xx.
  PERFORM lotes_modif TABLES gt_entr_lot
                             it_result
                             lt_item_data
                             lt_item_control
                      USING  is_cabecera
                      CHANGING e_error.

  CHECK e_error EQ abap_false.
*}+@LOTE


  "Modif.entrega
  LOOP AT  gt_lips02 ASSIGNING FIELD-SYMBOL(<fs_lips>).
    CLEAR ls_item_data.                                   "+@004 no arrastrar campos

*{+@LOTE  (reescrito @004)
*  Antes: toda línea con lote se saltaba. Una posición con un solo lote que
*  cambiaba de cantidad sin enviar lotes quedaba igual, sin aviso; y una
*  posición partida que ya no venía en la trama no se eliminaba.
    "Posición con lotes en la trama: la trata lotes_modif.
    READ TABLE gt_entr_lot TRANSPORTING NO FIELDS
         WITH KEY ebeln = <fs_lips>-vgbel
                  ebelp = <fs_lips>-vgpos.
    IF sy-subrc EQ 0.
      CONTINUE.
    ENDIF.

    "Subposición de lote (LIPS-UECHA = su padre): se trata junto con la padre.
    IF <fs_lips>-uecha IS NOT INITIAL.
      CONTINUE.
    ENDIF.

    "Padre de una partición de lote: tiene subposiciones (UECHA = su POSNR).
    CLEAR: lv_n_lin, lv_cant_sub.
    LOOP AT gt_lips02 ASSIGNING FIELD-SYMBOL(<fs_lips_pos>)
         WHERE uecha EQ <fs_lips>-posnr.
      lv_n_lin = lv_n_lin + 1.
      lv_cant_sub = lv_cant_sub + <fs_lips_pos>-lfimg.
    ENDLOOP.
    IF lv_n_lin GT 0.
      READ TABLE lt_detalle_aux ASSIGNING FIELD-SYMBOL(<fs_det_split>)
           WITH KEY ebeln = <fs_lips>-vgbel
                    ebelp = <fs_lips>-vgpos.
      IF sy-subrc EQ 0.
        "Sigue en la trama pero sin lotes: no se sabe a qué lote va un cambio
        "de cantidad. El FM ya lo rechaza antes; esto es una red de seguridad.
        IF <fs_det_split>-menge NE lv_cant_sub.
          APPEND INITIAL LINE TO it_result ASSIGNING FIELD-SYMBOL(<fs_res_split>).
          <fs_res_split>-codigo = '999'.
          <fs_res_split>-type   = 'E'.
          <fs_res_split>-msg    = |Pos. { CONV i( <fs_lips>-vgpos ) } del pedido { <fs_lips>-vgbel } | &&
                                  |tiene lotes: envíe el detalle de lotes para cambiar su cantidad|.
          e_error = abap_true.
        ENDIF.
        CONTINUE.
      ENDIF.
      "Ya no viene en la trama: se elimina la padre (arrastra sus
      "subposiciones de lote; verificar en DEV). Sigue al borrado normal.
    ENDIF.
*}+@LOTE


    lv_del = abap_false.
    READ TABLE lt_detalle_aux ASSIGNING FIELD-SYMBOL(<fs_detalle_aux>) WITH KEY ebeln = <fs_lips>-vgbel
                                                                                ebelp = <fs_lips>-vgpos.
    IF sy-subrc EQ 0.

      READ TABLE lt_ekpo ASSIGNING FIELD-SYMBOL(<fs_ekpo>) WITH KEY ebeln = <fs_detalle_aux>-ebeln
                                                                       ebelp = <fs_detalle_aux>-ebelp+1(5).
      IF sy-subrc EQ 0.
        ls_item_data-deliv_numb = <fs_detalle_aux>-vbeln.
        ls_item_data-deliv_item = <fs_lips>-posnr.
        ls_item_data-material  = <fs_lips>-matnr.
        ls_item_data-batch  = <fs_lips>-charg.
        ls_item_data-dlv_qty = <fs_detalle_aux>-menge.
        ls_item_data-sales_unit    = <fs_detalle_aux>-meins.
        ls_item_data-dlv_qty_imunit = 0.
        ls_item_data-fact_unit_denom = <fs_ekpo>-umren.
        ls_item_data-fact_unit_nom   = <fs_lips>-umvkz.
        APPEND  ls_item_data TO lt_item_data.
      ENDIF.

      "Eliminar pos.
    ELSE.
      lv_del = abap_true.

      ls_item_data-deliv_numb = <fs_lips>-vbeln.
      ls_item_data-deliv_item = <fs_lips>-posnr.
      ls_item_data-material  = <fs_lips>-matnr.
      ls_item_data-batch  = <fs_lips>-charg.
      ls_item_data-dlv_qty = <fs_lips>-lfimg.
*          ls_item_data-dlv_qty_imunit = <fs_lips>-lfimg.
      ls_item_data-sales_unit    = <fs_lips>-meins.
      ls_item_data-fact_unit_denom = <fs_lips>-umvkn.
      ls_item_data-fact_unit_nom   = <fs_lips>-umvkz.
      APPEND  ls_item_data TO lt_item_data.
    ENDIF.

    APPEND INITIAL LINE TO lt_item_control ASSIGNING FIELD-SYMBOL(<fs_item_control>).
    <fs_item_control>-deliv_numb     = ls_item_data-deliv_numb.
    <fs_item_control>-deliv_item     = ls_item_data-deliv_item .

    "Borrar
    IF lv_del EQ abap_true.
      <fs_item_control>-del_item    =  abap_true.
      "Modificar
    ELSE.
      <fs_item_control>-chg_delqty     =  abap_true.
    ENDIF.

  ENDLOOP.

  "+@004 Posición partida que cambió de cantidad sin lotes: no se modifica nada.
  CHECK e_error EQ abap_false.
***********
***********  LOOP AT lt_detalle_aux ASSIGNING FIELD-SYMBOL(<fs_detalle_aux>).
***********
***********       CLEAR: ls_item_data.
***********
***********       READ TABLE lt_ekpo ASSIGNING FIELD-SYMBOL(<fs_ekpo>) WITH KEY ebeln = <fs_detalle_aux>-ebeln
***********                                                                       ebelp = <fs_detalle_aux>-ebelp+1(5).
***********       IF sy-subrc EQ 0.
************          APPEND INITIAL LINE TO lt_item_data ASSIGNING FIELD-SYMBOL(<fs_iten_data>).
***********           ls_item_data-deliv_numb = <fs_detalle_aux>-vbeln."<fs_item_data>-deliv_numb = <fs_detalle>-vbeln.
***********
***********          READ TABLE gt_lips02 ASSIGNING FIELD-SYMBOL(<fs_lips>) WITH KEY vgbel =  <fs_detalle_aux>-ebeln
***********                                                                          vgpos =  <fs_detalle_aux>-ebelp.
***********          IF sy-subrc EQ 0.
***********            ls_item_data-deliv_item = <fs_lips>-posnr.
***********            ls_item_data-material  = <fs_lips>-matnr.
***********            ls_item_data-batch  = <fs_lips>-charg.
***********            ls_item_data-dlv_qty = <fs_detalle_aux>-menge.
***********            ls_item_data-sales_unit    = <fs_detalle_aux>-meins.
***********            ls_item_data-dlv_qty_imunit = 0.
***********            ls_item_data-fact_unit_denom = <fs_ekpo>-umren.
***********            ls_item_data-fact_unit_nom   = <fs_lips>-umvkz.
***********
***********          APPEND  ls_item_data TO lt_item_data.
************          COLLECT ls_item_data INTO lt_item_data.
***********       ENDIF.
***********
***********  ENDLOOP.
***********
***********"DATA CONTROL
***********  LOOP AT lt_item_data ASSIGNING FIELD-SYMBOL(<fs_item_data>).
***********       APPEND INITIAL LINE TO lt_item_control ASSIGNING FIELD-SYMBOL(<fs_item_control>).
***********       <fs_item_control>-deliv_numb     = <fs_item_data>-deliv_numb.
***********       <fs_item_control>-deliv_item     = <fs_item_data>-deliv_item .
***********       <fs_item_control>-chg_delqty     =  abap_true.
***********  ENDLOOP.

  APPEND INITIAL LINE TO lt_extension2 ASSIGNING FIELD-SYMBOL(<fs_extension2>).
  <fs_extension2>-param = lv_param."  - Constante
  <fs_extension2>-field = lv_field1.   "ANZPK- Cantidad de bultos
  <fs_extension2>-value = is_cabecera-anzpk.

  APPEND INITIAL LINE TO lt_extension2 ASSIGNING <fs_extension2>.
  <fs_extension2>-param = lv_param.  "- Constante
  <fs_extension2>-field = 'BRGEW'. "lv_field2.    "BTGEW  Peso total
  <fs_extension2>-value = is_cabecera-brgew.
  CONDENSE <fs_extension2>-value NO-GAPS.

  SORT lt_item_data BY deliv_item.

  ls_header_data-deliv_numb = is_cabecera-vbeln.
  ls_header_control-deliv_numb = is_cabecera-vbeln.

  CALL FUNCTION 'BAPI_INB_DELIVERY_CHANGE'
    EXPORTING
      header_data    = ls_header_data
      header_control = ls_header_control
      delivery       = is_cabecera-vbeln
    TABLES
      item_data      = lt_item_data
      item_control   = lt_item_control
*     item_serial_no = lt_item_serial
      extension2     = lt_extension2
      return         = lt_return.

  IF  lt_return IS INITIAL.

    PERFORM commit_wait.
    APPEND INITIAL LINE TO it_result ASSIGNING FIELD-SYMBOL(<fs_result>).
    <fs_result>-codigo = '000'.
    CONCATENATE TEXT-044 is_cabecera-vbeln INTO <fs_result>-msg SEPARATED BY space.

*{+@004 Los lotes ya están aplicados: en la segunda llamada de proce_hu no se
*       repiten. Y LIPS se relee: ahora existen las subposiciones 9000xx que
*       el embalaje tiene que usar.
    gv_lotes_mod_hechos = abap_true.
    PERFORM refresca_lips02 USING is_cabecera-vbeln.
*}+@004

    "Sólo actualizar peso total, excluir posiciones y control de posiciones.
    REFRESH: lt_item_data, lt_item_control.

    CALL FUNCTION 'BAPI_INB_DELIVERY_CHANGE'
      EXPORTING
        header_data    = ls_header_data
        header_control = ls_header_control
        delivery       = is_cabecera-vbeln
      TABLES
        item_data      = lt_item_data       "refrescada.
        item_control   = lt_item_control    "refrescada.
*       item_serial_no = lt_item_serial
        extension2     = lt_extension2
        return         = lt_return.

    IF  lt_return IS INITIAL.
      PERFORM commit_wait.
    ELSE.
      "Error al modificar la entrega
      e_error = abap_true.
      PERFORM carga_errores TABLES lt_return
                                   it_result.

    ENDIF.


  ELSE.
    "Error al modificar la entrega
    e_error = abap_true.
    PERFORM carga_errores TABLES lt_return
                                 it_result.
  ENDIF.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form get_constantes
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*&      --> LV_PARAM
*&      --> LV_FIELD1
*&      --> LV_FIELD2
*&      --> LV_FIELD3
*&      --> LV_FIELD4
*&      --> LV_FIELD5
*&      --> LV_FIELD6
*&      --> LV_FIELD7
*&      --> LV_STATUS
*&      --> LV_PACKMT
*&      --> LV_MATOBJ
*&      --> LV_OBJCT1
*&      --> LV_SVSTEP
*&      --> LV_PACKM2
*&      --> LV_DLVRYT
*&      --> LV_PACKAT
*&      --> LV_PACKTY
*&      --> LV_CATEG
*&---------------------------------------------------------------------*
FORM get_constantes  USING i_param  TYPE zge_t_constantes-low "ztconstantes-valor_low
                          i_field1 TYPE zge_t_constantes-low "ztconstantes-valor_low
                          i_field2 TYPE zge_t_constantes-low "ztconstantes-valor_low
                          i_field3 TYPE zge_t_constantes-low "ztconstantes-valor_low
                          i_field4 TYPE zge_t_constantes-low "ztconstantes-valor_low
                          i_field5 TYPE zge_t_constantes-low "ztconstantes-valor_low
                          i_field6 TYPE zge_t_constantes-low "ztconstantes-valor_low
                          i_field7 TYPE zge_t_constantes-low "ztconstantes-valor_low
                          i_status TYPE zge_t_constantes-low "ztconstantes-valor_low
                          i_packmt TYPE zge_t_constantes-low "ztconstantes-valor_low
                          i_matobj TYPE zge_t_constantes-low "ztconstantes-valor_low
                          i_objct1 TYPE zge_t_constantes-low "ztconstantes-valor_low
                          i_svstep TYPE zge_t_constantes-low "ztconstantes-valor_low
                          i_packm2 TYPE zge_t_constantes-low "ztconstantes-valor_low
                          i_dlvryt TYPE likp-vbtyp  "ztconstantes-valor_low,
                          i_packat TYPE zge_t_constantes-low "ztconstantes-valor_low
                          i_packty TYPE zge_t_constantes-low "ztconstantes-valor_low
                          i_categ  TYPE zge_t_constantes-low. "ztconstantes-valor_low

  SELECT * INTO TABLE @DATA(lt_ztconstantes)
    FROM zge_t_constantes "ztconstantes
    WHERE modulo   EQ 'MM'
    AND   programa EQ 'SAPLZGF_CON_PORTAL'.
*  AND   campo    EQ 'PARAM'.

  LOOP AT lt_ztconstantes ASSIGNING FIELD-SYMBOL(<fs_ztcons>).
    CASE <fs_ztcons>-campo.
      WHEN 'PARAM'.
        i_param = <fs_ztcons>-low. "valor_low.
      WHEN 'FIELD1'.
        i_field1 = <fs_ztcons>-low. "valor_low.
      WHEN 'FIELD2'.
        i_field2 = <fs_ztcons>-low. "valor_low.
      WHEN 'FIELD3'.
        i_field3 = <fs_ztcons>-low. "valor_low.
      WHEN 'FIELD4'.
        i_field4 = <fs_ztcons>-low. "valor_low.
      WHEN 'FIELD5'.
        i_field5 = <fs_ztcons>-low. "valor_low.
      WHEN 'FIELD6'.
        i_field6 = <fs_ztcons>-low. "valor_low.
      WHEN 'FIELD7'.
        i_field7 = <fs_ztcons>-low. "valor_low.
      WHEN 'STATUS'.
        i_status = <fs_ztcons>-low. "valor_low.
      WHEN 'PACKMT'.
        i_packmt = <fs_ztcons>-low. "valor_low.
      WHEN 'MATOBJ'.
        i_matobj = <fs_ztcons>-low. "valor_low.
      WHEN 'OBJCT1'.
        i_objct1 = <fs_ztcons>-low. "valor_low.
      WHEN 'SVSTEP'.
        i_svstep = <fs_ztcons>-low. "valor_low.
      WHEN 'PACKM2'.
        i_packm2 = <fs_ztcons>-low. "valor_low.
      WHEN 'DLVRYT'.
        i_dlvryt = <fs_ztcons>-low. "valor_low.
      WHEN 'PACKAT'.
        i_packat = <fs_ztcons>-low. "valor_low.
      WHEN 'PACKTY'.
        i_packty = <fs_ztcons>-low. "valor_low.
      WHEN 'CONF_CATEG'.
        i_categ  = <fs_ztcons>-low. "valor_low.
    ENDCASE.

  ENDLOOP.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form act_entrega_nohu
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*&      --> LT_DETALLE
*&      --> IT_RESULT
*&      --> IS_CABECERA
*&      <-- E_ERROR
*&---------------------------------------------------------------------*
FORM act_entrega_nohu TABLES it_detalle STRUCTURE zbvmm_st_modificar_entrega_det
                             it_result  STRUCTURE zbvmm_st_result
                      USING is_cabecera TYPE zbvmm_st_modificar_entrega
                      CHANGING e_error TYPE abap_bool
                            .
  CLEAR: gt_entrenohu.

  "Borrar todos embalajes.
  DELETE FROM  zbvmm_entrenohu WHERE vbeln EQ is_cabecera-vbeln.
  COMMIT WORK.

  LOOP AT it_detalle ASSIGNING FIELD-SYMBOL(<fs_detalle>).
    APPEND INITIAL LINE TO gt_entrenohu ASSIGNING FIELD-SYMBOL(<fs_nohu>).
    MOVE-CORRESPONDING <fs_detalle> TO <fs_nohu>.
    "detalle de la entrega.
    READ TABLE gt_lips02 ASSIGNING FIELD-SYMBOL(<fs_lips>)
                                   WITH KEY vgbel = <fs_detalle>-ebeln
                                            vgpos = <fs_detalle>-ebelp.
    IF sy-subrc EQ 0.
      "Entrega, posición y fecha de creación.
      <fs_nohu>-vbeln = <fs_lips>-vbeln.
      <fs_nohu>-posnr = <fs_lips>-posnr.
      <fs_nohu>-lfdat = sy-datum.
      <fs_nohu>-lfuhr = sy-uzeit.
    ENDIF.
  ENDLOOP.

  IF gt_entrenohu IS NOT INITIAL.
    "Actualiza tabla de entrega sin HU.
    MODIFY zbvmm_entrenohu FROM TABLE gt_entrenohu.
    IF sy-subrc EQ 0.
      COMMIT WORK.

    ENDIF.

  ENDIF.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form f_act_zbvmmemb_comp
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*&      --> LTD_ENTR_DET2
*&      --> <FS_ENTR_CAB>
*&---------------------------------------------------------------------*
FORM f_act_zbvmmemb_comp  TABLES ltd_entr_det STRUCTURE zbvmm_st_modificar_entrega_det
                          USING ls_entr_cab TYPE zbvmm_st_modificar_entrega.

  TYPES: BEGIN OF gty_hucomple,
           vhilm_ku TYPE vhilm_ku,
           exidv    TYPE exidv,
         END OF gty_hucomple,
*{INSERT @JGRS
         BEGIN OF gty_zzlug_ent,
           ebeln     TYPE ekpo-ebeln,
           ebelp     TYPE ekpo-ebelp,
           inco1     TYPE ekpo-inco1, "+@001
           zzlug_ent TYPE ekpo-zzlug_ent,
         END OF gty_zzlug_ent.
  DATA:lt_zzlug_ent TYPE STANDARD TABLE OF gty_zzlug_ent.
  FIELD-SYMBOLS:<fs_zzlug_ent> LIKE LINE OF lt_zzlug_ent.
*}INSERT @JGRS
  DATA: lt_hu_fict TYPE STANDARD TABLE OF gty_hucomple,
        lv_corre   TYPE i.

*{INSERT @JGRS
*  SELECT ebeln ebelp zzlug_ent "-@001
  SELECT ebeln ebelp inco1 zzlug_ent "+@001
  INTO TABLE lt_zzlug_ent
  FROM ekpo
  FOR ALL ENTRIES IN ltd_entr_det
  WHERE ebeln EQ ltd_entr_det-ebeln
    AND ebelp EQ ltd_entr_det-ebelp+1(5).
  IF sy-subrc EQ '0'.
  ENDIF.
*}INSERT @JGRS

  REFRESH: gt_entrenohu.
  "Correlativo para embalaje complementario.
  IF g_marc_nohu EQ abap_true.

    "Ordena embalajes principales.
    LOOP AT ltd_entr_det ASSIGNING FIELD-SYMBOL(<fs_entr>).
      APPEND INITIAL LINE TO lt_hu_fict ASSIGNING FIELD-SYMBOL(<fs_hu_fict>).
      MOVE-CORRESPONDING <fs_entr> TO <fs_hu_fict>.
    ENDLOOP.

    SORT lt_hu_fict BY vhilm_ku.
    DELETE ADJACENT DUPLICATES FROM lt_hu_fict COMPARING vhilm_ku.

    LOOP AT lt_hu_fict ASSIGNING <fs_hu_fict>.
      PERFORM get_hucomp_correlativo CHANGING lv_corre.
      <fs_hu_fict>-exidv = lv_corre.
    ENDLOOP.

  ENDIF.

  LOOP AT ltd_entr_det ASSIGNING <fs_entr>.
    APPEND INITIAL LINE TO gt_entrenohu ASSIGNING FIELD-SYMBOL(<fs_nohu>).
    MOVE-CORRESPONDING <fs_entr> TO <fs_nohu>.
    READ TABLE gt_lips02 ASSIGNING FIELD-SYMBOL(<fs_lips01>) WITH KEY vgbel  = <fs_entr>-ebeln  """""""
                                                                       vgpos = <fs_entr>-ebelp.
    IF sy-subrc = 0.
      <fs_nohu>-vbeln = <fs_lips01>-vbeln.
      <fs_nohu>-posnr = <fs_lips01>-posnr.
      <fs_nohu>-lfdat = sy-datum.
      <fs_nohu>-lfuhr = sy-uzeit.
    ENDIF."""""""""""""""
    "Asigna embalaje fict.
    READ TABLE lt_hu_fict ASSIGNING <fs_hu_fict> WITH KEY vhilm_ku = <fs_entr>-vhilm_ku.
    IF sy-subrc EQ 0.
      <fs_nohu>-exidv = <fs_hu_fict>-exidv.
      PERFORM agrega_ceros CHANGING <fs_nohu>-exidv.
*      CONDENSE <fs_nohu>-exidv NO-GAPS.
    ENDIF.

    "Verificar embalajes complementarios.
    LOOP AT gt_emb_compl_mod ASSIGNING FIELD-SYMBOL(<fs_emb_compl_mod>)
                                   WHERE vhilm_ku_p EQ <fs_entr>-vhilm_ku.

      APPEND INITIAL LINE TO gt_embcomp ASSIGNING FIELD-SYMBOL(<fs_embcomp>).
      MOVE-CORRESPONDING <fs_emb_compl_mod> TO <fs_embcomp>.
      READ TABLE gt_lips02 ASSIGNING FIELD-SYMBOL(<fs_lips02>) WITH KEY vgbel  = <fs_entr>-ebeln
                                                                         vgpos = <fs_entr>-ebelp.
      IF sy-subrc = 0.
        <fs_embcomp>-vbeln = <fs_lips02>-vbeln.
***        <fs_embcomp>-posnr = <fs_lips02>-posnr. "Comentado porque el campo ya no existe en la tabla
        <fs_nohu>-vbeln = <fs_lips02>-vbeln.
        <fs_nohu>-posnr = <fs_lips02>-posnr.
        <fs_nohu>-lfdat = sy-datum.
        <fs_nohu>-lfuhr = sy-uzeit.
      ENDIF.
***      <fs_embcomp>-ebeln = <fs_entr>-ebeln."Comentado porque el campo ya no existe en la tabla
***      <fs_embcomp>-ebelp = <fs_entr>-ebelp. "Comentado porque el campo ya no existe en la tabla
      <fs_embcomp>-vhilm_ku = <fs_emb_compl_mod>-vhilm_ku_p.
      <fs_embcomp>-vhilm_ku_sub = <fs_emb_compl_mod>-vhilm_ku.  "Emb. complemantario.
      <fs_embcomp>-lfdat = sy-datum.
      <fs_embcomp>-lfuhr = sy-uzeit.
      <fs_embcomp>-exidv = <fs_nohu>-exidv.

      IF g_marc_nohu EQ abap_false.

        READ TABLE gt_hucomple ASSIGNING <fs_hu_fict> WITH KEY vhilm_ku = <fs_entr>-vhilm_ku.
        IF sy-subrc EQ 0.
          <fs_embcomp>-exidv = <fs_hu_fict>-exidv.
          PERFORM agrega_ceros CHANGING <fs_embcomp>-exidv.
*          PERFORM quitar_ceros CHANGING <fs_embcomp>-exidv.
*          CONDENSE  <fs_embcomp>-exidv NO-GAPS.
        ENDIF.
      ENDIF.
*{INSERT @JGRS
      READ TABLE gt_likp ASSIGNING FIELD-SYMBOL(<fs_g_likp>) WITH KEY vbeln = <fs_lips02>-vbeln.
      IF sy-subrc EQ '0'.
        MOVE <fs_g_likp>-zzlfstk TO <fs_embcomp>-zzlfstk.
      ENDIF.
      READ TABLE lt_zzlug_ent ASSIGNING <fs_zzlug_ent> WITH KEY ebeln = <fs_entr>-ebeln
                                                                ebelp = <fs_entr>-ebelp+1(5).
      IF sy-subrc EQ 0.
*        <fs_embcomp>-zzlug_ent = <fs_zzlug_ent>-zzlug_ent. "-@001
        <fs_embcomp>-zzlug_ent = <fs_zzlug_ent>-inco1. "+@001
      ENDIF.
*}INSERT @JGRS
    ENDLOOP.
  ENDLOOP.

  "Actualiza tabla de entrega sin HU.
  IF gt_entrenohu IS NOT INITIAL AND g_marc_nohu EQ abap_true.
    "Borrar todos embalajes.
    DELETE FROM  zbvmm_entrenohu WHERE vbeln EQ ls_entr_cab-vbeln.
    COMMIT WORK.
    MODIFY zbvmm_entrenohu FROM TABLE gt_entrenohu.
    IF sy-subrc EQ 0.
      COMMIT WORK.
    ENDIF.
  ENDIF.

  "Actualiza tabla de embalajes complementarios.
  IF gt_embcomp IS NOT INITIAL.
    "Borrar todos embalajes.
    DELETE FROM zbvmm_emb_comp WHERE vbeln EQ ls_entr_cab-vbeln.
    COMMIT WORK.

    MODIFY zbvmm_emb_comp FROM TABLE gt_embcomp.
    IF sy-subrc EQ 0.
      COMMIT WORK.
    ENDIF.
  ENDIF.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form proce_hu
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*&      --> LTD_ENTR_DET
*&      --> T_RESULT
*&      --> <FS_ENTR_CAB>
*&      <-- L_ERROR
*&---------------------------------------------------------------------*
FORM proce_hu  TABLES it_detalle STRUCTURE zbvmm_st_modificar_entrega_det
                      it_result  STRUCTURE zbvmm_st_result
               USING is_cabecera TYPE zbvmm_st_modificar_entrega
                CHANGING e_error TYPE abap_bool.

  DATA: lv_message        TYPE bapi_msg,
        lv_type           TYPE bapi_mtype,
        lw_hukey          TYPE bapihukey-hu_exid,
        lw_hu_id          TYPE rlmob-clenum,
        ls_header_data    TYPE bapiibdlvhdrchg,
        ls_header_control TYPE bapiibdlvhdrctrlchg,
        ls_headerproposal TYPE bapihuhdrproposal,
        ls_huheader       TYPE bapihuheader,
        ls_ref_object     TYPE hum_object,
        ls_hu_header_main TYPE huhdr_proposal,
        ls_mm_data        TYPE hum_plant_stloc,
        ls_item_proposal  TYPE huitm_proposal,
        lt_return         TYPE STANDARD TABLE OF bapiret2,
        lw_btgew          TYPE likp-btgew,    "Peso total
        lw_brgew          TYPE vekp-brgew.     "Peso por bulto

*{+@001
  TYPES: BEGIN OF lty_pack_mat,
           pack_mat TYPE vhilm18,
           vegr2    TYPE vegr2,
         END OF lty_pack_mat.
  DATA lt_pack_mat    TYPE STANDARD TABLE OF lty_pack_mat.

*{+@004 Reparto de lotes entre bultos
  TYPES: BEGIN OF lty_lot_cons,
           posnr TYPE lips-posnr,
           usado TYPE lfimg,
         END OF lty_lot_cons,
         BEGIN OF lty_lips_bulto,
           posnr    TYPE lips-posnr,
           vhilm_ku TYPE vhilm_ku,
         END OF lty_lips_bulto,
         BEGIN OF lty_emb,
           posnr TYPE lips-posnr,
           cant  TYPE lfimg,
         END OF lty_emb,
         BEGIN OF lty_cons_bul,
           posnr    TYPE lips-posnr,
           vhilm_ku TYPE vhilm_ku,
           usado    TYPE lfimg,
         END OF lty_cons_bul.
  DATA: lt_lot_cons   TYPE HASHED TABLE OF lty_lot_cons WITH UNIQUE KEY posnr,
        lt_lips_bulto TYPE HASHED TABLE OF lty_lips_bulto WITH UNIQUE KEY posnr,
        lt_cons_bul   TYPE HASHED TABLE OF lty_cons_bul WITH UNIQUE KEY posnr vhilm_ku,
        lv_asig       TYPE lfimg,       "asignado al bulto en esa línea
        lv_es_padre   TYPE abap_bool,
        lt_emb        TYPE STANDARD TABLE OF lty_emb,
        lv_pend       TYPE lfimg,       "lo que le falta embalar al bulto
        lv_disp       TYPE lfimg,       "lo que queda libre en la línea
        lv_cant       TYPE lfimg.       "lo que se embala en esta pasada
*}+@004

  SELECT low, high INTO TABLE @DATA(lt_ztconstantes)
  FROM zge_t_constantes
  WHERE modulo   EQ 'MM'
  AND   programa EQ 'SAPLZGF_CON_PORTAL'
  AND   campo    EQ 'PACKMT'.

  LOOP AT lt_ztconstantes ASSIGNING FIELD-SYMBOL(<fs_ztcons>).
    APPEND INITIAL LINE TO lt_pack_mat ASSIGNING FIELD-SYMBOL(<fs_pack_mat>).
    <fs_pack_mat>-vegr2 = <fs_ztcons>-high.
    <fs_pack_mat>-pack_mat = <fs_ztcons>-low.
  ENDLOOP.
*}+@001
  "Datos de bultos
  SELECT vhilm_ku, vbeln, posnr
    FROM vekp AS v1
    INNER JOIN vepo AS v2
    ON v2~venum EQ v1~venum
    INTO TABLE @DATA(lt_vepo)
    FOR ALL ENTRIES IN @gt_lips02
    WHERE vbeln EQ @gt_lips02-vbeln
    AND   posnr EQ @gt_lips02-posnr.

  IF sy-subrc EQ 0.
    DATA(lt_vepo_bultos) = lt_vepo[].
    SORT lt_vepo_bultos BY vhilm_ku.
    DELETE ADJACENT DUPLICATES FROM lt_vepo_bultos COMPARING vhilm_ku.

    CLEAR: lv_message.

    "Se eliminan l98*os embalajes de la entrega.
    LOOP AT lt_vepo_bultos ASSIGNING FIELD-SYMBOL(<fs_vepo_bultos>).

      CALL FUNCTION 'ZBVMM_OC_ELIMINAR_EMBALAJE'
        EXPORTING
          i_vbeln   = <fs_vepo_bultos>-vbeln
          i_bulto   = <fs_vepo_bultos>-vhilm_ku
        IMPORTING
          e_message = lv_message
          e_type    = lv_type.
      "Error devuelto de la función anterior.
      IF lv_type EQ 'E'.
        APPEND INITIAL LINE TO it_result ASSIGNING FIELD-SYMBOL(<fs_result>).
        <fs_result>-msg = lv_message.
        <fs_result>-type = lv_type.
        <fs_result>-codigo = '999'.
        e_error = abap_true.                       "+@004 antes se ignoraba
      ENDIF.

    ENDLOOP.
  ENDIF.            "+@004 el IF envuelve solo el borrado de HU: sin HU previos
  "                 "      tambien hay que modificar la entrega y embalar.
  CHECK e_error EQ abap_false.                   "+@004

    "Modificar entrega.
    PERFORM modif_entrega TABLES it_detalle
                                 it_result
                          USING is_cabecera
                          CHANGING e_error.

    CHECK e_error EQ abap_false. "Continúa si no hay error.

    DATA(lt_entr_det_aux) = it_detalle[].
    SORT lt_entr_det_aux BY vhilm_ku.                                  "+@004
    "-@004 sin SORT, un bulto con líneas no contiguas se creaba dos veces.
    DELETE ADJACENT DUPLICATES FROM lt_entr_det_aux COMPARING vhilm_ku. "Sólo quedan bultos diferentes.

*{+@004 Líneas de LIPS que tienen bulto asignado por el portal (gt_lote_bulto:
*       un lote puede estar repartido en varios bultos, con cantidad por bulto).
    CLEAR: lt_lot_cons, lt_lips_bulto, lt_cons_bul.
    LOOP AT gt_lote_bulto ASSIGNING FIELD-SYMBOL(<fs_lb0>).
      INSERT VALUE #( posnr = <fs_lb0>-posnr ) INTO TABLE lt_lips_bulto.
    ENDLOOP.
*}+@004

    LOOP AT lt_entr_det_aux ASSIGNING FIELD-SYMBOL(<fs_entr_aux>).
      IF e_error EQ abap_true.          "+@004 tras un error no se crean más HU
        EXIT.
      ENDIF.

      READ TABLE gt_ekpo02 ASSIGNING FIELD-SYMBOL(<fs_ekpo>) WITH KEY ebeln = <fs_entr_aux>-ebeln  ebelp = <fs_entr_aux>-ebelp.
      IF sy-subrc EQ 0 .

        READ TABLE gt_t001l02 ASSIGNING FIELD-SYMBOL(<fs_t001l>) WITH KEY werks = <fs_ekpo>-werks lgort = <fs_ekpo>-lgort.
        IF sy-subrc EQ 0.
*          IF <fs_t001l>-xhupf NE space. "-@001
          IF <fs_t001l>-lgort IN gr_lgort_tr.  "+@001
            CLEAR: ls_headerproposal.
            ls_headerproposal-hu_status_init    = 'B'.
*            ls_headerproposal-pack_mat          = 'EMBALAJE'. "-@001
*{+@001
            READ TABLE lt_pack_mat ASSIGNING <fs_pack_mat>
                                    WITH KEY vegr2 = <fs_entr_aux>-vegr2.
            IF sy-subrc EQ 0.
              ls_headerproposal-pack_mat = <fs_pack_mat>-pack_mat.
            ENDIF.
*}+@001

            ls_headerproposal-plant             = <fs_ekpo>-werks.
            ls_headerproposal-stge_loc          = <fs_ekpo>-lgort.
            ls_headerproposal-hu_grp2           = <fs_entr_aux>-vegr2.
            ls_headerproposal-content           = <fs_entr_aux>-inhalt.
            ls_headerproposal-pack_mat_customer = <fs_entr_aux>-vhilm_ku.

            REFRESH lt_return.
            CALL FUNCTION 'BAPI_HU_CREATE'
              EXPORTING
                headerproposal = ls_headerproposal
              IMPORTING
                huheader       = ls_huheader
                hukey          = lw_hukey
              TABLES
                return         = lt_return.

            IF lt_return IS INITIAL.

              PERFORM commit_wait.

              ls_huheader-pack_mat_object  = '03'.
              ls_huheader-pack_mat_obj_key = is_cabecera-vbeln.
              ls_huheader-total_wght        = <fs_entr_aux>-brgew.
              ls_huheader-lenght           = <fs_entr_aux>-laeng.
              ls_huheader-width	            = <fs_entr_aux>-breit.
              ls_huheader-height            = <fs_entr_aux>-hoehe.
              lw_btgew = lw_btgew + <fs_entr_aux>-brgew.  "Peso total

              CALL FUNCTION 'BAPI_HU_CHANGE_HEADER'
                EXPORTING
                  hukey     = lw_hukey
                  huchanged = ls_huheader
                IMPORTING
                  huheader  = ls_huheader
                TABLES
                  return    = lt_return.

              IF lt_return IS INITIAL.
                PERFORM commit_wait.

                lw_hu_id = is_cabecera-vbeln.
                CLEAR ls_ref_object.
                ls_ref_object-object = '7'.
                ls_ref_object-objkey = is_cabecera-vbeln.
                CLEAR ls_hu_header_main.
                ls_hu_header_main-exidv = ls_huheader-hu_exid.
                ls_hu_header_main-vhilm = ls_huheader-pack_mat.

                CLEAR ls_mm_data.
                ls_mm_data-plant    = <fs_ekpo>-werks.
                ls_mm_data-stge_loc = <fs_ekpo>-lgort.

                LOOP AT it_detalle ASSIGNING FIELD-SYMBOL(<fs_detalle>)
                                   WHERE vhilm_ku = <fs_entr_aux>-vhilm_ku
                                     AND matnr IS NOT INITIAL.        "+@004 sin complementarios

*                  READ TABLE gt_lips02 ASSIGNING FIELD-SYMBOL(<fs_lips>)   "-@004
*                                       WITH  KEY vgbel = <fs_detalle>-ebeln
*                                                 vgpos = <fs_detalle>-ebelp.
*{+@004 Antes se embalaba todo en la primera línea de LIPS de la posición.
*  Con lotes esa es la posición padre (sin lote) y las subposiciones 9000xx
*  quedaban sin embalar. Ahora el bulto toma lo que declara, de las líneas
*  que correspondan:
*    Pasada 1: lotes que el portal asignó a este bulto (VHILMLT).
*    Pasada 2: lotes sin bulto asignado, repartidos por cantidad.
*  Si la posición está partida, la padre no lleva cantidad propia.
                  CLEAR lt_emb.
                  lv_pend = <fs_detalle>-menge.
                  DO 2 TIMES.
                    DATA(lv_pasada) = sy-index.
                    LOOP AT gt_lips02 ASSIGNING FIELD-SYMBOL(<fs_lips>)
                         WHERE vgbel EQ <fs_detalle>-ebeln
                           AND vgpos EQ <fs_detalle>-ebelp.
                      IF lv_pend LE 0.
                        EXIT.
                      ENDIF.
                      "Padre de una partición (tiene subposiciones por UECHA):
                      "su cantidad está en las subposiciones, no se embala.
                      lv_es_padre = xsdbool( line_exists( gt_lips02[ uecha = <fs_lips>-posnr ] ) ).
                      IF lv_es_padre EQ abap_true.
                        CONTINUE.
                      ENDIF.
                      READ TABLE lt_lot_cons ASSIGNING FIELD-SYMBOL(<fs_cons>)
                           WITH TABLE KEY posnr = <fs_lips>-posnr.
                      IF sy-subrc NE 0.
                        INSERT VALUE #( posnr = <fs_lips>-posnr ) INTO TABLE lt_lot_cons
                               ASSIGNING <fs_cons>.
                      ENDIF.
                      lv_disp = <fs_lips>-lfimg - <fs_cons>-usado.
                      IF lv_disp LE 0.
                        CONTINUE.            "agotada por un bulto anterior
                      ENDIF.
                      IF lv_pasada EQ 1.
                        "Solo lo que el portal asignó de esta línea a este bulto.
                        CLEAR lv_asig.
                        LOOP AT gt_lote_bulto ASSIGNING FIELD-SYMBOL(<fs_lbu>)
                             WHERE posnr    EQ <fs_lips>-posnr
                               AND vhilm_ku EQ <fs_detalle>-vhilm_ku.
                          lv_asig = lv_asig + <fs_lbu>-cant.
                        ENDLOOP.
                        READ TABLE lt_cons_bul ASSIGNING FIELD-SYMBOL(<fs_cb>)
                             WITH TABLE KEY posnr = <fs_lips>-posnr vhilm_ku = <fs_detalle>-vhilm_ku.
                        IF sy-subrc NE 0.
                          INSERT VALUE #( posnr = <fs_lips>-posnr vhilm_ku = <fs_detalle>-vhilm_ku )
                                 INTO TABLE lt_cons_bul ASSIGNING <fs_cb>.
                        ENDIF.
                        lv_asig = lv_asig - <fs_cb>-usado.
                        IF lv_asig LE 0.
                          CONTINUE.          "sin asignación (restante) a este bulto
                        ENDIF.
                        lv_cant     = nmin( val1 = lv_disp val2 = nmin( val1 = lv_pend val2 = lv_asig ) ).
                        <fs_cb>-usado = <fs_cb>-usado + lv_cant.
                      ELSE.
                        "Pasada 2: solo líneas sin ningún bulto asignado.
                        IF line_exists( lt_lips_bulto[ posnr = <fs_lips>-posnr ] ).
                          CONTINUE.
                        ENDIF.
                        lv_cant = nmin( val1 = lv_disp val2 = lv_pend ).
                      ENDIF.
                      <fs_cons>-usado = <fs_cons>-usado + lv_cant.
                      lv_pend         = lv_pend - lv_cant.
                      APPEND VALUE #( posnr = <fs_lips>-posnr
                                      cant  = lv_cant ) TO lt_emb.
                    ENDLOOP.
                  ENDDO.

                  "El bulto declara más de lo que hay en la entrega para la posición.
                  IF lv_pend GT 0.
                    APPEND INITIAL LINE TO it_result ASSIGNING <fs_result>.
                    <fs_result>-codigo = '999'.
                    <fs_result>-type   = 'E'.
                    <fs_result>-msg    = |Bulto { <fs_detalle>-vhilm_ku }: faltan { lv_pend NUMBER = USER } | &&
                                         |de la pos. { CONV i( <fs_detalle>-ebelp ) } del pedido { <fs_detalle>-ebeln }|.
                    e_error = abap_true.
                    EXIT.
                  ENDIF.

                  LOOP AT lt_emb ASSIGNING FIELD-SYMBOL(<fs_emb>).
                    READ TABLE gt_lips02 ASSIGNING <fs_lips> WITH KEY posnr = <fs_emb>-posnr.
*}+@004
                  IF sy-subrc EQ 0.

                    CLEAR ls_item_proposal.
                    ls_item_proposal-exidv    = ls_huheader-hu_exid.
                    ls_item_proposal-velin    = '1'.
*                    ls_item_proposal-quantity = <fs_detalle>-menge.   "-@004
                    ls_item_proposal-quantity = <fs_emb>-cant.          "+@004
                    ls_item_proposal-meins    = <fs_detalle>-meins.
                    ls_item_proposal-matnr    = <fs_detalle>-matnr.
                    ls_item_proposal-charg    = <fs_lips>-charg.
                    ls_item_proposal-werks    = <fs_lips>-werks.
                    ls_item_proposal-lgort    = <fs_lips>-lgort.
                    ls_item_proposal-belnr    = is_cabecera-vbeln.
                    ls_item_proposal-posnr    = <fs_lips>-posnr.

                    CALL FUNCTION 'PROCESS_HU_INBOUND_DLVRY'
                      EXPORTING
                        i_hu_id               = lw_hu_id
                        i_new_hu              = space
                        i_update_db           = 'X'
                        i_reference_object    = ls_ref_object
                        i_mm_data             = ls_mm_data
                        i_hu_header_main      = ls_hu_header_main
                        i_save_step           = 'ITEM'
                        i_pack_activity       = 'MAT'
                        i_delivery_type       = '7'
                        i_packing_activity    = 'PACK'
                        i_pack_type           = 'MAT'
                        is_item_proposal      = ls_item_proposal
                      EXCEPTIONS
                        input_missing         = 1
                        not_possible          = 2
                        header_error          = 3
                        item_error            = 4
                        serial_nr_error       = 5
                        fatal_error           = 6
                        operation_failed      = 7
                        delivery_update_error = 8
                        OTHERS                = 9.

                    IF sy-subrc EQ 0.
*{-@004 Peso, complementario y mensaje: una vez por línea de detalle, tras
*       embalar todas sus líneas (abajo), no una vez por lote embalado.
*                      "@DL{  "Actualiza peso de bulto
*                      PERFORM act_venum USING  ls_huheader-hu_exid
*                                               <fs_detalle>-brgew.
*                      "@DL}
*
*                      "@MP{
*                      IF gt_emb_compl_mod IS NOT INITIAL.
*                        APPEND INITIAL LINE TO gt_hucomple ASSIGNING FIELD-SYMBOL(<fs_hucomple>).
*                        <fs_hucomple>-exidv = ls_huheader-hu_exid.
*                        <fs_hucomple>-vhilm_ku = <fs_entr_aux>-vhilm_ku.
*                      ENDIF.
*                      "@MP}
*}-@004

                      PERFORM commit_wait.

*                      APPEND INITIAL LINE TO it_result ASSIGNING <fs_result>.   "-@004
*                      <fs_result>-codigo = '000'.
*                      CONCATENATE TEXT-044 is_cabecera-vbeln INTO <fs_result>-msg SEPARATED BY space.

                    ELSE.  "Error de embalaje.
                      MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
                      INTO DATA(mtext)
                      WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.

                      APPEND INITIAL LINE TO it_result ASSIGNING <fs_result>.
                      <fs_result>-codigo = '999'.
                      <fs_result>-msg = mtext.
                      <fs_result>-type = 'E'.
                      e_error = abap_true.
                      EXIT.                                    "+@004

                    ENDIF.
                  ENDIF.    "Implementar error para no vgbel de lips
                  ENDLOOP.  "lt_emb                            "+@004
                  IF e_error EQ abap_true.                     "+@004
                    EXIT.
                  ENDIF.
*{+@004 (movido desde arriba)
                  "@DL{  "Actualiza peso de bulto
                  PERFORM act_venum USING  ls_huheader-hu_exid
                                           <fs_detalle>-brgew.
                  "@DL}
                  "@MP{
                  IF gt_emb_compl_mod IS NOT INITIAL.
                    APPEND INITIAL LINE TO gt_hucomple ASSIGNING FIELD-SYMBOL(<fs_hucomple>).
                    <fs_hucomple>-exidv = ls_huheader-hu_exid.
                    <fs_hucomple>-vhilm_ku = <fs_entr_aux>-vhilm_ku.
                  ENDIF.
                  "@MP}
                  APPEND INITIAL LINE TO it_result ASSIGNING <fs_result>.
                  <fs_result>-codigo = '000'.
                  CONCATENATE TEXT-044 is_cabecera-vbeln INTO <fs_result>-msg SEPARATED BY space.
*}+@004
                ENDLOOP.

              ELSE.  "Error al modificar cab-hu
                e_error = abap_true.
                PERFORM carga_errores TABLES lt_return
                                             it_result.
              ENDIF.

            ELSE.  "Error al crear hu
              e_error = abap_true.
              PERFORM carga_errores TABLES lt_return
                                           it_result.

            ENDIF.

          ENDIF.
        ENDIF.

      ENDIF.

    ENDLOOP.

*{+@004 Cantidad de la entrega que ningún bulto declaró: quedaría sin embalar
*       y la entrada de mercancía por HU no se podría contabilizar.
    IF e_error EQ abap_false.
      LOOP AT gt_lips02 ASSIGNING <fs_lips>.
        READ TABLE it_detalle TRANSPORTING NO FIELDS
             WITH KEY ebeln = <fs_lips>-vgbel
                      ebelp = <fs_lips>-vgpos.
        CHECK sy-subrc EQ 0.
        "Padre de una partición (UECHA): su cantidad está en las subposiciones.
        CHECK NOT line_exists( gt_lips02[ uecha = <fs_lips>-posnr ] ).
        READ TABLE lt_lot_cons ASSIGNING <fs_cons>
             WITH TABLE KEY posnr = <fs_lips>-posnr.
        IF sy-subrc NE 0 OR <fs_cons>-usado LT <fs_lips>-lfimg.
          APPEND INITIAL LINE TO it_result ASSIGNING <fs_result>.
          <fs_result>-codigo = '999'.
          <fs_result>-type   = 'E'.
          <fs_result>-msg    = |Pos. { CONV i( <fs_lips>-vgpos ) } del pedido { <fs_lips>-vgbel } | &&
                               |(lote { <fs_lips>-charg }): quedó cantidad sin asignar a un bulto|.
          e_error = abap_true.
        ENDIF.
      ENDLOOP.
    ENDIF.
    CHECK e_error EQ abap_false.
*}+@004

    "Modificar entrega. - Nuevamente
    PERFORM modif_entrega TABLES it_detalle
                                 it_result
                          USING is_cabecera
                          CHANGING e_error.

*  ENDIF.   "-@004 el IF de los HU previos ya se cerró tras el borrado
ENDFORM.
*&---------------------------------------------------------------------*
*& Form act_entrega_modif
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*&      --> T_RESULT
*&      --> <FS_ENTR_CAB>
*&      <-- L_ERROR
*&---------------------------------------------------------------------*
FORM act_entrega_modif  TABLES it_result  STRUCTURE zbvmm_st_result
                        USING is_cabecera TYPE zbvmm_st_modificar_entrega
                         CHANGING e_error TYPE abap_bool
                            .

  DATA: lt_entrega_re TYPE STANDARD TABLE OF zbvmm_entrega_re,
        lt_datos      TYPE STANDARD TABLE OF zbvmm_st_registro_ee,
        lv_zul_aufl   TYPE zbvmm_entrega_re-zul_aufl.

  "Datos de entrega-cita.
  SELECT zcita zvbeln zvgpos zplaca zplaca2 zplaca3 zplaca4 zdni zdni2
         zdni3 zdni4 zdireccion zzlfstk zcita_np zcorreo_re_pl ztelefono
     INTO CORRESPONDING FIELDS OF TABLE lt_entrega_re FROM zbvmm_entrega_re
     WHERE zvbeln EQ is_cabecera-vbeln.

  IF sy-subrc EQ 0.
    lv_zul_aufl = '1'.

    LOOP AT lt_entrega_re ASSIGNING FIELD-SYMBOL(<fs_entrega>).

      APPEND INITIAL LINE TO lt_datos ASSIGNING FIELD-SYMBOL(<fs_datos>).
      MOVE-CORRESPONDING <fs_entrega> TO <fs_datos>.
      <fs_datos>-zndni = <fs_entrega>-zdni.
      <fs_datos>-zndni2 = <fs_entrega>-zdni2.
      <fs_datos>-zndni3 = <fs_entrega>-zdni3.
      <fs_datos>-zndni4 = <fs_entrega>-zdni4.

      UPDATE zbvmm_entrega_re SET zul_aufl =  lv_zul_aufl  WHERE zvbeln EQ <fs_entrega>-zvbeln
                                                             AND zvgpos EQ <fs_entrega>-zvgpos.
      IF sy-subrc EQ 0.
        PERFORM commit_wait.
      ENDIF.

    ENDLOOP.

    "Marcar registros viejos.


    IF lt_entrega_re[] IS NOT INITIAL .
      "Actualiza tabla principal.
      CALL FUNCTION 'ZBVMM_OC_REG_ENTREGAS'
        TABLES
          i_datos_ree = lt_datos
          i_resultado = it_result.

      READ TABLE it_result WITH KEY type = 'E'.
      IF sy-subrc EQ 0.
        CLEAR:  lv_zul_aufl.

        UPDATE zbvmm_entrega_re SET zul_aufl = lv_zul_aufl WHERE zvbeln EQ <fs_entrega>-zvbeln
                                                             AND zvgpos EQ <fs_entrega>-zvgpos.

      ELSE.
        DELETE FROM zbvmm_entrega_re WHERE zvbeln EQ is_cabecera-vbeln
                                       AND zul_aufl EQ lv_zul_aufl.
        IF sy-subrc EQ 0.
          PERFORM commit_wait.

        ENDIF.

      ENDIF.

    ENDIF.

  ENDIF.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form verif_ped_sust
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*&      --> LT_PED_SUST
*&---------------------------------------------------------------------*
FORM verif_ped_sust.

  DATA: lv_vgbel      TYPE lips-vgbel,
        lv_vgpos      TYPE lips-vgpos,
        lwa_header    TYPE bapiibdlvhdrchg,
        lwa_header_c  TYPE bapiibdlvhdrctrlchg,
        lv_doc_nr_ent TYPE msr_doc_nr,
        lt_return     TYPE STANDARD TABLE OF bapiret2.

  SELECT doc_nr, doc_item
    FROM msr_d_executed
    INTO TABLE @DATA(lt_ped_sust)
    FOR ALL ENTRIES IN @lt_executed
    WHERE doc_type EQ @lv_doc_type "'14'
      AND doc_nr   EQ @lt_executed-doc_nr
      AND doc_item EQ @lt_executed-doc_item.

  LOOP AT lt_ped_sust ASSIGNING FIELD-SYMBOL(<fs_ped_sust>).
    CLEAR: lv_vgbel, lv_vgpos, lwa_header, lwa_header_c.
    lv_vgbel = <fs_ped_sust>-doc_nr.
    lv_vgpos = <fs_ped_sust>-doc_item.

    SELECT SINGLE vbeln FROM lips
      INTO @DATA(lv_vbeln)
      WHERE vgbel = @lv_vgbel
        AND vgpos = @lv_vgpos.
    IF sy-subrc EQ 0.
      CLEAR lv_doc_nr_ent.
      lv_doc_nr_ent = lv_vbeln.

      SELECT SINGLE created_lfe
        FROM msr_d_executed
        INTO @DATA(lv_cr_aut)
       WHERE doc_nr EQ @lv_doc_nr_ent.

      CHECK lv_cr_aut IS NOT INITIAL.

      lwa_header-deliv_numb   = lv_vbeln.
      lwa_header_c-deliv_numb = lv_vbeln.
      lwa_header_c-dlv_del    = abap_true.

      CALL FUNCTION 'BAPI_INB_DELIVERY_CHANGE'
        EXPORTING
          header_data    = lwa_header
          header_control = lwa_header_c
          delivery       = lv_vbeln
        TABLES
          return         = lt_return.

      IF sy-subrc EQ 0.
        CALL FUNCTION 'BAPI_TRANSACTION_COMMIT'
          EXPORTING
            wait = 'X'.
      ENDIF.
    ENDIF.
  ENDLOOP.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form f_act_entre_reparaciones
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*&      --> LT_DETALLE_AUX
*&      --> LTD_ENTREGA_DETALLE
*&      --> LW_DELIVERY
*&      --> LV_ZZLFSTK
*&---------------------------------------------------------------------*
FORM f_act_entre_reparaciones  TABLES it_entr_det STRUCTURE zbvmm_st_guardar_entrega_det
                                   it_entrega_detalle STRUCTURE bbp_inbd_d
                             USING i_delivery TYPE vbeln_vl
                                   lv_status   TYPE ze_lfstk
                                   i_exidv TYPE exidv
                                   i_entr_aux TYPE zbvmm_st_guardar_entrega_det.
  TYPES: BEGIN OF gty_hucomple,
           vhilm_ku TYPE vhilm_ku,
           exidv    TYPE exidv,
         END OF gty_hucomple,

         BEGIN OF gty_zzlug_ent,
           ebeln     TYPE ekpo-ebeln,
           ebelp     TYPE ekpo-ebelp,
           zzlug_ent TYPE ekpo-zzlug_ent,
           inco1     TYPE ekpo-inco1, "+@001
         END OF gty_zzlug_ent.


  DATA: lt_hu_fict   TYPE STANDARD TABLE OF gty_hucomple,
        lt_zzlug_ent TYPE STANDARD TABLE OF gty_zzlug_ent,
        lv_corre     TYPE i.

  FIELD-SYMBOLS:<fs_zzlug_ent> LIKE LINE OF lt_zzlug_ent.


  LOOP AT it_entr_det ASSIGNING FIELD-SYMBOL(<fs_entr>) WHERE vhilm_ku EQ i_entr_aux-vhilm_ku.
    APPEND INITIAL LINE TO gt_entrenohu ASSIGNING FIELD-SYMBOL(<fs_nohu>).
    MOVE-CORRESPONDING <fs_entr> TO <fs_nohu>.
    "detalle de la entrega.
    READ TABLE it_entrega_detalle ASSIGNING FIELD-SYMBOL(<fs_detalle>)
                                  WITH KEY po_number = <fs_entr>-ebeln
                                           po_item = <fs_entr>-ebelp.
    IF sy-subrc EQ 0.
      "Entrega, posición y fecha de creación.
      <fs_nohu>-vbeln = <fs_detalle>-delivery.
      <fs_nohu>-posnr = <fs_detalle>-deliv_item.
      <fs_nohu>-lfdat = sy-datum.
      <fs_nohu>-lfuhr = sy-uzeit.
      <fs_nohu>-exidv = i_exidv.
    ENDIF.

*      "Asigna embalaje fict.
*      READ TABLE lt_hu_fict ASSIGNING <fs_hu_fict> WITH KEY vhilm_ku = <fs_entr>-vhilm_ku.
*      IF sy-subrc EQ 0.
*        <fs_nohu>-exidv = <fs_hu_fict>-exidv.
*        PERFORM agrega_ceros CHANGING <fs_nohu>-exidv.
**      CONDENSE <fs_nohu>-exidv NO-GAPS.
*      ENDIF.

  ENDLOOP.

  SELECT ebeln ebelp zzlug_ent
    inco1 "+@001
  INTO TABLE lt_zzlug_ent
  FROM ekpo
  FOR ALL ENTRIES IN it_entr_det
  WHERE ebeln EQ it_entr_det-ebeln
    AND ebelp EQ it_entr_det-ebelp+1(5).
  IF sy-subrc EQ '0'.
  ENDIF.

  "Verificar embalajes complementarios.
  LOOP AT gt_emb_compl ASSIGNING FIELD-SYMBOL(<fs_emb_compl>) WHERE vhilm_ku EQ i_entr_aux-vhilm_ku.

    APPEND INITIAL LINE TO gt_embcomp ASSIGNING FIELD-SYMBOL(<fs_embcomp>).
    MOVE-CORRESPONDING <fs_emb_compl> TO <fs_embcomp>. " <fs_nohu> TO <fs_embcomp>
    <fs_embcomp>-vbeln = i_delivery.
*      <fs_embcomp>-posnr = <fs_detalle>-deliv_item.
*      <fs_embcomp>-ebeln = <fs_entr>-ebeln.
*      <fs_embcomp>-ebelp = <fs_entr>-ebelp
    <fs_embcomp>-vhilm_ku = <fs_emb_compl>-vhilm_ku_p.
    <fs_embcomp>-vhilm_ku_sub = <fs_emb_compl>-vhilm_ku.  "Emb. complemantario.
    <fs_embcomp>-lfdat = sy-datum.
    <fs_embcomp>-lfuhr = sy-uzeit.

    READ TABLE it_entr_det ASSIGNING <fs_entr> WITH KEY vhilm_ku = <fs_emb_compl>-vhilm_ku_p.
    IF sy-subrc EQ 0.
      READ TABLE lt_zzlug_ent ASSIGNING <fs_zzlug_ent> WITH KEY ebeln = <fs_entr>-ebeln
                                                                ebelp = <fs_entr>-ebelp+1(5).
      IF sy-subrc EQ 0.
*        <fs_embcomp>-zzlug_ent = <fs_zzlug_ent>-zzlug_ent. "-@001
        <fs_embcomp>-zzlug_ent = <fs_zzlug_ent>-inco1. "+@001
      ENDIF.
    ENDIF.
    <fs_embcomp>-zzlfstk = lv_status.

    "NO HU
*    IF g_marc_nohu EQ abap_true.
    "Asigna embalaje fict.
*      READ TABLE lt_hu_fict ASSIGNING <fs_hu_fict> WITH KEY vhilm_ku = <fs_embcomp>-vhilm_ku.
*      IF sy-subrc EQ 0.
*        <fs_embcomp>-exidv = <fs_hu_fict>-exidv.
*        PERFORM agrega_ceros CHANGING <fs_embcomp>-exidv.
*      ENDIF.
    "HU OBL.
*    ELSE.
    READ TABLE gt_hucomple ASSIGNING FIELD-SYMBOL(<fs_hu_fict>) WITH KEY vhilm_ku = <fs_embcomp>-vhilm_ku.
    IF sy-subrc EQ 0.
      <fs_embcomp>-exidv = <fs_hu_fict>-exidv.
    ENDIF.
*    ENDIF.
  ENDLOOP.
  "Actualiza tabla de entrega sin HU.
  IF gt_entrenohu IS NOT INITIAL.
    MODIFY zbvmm_entrenohu FROM TABLE gt_entrenohu.
    IF sy-subrc EQ 0.
      COMMIT WORK.
    ENDIF.
  ENDIF.
  "Actualiza tabla de embalajes complementarios.
  IF gt_embcomp IS NOT INITIAL.
    MODIFY zbvmm_emb_comp FROM TABLE gt_embcomp.
    IF sy-subrc EQ 0.
      COMMIT WORK.
    ENDIF.
  ENDIF.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form CALL_INITIALIZE_PACKING
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*&      --> RETURN
*&      --> CT_RETMESSAGES
*&      --> LF_PLANT
*&      --> LF_STOLOC
*&      --> LS_OBJECT
*&---------------------------------------------------------------------*
FORM call_initialize_packing  TABLES   ct_return STRUCTURE bapiret2
                                      ct_messages STRUCTURE bapiret2
                         USING  if_plant TYPE werks  "insert note 400276
                               if_stoloc TYPE lgort "insert note 400276
                               is_object TYPE hum_object.   "HP_425776
  DATA: lt_messages TYPE huitem_messages_t.
*<<<<< changed by HP_425776  >>>>>>>>>>>>>>>>>>>>>>>>>>>
  DATA: ls_header51 TYPE header51,
        ls_hum_mm   TYPE hum_plant_stloc.

  ls_hum_mm-plant = if_plant.
  ls_hum_mm-stge_loc = if_stoloc-lgort.                     "n_1235156

  CALL FUNCTION 'HU_INITIALIZE_PACKING'
    EXPORTING
      is_object      = is_object
      is_plant_stloc = ls_hum_mm
    IMPORTING
      et_messages    = lt_messages
    EXCEPTIONS
      not_possible   = 1
      OTHERS         = 99.
  IF sy-subrc <> 0.
    PERFORM fill_return TABLES ct_return[].
  ENDIF.
  CHECK NOT lt_messages IS INITIAL.
  PERFORM fill_messages TABLES lt_messages
                               ct_messages[].
ENDFORM.
*&---------------------------------------------------------------------*
*& Form fill_messages
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*&      --> LT_MESSAGES
*&      --> CT_MESSAGES[]
*&---------------------------------------------------------------------*
FORM fill_messages  TABLES   it_messages STRUCTURE huitem_messages
                            ct_messages STRUCTURE bapiret2.
  DATA: ls_mes TYPE huitem_messages,
        ls_ret TYPE bapiret2.

  LOOP AT it_messages INTO ls_mes.
    CLEAR ls_ret.
    ls_ret-type = ls_mes-msgty.
    ls_ret-id = ls_mes-msgid.
    ls_ret-number = ls_mes-msgno.
    ls_ret-message_v1 = ls_mes-msgv1.
    ls_ret-message_v2 = ls_mes-msgv2.
    ls_ret-message_v3 = ls_mes-msgv3.
    ls_ret-message_v4 = ls_mes-msgv4.
    APPEND ls_ret TO ct_messages.
  ENDLOOP.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form fill_return
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*&      --> CT_RETURN[]
*&---------------------------------------------------------------------*
FORM fill_return  TABLES p_return STRUCTURE bapiret2.
  MOVE sy-msgty TO p_return-type.
  MOVE sy-msgid TO p_return-id.
  MOVE sy-msgno TO p_return-number.
  MOVE sy-msgv1 TO p_return-message_v1.
  MOVE sy-msgv2 TO p_return-message_v2.
  MOVE sy-msgv3 TO p_return-message_v3.
  MOVE sy-msgv4 TO p_return-message_v4.
  MESSAGE ID   sy-msgid                                     "HP_482260
        TYPE   'I'
        NUMBER sy-msgno
        WITH   sy-msgv1
               sy-msgv2
               sy-msgv3
               sy-msgv4
        INTO   p_return-message.

  APPEND p_return.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form create_lt_changed
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*&      --> RETURN
*&      --> HUCHANGED
*&      --> LS_HEADER
*&      <-- LT_CHANGED
*&---------------------------------------------------------------------*
FORM create_lt_changed TABLES ct_return STRUCTURE bapiret2
                       USING huchanged TYPE bapihuheader
                             ls_header TYPE vekpvb
                       CHANGING   ct_changed TYPE hum_update_header_t.
  DATA: ls_changed_hu TYPE vekpvb.
*  type-pools: vsep.
  DATA: ls_changed        TYPE hum_update_header,
        field_of_vekp(30),
        lt_nametab        TYPE TABLE OF x031l,
        ls_nametab        TYPE x031l.
  FIELD-SYMBOLS: <fa>.
  CALL FUNCTION 'MAP2I_BAPIHUHEADER_TO_VEKPVB'
    EXPORTING
      bapihuheader              = huchanged
    CHANGING
      vekpvb                    = ls_changed_hu
    EXCEPTIONS
      error_converting_iso_code = 1
      OTHERS                    = 2.
  IF sy-subrc <> 0.
    PERFORM fill_return TABLES ct_return[].
  ENDIF.
  CHECK ct_return[] IS INITIAL.

  ls_changed_hu-venum = ls_header-venum.
  ls_changed_hu-exidv = ls_header-exidv.

* 3. Bestimme die Felder, die sich geändert haben
  CALL FUNCTION 'DDIF_NAMETAB_GET'
    EXPORTING
      tabname   = 'VEKPVB'
    TABLES
      x031l_tab = lt_nametab
    EXCEPTIONS
      not_found = 01
      OTHERS    = 99.
  IF NOT sy-subrc IS INITIAL.
    sy-msgid = 'HUFUNCTIONS'.
    sy-msgty = 'E'.
    sy-msgno = 110.
*    MESSAGE E110(HUFUNCTIONS) RAISING NO_NAMETAB.
    PERFORM fill_return TABLES ct_return[].
  ENDIF.
  DELETE lt_nametab WHERE fieldname = 'VENUM'.
  DELETE lt_nametab WHERE fieldname = 'EXIDV'.
  DELETE lt_nametab WHERE fieldname = 'MANDT'.
  DELETE lt_nametab WHERE fieldname = 'ANZGL'.
  DELETE lt_nametab WHERE fieldname = 'ERNAM'.
  DELETE lt_nametab WHERE fieldname = 'ERDAT'.
  DELETE lt_nametab WHERE fieldname = 'ERUHR'.
  DELETE lt_nametab WHERE fieldname = 'VHILM'.
  DELETE lt_nametab WHERE fieldname = 'VHART'.
  DELETE lt_nametab WHERE fieldname = 'KAPPL'.
  DELETE lt_nametab WHERE fieldname = 'KALSM'.
  DELETE lt_nametab WHERE fieldname = 'KSCHL'.
  DELETE lt_nametab WHERE fieldname = 'MAGRV'.
  DELETE lt_nametab WHERE fieldname = 'VELTP'.
  DELETE lt_nametab WHERE fieldname = 'HANDLE'.
  DELETE lt_nametab WHERE fieldname = 'SAPRL'.

  LOOP AT lt_nametab INTO ls_nametab.
    CLEAR ls_changed.
    ls_changed-hdl_unit_itid = ls_changed_hu-venum.
    ls_changed-field_name = ls_nametab-fieldname.
    CONCATENATE 'LS_CHANGED_HU-' ls_nametab-fieldname INTO field_of_vekp.
    ASSIGN (field_of_vekp) TO <fa>.
    IF NOT sy-subrc IS INITIAL. CONTINUE. ENDIF.
    ls_changed-field_value = <fa>.
    IF NOT <fa> IS INITIAL.
      APPEND ls_changed TO ct_changed.
    ENDIF.
  ENDLOOP.


*  CALL FUNCTION 'V51F_DETERMINE_CHANGED_FIELDS'
*       EXPORTING
*            IS_HU_A           = ls_header
*            IS_HU_B           = ls_changed_hu
*       IMPORTING
*            ET_CHANGED_FIELDS = lt_changed_vsep
*       EXCEPTIONS
*            NO_NAMETAB        = 1
*            OTHERS            = 2.
*  IF SY-SUBRC <> 0.
*    PERFORM FILL_RETURN TABLES CT_RETURN[].
*  ENDIF.
*  delete lt_changed_vsep where f_value is initial.
*  delete lt_changed_vsep where f_value = 0.
*  loop at lt_changed_vsep into ls_changed_vsep.
*    ls_changed-HDL_UNIT_ITID = ls_header-venum.
*    ls_changed-FIELD_NAME = ls_changed_vsep-CHANGED_F.
*    condense ls_changed_vsep-f_value.
**    write ls_changed_vsep-f_value to ls_changed-FIELD_VALUE
**left-justified.
*    ls_changed-FIELD_VALUE = ls_changed_vsep-f_value.
*    append ls_changed to lt_changed.
*  endloop.
**  message s017(hufunctions).
ENDFORM.
*&---------------------------------------------------------------------*
*& Form find_hu
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*&      --> RETURN
*&      --> HUKEY
*&      <-- LS_HEADER
*&      <-- LF_LOCK
*&---------------------------------------------------------------------*
FORM find_hu  TABLES   p_return STRUCTURE bapiret2
             USING    p_lf_hukey_hu_exid TYPE bapihukey-hu_exid
             CHANGING p_ls_header TYPE vekpvb
                      not_highest TYPE xfeld.
  DATA: lt_exidv   TYPE hum_exidv_t,
        lt_header  TYPE hum_hu_header_t,
        lt_highest TYPE hum_venum_t,
        ls_highest TYPE vekp-venum.

* not_highest wird auch als Flag fürs Sperren verwendet !!!
  APPEND p_lf_hukey_hu_exid TO lt_exidv.

  CALL FUNCTION 'HU_GET_HUS'
    EXPORTING
      it_hus             = lt_exidv
      if_lock_hus        = not_highest
      if_mara_packmittel = 'X'                            "n_1550253
    IMPORTING
      et_header          = lt_header
      et_highest_levels  = lt_highest
    EXCEPTIONS
      no_hu_found        = 1
      OTHERS             = 3.
  IF sy-subrc <> 0.
    sy-msgty = 'E'.                                         "n_1026857
    PERFORM fill_return TABLES p_return[].
    EXIT.
  ENDIF.


  READ TABLE lt_header INTO p_ls_header
                       WITH KEY exidv = p_lf_hukey_hu_exid.
  READ TABLE lt_highest INTO ls_highest INDEX 1.
  CLEAR not_highest.
  IF p_ls_header-venum NE ls_highest.
    not_highest = 'X'.
  ENDIF.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form CALL_POST
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*&      --> CT_RETMESSAGES
*&---------------------------------------------------------------------*
FORM call_post  TABLES   ct_retmessages STRUCTURE bapiret2.
  DATA: lt_messages TYPE huitem_messages_t.
  DATA: ls_object TYPE hum_object.
  ls_object-object = '12'.
* posting
  CALL FUNCTION 'HU_POST'
    EXPORTING
      if_synchron = ' '
      if_commit   = ' '
      is_object   = ls_object
    IMPORTING
      et_messages = lt_messages.

  IF NOT lt_messages IS INITIAL.
    PERFORM fill_messages TABLES lt_messages
                                 ct_retmessages[].
    CLEAR lt_messages.
  ENDIF.
ENDFORM.
*{+@004
*&---------------------------------------------------------------------*
*& Form refresca_lips02
*&---------------------------------------------------------------------*
*& Relee las posiciones de la entrega en gt_lips02. Se usa después de
*& modificar la entrega: las subposiciones de lote 9000xx recién creadas
*& tienen que estar en gt_lips02 para embalarlas.
*&---------------------------------------------------------------------*
FORM refresca_lips02 USING iv_vbeln TYPE vbeln_vl.

  CLEAR gt_lips02.
  SELECT vbeln posnr matnr werks lgort charg vgbel lfimg meins umvkz umvkn vgpos
         vrkme uecha
    FROM lips
    INTO CORRESPONDING FIELDS OF TABLE gt_lips02
    WHERE vbeln EQ iv_vbeln.

ENDFORM.
*}+@004
