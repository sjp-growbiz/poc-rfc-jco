FUNCTION ZBVMM_OC_MOD_ENTR_02.
*"----------------------------------------------------------------------
*"*"Interfase local
*"  EXPORTING
*"     REFERENCE(E_MESSAGE) TYPE  BAPI_MSG
*"  TABLES
*"      T_ENTR_CAB TYPE  ZBVMM_TT_MODIFICAR_ENTREGA
*"      T_ENTR_DET TYPE  ZBVMM_TT_MODIFICAR_ENTREGA_DET
*"      T_RESULT TYPE  ZBVMM_TT_CONFIRMAR_RESULTADO
*"      T_ENTR_LOT TYPE  ZBVMM_TT_GUARDAR_ENTREGA_DET_M
*"----------------------------------------------------------------------
*&----------------------------------------------------------------------&*
* Autor      : Keny Luy - NTT Data
* Descripción: WB-FI: QUIPU S4 HANA Migración
* Fecha      : 17.11.2023  Marca: @001
*&----------------------------------------------------------------------&*
* Marca: @004  Fecha: 16.10.2026  Multilote en modificación de entrega
* - T_ENTR_LOT llega a los FORMs (gt_entr_lot); antes se ignoraba.
* - Estado global limpio en cada llamada.
* - Validación previa: por posición, suma de lotes = suma de bultos.
* - LIPS con unidad de venta (VRKME) y releída tras crear subposiciones.
* - Si la llamada falla, los lotes creados en ella y que no quedaron en
*   la entrega se marcan para borrado.
*&----------------------------------------------------------------------&*
  TYPES: BEGIN OF ty_lips,
           vbeln TYPE lips-vbeln,
           posnr TYPE lips-posnr,
           matnr TYPE lips-matnr,
           charg TYPE lips-charg,
           werks TYPE lips-werks,
           lgort TYPE lips-lgort,
           lfimg TYPE lips-lfimg,
           meins TYPE lips-meins,
           vgbel TYPE lips-vgbel,
           vgpos TYPE lips-vgpos,
           umvkz TYPE lips-umvkz,
           flag  TYPE abap_bool,
         END OF ty_lips.

  DATA: ls_header_data    TYPE bapiibdlvhdrchg,
        ls_header_control TYPE bapiibdlvhdrctrlchg,
        ls_headerproposal TYPE bapihuhdrproposal,
        ls_huheader       TYPE bapihuheader,
        ls_ref_object     TYPE hum_object,
        ls_hu_header_main TYPE huhdr_proposal,
        ls_mm_data        TYPE hum_plant_stloc,
        ls_item_proposal  TYPE huitm_proposal,
        ls_result         TYPE zbvmm_st_result,
        lw_btgew          TYPE likp-btgew,    "Peso total
        lw_brgew          TYPE vekp-brgew,    "Peso por bulto
        lw_anzpk          TYPE likp-anzpk,    "Nro. de bultos
        lw_um             TYPE char01,        "Gestion de unidades
        lw_borgr_grp      TYPE likp-borgr_grp,
        lw_texto1         TYPE char10,
        lw_texto2         TYPE char10,
        lw_texto3         TYPE char10,
        i_msg             TYPE natxt,
        l_error           TYPE abap_bool,
        ltd_lips2         TYPE STANDARD TABLE OF ty_lips,
        l_save            TYPE abap_bool,
        t_line            TYPE tlinet.

  DATA: lw_hukey TYPE bapihukey-hu_exid,
        lw_hu_id TYPE rlmob-clenum.

  DATA: lt_item_data     TYPE STANDARD TABLE OF bapiibdlvitemchg,
        lt_item_control  TYPE STANDARD TABLE OF bapiibdlvitemctrlchg,
        lt_entr_det_aux  TYPE STANDARD TABLE OF zbvmm_st_modificar_entrega_det,
        lt_extension2    TYPE STANDARD TABLE OF  bapiext,
        lwa_item_data    TYPE bapiibdlvitemchg,
        lwa_item_control TYPE bapiibdlvitemctrlchg,
        lt_return        TYPE STANDARD TABLE OF bapiret2.
  DATA: lv_param  TYPE ZGE_T_CONSTANTES-low. "ztconstantes-valor_low.

  DATA: ltd_entr_det2 TYPE STANDARD TABLE OF zbvmm_st_modificar_entrega_det.

