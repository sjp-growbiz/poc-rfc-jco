FUNCTION zbvmm_oc_guardar_entregav2.
*"----------------------------------------------------------------------
*"*"Interfase local
*"  TABLES
*"      T_ENTR_CAB TYPE  ZBVMM_TT_GUARDAR_ENTREGA
*"      T_ENTR_DET TYPE  ZBVMM_TT_GUARDAR_ENTREGA_DET
*"      T_ENTR_DET_LOT TYPE  ZBVMM_TT_GUARDAR_ENTREGA_DET_M
*"      T_PEDIDOTEXT TYPE  ZBVMM_TT_TXTPOSICIONPEDIDO
*"      T_RESULT TYPE  ZBVMM_TT_CONFIRMAR_RESULTADO
*"----------------------------------------------------------------------
*&----------------------------------------------------------------------&*
* Autor      : Keny Luy - NTT Data
* Descripción: WB-FI: QUIPU S4 HANA Migración
* Fecha      : 07.11.2023  Marca: @001
*&----------------------------------------------------------------------&*
***DEFINE MAC_CONV_MSG.
***
***  CALL FUNCTION 'BAPI_MESSAGE_GETDETAIL'
***     EXPORTING
***        id                 = &1-id
***        number             = &1-number
***        language           = 'S'
***        textformat         = 'ASC'
****        linkpattern        =
***        message_v1         = &1-message_v1
***        message_v2         = &1-message_v2
***        message_v3         = &1-message_v3
***        message_v4         = &1-message_v4
****                        language_iso       =
***     IMPORTING
***        message            = &2
****                        RETURN             =
****                      TABLES
****                        TEXT               =
***                               .
***
***END-OF-DEFINITION.


  DATA: lt_detail  TYPE STANDARD TABLE OF bbp_inbd_d,
        ls_detail  TYPE bbp_inbd_d,
        lt_return  TYPE STANDARD TABLE OF bapireturn,
        lt_return2 TYPE STANDARD TABLE OF bapiret2,
        ls_return  TYPE bapireturn,
        ls_return2 TYPE bapiret2.
  DATA: lt_item_data    TYPE STANDARD TABLE OF bapiibdlvitemchg,
        ls_item_data    TYPE bapiibdlvitemchg,
        lt_item_control TYPE STANDARD TABLE OF bapiibdlvitemctrlchg,
        ls_item_control TYPE bapiibdlvitemctrlchg,
        lt_item_serial  TYPE STANDARD TABLE OF bapidlvitmserno,
        ls_item_serial  TYPE bapidlvitmserno,
        lt_extension1   TYPE STANDARD TABLE OF   bapiextc,
        lt_extension2   TYPE STANDARD TABLE OF  bapiext,
        lt_entr_det_aux TYPE STANDARD TABLE OF zbvmm_st_guardar_entrega_det,
        lt_uekes        TYPE TABLE OF uekes,
        ls_uekes        LIKE LINE OF  lt_uekes,
        lv_zul_aufl     TYPE char255,
        l_tabix_a       TYPE sy-tabix,
        l_tabix_b       TYPE sy-tabix,
        l_save          TYPE abap_bool,
        t_line          TYPE tlinet,
        lt_return_carg  TYPE zbvmm_st_i_resultado.

  DATA: ls_header TYPE bbp_inbd_l.

  DATA: lw_delivery TYPE likp-vbeln,
        lw_lgort    TYPE lgort_d,
        lw_hukey    TYPE bapihukey-hu_exid,
        lw_hu_id    TYPE rlmob-clenum.
  DATA: ls_header_data    TYPE bapiibdlvhdrchg,
        ls_header_control TYPE bapiibdlvhdrctrlchg,
        ls_headerproposal TYPE bapihuhdrproposal,
        ls_huheader       TYPE bapihuheader,
        ls_ref_object     TYPE hum_object,
        ls_hu_header_main TYPE huhdr_proposal,
        ls_mm_data        TYPE hum_plant_stloc,
        ls_item_proposal  TYPE huitm_proposal,
        ls_ekes           TYPE ekes.
  DATA: ltd_entrega_detalle TYPE STANDARD TABLE OF bbp_inbd_d,
        ls_result           TYPE zbvmm_st_result.

  DATA: lv_param  TYPE zge_t_constantes-low,
        lv_field1 TYPE zge_t_constantes-low,
        lv_field2 TYPE zge_t_constantes-low,
        lv_field3 TYPE zge_t_constantes-low,
        lv_field4 TYPE zge_t_constantes-low,
        lv_field5 TYPE zge_t_constantes-low,
        lv_field6 TYPE zge_t_constantes-low,
        lv_field7 TYPE zge_t_constantes-low,
        lv_status TYPE zge_t_constantes-low,
        lv_packmt TYPE zge_t_constantes-low,
        lv_matobj TYPE zge_t_constantes-low,
        lv_objct1 TYPE zge_t_constantes-low,
        lv_svstep TYPE zge_t_constantes-low,
        lv_packm2 TYPE zge_t_constantes-low,
        lv_dlvryt TYPE likp-vbtyp,  "ztconstantes-valor_low,
        lv_packat TYPE zge_t_constantes-low,
        lv_packty TYPE zge_t_constantes-low,
        lv_categ  TYPE zge_t_constantes-low.
  DATA: lw_btgew       TYPE likp-btgew,    "Peso total
        lw_peso_comple TYPE likp-btgew,  "Peso total de embalajes complementarios.
        lw_brgew       TYPE vekp-brgew,    "Peso por bulto
        lw_anzpk       TYPE likp-anzpk,    "Nro. de bultos
        lw_um          TYPE char01,        "Gestion de unidades
        lw_borgr_grp   TYPE likp-borgr_grp,
        lw_texto1      TYPE char10,
        lw_texto2      TYPE char10,
        lw_texto3      TYPE char10,
        lw_menge       TYPE ekes-menge,
        lw_flagekes    TYPE c,
        lw_etens       TYPE ekes-etens.
  DATA: lw_message          TYPE string,
*{+@001
        lv_bsart            TYPE esart,
        lv_e_bsart          TYPE esart,
        lv_count            TYPE i,

        i_msg(220)          TYPE c,
        l_msgid             TYPE symsgid,
        l_msgno             TYPE symsgno,
        l_msgv1             TYPE syst_msgv,
        l_msgv2             TYPE syst_msgv,
        l_msgv3             TYPE syst_msgv,
        l_msgv4             TYPE syst_msgv,

        lwa_batchattributes TYPE bapibatchatt.
*}+@001
  DATA: lt_line        TYPE TABLE OF tline,
        wa_line        TYPE tline,
        wa_header      TYPE thead,
        lv_s1          TYPE string,
        lv_s2          TYPE string,
        lv_s3          TYPE string,
        lv_mensaje     TYPE bapi_msg,
        "@DL MEJORAS {
        ls_entr_cab    TYPE zbvmm_st_i_entr_cab,
        lv_zzlfstk     TYPE ze_lfstk,
        lt_result      TYPE STANDARD TABLE OF  zbvmm_st_result,
        lv_str_comp    TYPE string,
        lv_emb         TYPE string,
        lv_emb2        TYPE string,
        lv_matnr_batch TYPE matnr18
        .
  "@DL MEJORAS }

  REFRESH: gt_emb_compl.
  DATA(ltd_entr_det) = t_entr_det[].

  "Se separan los embalajes complementarios de los bultos.
  LOOP AT t_entr_det ASSIGNING FIELD-SYMBOL(<fs_entr_compl>).
    CLEAR: lv_str_comp.
    lv_str_comp = <fs_entr_compl>-vhilm_ku.
    REPLACE ALL OCCURRENCES OF '.' IN lv_str_comp WITH 'h'.
    SEARCH lv_str_comp FOR 'h'.

    IF sy-subrc EQ 0.
      CLEAR: lv_emb, lv_emb2.
      SPLIT lv_str_comp AT 'h' INTO lv_emb lv_emb2.
      APPEND INITIAL LINE TO gt_emb_compl ASSIGNING FIELD-SYMBOL(<fs_emb_compl>).
      MOVE-CORRESPONDING <fs_entr_compl> TO <fs_emb_compl>.
      <fs_emb_compl>-vhilm_ku_p = lv_emb.   "emb principal.
      <fs_emb_compl>-vhilm_ku = lv_emb2.   "emb compl.
      ADD <fs_entr_compl>-brgew TO lw_peso_comple. "Acumular peso de ambalajes complementarios.
    ENDIF.

  ENDLOOP.

  SORT gt_emb_compl BY vhilm_ku_p ASCENDING.

  DELETE ltd_entr_det WHERE ebeln IS INITIAL.
  DELETE ltd_entr_det WHERE ebelp IS INITIAL.
  DELETE t_entr_det WHERE matnr IS INITIAL.  "Sacar embalajes complementarios (ya están en gt_emb_compl)


  TYPES: BEGIN OF lty_sy,
           msgid TYPE sy-msgid,
           msgty TYPE sy-msgty,
           msgno TYPE sy-msgno,
           ebeln TYPE ebeln,
         END OF lty_sy,
