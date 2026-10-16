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
  SORT gt_emb_compl BY vhilm_ku_p ASCENDING.
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
      FROM lips
      INTO CORRESPONDING FIELDS OF TABLE
      gt_lips02
      WHERE  vbeln EQ <fs_entr_cab>-vbeln.
    IF gt_lips02[] IS NOT INITIAL.
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



ENDFUNCTION.