*{+@004
  TYPES: BEGIN OF lty_cuadre,
           ebeln TYPE vbelv,
           ebelp TYPE posnv,
           bulto TYPE vhilm_ku,
           cant  TYPE bstmg,
         END OF lty_cuadre,
         BEGIN OF lty_map,
           raw TYPE sy-tabix,      "fila en T_ENTR_LOT
           gt  TYPE sy-tabix,      "fila en gt_entr_lot
         END OF lty_map.
  DATA: lt_lot_pos  TYPE SORTED TABLE OF lty_cuadre WITH UNIQUE KEY ebeln ebelp bulto,
        lt_lot_bul  TYPE SORTED TABLE OF lty_cuadre WITH UNIQUE KEY ebeln ebelp bulto,
        lt_det_pos  TYPE SORTED TABLE OF lty_cuadre WITH UNIQUE KEY ebeln ebelp bulto,
        lt_det_bul  TYPE SORTED TABLE OF lty_cuadre WITH UNIQUE KEY ebeln ebelp bulto,
        lt_sin_bul  TYPE SORTED TABLE OF lty_cuadre WITH UNIQUE KEY ebeln ebelp bulto,
        ls_cuadre   TYPE lty_cuadre,
        ls_otro     TYPE lty_cuadre,
        lt_map      TYPE STANDARD TABLE OF lty_map,
        lv_tabix    TYPE sy-tabix,
        lv_n_sub    TYPE i,
        lv_cant_sub TYPE lfimg,
        lwa_battr   TYPE bapibatchatt,
        lwa_battrx  TYPE bapibatchattx.

  "Estado global del grupo: no arrastrar datos de otra llamada en la sesión.
  CLEAR: gr_lgort_tr, gt_entr_lot, gt_lotes_mod_creados, gv_lotes_mod_hechos,
         gt_lote_bulto, gt_hucomple, gt_ekpo02, gt_t001l02, gt_likp, gt_lips02.

  "Lotes de la trama -> gt_entr_lot, que es lo que leen los FORMs (antes
  "T_ENTR_LOT no se copiaba y la lógica de lotes no se ejecutaba nunca).
  "  - Lote nuevo (sin POSNR): una fila por cada fila de la trama.
  "  - Lote existente (con POSNR): una sola fila por POSNR sumando todos sus
  "    bultos; el reparto por bulto queda en gt_lote_bulto para el embalaje.
  "    (Los lotes nuevos los agrega lotes_modif al crearlos.)
  LOOP AT t_entr_lot ASSIGNING FIELD-SYMBOL(<fs_tl>).
    lv_tabix = sy-tabix.
    IF <fs_tl>-posnr IS INITIAL.
      APPEND <fs_tl> TO gt_entr_lot.
      APPEND VALUE #( raw = lv_tabix gt = lines( gt_entr_lot ) ) TO lt_map.
    ELSE.
      READ TABLE gt_entr_lot ASSIGNING FIELD-SYMBOL(<fs_gl>)
           WITH KEY ebeln = <fs_tl>-ebeln
                    ebelp = <fs_tl>-ebelp
                    posnr = <fs_tl>-posnr.
      IF sy-subrc EQ 0.
        <fs_gl>-ltmenge = <fs_gl>-ltmenge + <fs_tl>-ltmenge.
      ELSE.
        APPEND <fs_tl> TO gt_entr_lot.
      ENDIF.
      IF <fs_tl>-vhilmlt IS NOT INITIAL.
        APPEND VALUE #( posnr    = <fs_tl>-posnr
                        vhilm_ku = <fs_tl>-vhilmlt
                        cant     = <fs_tl>-ltmenge ) TO gt_lote_bulto.
      ENDIF.
    ENDIF.

    "Sumas para el cuadre: por posición y por (posición, bulto).
    CLEAR ls_cuadre.
    ls_cuadre-ebeln = <fs_tl>-ebeln.
    ls_cuadre-ebelp = <fs_tl>-ebelp.
    ls_cuadre-cant  = <fs_tl>-ltmenge.
    COLLECT ls_cuadre INTO lt_lot_pos.
    IF <fs_tl>-vhilmlt IS INITIAL.
      ls_cuadre-cant = 0.
      COLLECT ls_cuadre INTO lt_sin_bul.          "posición con algún lote sin bulto
    ELSE.
      ls_cuadre-bulto = <fs_tl>-vhilmlt.
      COLLECT ls_cuadre INTO lt_lot_bul.
    ENDIF.
  ENDLOOP.

  LOOP AT t_entr_det ASSIGNING FIELD-SYMBOL(<fs_det_c>) WHERE matnr IS NOT INITIAL.
    CLEAR ls_cuadre.
    ls_cuadre-ebeln = <fs_det_c>-ebeln.
    ls_cuadre-ebelp = <fs_det_c>-ebelp.
    ls_cuadre-cant  = <fs_det_c>-menge.
    COLLECT ls_cuadre INTO lt_det_pos.
    ls_cuadre-bulto = <fs_det_c>-vhilm_ku.
    COLLECT ls_cuadre INTO lt_det_bul.
  ENDLOOP.

  "Cuadre previo, sin tocar nada (proce_hu elimina los HU al empezar):
  "  1) por posición con lotes: suma de lotes = suma de bultos;
  "  2) por bulto: lo que cada bulto declara = sus lotes (si todos los lotes
  "     de la posición indican bulto).
  LOOP AT lt_lot_pos ASSIGNING FIELD-SYMBOL(<fs_lp>).
    CLEAR ls_otro.
    READ TABLE lt_det_pos INTO ls_otro
         WITH TABLE KEY ebeln = <fs_lp>-ebeln ebelp = <fs_lp>-ebelp bulto = space.
    IF ls_otro-cant NE <fs_lp>-cant.
      APPEND INITIAL LINE TO t_result ASSIGNING FIELD-SYMBOL(<fs_res_c>).
      <fs_res_c>-codigo = '999'.
      <fs_res_c>-type   = 'E'.
      <fs_res_c>-msg    = |Pos. { CONV i( <fs_lp>-ebelp ) } del pedido { <fs_lp>-ebeln }: | &&
                          |lotes { <fs_lp>-cant NUMBER = USER } no cuadran con bultos | &&
                          |{ ls_otro-cant NUMBER = USER }|.
      l_error = abap_true.
      CONTINUE.
    ENDIF.
    CHECK NOT line_exists( lt_sin_bul[ ebeln = <fs_lp>-ebeln ebelp = <fs_lp>-ebelp bulto = space ] ).
    LOOP AT lt_det_bul ASSIGNING FIELD-SYMBOL(<fs_db>)
         WHERE ebeln = <fs_lp>-ebeln AND ebelp = <fs_lp>-ebelp.
      CLEAR ls_otro.
      READ TABLE lt_lot_bul INTO ls_otro
           WITH TABLE KEY ebeln = <fs_db>-ebeln ebelp = <fs_db>-ebelp bulto = <fs_db>-bulto.
      IF ls_otro-cant NE <fs_db>-cant.
        APPEND INITIAL LINE TO t_result ASSIGNING <fs_res_c>.
        <fs_res_c>-codigo = '999'.
        <fs_res_c>-type   = 'E'.
        <fs_res_c>-msg    = |Bulto { <fs_db>-bulto }, pos. { CONV i( <fs_db>-ebelp ) } del pedido | &&
                            |{ <fs_db>-ebeln }: declara { <fs_db>-cant NUMBER = USER } y sus lotes | &&
                            |suman { ls_otro-cant NUMBER = USER }|.
        l_error = abap_true.
      ENDIF.
    ENDLOOP.
  ENDLOOP.
  IF l_error EQ abap_true.
    RETURN.
  ENDIF.