*{+@001
         BEGIN OF lty_pack_mat,
           pack_mat TYPE vhilm18,
           vegr2    TYPE vegr2,
         END OF lty_pack_mat.
*}+@001
  DATA: lt_sy          TYPE STANDARD TABLE OF lty_sy,
        lt_pack_mat    TYPE STANDARD TABLE OF lty_pack_mat, "+@001

        lt_detalle_aux TYPE STANDARD TABLE OF zbvmm_st_guardar_entrega_det.

*  SELECT SINGLE valor_low
*  INTO lv_param
  SELECT * INTO TABLE @DATA(lt_ztconstantes)
  FROM zge_t_constantes
  WHERE modulo   EQ 'MM'
  AND   programa EQ 'SAPLZGF_CON_PORTAL'.
*  AND   campo    EQ 'PARAM'.

  LOOP AT lt_ztconstantes ASSIGNING FIELD-SYMBOL(<fs_ztcons>).
    CASE <fs_ztcons>-campo.
      WHEN 'PARAM'.
        lv_param = <fs_ztcons>-low.
      WHEN 'FIELD1'.
        lv_field1 = <fs_ztcons>-low.
      WHEN 'FIELD2'.
        lv_field2 = <fs_ztcons>-low.
      WHEN 'FIELD3'.
        lv_field3 = <fs_ztcons>-low.
      WHEN 'FIELD4'.
        lv_field4 = <fs_ztcons>-low.
      WHEN 'FIELD5'.
        lv_field5 = <fs_ztcons>-low.
      WHEN 'FIELD6'.
        lv_field6 = <fs_ztcons>-low.
      WHEN 'FIELD7'.
        lv_field7 = <fs_ztcons>-low.
      WHEN 'STATUS'.
        lv_status = <fs_ztcons>-low.
      WHEN 'PACKMT'.
*        lv_packmt = <fs_ztcons>-low. "-@001
*{+@001
        APPEND INITIAL LINE TO lt_pack_mat ASSIGNING FIELD-SYMBOL(<fs_pack_mat>).
        <fs_pack_mat>-vegr2 = <fs_ztcons>-high.
        <fs_pack_mat>-pack_mat = <fs_ztcons>-low.
      WHEN 'E_BSART'.
        lv_e_bsart = <fs_ztcons>-low.
      WHEN 'DOC_TYPE'.
        lv_doc_type = <fs_ztcons>-low.
*}+@001
      WHEN 'MATOBJ'.
        lv_matobj = <fs_ztcons>-low.
      WHEN 'OBJCT1'.
        lv_objct1 = <fs_ztcons>-low.
      WHEN 'SVSTEP'.
        lv_svstep = <fs_ztcons>-low.
      WHEN 'PACKM2'.
        lv_packm2 = <fs_ztcons>-low.
      WHEN 'DLVRYT'.
        lv_dlvryt = <fs_ztcons>-low.
      WHEN 'PACKAT'.
        lv_packat = <fs_ztcons>-low.
      WHEN 'PACKTY'.
        lv_packty = <fs_ztcons>-low.
      WHEN 'CONF_CATEG'.
        lv_categ  = <fs_ztcons>-low.
      WHEN: 'LGORT_TRANSITO'.
        APPEND INITIAL LINE TO gr_lgort_tr ASSIGNING FIELD-SYMBOL(<fs_lgort_tr>).
        MOVE 'I'                   TO <fs_lgort_tr>-sign.
        MOVE 'EQ'                  TO <fs_lgort_tr>-option.
        MOVE <fs_ztcons>-low  TO <fs_lgort_tr>-low.
    ENDCASE.
  ENDLOOP.

*{+@001
  "Validar si es Pedido sustituto
  LOOP AT ltd_entr_det ASSIGNING FIELD-SYMBOL(<fs_entr>).
    APPEND INITIAL LINE TO lt_executed ASSIGNING FIELD-SYMBOL(<fs_executed>).
    <fs_executed>-doc_nr   = <fs_entr>-ebeln.
    <fs_executed>-doc_item = <fs_entr>-ebelp.
  ENDLOOP.

  IF lt_executed IS NOT INITIAL.
    PERFORM verif_ped_sust.
  ENDIF.
*}+@001

  SELECT p~ebeln, p~ebelp, p~werks, p~lgort, p~umren, p~bstae, b~eindt, b~menge, b~wamng, b~nodisp,
          p~bwtar "+@001
          INTO TABLE @DATA(ltd_ekpo)
  FROM ekpo AS p INNER JOIN eket AS b
       ON p~ebeln = b~ebeln
      AND p~ebelp = b~ebelp
    FOR ALL ENTRIES IN @ltd_entr_det
    WHERE p~ebeln EQ @ltd_entr_det-ebeln
      AND p~ebelp EQ @ltd_entr_det-ebelp+1(5).

  SELECT * INTO TABLE @DATA(ltd_ekes)
  FROM ekes
    FOR ALL ENTRIES IN @ltd_entr_det
    WHERE ebeln EQ @ltd_entr_det-ebeln
      AND ebelp EQ @ltd_entr_det-ebelp+1(5).
  DELETE ltd_ekes WHERE ( ebtyp = lv_categ  AND xblnr <> '' ) OR ( ebtyp = 'LA' AND dabmg NE 0 ).
  SORT ltd_ekes BY ebeln ebelp etens.

  IF ltd_ekes[] IS NOT INITIAL.
    LOOP AT ltd_ekpo ASSIGNING FIELD-SYMBOL(<fs_ekpo1>).
      CLEAR: lw_menge, <fs_ekpo1>-nodisp.
      LOOP AT ltd_ekes ASSIGNING FIELD-SYMBOL(<fs_ekes>) WHERE ebeln = <fs_ekpo1>-ebeln
                                                           AND ebelp = <fs_ekpo1>-ebelp.

        IF ( <fs_ekes>-ebtyp = lv_categ  AND <fs_ekes>-xblnr <> '' ) OR
           ( <fs_ekes>-ebtyp = 'LA' AND <fs_ekes>-dabmg NE 0 ).
          DELETE ltd_ekes.
        ENDIF.
        IF <fs_ekes>-vbeln IS NOT INITIAL.
          <fs_ekpo1>-wamng = <fs_ekpo1>-wamng + <fs_ekes>-menge.
        ELSE.
          lw_menge = lw_menge + <fs_ekes>-menge.
        ENDIF.
      ENDLOOP.
      IF lw_menge = ( <fs_ekpo1>-menge - <fs_ekpo1>-wamng ).
        <fs_ekpo1>-nodisp = 'X'.
      ENDIF.
    ENDLOOP.
  ENDIF.
  SORT ltd_ekes BY ebeln ebelp eindt.

  SELECT werks, lgort, xhupf INTO TABLE @DATA(ltd_t001l)
    FROM t001l
  FOR ALL ENTRIES IN @ltd_ekpo
 WHERE werks = @ltd_ekpo-werks AND
       lgort = @ltd_ekpo-lgort.
  IF sy-subrc EQ 0.
    "@{DL Ordenar material-posición no HU.
    CLEAR:  g_marc_nohu.
    lt_detalle_aux =  t_entr_det[].
    READ TABLE ltd_t001l ASSIGNING FIELD-SYMBOL(<f_t001l>) INDEX 1.
    IF sy-subrc EQ 0.
      PERFORM f_agrupa_no_hu TABLES t_entr_det
