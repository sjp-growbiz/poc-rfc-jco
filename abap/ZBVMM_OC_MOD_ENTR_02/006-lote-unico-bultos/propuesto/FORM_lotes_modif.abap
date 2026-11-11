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

*{+@006 Un lote nuevo repartido en varios bultos llega como varias filas con
*       el mismo vencimiento (una por bulto). Se crea un solo lote por
*       vencimiento y posición; las demás filas lo reutilizan.
  TYPES: BEGIN OF lty_nuevo,
           ltvfdat TYPE zbvmm_st_guardar_entrega_det_m-ltvfdat,
           posnr   TYPE lips-posnr,
           charg   TYPE charg_d,
           idx     TYPE sy-tabix,          "fila en ct_item_data
         END OF lty_nuevo.
  DATA: lt_nuevo  TYPE STANDARD TABLE OF lty_nuevo,
        lt_fechas TYPE STANDARD TABLE OF zbvmm_st_guardar_entrega_det_m-ltvfdat
                  WITH DEFAULT KEY.
*}+@006

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
    CLEAR: lt_nuevo, lt_fechas.                   "+@006

    LOOP AT it_lot ASSIGNING FIELD-SYMBOL(<fs_lot>)
                   WHERE ebeln EQ <fs_pos>-vgbel
                     AND ebelp EQ <fs_pos>-vgpos.
      lv_hay_lotes = abap_true.
      "+@006 Lotes nuevos con el mismo vencimiento son UN lote (en varios
      "bultos): cuentan una vez. Decide si el lote va en la posición padre.
      IF <fs_lot>-posnr IS INITIAL.                                   "+@006
        READ TABLE lt_fechas TRANSPORTING NO FIELDS                   "+@006
             WITH KEY table_line = <fs_lot>-ltvfdat.                  "+@006
        IF sy-subrc EQ 0.                                             "+@006
          CONTINUE.                                                   "+@006
        ENDIF.                                                        "+@006
        APPEND <fs_lot>-ltvfdat TO lt_fechas.                         "+@006
      ENDIF.                                                          "+@006
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

*{+@006 Mismo vencimiento que un lote nuevo ya preparado para esta posición:
*       es el mismo lote en otro bulto. No se crea otro lote ni otra
*       subposición: se suma la cantidad a la línea ya preparada y se
*       registra la parte de este bulto para el embalaje.
      READ TABLE lt_nuevo ASSIGNING FIELD-SYMBOL(<fs_nuevo>)
           WITH KEY ltvfdat = <fs_lot>-ltvfdat.
      IF sy-subrc EQ 0.
        READ TABLE ct_item_data ASSIGNING FIELD-SYMBOL(<fs_id_nuevo>)
             INDEX <fs_nuevo>-idx.
        IF sy-subrc EQ 0.
          <fs_id_nuevo>-dlv_qty = <fs_id_nuevo>-dlv_qty + <fs_lot>-ltmenge.
        ENDIF.
        <fs_lot>-charg = <fs_nuevo>-charg.
        <fs_lot>-posnr = <fs_nuevo>-posnr.
        IF <fs_lot>-vhilmlt IS NOT INITIAL.
          APPEND VALUE #( posnr    = <fs_lot>-posnr
                          vhilm_ku = <fs_lot>-vhilmlt
                          cant     = <fs_lot>-ltmenge ) TO gt_lote_bulto.
        ENDIF.
        CONTINUE.
      ENDIF.
*}+@006

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
      "+@006 Para que las demás filas del mismo vencimiento lo reutilicen.
      APPEND VALUE #( ltvfdat = <fs_lot>-ltvfdat
                      posnr   = <fs_lot>-posnr
                      charg   = lv_charg
                      idx     = lines( ct_item_data[] ) ) TO lt_nuevo.
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