*}+@004
*{+@001
*  DATA: gr_lgort_tr TYPE RANGE OF t001l-lgort.





  SELECT * INTO TABLE @DATA(lt_ztconstantes)
  FROM zge_t_constantes
  WHERE modulo   EQ 'MM'
  AND   programa EQ 'SAPLZGF_CON_PORTAL'
  AND   campo    EQ 'LGORT_TRANSITO'.

  LOOP AT lt_ztconstantes ASSIGNING FIELD-SYMBOL(<fs_ztcons>).
        APPEND INITIAL LINE TO gr_lgort_tr ASSIGNING FIELD-SYMBOL(<fs_lgort_tr>).
        MOVE 'I'                   TO <fs_lgort_tr>-sign.
        MOVE 'EQ'                  TO <fs_lgort_tr>-option.
        MOVE <fs_ztcons>-low  TO <fs_lgort_tr>-low.
  ENDLOOP.
*}+@001
  SELECT SINGLE low "valor_low
    INTO lv_param
    FROM ZGE_T_CONSTANTES "ztconstantes
    WHERE modulo   EQ 'MM'
    AND   programa EQ 'SAPLZGF_CON_PORTAL'
    AND   campo    EQ 'PARAM'.

  DATA(ltd_entr_det) = t_entr_det[].
  DELETE ltd_entr_det WHERE ebeln IS INITIAL.
  DELETE ltd_entr_det WHERE ebelp IS INITIAL.

  ltd_entr_det2[] = ltd_entr_det[].


  SELECT ebeln ebelp werks lgort
   INTO TABLE gt_ekpo02
   FROM ekpo
   FOR ALL ENTRIES IN ltd_entr_det
   WHERE  ebeln EQ ltd_entr_det-ebeln .

  SELECT werks lgort xhupf
    INTO CORRESPONDING FIELDS OF TABLE gt_t001l02
    FROM t001l
    FOR ALL ENTRIES IN gt_ekpo02
    WHERE werks = gt_ekpo02-werks
      AND lgort = gt_ekpo02-lgort.


  "Se separan los embalajes complementarios de los bultos.
  "MP{ - Mejoras
  DATA: lv_str_comp    TYPE string,
        lv_emb         TYPE string,
        lv_emb2        TYPE string,
        lw_peso_comple TYPE likp-btgew.  "Peso total de embalajes complementarios.

  DATA: ls_entr_cab TYPE zbvmm_st_modificar_entrega.
  DATA: lv_ent TYPE vbeln_vl.

  CLEAR: lv_ent.
  READ TABLE t_entr_cab[] ASSIGNING FIELD-SYMBOL(<fs_entr_cab>) INDEX 1.
  IF sy-subrc = 0.
    lv_ent = <fs_entr_cab>-vbeln.
  ENDIF.
  ls_entr_cab-vbeln = lv_ent.


  REFRESH: gt_emb_compl_mod.

  LOOP AT t_entr_det ASSIGNING FIELD-SYMBOL(<fs_entr_compl>).
    CLEAR: lv_str_comp.
    lv_str_comp = <fs_entr_compl>-vhilm_ku.
    REPLACE ALL OCCURRENCES OF '.' IN lv_str_comp WITH 'h'.
    SEARCH lv_str_comp FOR 'h'.

    IF sy-subrc EQ 0.
      CLEAR: lv_emb, lv_emb2.
      SPLIT lv_str_comp AT 'h' INTO lv_emb lv_emb2.
      APPEND INITIAL LINE TO gt_emb_compl_mod ASSIGNING FIELD-SYMBOL(<fs_emb_compl_mod>).
      MOVE-CORRESPONDING <fs_entr_compl> TO <fs_emb_compl_mod>.
      <fs_emb_compl_mod>-vhilm_ku_p = lv_emb.   "emb principal.
      <fs_emb_compl_mod>-vhilm_ku = lv_emb2.   "emb compl.
      ADD <fs_entr_compl>-brgew TO lw_peso_comple. "Acumular peso de ambalajes complementarios.
    ENDIF.
  ENDLOOP.