*                               USING <f_t001l>-xhupf. "-@001
                               USING <f_t001l>-lgort.  "+@001
    ENDIF.
    "}@DL

    READ TABLE t_entr_cab ASSIGNING FIELD-SYMBOL(<fs_entr_cab>) INDEX 1.
    IF sy-subrc EQ 0.

      lw_anzpk = <fs_entr_cab>-anzpk.
      <fs_entr_cab>-lfdat = sy-datum.
      ls_header-deliv_date = <fs_entr_cab>-lfdat .
      LOOP AT t_entr_det ASSIGNING FIELD-SYMBOL(<fs_entr_det>).
        "Datos para verificación de clave de confirmación.
        APPEND INITIAL LINE TO gt_pedpos ASSIGNING FIELD-SYMBOL(<fs_pedpos>).
        <fs_pedpos>-ebeln = <fs_entr_det>-ebeln.
        <fs_pedpos>-ebelp = <fs_entr_det>-ebelp.
*      APPEND INITIAL LINE TO lt_detail ASSIGNING FIELD-SYMBOL(<fs_detail>).
        ls_detail-po_number = <fs_entr_det>-ebeln.
        ls_detail-po_item   = <fs_entr_det>-ebelp.
        ls_detail-material  = <fs_entr_det>-matnr.
        ls_detail-deliv_qty = <fs_entr_det>-menge.
        ls_detail-unit      = <fs_entr_det>-meins.
        lw_brgew = <fs_entr_det>-brgew.
        COLLECT ls_detail INTO lt_detail.
        READ TABLE ltd_ekpo ASSIGNING FIELD-SYMBOL(<fs_ekpo>) WITH KEY ebeln = <fs_entr_det>-ebeln
                                                                       ebelp = <fs_entr_det>-ebelp+1(5).
        IF sy-subrc = 0.
          APPEND INITIAL LINE TO gt_ekpo ASSIGNING FIELD-SYMBOL(<gfs_ekpo>).
          MOVE-CORRESPONDING <fs_ekpo> TO <gfs_ekpo>.

          <fs_ekpo>-eindt =  <fs_entr_det>-eindt.
        ENDIF.

        AT END OF vhilm_ku.
          lw_btgew = lw_btgew + lw_brgew.
*          ADD 1 TO lw_anzpk.
        ENDAT.
      ENDLOOP.

      "Se asigna el valor del peso total
      IF g_marc_nohu EQ abap_true.
        lw_btgew = g_pesototal. "Peso total no HU calculado en form f_agrupa_no_hu.
      ENDIF.

      ADD lw_peso_comple TO lw_btgew. "Agregar peso de embalajes complementarios.

      "Verifica clave de confirmación.
      CLEAR: g_error.
      PERFORM verif_clave_confirmacion  CHANGING g_error.

      IF g_error EQ abap_false.
*{+@001
        CLEAR lv_bsart.
        READ TABLE ltd_ekpo ASSIGNING FIELD-SYMBOL(<fs_bsart>) INDEX 1.
        IF sy-subrc EQ 0.
          SELECT SINGLE bsart FROM ekko
            INTO lv_bsart
            WHERE ebeln EQ <fs_bsart>-ebeln.
        ENDIF.

*}+@001
*      CALL FUNCTION 'BBP_INB_DELIVERY_CREATE' "-@001
        CALL FUNCTION 'ZBBP_INB_DELIVERY_CREATE'  "+@001
          EXPORTING
            is_inb_delivery_header = ls_header
            i_bsart                = lv_bsart
          IMPORTING
            ef_delivery            = lw_delivery
          TABLES
            it_inb_delivery_detail = lt_detail
            return                 = lt_return
          EXCEPTIONS
            error_message          = 1.
        IF sy-subrc EQ 0.

          IMPORT lt_sy TO lt_sy FROM MEMORY ID 'LT_SY'.
          READ TABLE lt_sy ASSIGNING FIELD-SYMBOL(<f_sy>) INDEX 1.
          IF sy-subrc EQ 0.
            MESSAGE ID <f_sy>-msgid TYPE <f_sy>-msgty NUMBER <f_sy>-msgno
             INTO DATA(mtext).
            ls_result-codigo = <f_sy>-msgno.
            ls_result-type = <f_sy>-msgty. "@DL06082021
            IF <f_sy>-msgty = 'E'. "@DL MEJORAS
              g_error = abap_true.
            ENDIF.
            SPLIT mtext AT space INTO lv_s1 lv_s2 lv_s3.
            CONCATENATE lv_s1 <f_sy>-ebeln lv_s2 lv_s3 INTO ls_result-msg SEPARATED BY space.
            APPEND ls_result TO t_result.
          ENDIF.
          FREE MEMORY ID 'LT_SY'.

        ENDIF.

        "Error clave de confirmación.
      ELSE.
        mac_ap_table gt_mensajes t_result.

      ENDIF.

      IF lw_delivery IS NOT INITIAL.

        PERFORM commit_wait. "@DL02 MEJORAS.
        ls_entr_cab-vbeln = lw_delivery.
        lv_zzlfstk = '08'.
        PERFORM f_actualiza_entrega_cab TABLES lt_return2
                                        USING ls_entr_cab
                                              lv_param
                                              lv_zzlfstk.
        REFRESH lt_return.
        CALL FUNCTION 'BBP_INB_DELIVERY_GETDETAIL'
          EXPORTING
            if_delivery            = lw_delivery
          TABLES
            et_inb_delivery_detail = ltd_entrega_detalle
            return                 = lt_return.

        REFRESH lt_return.
        ls_header_data-deliv_numb     = lw_delivery.
        ls_header_control-deliv_numb  = lw_delivery.

** campos adicionales
*      LOOP AT t_entr_det ASSIGNING FIELD-SYMBOL(<fs_entr_det2>).
        DATA: lv_sytabix TYPE int4,
              lv_posnrlt TYPE lips-posnr VALUE '900000'.
        LOOP AT ltd_entrega_detalle ASSIGNING FIELD-SYMBOL(<fs_entrega_detalle>). " WITH KEY po_number = <fs_entr_det2>-ebeln    po_item = <fs_entr_det2>-ebelp.

          READ TABLE ltd_ekpo ASSIGNING <fs_ekpo> WITH KEY ebeln = <fs_entrega_detalle>-po_number  ebelp = <fs_entrega_detalle>-po_item.
          IF sy-subrc EQ 0 .
            REFRESH lt_return2.
*@002+/INI/02-09-2026-*************************************************************
*                 item_data      = lt_item_data
*            item_control   = lt_item_control
            READ TABLE t_entr_det_lot  TRANSPORTING NO FIELDS
                                           WITH KEY ebeln = <fs_ekpo>-ebeln
                                                    ebelp = <fs_ekpo>-ebelp  "<fs_vidx_PRPS>
                                           BINARY SEARCH.
            IF sy-subrc EQ 0.
              lv_sytabix = sy-tabix.
              LOOP AT t_entr_det_lot ASSIGNING FIELD-SYMBOL(<fs_det_lot>) FROM lv_sytabix.  "<fs_vidx_cpl>
                IF  <fs_det_lot>-ebeln  NE <fs_ekpo>-ebeln
                 OR <fs_det_lot>-ebelp  NE <fs_ekpo>-ebelp.
                  EXIT.
                ENDIF.
                <fs_det_lot>-posnr    = <fs_entrega_detalle>-deliv_item.

                APPEND INITIAL LINE TO lt_item_data ASSIGNING FIELD-SYMBOL(<fs_item_data>).
                APPEND INITIAL LINE TO lt_item_control ASSIGNING FIELD-SYMBOL(<fs_item_control>).

                <fs_item_data>-deliv_numb =  <fs_entrega_detalle>-delivery .
*@002+/INI/02-09-2026-*************************************************************
                IF <fs_det_lot>-ltmenge EQ <fs_entrega_detalle>-deliv_qty.
                  <fs_item_data>-deliv_item = <fs_entrega_detalle>-deliv_item .
                  <fs_item_control>-deliv_item     =  <fs_entrega_detalle>-deliv_item .
                  <fs_item_control>-chg_delqty     =  abap_true.
                ELSE.
                  ADD 1 TO lv_posnrlt.
                  <fs_item_data>-deliv_item = lv_posnrlt.
                  <fs_item_control>-deliv_item     =  lv_posnrlt. "<fs_entrega_detalle>-deliv_item .
                  <fs_item_data>-hieraritem = <fs_entrega_detalle>-deliv_item.
                  <fs_item_data>-usehieritm = '1'.
                  <fs_item_control>-chg_delqty     =  abap_true.
                ENDIF.
                <fs_item_data>-expirydate = <fs_det_lot>-ltvfdat.
                <fs_item_control>-expirydate_flg = abap_true.
