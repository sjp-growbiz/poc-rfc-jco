METHOD custome_create_deep_entity.
    TYPES:
      BEGIN OF typ_header,
        zflag TYPE char10,
        lfdat	TYPE lfdat,
        lfuhr	TYPE lfuhr,
        anzpk	TYPE anzpk,
      END OF typ_header .

    TYPES:
      BEGIN OF typ_item,
        vhilm_ku TYPE	vhilm_ku,
        lfdat	   TYPE	lfdat,
        laeng	   TYPE	laeng,
        breit	   TYPE	breit,
        hoehe	   TYPE	hoehe,
        inhalt   TYPE inhalt,
        brgew	   TYPE	brgew,
        vegr2	   TYPE	vegr2,
        zul_aufl TYPE pl_maxstwe,
        ebeln	   TYPE	vgbel,
        ebelp	   TYPE	vgpos,
        matnr	   TYPE	matnr,
        tdline   TYPE tdline, "+@JY 15.03.2021
        menge	   TYPE	bstmg,
        meins	   TYPE	bstme,
        eindt    TYPE eindt,
      END OF typ_item .

    TYPES:
      BEGIN OF typ_result,
        codigo TYPE symsgno,
        msg    TYPE bapi_msg,
      END OF typ_result .

    DATA: ir_deep_entity TYPE                    zcl_zbvmm_web_oc_guard_mpc_ext=>ts_deep_entity,
          it_rfc_header  TYPE STANDARD TABLE OF  typ_header,
          it_rfc_item    TYPE TABLE OF           typ_item,
          it_det_lot     TYPE  ZBVMM_TT_GUARDAR_ENTREGA_DET_M, "*@002+/02-09-2026********************
          it_rfc_pedidotext TYPE STANDARD TABLE OF zbvmm_st_txtposicionpedido,
          it_rfc_result  TYPE STANDARD TABLE OF  zbvmm_st_result, "typ_result,
          lt_txtmaterial TYPE STANDARD TABLE OF  zbvmm_st_txtmaterialpos, "+@JY 15.03.2021
          wa_resultset   TYPE                    zcl_zbvmm_web_oc_guard_mpc_ext=>ts_zetresultado,
          wa_item        TYPE                    zcl_zbvmm_web_oc_guard_mpc_ext=>ts_zetdetalle,
          lv_date        TYPE string.


*Recepción de datos de entrada
    io_data_provider->read_entry_data(
    IMPORTING
     es_data = ir_deep_entity ).

* Extraer datos de la cabecera  Entity 'Header'
    APPEND INITIAL LINE TO it_rfc_header ASSIGNING FIELD-SYMBOL(<fs_header>).
    <fs_header>-lfdat	= ir_deep_entity-lfdat.
    <fs_header>-lfuhr = ir_deep_entity-lfuhr.
    <fs_header>-anzpk	= ir_deep_entity-anzpk.

* Extraer detalle de posiciones Entity 'Item' (tabulabr input fields)
    LOOP AT ir_deep_entity-zdetalle ASSIGNING FIELD-SYMBOL(<fs_item>)."zetdetalleentregaset ASSIGNING FIELD-SYMBOL(<fs_item>).
      APPEND INITIAL LINE TO it_rfc_item ASSIGNING FIELD-SYMBOL(<fs_item_rfc>).
      <fs_item_rfc>-vhilm_ku = <fs_item>-vhilm_ku.
      <fs_item_rfc>-lfdat	   = <fs_item>-lfdat.
      <fs_item_rfc>-laeng	   = <fs_item>-laeng.
      <fs_item_rfc>-breit	   = <fs_item>-breit.
      <fs_item_rfc>-hoehe	   = <fs_item>-hoehe.
      <fs_item_rfc>-inhalt   = <fs_item>-inhalt.
      <fs_item_rfc>-brgew  	 = <fs_item>-brgew.
      <fs_item_rfc>-vegr2  	 = <fs_item>-vegr2.
      <fs_item_rfc>-zul_aufl = <fs_item>-zul_aufl.
      <fs_item_rfc>-ebeln    = <fs_item>-ebeln.
      <fs_item_rfc>-ebelp    = <fs_item>-ebelp.
      <fs_item_rfc>-matnr    = <fs_item>-matnr.
      <fs_item_rfc>-tdline   = <fs_item>-tdline. "+@JY 15.03.2021
      <fs_item_rfc>-menge    = <fs_item>-menge.
      <fs_item_rfc>-meins    = <fs_item>-meins.
      <fs_item_rfc>-eindt    = <fs_item>-eindt.
*@002+/INI/02-09-2026-*************************************************************
      IF  <fs_item>-zdetallelot[] IS NOT INITIAL.
        LOOP AT <fs_item>-zdetallelot ASSIGNING  FIELD-SYMBOL(<fs_zdetallelot>).
          APPEND VALUE #( EBELN   = <fs_item>-ebeln
                          EBELP   = <fs_item>-ebelp
                          VHILMLT = <fs_zdetallelot>-VHILMLT
                          LTVFDAT = <fs_zdetallelot>-LTVFDAT
                           LTMENGE = <fs_zdetallelot>-ltmenge ) TO it_det_lot.
        ENDLOOP.
      ENDIF.
*@002+/END/02-09-2026-*************************************************************
    ENDLOOP.

 "Extraer textos para posiciones.
 LOOP AT ir_deep_entity-zetpedidotextset ASSIGNING FIELD-SYMBOL(<fs_pedtext>).
   APPEND INITIAL LINE TO it_rfc_pedidotext ASSIGNING FIELD-SYMBOL(<fs_text>).
   MOVE-CORRESPONDING <fs_pedtext> TO <fs_text>.
 ENDLOOP.

    SORT it_det_lot BY ebeln ebelp ASCENDING.
    IF it_rfc_header IS NOT INITIAL  AND it_rfc_item IS NOT INITIAL.

      CALL FUNCTION 'ZBVMM_OC_GUARDAR_ENTREGAV2'
        TABLES
          t_entr_cab     = it_rfc_header
          t_entr_det     = it_rfc_item
          t_entr_det_lot = it_det_lot         "*@002+/02-09-2026********************
          t_pedidotext   = it_rfc_pedidotext
          t_result       = it_rfc_result.
      IF it_rfc_result IS NOT INITIAL.
        "**Exportar data de salida EntitySet 'ResultSet'
        LOOP AT it_rfc_result ASSIGNING FIELD-SYMBOL(<fs_result>).
          "Devuelve el resultado a Entity 'RESULT' via 'NavigationProperty=NAVRESULT'
          wa_resultset-codigo = <fs_result>-codigo.
          wa_resultset-msg = <fs_result>-msg.
          wa_resultset-type = <fs_result>-type.
          APPEND wa_resultset TO er_deep_entity-zetresultadoset. CLEAR wa_resultset.
        ENDLOOP.
        COMMIT WORK.
      ENDIF.

    ENDIF.
  ENDMETHOD.