*  SORT gt_emb_compl BY vhilm_ku_p ASCENDING.        "-@004 tabla equivocada
  SORT gt_emb_compl_mod BY vhilm_ku_p ASCENDING.     "+@004
  "MP} - Mejoras
  DELETE t_entr_det WHERE matnr IS INITIAL.  "Sacar embalajes complementarios (ya están en gt_emb_compl)

  READ TABLE t_entr_cab ASSIGNING <fs_entr_cab> INDEX 1.
  IF sy-subrc EQ 0.
    SELECT vbeln lfdat btgew anzpk lfuhr bolnr lifnr verur vegr2 inhalt zul_aufl zzlfstk
        FROM likp
        INTO CORRESPONDING FIELDS OF TABLE gt_likp
        FOR ALL ENTRIES IN t_entr_cab
        WHERE vbeln EQ t_entr_cab-vbeln.
    "Datos de entrega.
    CLEAR: gt_lips02.
    SELECT vbeln posnr matnr werks lgort charg vgbel lfimg meins umvkz umvkn vgpos
           vrkme uecha                                 "+@004 unidad de venta y partición
      FROM lips
      INTO CORRESPONDING FIELDS OF TABLE
      gt_lips02
      WHERE  vbeln EQ <fs_entr_cab>-vbeln.
    IF gt_lips02[] IS NOT INITIAL.