*@002+/END/02-09-2026-*************************************************************

                <fs_item_control>-deliv_numb     = <fs_entrega_detalle>-delivery .


                <fs_item_data>-material  = <fs_entrega_detalle>-material.
                <fs_item_data>-dlv_qty = <fs_det_lot>-ltmenge. " Cantidad parcial del lote <fs_entrega_detalle>-deliv_qty.
                <fs_item_data>-sales_unit    = <fs_entrega_detalle>-unit.
                <fs_item_data>-dlv_qty_imunit = 0.
                <fs_item_data>-fact_unit_denom = <fs_ekpo>-umren. "1.

                SELECT SINGLE umvkz meins
                FROM lips INTO (<fs_item_data>-fact_unit_nom, <fs_item_data>-base_uom)
                WHERE vbeln = <fs_entrega_detalle>-delivery
                AND posnr = <fs_entrega_detalle>-deliv_item .

                lv_matnr_batch = <fs_entrega_detalle>-material.
                lwa_batchattributes-val_type = <fs_ekpo>-bwtar.
                lwa_batchattributes-expirydate = <fs_det_lot>-ltvfdat.    "*@002+/02-09-2026********************
                CALL FUNCTION 'BAPI_BATCH_CREATE'
                  EXPORTING
                    material        = lv_matnr_batch
                    plant           = <fs_ekpo>-werks
                    batchattributes = lwa_batchattributes
                  IMPORTING
                    batch           = <fs_item_data>-batch
                  TABLES
                    return          = lt_return2.
                IF  lt_return2 IS NOT INITIAL.
                  LOOP AT lt_return2 ASSIGNING FIELD-SYMBOL(<fs_ret2>) WHERE type EQ 'E'.
                    CLEAR: g_msg.
                    APPEND INITIAL LINE TO t_result ASSIGNING FIELD-SYMBOL(<fs_result>).
                    PERFORM f_read_msg_error
                      USING
                        <fs_ret2>
                      CHANGING
                        g_msg                  .
                    MOVE-CORRESPONDING <fs_ret2> TO <fs_result>.
                    <fs_result>-msg = g_msg.
                    g_error = abap_true.
                  ENDLOOP.
                ENDIF.
                CALL FUNCTION 'BAPI_TRANSACTION_COMMIT'
                  EXPORTING
                    wait = 'X'.
                CLEAR lv_count.
                DO 5 TIMES.
                  SELECT SINGLE charg
                  FROM mcha
                  INTO @DATA(lv_charg)
                  WHERE matnr EQ @lv_matnr_batch
                    AND werks EQ @<fs_ekpo>-werks
                    AND charg EQ @<fs_item_data>-batch.
                  IF sy-subrc EQ 0.
                    EXIT.
                  ELSE.
                    WAIT UP TO 1 SECONDS.
                  ENDIF.
                ENDDO.
                <fs_det_lot>-charg = <fs_item_data>-batch.
              ENDLOOP.
*@002+/END/02-09-2026-*************************************************************
*@002-/INI/02-09-2026-*************************************************************
*              APPEND INITIAL LINE TO lt_item_data ASSIGNING <fs_item_data>."FIELD-SYMBOL(<fs_item_data>). "*@002-/02-09-2026********************
**          READ TABLE ltd_entrega_detalle ASSIGNING FIELD-SYMBOL(<fs_entrega_detalle>) WITH KEY po_number = <fs_entr_det2>-ebeln    po_item = <fs_entr_det2>-ebelp.
*              IF sy-subrc EQ 0.
*                <fs_item_data>-deliv_numb =  <fs_entrega_detalle>-delivery .
*                <fs_item_data>-deliv_item = <fs_entrega_detalle>-deliv_item .
*                APPEND INITIAL LINE TO lt_item_control ASSIGNING <fs_item_control>."FIELD-SYMBOL(<fs_item_control>). "*@002-/02-09-2026********************
*                <fs_item_control>-deliv_numb     = <fs_entrega_detalle>-delivery .
*                <fs_item_control>-deliv_item     =  <fs_entrega_detalle>-deliv_item .
*                <fs_item_control>-chg_delqty     =  abap_true.
*              ENDIF.
*              <fs_item_data>-material  = <fs_entrega_detalle>-material.
*              <fs_item_data>-dlv_qty = <fs_entrega_detalle>-deliv_qty.
*              <fs_item_data>-sales_unit    = <fs_entrega_detalle>-unit.
*              <fs_item_data>-dlv_qty_imunit = 0.
*              <fs_item_data>-fact_unit_denom = <fs_ekpo>-umren. "1.
*
*              SELECT SINGLE umvkz meins
*              FROM lips INTO (<fs_item_data>-fact_unit_nom, <fs_item_data>-base_uom)
*              WHERE vbeln = <fs_entrega_detalle>-delivery
*              AND posnr = <fs_entrega_detalle>-deliv_item .
*
*              lv_matnr_batch = <fs_entrega_detalle>-material. "+@001
*              lwa_batchattributes-val_type = <fs_ekpo>-bwtar. "+@001
*              CALL FUNCTION 'BAPI_BATCH_CREATE'
*                EXPORTING
**                 material        = <fs_entrega_detalle>-material "-@001
*                  material        = lv_matnr_batch   "+@001
*                  plant           = <fs_ekpo>-werks
*                  batchattributes = lwa_batchattributes  "+@001
*                IMPORTING
*                  batch           = <fs_item_data>-batch
*                TABLES
*                  return          = lt_return2.
*              "{@DL06082021
*              IF  lt_return2 IS NOT INITIAL."FIELD-SYMBOL(<fs_ret2>). "*@002-/02-09-2026********************
*                LOOP AT lt_return2 ASSIGNING <fs_ret2> WHERE type EQ 'E'.
*                  CLEAR: g_msg.
*                  APPEND INITIAL LINE TO t_result ASSIGNING <fs_result>."FIELD-SYMBOL(<fs_result>). "*@002-/02-09-2026********************
*                  "Lectura del mensaje.
*                  PERFORM f_read_msg_error
*                    USING
*                      <fs_ret2>
*                    CHANGING
*                      g_msg                  .
*                  MOVE-CORRESPONDING <fs_ret2> TO <fs_result>.
*                  <fs_result>-msg = g_msg.
*                  g_error = abap_true. "@DL MEJORAS.
*                ENDLOOP.
*              ENDIF.
*              "}@DL06082021
*              CALL FUNCTION 'BAPI_TRANSACTION_COMMIT'
*                EXPORTING
*                  wait = 'X'.
**{+@001
*              CLEAR lv_count.
*              DO 5 TIMES.
*                SELECT SINGLE charg
*                FROM mcha
*                INTO @lv_charg  "lv_charg "*@002-/02-09-2026********************
*                WHERE matnr EQ @lv_matnr_batch
*                  AND werks EQ @<fs_ekpo>-werks
*                  AND charg EQ @<fs_item_data>-batch.
*                IF sy-subrc EQ 0.
*                  EXIT.
*                ELSE.
*                  WAIT UP TO 1 SECONDS.
*                ENDIF.
*              ENDDO.
**}+@001
*@002-/END/02-09-2026-*************************************************************
            ENDIF."*@002+/02-09-2026********************
            READ TABLE ltd_t001l ASSIGNING FIELD-SYMBOL(<fs_t001l>) WITH KEY werks = <fs_ekpo>-werks
                                                                             lgort = <fs_ekpo>-lgort.
            IF sy-subrc EQ 0.
*              IF  <fs_t001l>-xhupf = space. "-@001
              IF  <fs_t001l>-lgort NOT IN gr_lgort_tr. "NE '0230'. "+@001
                lw_um = 'X'.
              ENDIF.
            ENDIF.
            "Guardar textos {@DL
            PERFORM f_save_text
               TABLES
                   t_pedidotext
               USING
                   <fs_entrega_detalle>                           .
            "Guardar textos }@DL