*{+@004 Validaciones contra la entrega, antes de tocar nada:
*       - lotes de posiciones que no están en la entrega;
*       - posición partida en lotes que llega sin lotes y con otra cantidad
*         (no se sabe a qué lote va el cambio);
*       - posición con un único lote en la propia posición que pasa a varios
*         lotes o a otro lote (requiere partir la posición: no soportado).
*       La partición se reconoce por LIPS-UECHA (subposición -> superior).
      LOOP AT lt_lot_pos ASSIGNING <fs_lp>.
        CHECK NOT line_exists( gt_lips02[ vgbel = <fs_lp>-ebeln vgpos = <fs_lp>-ebelp ] ).
        APPEND INITIAL LINE TO t_result ASSIGNING <fs_res_c>.
        <fs_res_c>-codigo = '999'.
        <fs_res_c>-type   = 'E'.
        <fs_res_c>-msg    = |Pos. { CONV i( <fs_lp>-ebelp ) } del pedido { <fs_lp>-ebeln } | &&
                            |no está en la entrega { <fs_entr_cab>-vbeln }: no se pueden asignar lotes|.
        l_error = abap_true.
      ENDLOOP.

      LOOP AT gt_lips02 ASSIGNING FIELD-SYMBOL(<fs_l2>) WHERE uecha IS INITIAL.
        "Subposiciones de lote de esta posición.
        CLEAR: lv_n_sub, lv_cant_sub.
        LOOP AT gt_lips02 ASSIGNING FIELD-SYMBOL(<fs_l2s>) WHERE uecha EQ <fs_l2>-posnr.
          lv_n_sub    = lv_n_sub + 1.
          lv_cant_sub = lv_cant_sub + <fs_l2s>-lfimg.
        ENDLOOP.
        IF line_exists( lt_lot_pos[ ebeln = <fs_l2>-vgbel ebelp = <fs_l2>-vgpos bulto = space ] ).
          "Lote único en la propia posición: solo se admite ese mismo lote.
          IF lv_n_sub EQ 0 AND <fs_l2>-charg IS NOT INITIAL.
            LOOP AT gt_entr_lot TRANSPORTING NO FIELDS
                 WHERE ebeln EQ <fs_l2>-vgbel
                   AND ebelp EQ <fs_l2>-vgpos
                   AND posnr NE <fs_l2>-posnr.
              APPEND INITIAL LINE TO t_result ASSIGNING <fs_res_c>.
              <fs_res_c>-codigo = '999'.
              <fs_res_c>-type   = 'E'.
              <fs_res_c>-msg    = |Pos. { CONV i( <fs_l2>-vgpos ) } del pedido { <fs_l2>-vgbel } | &&
                                  |tiene el lote { <fs_l2>-charg }: no se puede cambiar a varios lotes u otro lote|.
              l_error = abap_true.
              EXIT.
            ENDLOOP.
          ENDIF.
        ELSEIF lv_n_sub GT 0.
          "Partida y sin lotes en la trama: solo si la cantidad no cambia.
          CLEAR ls_otro.
          READ TABLE lt_det_pos INTO ls_otro
               WITH TABLE KEY ebeln = <fs_l2>-vgbel ebelp = <fs_l2>-vgpos bulto = space.
          IF sy-subrc EQ 0 AND ls_otro-cant NE lv_cant_sub.
            APPEND INITIAL LINE TO t_result ASSIGNING <fs_res_c>.
            <fs_res_c>-codigo = '999'.
            <fs_res_c>-type   = 'E'.
            <fs_res_c>-msg    = |Pos. { CONV i( <fs_l2>-vgpos ) } del pedido { <fs_l2>-vgbel } | &&
                                |tiene lotes: envíe el detalle de lotes para cambiar su cantidad|.
            l_error = abap_true.
          ENDIF.
        ENDIF.
      ENDLOOP.
      IF l_error EQ abap_true.
        RETURN.
      ENDIF.
*}+@004
      READ TABLE gt_t001l02 ASSIGNING FIELD-SYMBOL(<fs_t001l>) INDEX 1.
      IF sy-subrc EQ 0.