**      actualizar campo texto de entrega +@clh{
***            READ TABLE t_entr_det ASSIGNING <fs_entr_det> WITH KEY ebeln = <fs_entrega_detalle>-po_number
***                                                                   ebelp = <fs_entrega_detalle>-po_item.
***            IF sy-subrc = 0 .
***              FREE:  lt_line.
***              CLEAR: wa_header,wa_line.
***              wa_line-tdline = <fs_entr_det>-tdline.
***              APPEND wa_line TO lt_line.
***              CONCATENATE <fs_entrega_detalle>-delivery
***                          <fs_entrega_detalle>-deliv_item
***                     INTO wa_header-tdname.
***
***              wa_header-tdobject = 'VBBP'.
***              wa_header-tdid     = 'Z003'.
***              wa_header-tdspras  = sy-langu.
***
***              CALL FUNCTION 'SAVE_TEXT'
***                EXPORTING
***                  client          = sy-mandt
***                  header          = wa_header
***                  insert          = 'X'
***                  savemode_direct = 'X'
***                TABLES
***                  lines           = lt_line
***                EXCEPTIONS
***                  id              = 1
***                  language        = 2
***                  name            = 3
***                  object          = 4
***                  OTHERS          = 5.
***            ENDIF.
*         }+@clh
          ENDIF.
        ENDLOOP.
        "MP{
*        IF lv_bsart NE lv_e_bsart. "Caso reparaciones "+@001
        "Estatus
        APPEND INITIAL LINE TO lt_extension2 ASSIGNING FIELD-SYMBOL(<fs_extension2>).
        <fs_extension2>-param = lv_param."  - Constante
        <fs_extension2>-field = 'ZZLFSTK'.   "ZZLFSTK - Estatus
        <fs_extension2>-value = '08'. ""@DL Mejoras "'04'.
        "MP}
        APPEND INITIAL LINE TO lt_extension2 ASSIGNING <fs_extension2>.
        <fs_extension2>-param = lv_param."  - Constante
        <fs_extension2>-field = lv_field1.   "ANZPK- Cantidad de bultos
        <fs_extension2>-value = lw_anzpk.

        APPEND INITIAL LINE TO lt_extension2 ASSIGNING <fs_extension2>.
        <fs_extension2>-param = lv_param.  "- Constante
        <fs_extension2>-field = 'BRGEW'. "lv_field2.    "BTGEW  Peso total
        <fs_extension2>-value = lw_btgew.
        IF lw_um = 'X'.
          READ TABLE t_entr_det ASSIGNING FIELD-SYMBOL(<fs_entr_det2>) INDEX 1.
          IF sy-subrc = 0.
            APPEND INITIAL LINE TO lt_extension2 ASSIGNING <fs_extension2>.
            <fs_extension2>-param = lv_param."  - Constante
            <fs_extension2>-field = lv_field5.  "VEGR2
            <fs_extension2>-value = <fs_entr_det2>-vegr2. "(debe ser único para todos)

            APPEND INITIAL LINE TO lt_extension2 ASSIGNING <fs_extension2>.
            <fs_extension2>-param = lv_param."  - Constante
            <fs_extension2>-field = lv_field6.    "INHALT
            <fs_extension2>-value = <fs_entr_det2>-inhalt. "(debe ser único para todos)

            IF <fs_entr_det> IS NOT INITIAL.
              lv_zul_aufl = <fs_entr_det>-zul_aufl.
              CONDENSE lv_zul_aufl NO-GAPS.
              APPEND INITIAL LINE TO lt_extension2 ASSIGNING <fs_extension2>.
              <fs_extension2>-param = lv_param."  - Constante
              <fs_extension2>-field = lv_field7.    "zul_aufl.
              <fs_extension2>-value = lv_zul_aufl."<fs_entr_det>-zul_aufl. "(debe ser único para todos)
            ENDIF.
*
*          APPEND INITIAL LINE TO lt_extension2 ASSIGNING <fs_extension2>.
*          <fs_extension2>-param = lv_param."  - Constante
*          <fs_extension2>-field = text-c01.    "INHALT
*          WRITE <fs_entr_det2>-laeng TO lw_texto1 DECIMALS 0 LEFT-JUSTIFIED .
*          WRITE <fs_entr_det2>-breit TO lw_texto2 DECIMALS 0 LEFT-JUSTIFIED.
*          WRITE <fs_entr_det2>-breit TO lw_texto3 DECIMALS 0 LEFT-JUSTIFIED.
*          CONCATENATE text-c02 lw_texto1 INTO lw_borgr_grp SEPARATED BY space.
*          CONCATENATE lw_borgr_grp 'X' lw_texto2 'X' lw_texto3 INTO lw_borgr_grp SEPARATED BY space.
*          <fs_extension2>-value = lw_borgr_grp.
          ENDIF.
        ENDIF.

        REFRESH lt_return2.

        CALL FUNCTION 'BAPI_INB_DELIVERY_CHANGE'
          EXPORTING
            header_data    = ls_header_data
            header_control = ls_header_control
            delivery       = lw_delivery
          TABLES
            item_data      = lt_item_data
            item_control   = lt_item_control
*           item_serial_no = lt_item_serial
            extension2     = lt_extension2
            return         = lt_return2.

        IF lt_return2 IS INITIAL.
          CALL FUNCTION 'BAPI_TRANSACTION_COMMIT'
            EXPORTING
              wait = 'X'.
*****Guarda texto cabecera  para dimensiones. revisar.
          IF lw_um = 'X'.
            l_save = abap_true. "Indicador de creación de texto nuevo (likp)

            PERFORM f_textos_dimensiones_likp
              TABLES
                 t_line
              USING
                 <fs_entrega_detalle>-delivery
                 l_save
                 <fs_entr_det2>-laeng
                 <fs_entr_det2>-breit
                 <fs_entr_det2>-hoehe
                   .
          ENDIF.
*       Verifica y actualiza confirmaciones
          SORT t_entr_det BY ebeln ebelp.
          LOOP AT t_entr_det ASSIGNING <fs_entr_det>.

*          READ TABLE ltd_ekes ASSIGNING FIELD-SYMBOL(<fs_ekes_hu>) WITH KEY ebeln = <fs_entr_det>-ebeln
*                                                                   ebelp = <fs_entr_det>-ebelp+1(5)
*                                                                   eindt = <fs_entr_det>-eindt.
**                                                                   menge = <fs_entrega_detalle>-deliv_qty.
*          IF sy-subrc = 0.

            READ TABLE ltd_ekpo ASSIGNING <fs_ekpo1> WITH KEY ebeln = <fs_entr_det>-ebeln
                                                              ebelp = <fs_entr_det>-ebelp+1(5).
            IF sy-subrc EQ 0 .
*            lw_menge = <fs_ekpo1>-menge - <fs_ekpo1>-wamng.
              lw_flagekes = <fs_ekpo1>-nodisp.
            ENDIF.
            lw_menge = <fs_entr_det>-menge.
            CLEAR: lw_etens.
            LOOP AT ltd_ekes ASSIGNING  FIELD-SYMBOL(<fs_ekes_hu>) WHERE ebeln = <fs_entr_det>-ebeln
                                                                     AND ebelp = <fs_entr_det>-ebelp+1(5)
                                                                     AND vbeln = ''.
              APPEND INITIAL LINE TO lt_uekes ASSIGNING FIELD-SYMBOL(<fs_uekes>).
              MOVE-CORRESPONDING <fs_ekes_hu> TO <fs_uekes>.
              <fs_uekes>-kz    = 'U'.
              IF lw_menge LT <fs_ekes_hu>-menge AND lw_menge GT 0.
                <fs_uekes>-menge = lw_menge.
                <fs_uekes>-xblnr = lw_delivery.
                IF <fs_ekpo1>-nodisp  = 'X'.
                  APPEND INITIAL LINE TO lt_uekes ASSIGNING <fs_uekes>.
                  MOVE-CORRESPONDING <fs_ekes_hu> TO <fs_uekes>.
                  <fs_uekes>-menge =  <fs_ekes_hu>-menge - lw_menge.
                  <fs_uekes>-kz    = 'U'.
                  IF lw_etens IS INITIAL.
                    SELECT MAX( etens ) INTO lw_etens FROM ekes WHERE ebeln = <fs_entr_det>-ebeln
                                                                 AND ebelp = <fs_entr_det>-ebelp+1(5).
                    IF sy-subrc = 0.
                      lw_etens = lw_etens + 1.
                      <fs_uekes>-etens = lw_etens.
                    ENDIF.
                  ELSE.
                    lw_etens = lw_etens + 1.
                    <fs_uekes>-etens = lw_etens.
                  ENDIF.
                ENDIF.
              ELSEIF lw_menge GE <fs_ekes_hu>-menge.
                <fs_uekes>-xblnr = lw_delivery.
              ENDIF.
              lw_menge = lw_menge - <fs_ekes_hu>-menge.
            ENDLOOP.
*          ENDIF.
            AT END OF ebeln.
*            DELETE ADJACENT DUPLICATES FROM lt_uekes COMPARING ebeln ebelp eindt.
              IF lt_uekes[] IS NOT INITIAL.
                CALL FUNCTION 'ME_CONFIRMATION_UPDATE'
                  EXPORTING
                    i_ebeln = <fs_entr_det>-ebeln "purchase ORDER NUMBER IS the KEY FOR the fumo(fuba)
                  TABLES
                    xekes   = lt_uekes.

                IF sy-subrc = 0.

                  CALL FUNCTION 'BAPI_TRANSACTION_COMMIT'
                    EXPORTING
                      wait   = 'X'
                    IMPORTING
                      return = ls_return2.

                  "Error en confirmación
                  IF ls_return2-type EQ 'E'.
                    CLEAR: g_msg.

                    PERFORM f_read_msg_error
                      USING
                        ls_return2
                      CHANGING
                         g_msg.

                    APPEND INITIAL LINE TO t_result ASSIGNING <fs_result>.
                    MOVE-CORRESPONDING ls_return2 TO <fs_result>.
                    <fs_result>-msg = g_msg.
                    g_error = abap_true. "@DL MEJORAS
                  ENDIF.

                ENDIF.

              ENDIF.
              FREE lt_uekes.
              CLEAR lt_uekes.
            ENDAT.
*+{@JY 15.03.2021
***          FREE:  lt_line.
***          CLEAR: wa_header,wa_line.
***
***          wa_line-tdline = <fs_entr_det>-tdline.
***          APPEND wa_line TO lt_line.
***
***          CONCATENATE <fs_entr_det>-ebeln
***                      <fs_entr_det>-ebelp
***                 INTO wa_header-tdname.
***
***          wa_header-tdobject = 'VBBP'.
***          wa_header-tdid     = 'Z003'.
***          wa_header-tdspras  = sy-langu.
***
***          CALL FUNCTION 'SAVE_TEXT'
***            EXPORTING
***              client          = sy-mandt
***              header          = wa_header
***              savemode_direct = 'X'
***            TABLES
***              lines           = lt_line
***            EXCEPTIONS
***              id              = 1
***              language        = 2
***              name            = 3
***              object          = 4
***              OTHERS          = 5.
*+}@JY 15.03.2021
          ENDLOOP.
        ELSE.
          "{@DL06082021.
          LOOP AT lt_return2 ASSIGNING <fs_ret2> WHERE type EQ 'E'.
            CLEAR: g_msg.
            APPEND INITIAL LINE TO t_result ASSIGNING <fs_result>.
            "Lectura del mensaje.
            PERFORM f_read_msg_error
              USING
                <fs_ret2>
              CHANGING
                g_msg
.
            MOVE-CORRESPONDING <fs_ret2> TO <fs_result>.
            <fs_result>-msg = g_msg.
            <fs_result>-codigo = <fs_ret2>-number.
            g_error = abap_true. "@DL MEJORAS

          ENDLOOP.
          "}@DL06082021.
        ENDIF.
************************************HU********************************************
        IF g_error EQ abap_false.
          IF lw_um NE 'X'.
            SELECT vbeln, posnr, charg, werks, lgort, vgbel, vgpos, LFIMG, meins, matnr
              FROM lips
              INTO TABLE
              @DATA(ltd_lips)
              FOR ALL ENTRIES IN @ltd_entr_det
              WHERE vbeln EQ @lw_delivery
                AND vgbel EQ @ltd_entr_det-ebeln
                AND charg NE @space. "@002+/02-09-2026-*************************************************************

            lt_entr_det_aux[] = t_entr_det[].

            SORT lt_entr_det_aux BY vhilm_ku ASCENDING."@001-RAVA-JJGD-Error Muutiples Bultos 14.10.2020

            DELETE ADJACENT DUPLICATES FROM lt_entr_det_aux COMPARING vhilm_ku.
            LOOP AT lt_entr_det_aux ASSIGNING FIELD-SYMBOL(<fs_entr_aux>).
              l_tabix_a = sy-tabix.

              READ TABLE ltd_ekpo ASSIGNING FIELD-SYMBOL(<fs_ekpo3>) WITH KEY ebeln = <fs_entr_aux>-ebeln  ebelp = <fs_entr_aux>-ebelp.
              IF sy-subrc EQ 0 .
                READ TABLE ltd_t001l ASSIGNING FIELD-SYMBOL(<fs_t001l3>) WITH KEY werks = <fs_ekpo3>-werks lgort = <fs_ekpo3>-lgort.
                IF sy-subrc EQ 0.
*                IF  <fs_t001l3>-xhupf NE space. "-@001
                  IF  <fs_t001l3>-lgort IN gr_lgort_tr. " '0230'. "+@001
                    CLEAR: ls_headerproposal.
                    IF lv_bsart NE lv_e_bsart. "Caso reparaciones "+@001
                      ls_headerproposal-hu_status_init    = lv_status.
                    ENDIF.
*                ls_headerproposal-pack_mat          = lv_packmt. "-@001
*{+@001
                    READ TABLE lt_pack_mat ASSIGNING <fs_pack_mat>
                                            WITH KEY vegr2 = <fs_entr_aux>-vegr2.
                    IF sy-subrc EQ 0.
                      ls_headerproposal-pack_mat = <fs_pack_mat>-pack_mat.
                    ENDIF.
*}+@001
                    ls_headerproposal-plant             = <fs_ekpo3>-werks.
                    ls_headerproposal-stge_loc          = <fs_ekpo3>-lgort.
                    ls_headerproposal-hu_grp2           = <fs_entr_aux>-vegr2.
                    ls_headerproposal-content           = <fs_entr_aux>-inhalt.
*              ls_headerproposal-total_wght        = <fs_entr_aux>-brgew.
                    ls_headerproposal-pack_mat_customer = <fs_entr_aux>-vhilm_ku.
*              ls_headerproposal-length            = <fs_entr_aux>-laeng.
*              ls_headerproposal-width              = <fs_entr_aux>-breit.
*              ls_headerproposal-height            = <fs_entr_aux>-hoehe.
                    REFRESH lt_return2.
                    CALL FUNCTION 'BAPI_HU_CREATE'
                      EXPORTING
                        headerproposal = ls_headerproposal
                      IMPORTING
                        huheader       = ls_huheader
                        hukey          = lw_hukey
                      TABLES
                        return         = lt_return2.
                    IF lt_return2 IS INITIAL.
                      CALL FUNCTION 'BAPI_TRANSACTION_COMMIT'
                        EXPORTING
                          wait = 'X'.

*                  CLEAR: ls_huheader.

*                  ls_huheader-pack_mat_object  = lv_matobj. "-@001
*                  ls_huheader-pack_mat_obj_key = lw_delivery. "-@001
*{+@001
                      IF lv_bsart NE lv_e_bsart. "Si EKKO-BSART ne "ZREP" "Caso reparaciones
                        ls_huheader-pack_mat_object  = lv_matobj.
                        ls_huheader-pack_mat_obj_key = lw_delivery.
                      ENDIF.
*}+@001
                      ls_huheader-total_wght       = <fs_entr_aux>-brgew.   "
                      ls_huheader-lenght           = <fs_entr_aux>-laeng.
                      ls_huheader-width	           = <fs_entr_aux>-breit.
                      ls_huheader-height           = <fs_entr_aux>-hoehe.
                      ls_huheader-permiss_workload = <fs_entr_aux>-zul_aufl.
                      ls_huheader-unit_dim         = 'CM'.
                      REFRESH lt_return2.
                      CALL FUNCTION 'BAPI_HU_CHANGE_HEADER'
                        EXPORTING
                          hukey     = lw_hukey
                          huchanged = ls_huheader
                        IMPORTING
                          huheader  = ls_huheader
                        TABLES
                          return    = lt_return2.

                      IF lt_return2 IS INITIAL.
                        CALL FUNCTION 'BAPI_TRANSACTION_COMMIT'
                          EXPORTING
                            wait = 'X'.