*        IF <fs_t001l>-xhupf IS INITIAL. "-@001
        IF <fs_t001l>-lgort NOT IN gr_lgort_tr. "+@001
          "HU no obligatoria.
          PERFORM proce_hu_no TABLES ltd_entr_det
                                     t_result
                              USING <fs_entr_cab>
                              CHANGING l_error.
          "MP{
          "Embalaje complementario
          PERFORM f_act_zbvmmemb_comp TABLES ltd_entr_det2
                                      USING <fs_entr_cab>.
          "MP}
        ELSE.
          "HU Obligatoria.
          PERFORM proce_hu TABLES ltd_entr_det
                                  t_result
                           USING <fs_entr_cab>
                           CHANGING l_error.
          "MP{
          "Embalaje complementario
          PERFORM f_act_zbvmmemb_comp TABLES ltd_entr_det
                                      USING ls_entr_cab.
          "MP}
        ENDIF.
      ENDIF.


      "Actualiza tabla Z principal.
      PERFORM act_entrega_modif TABLES t_result
                                USING <fs_entr_cab>
                                CHANGING l_error.


    ELSE. "No existe la entrega.

      APPEND INITIAL LINE TO t_result ASSIGNING FIELD-SYMBOL(<f_result>).
      <f_result>-codigo = '999'.
      CONCATENATE text-042 <fs_entr_cab>-vbeln INTO <f_result>-msg SEPARATED BY space.

    ENDIF.
  ENDIF.

*{+@004 Devolver posición y lote reales de los lotes nuevos, en el orden
*       de la trama (el DPC los devuelve al portal para la próxima
*       modificación). Si hubo error no se devuelven: no son definitivos.
  IF l_error EQ abap_false.
    LOOP AT lt_map ASSIGNING FIELD-SYMBOL(<fs_map>).
      READ TABLE gt_entr_lot ASSIGNING <fs_gl> INDEX <fs_map>-gt.
      CHECK sy-subrc EQ 0.
      READ TABLE t_entr_lot ASSIGNING <fs_tl> INDEX <fs_map>-raw.
      CHECK sy-subrc EQ 0.
      <fs_tl>-posnr = <fs_gl>-posnr.
      <fs_tl>-charg = <fs_gl>-charg.
    ENDLOOP.
  ENDIF.

  "Si la llamada falló, los lotes que creó y que no quedaron en la entrega
  "se marcan para borrado (no se pueden borrar).
  IF l_error EQ abap_true AND gt_lotes_mod_creados IS NOT INITIAL.
    LOOP AT gt_lotes_mod_creados ASSIGNING FIELD-SYMBOL(<fs_lote_cre>).
      SELECT SINGLE vbeln FROM lips INTO @DATA(lv_vbeln_uso)
        WHERE vbeln EQ @lv_ent
          AND matnr EQ @<fs_lote_cre>-material
          AND charg EQ @<fs_lote_cre>-batch.
      CHECK sy-subrc NE 0.
      CLEAR: lwa_battr, lwa_battrx, lt_return.
      lwa_battr-del_flag  = abap_true.
      lwa_battrx-del_flag = abap_true.
      CALL FUNCTION 'BAPI_BATCH_CHANGE'
        EXPORTING
          material         = <fs_lote_cre>-material
          batch            = <fs_lote_cre>-batch
          plant            = <fs_lote_cre>-plant
          batchattributes  = lwa_battr
          batchattributesx = lwa_battrx
        TABLES
          return           = lt_return.
      READ TABLE lt_return TRANSPORTING NO FIELDS WITH KEY type = 'E'.
      IF sy-subrc EQ 0.
        CALL FUNCTION 'BAPI_TRANSACTION_ROLLBACK'.
        APPEND INITIAL LINE TO t_result ASSIGNING FIELD-SYMBOL(<fs_res_w>).
        <fs_res_w>-codigo = '999'.
        <fs_res_w>-type   = 'W'.
        <fs_res_w>-msg    = |No se pudo marcar para borrado el lote { <fs_lote_cre>-batch }|.
      ELSE.
        PERFORM commit_wait.
      ENDIF.
    ENDLOOP.
  ENDIF.
*}+@004

ENDFUNCTION.