*                    WAIT UP TO 2 SECONDS.
*{+@001
                        IF lv_bsart NE lv_e_bsart. "Caso reparaciones - Si no es 'ZREP'
*}+@001
                          lw_hu_id = lw_delivery.
                          CLEAR ls_ref_object.
                          ls_ref_object-object = lv_objct1.
                          ls_ref_object-objkey = lw_delivery.
                          CLEAR ls_hu_header_main.
                          ls_hu_header_main-exidv = ls_huheader-hu_exid.
                          ls_hu_header_main-vhilm = ls_huheader-pack_mat.

                          CLEAR ls_mm_data.
                          ls_mm_data-plant    = <fs_ekpo3>-werks.
                          ls_mm_data-stge_loc = <fs_ekpo3>-lgort.

                          LOOP AT t_entr_det ASSIGNING FIELD-SYMBOL(<fs_entr_det3>)
                                             WHERE vhilm_ku = <fs_entr_aux>-vhilm_ku.
                            " l_tabix_b = sy-tabix.    "*@002-/02-09-2026********************
*                                  READ TABLE ltd_lips ASSIGNING FIELD-SYMBOL(<fs_lips>)          "*@002-/02-09-2026********************
*                                                      WITH  KEY vgbel = <fs_entr_det3>-ebeln       "*@002-/02-09-2026********************
*                                                                vgpos = <fs_entr_det3>-ebelp.    "*@002-/02-09-2026********************
                            LOOP AT  ltd_lips ASSIGNING FIELD-SYMBOL(<fs_lips>) WHERE  vgbel = <fs_entr_det3>-ebeln  AND vgpos = <fs_entr_det3>-ebelp .


                              CLEAR ls_item_proposal.
                              ls_item_proposal-exidv    = ls_huheader-hu_exid.
                              ls_item_proposal-velin    = '1'.
                              ls_item_proposal-quantity = <fs_lips>-LFIMG. "<fs_entr_det3>-menge.
                              ls_item_proposal-meins    = <fs_lips>-meins. "<fs_entr_det3>-meins.
                              ls_item_proposal-matnr    = <fs_lips>-matnr.  "<fs_entr_det3>-matnr.
*{+001
                              IF <fs_lips>-charg IS INITIAL.
                                APPEND INITIAL LINE TO t_result ASSIGNING <fs_result>.
                                CONCATENATE 'Error en embalaje de entrega:' lw_delivery
                                INTO <fs_result>-msg SEPARATED BY space.
                                <fs_result>-codigo = '000'.
                                <fs_result>-type = 'E'.
                                g_error = abap_true.
                                EXIT.
                              ENDIF.
*}+001
                              ls_item_proposal-charg    = <fs_lips>-charg.
                              ls_item_proposal-werks    = <fs_lips>-werks.
                              ls_item_proposal-lgort    = <fs_lips>-lgort.
                              ls_item_proposal-belnr    = lw_delivery.
                              ls_item_proposal-posnr    = <fs_lips>-posnr.

                              CALL FUNCTION 'PROCESS_HU_INBOUND_DLVRY'
                                EXPORTING
                                  i_hu_id               = lw_hu_id
                                  i_new_hu              = space
                                  i_update_db           = 'X'
                                  i_reference_object    = ls_ref_object
                                  i_mm_data             = ls_mm_data
                                  i_hu_header_main      = ls_hu_header_main
                                  i_save_step           = lv_svstep
                                  i_pack_activity       = lv_packm2
                                  i_delivery_type       = lv_dlvryt
                                  i_packing_activity    = lv_packat
                                  i_pack_type           = lv_packty
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
                                CALL FUNCTION 'BAPI_TRANSACTION_COMMIT'
                                  EXPORTING
                                    wait = 'X'.
                                "@DL{ "carga embalaje complementario.
                                IF gt_emb_compl IS NOT INITIAL.
                                  APPEND INITIAL LINE TO gt_hucomple ASSIGNING FIELD-SYMBOL(<fs_hucomple>).
                                  <fs_hucomple>-exidv = ls_huheader-hu_exid.
                                  <fs_hucomple>-vhilm_ku = <fs_entr_det3>-vhilm_ku.
                                ENDIF.


                                "Actualiza peso de bulto
                                PERFORM act_venum USING  ls_huheader-hu_exid
                                                         <fs_entr_det3>-brgew.
                                "@DL}
*                        "MP{
*                        CALL FUNCTION 'CONVERSION_EXIT_ALPHA_OUTPUT'
*                          EXPORTING
*                            input  = lw_delivery
*                          IMPORTING
*                            output = lw_delivery.
*                        "MP}
                                ls_result-codigo = '000'.
                                CONCATENATE 'Se creó la entrega: ' lw_delivery
                                INTO ls_result-msg RESPECTING BLANKS.
                                APPEND ls_result TO t_result.
                                lv_zzlfstk = '04'.                                "INSERT @JGRS
                                "Actualiza tablas de entrega no HU y embalajes complementario.
                                PERFORM f_act_entre_nohu_compl TABLES lt_detalle_aux "t_entr_det
                                                                     ltd_entrega_detalle
                                                              USING lw_delivery
                                                                    lv_zzlfstk.   "INSERT @JGRS


                              ELSE.

                                APPEND INITIAL LINE TO t_result ASSIGNING <fs_result>.
                                CONCATENATE 'Error en embalaje de entrega:' lw_delivery
                                INTO <fs_result>-msg SEPARATED BY space.
                                <fs_result>-codigo = '000'.
                                <fs_result>-type = 'E'.
                                g_error = abap_true. "@DL MEJORAS

                              ENDIF.
                            ENDLOOP. "*@002+/02-09-2026********************
                          ENDLOOP.
*{+@001
                        ELSE. "Caso reparaciones

                          ls_result-codigo = '000'.
                          CONCATENATE 'Se creó la entrega: ' lw_delivery
                          INTO ls_result-msg RESPECTING BLANKS.
                          APPEND ls_result TO t_result.

                          ls_entr_cab-vbeln = lw_delivery.
                          lv_zzlfstk = '04'.
                          PERFORM f_actualiza_entrega_cab TABLES lt_return2
                                                          USING ls_entr_cab
                                                                lv_param
                                                                lv_zzlfstk.
                          "Actualiza tablas de entrega no HU y embalajes complementario.
                          PERFORM f_act_entre_reparaciones TABLES lt_detalle_aux "t_entr_det
                                                                  ltd_entrega_detalle
                                                        USING lw_delivery
                                                              lv_zzlfstk
                                                              ls_huheader-hu_exid
                                                              <fs_entr_aux>.
                        ENDIF.
*}+@001
                        "@DL { MEJORAS.
                        "Cambia status de 08 a 04 si no hubo ningún error.
                        IF g_error EQ abap_false.
                          IF lv_bsart NE lv_e_bsart. "Caso reparaciones
                            ls_entr_cab-vbeln = lw_delivery.
                            lv_zzlfstk = '04'.
                            ls_entr_cab-anzpk = lw_anzpk.
                            PERFORM f_actualiza_entrega_cab TABLES lt_return2
                                                             USING ls_entr_cab
                                                                   lv_param
                                                                   lv_zzlfstk.
                          ENDIF.
                        ENDIF.
                        "@DL } MEJORAS.

                      ELSE. "Error change_hu
                        "{@DL06082021.
                        LOOP AT lt_return2 ASSIGNING <fs_ret2> WHERE type EQ 'E'.
                          CLEAR: g_msg.
                          APPEND INITIAL LINE TO t_result ASSIGNING <fs_result>.
                          "Lectura del mensaje.
                          PERFORM f_read_msg_error
                            USING
                              <fs_ret2>
                            CHANGING
                              g_msg.
                          MOVE-CORRESPONDING <fs_ret2> TO <fs_result>.
                          <fs_result>-msg = g_msg.
                          g_error = abap_true. "@DL MEJORAS

                        ENDLOOP.
*{+001
                        LOOP AT lt_return2 ASSIGNING <fs_ret2>.
                          CLEAR: g_msg.
                          APPEND INITIAL LINE TO t_result ASSIGNING <fs_result>.
                          "Lectura del mensaje.
                          PERFORM f_read_msg_error
                            USING
                              <fs_ret2>
                            CHANGING
                              g_msg.
                          MOVE-CORRESPONDING <fs_ret2> TO <fs_result>.
                          <fs_result>-msg = g_msg.
                          g_error = abap_true. "@DL MEJORAS

                        ENDLOOP.
*}+001
                        "}@DL06082021.
                      ENDIF.

                    ELSE. "Error create_hu
                      "{@DL06082021.
                      LOOP AT lt_return2 ASSIGNING <fs_ret2> WHERE type EQ 'E'.
                        CLEAR: g_msg.
                        APPEND INITIAL LINE TO t_result ASSIGNING <fs_result>.
                        "Lectura del mensaje.
                        PERFORM f_read_msg_error
                          USING
                            <fs_ret2>
                          CHANGING
                            g_msg.

                        MOVE-CORRESPONDING <fs_ret2> TO <fs_result>.
                        <fs_result>-msg = g_msg.
                        g_error = abap_true. "@DL MEJORAS

                      ENDLOOP.

                      "}@DL06082021.
                    ENDIF.

                  ENDIF.
                ENDIF.
              ENDIF.

            ENDLOOP.
          ELSEIF lw_delivery IS NOT INITIAL.
            ls_result-codigo = '000'.
            "Cambia status de 08 a 04 si no hubo ningún error.
            lv_zzlfstk = '04'.                                 "INSERT @JGRS
            "Actualiza tablas de entrega no HU y embalajes complementario.
            PERFORM f_act_entre_nohu_compl TABLES lt_detalle_aux "t_entr_det
                                                 ltd_entrega_detalle
                                          USING lw_delivery
                                                lv_zzlfstk.   "INSERT @JGRS
*                                               lt_emb_compl.

            "@DL { MEJORAS.
            "Cambia status de 08 a 04 si no hubo ningún error.
            ls_entr_cab-vbeln = lw_delivery.
*         lv_zzlfstk = '04'.                                "DELETE @JGRS
            PERFORM f_actualiza_entrega_cab TABLES lt_return2
                                            USING ls_entr_cab
                                                  lv_param
                                                  lv_zzlfstk.
            "@DL } MEJORAS.

*        "MP{
*        CALL FUNCTION 'CONVERSION_EXIT_ALPHA_OUTPUT'
*          EXPORTING
*            input  = lw_delivery
*          IMPORTING
*            output = lw_delivery.
*        "MP}
            CONCATENATE 'Se creó la entrega: ' lw_delivery
            INTO ls_result-msg RESPECTING BLANKS.
            APPEND ls_result TO t_result.
          ENDIF.
        ELSE.
        ENDIF.
************************************HU********************************************

        CONCATENATE 'Se creó la entrega: ' lw_delivery
        INTO ls_result-msg RESPECTING BLANKS.
        APPEND ls_result TO t_result.
      ENDIF.
    ELSE.
      READ TABLE ltd_ekpo ASSIGNING FIELD-SYMBOL(<f_ekp>) INDEX 1.
      IF sy-subrc EQ 0.
        CONCATENATE 'El documento' <f_ekp>-ebeln 'no tiene almacén'
                    INTO ls_result-msg SEPARATED BY space.
        ls_result-codigo = '901'.
        APPEND ls_result TO t_result.
      ENDIF.
    ENDIF.
  ENDIF.
  "@DL { MEJORAS.
  "Error general creación de entrega, Se elimina la entrega creada en pasos anteriores.
  IF g_error EQ abap_true.

    CALL FUNCTION 'ZBVMM_OC_ELIM_ENTR_ERROR'
      EXPORTING
        i_vbeln  = lw_delivery
      TABLES
        t_result = lt_result.

    LOOP AT lt_result ASSIGNING FIELD-SYMBOL(<fs_res_elim>).
      APPEND INITIAL LINE TO t_result ASSIGNING <fs_result>.
      MOVE-CORRESPONDING <fs_res_elim> TO <fs_result>.
      <fs_result>-msg = TEXT-046.
    ENDLOOP.
*{+@001
  ELSE. "Escenario: Mov. 103 Importaciones
    IF lv_bsart EQ 'ZBIM'.
      DATA: wa_goodsmvt_header TYPE bapi2017_gm_head_01,
            wa_goodsmvt_code   TYPE bapi2017_gm_code,
            lt_goodsmvt_item   TYPE STANDARD TABLE OF bapi2017_gm_item_create,
            lt_goodsmvt_return TYPE STANDARD TABLE OF bapiret2.

      SELECT k~vbeln, k~lfdat,
             s~matnr, s~werks, s~lgort, s~lfimg, s~vrkme, "s~meins,
        s~posnr
      FROM lips AS s
          INNER JOIN likp AS k ON ( k~vbeln EQ s~vbeln )
        INTO TABLE @DATA(lt_lips)
       FOR ALL ENTRIES IN  @ltd_entr_det
       WHERE k~vbeln EQ @lw_delivery
         AND s~vgbel EQ @ltd_entr_det-ebeln.
      IF sy-subrc EQ 0.

        wa_goodsmvt_code = '01'.

        CLEAR: wa_goodsmvt_header.
        FREE: lt_goodsmvt_item, lt_goodsmvt_return.

*          wa_goodsmvt_header-pstng_date = <fs_likp>-lfdat.
*          wa_goodsmvt_header-doc_date   = <fs_likp>-lfdat.
        wa_goodsmvt_header-ref_doc_no = lw_delivery.
        LOOP AT lt_lips ASSIGNING FIELD-SYMBOL(<fs_likp>).
          APPEND INITIAL LINE TO lt_goodsmvt_item ASSIGNING FIELD-SYMBOL(<fs_good_item>).
          <fs_good_item>-material = <fs_likp>-matnr.
          <fs_good_item>-plant    = <fs_likp>-werks.
          <fs_good_item>-stge_loc = <fs_likp>-lgort.
          <fs_good_item>-move_type = '103'.
          <fs_good_item>-entry_qnt = <fs_likp>-lfimg.
          <fs_good_item>-entry_uom = <fs_likp>-vrkme. "meins.
          <fs_good_item>-mvt_ind   = 'B'.
          <fs_good_item>-deliv_numb_to_search = <fs_likp>-vbeln.
          <fs_good_item>-deliv_item_to_search = <fs_likp>-posnr.
          wa_goodsmvt_header-pstng_date = <fs_likp>-lfdat.
          wa_goodsmvt_header-doc_date   = <fs_likp>-lfdat.
        ENDLOOP.
        CALL FUNCTION 'BAPI_GOODSMVT_CREATE'
          EXPORTING
            goodsmvt_header = wa_goodsmvt_header
            goodsmvt_code   = wa_goodsmvt_code
          TABLES
            goodsmvt_item   = lt_goodsmvt_item
            return          = lt_goodsmvt_return.

        READ TABLE lt_goodsmvt_return ASSIGNING FIELD-SYMBOL(<fs_good_return>) WITH KEY type = 'E'.
        IF sy-subrc EQ 0.

          APPEND INITIAL LINE TO t_result ASSIGNING <fs_result>.
          <fs_result>-codigo = <fs_good_return>-number.
          <fs_result>-type   = <fs_good_return>-type.
          <fs_result>-msg    = <fs_good_return>-message.

          FREE: lt_result.
          CALL FUNCTION 'ZBVMM_OC_ELIM_ENTR_ERROR'
            EXPORTING
              i_vbeln  = lw_delivery
            TABLES
              t_result = lt_result.

          LOOP AT lt_result ASSIGNING <fs_res_elim>.
            APPEND INITIAL LINE TO t_result ASSIGNING <fs_result>.
            MOVE-CORRESPONDING <fs_res_elim> TO <fs_result>.
            <fs_result>-msg = TEXT-046.
          ENDLOOP.

        ELSE.
          CALL FUNCTION 'BAPI_TRANSACTION_COMMIT'
            EXPORTING
              wait = 'X'.
        ENDIF.

      ENDIF.
    ENDIF.
*}+@001
  ENDIF.
  "@DL } MEJORAS.



ENDFUNCTION.
