class ZCL_ZBVMM_WEB_OC_PORTA_DPC_EXT definition
  public
  inheriting from ZCL_ZBVMM_WEB_OC_PORTA_DPC
  create public .

public section.

  methods /IWBEP/IF_MGW_APPL_SRV_RUNTIME~CREATE_DEEP_ENTITY
    redefinition .
protected section.
private section.
ENDCLASS.



CLASS ZCL_ZBVMM_WEB_OC_PORTA_DPC_EXT IMPLEMENTATION.


method /IWBEP/IF_MGW_APPL_SRV_RUNTIME~CREATE_DEEP_ENTITY.
**TRY.
*CALL METHOD SUPER->/IWBEP/IF_MGW_APPL_SRV_RUNTIME~CREATE_DEEP_ENTITY
*  EXPORTING
**    iv_entity_name          =
**    iv_entity_set_name      =
**    iv_source_name          =
*    IO_DATA_PROVIDER        =
**    it_key_tab              =
**    it_navigation_path      =
*    IO_EXPAND               =
**    io_tech_request_context =
**  IMPORTING
**    er_deep_entity          =
*    .
** CATCH /iwbep/cx_mgw_busi_exception .
** CATCH /iwbep/cx_mgw_tech_exception .
**ENDTRY.

  DATA: ir_deep_entity_mod TYPE zcl_zbvmm_web_oc_porta_mpc_ext=>gty_mod_entrega,
        "RFC
        it_entr_cab TYPE STANDARD TABLE OF zbvmm_st_modificar_entrega,
        it_entr_det TYPE STANDARD TABLE OF zbvmm_st_modificar_entrega_det,
        it_entr_lot TYPE zbvmm_tt_guardar_entrega_det_m,
        it_result   TYPE STANDARD TABLE OF zbvmm_st_result.

  CASE iv_entity_set_name.
    WHEN 'ZET_CABECERA_ENT_MODSet'.

      io_data_provider->read_entry_data(
        IMPORTING
          es_data = ir_deep_entity_mod
        ).

      "Cabecera.
      APPEND INITIAL LINE TO it_entr_cab ASSIGNING FIELD-SYMBOL(<fs_cab>).
      MOVE-CORRESPONDING ir_deep_entity_mod TO <fs_cab>.

      "Detalle.
      LOOP AT ir_deep_entity_mod-zet_detalle_ent_modset ASSIGNING FIELD-SYMBOL(<fs_deep_det>).
        APPEND INITIAL LINE TO it_entr_det ASSIGNING FIELD-SYMBOL(<fs_det>).
        MOVE-CORRESPONDING <fs_deep_det> TO <fs_det>.

        "Lotes de la posición. El nodo OData no trae pedido ni posición:
        "se heredan del detalle padre para que la FM pueda enlazarlos.
        LOOP AT <fs_deep_det>-zet_detalle_lot_modset ASSIGNING FIELD-SYMBOL(<fs_deep_lot>).
          APPEND INITIAL LINE TO it_entr_lot ASSIGNING FIELD-SYMBOL(<fs_lot>).
          MOVE-CORRESPONDING <fs_deep_lot> TO <fs_lot>.
          <fs_lot>-ebeln = <fs_deep_det>-ebeln.
          <fs_lot>-ebelp = <fs_deep_det>-ebelp.
          "+@004 El lote viene anidado en su bulto: si no indica bulto, es ese.
          IF <fs_lot>-vhilmlt IS INITIAL.
            <fs_lot>-vhilmlt = <fs_deep_det>-vhilm_ku.
          ENDIF.
        ENDLOOP.
      ENDLOOP.

      "RFC
      CALL FUNCTION 'ZBVMM_OC_MOD_ENTR_02'
        TABLES
          t_entr_cab = it_entr_cab
          t_entr_det = it_entr_det
          t_entr_lot = it_entr_lot
          t_result   = it_result.


      "+@004 Devolver al portal la posición (POSNR) y el lote SAP (CHARG) de
      "cada lote, en el mismo orden en que llegaron: en la próxima
      "modificación el portal debe enviarlos para que el lote se reconozca
      "como existente. Si la llamada falló, el FM los devuelve sin cambios.
      DATA(lv_ilot) = 0.
      LOOP AT ir_deep_entity_mod-zet_detalle_ent_modset ASSIGNING <fs_deep_det>.
        LOOP AT <fs_deep_det>-zet_detalle_lot_modset ASSIGNING <fs_deep_lot>.
          lv_ilot = lv_ilot + 1.
          READ TABLE it_entr_lot ASSIGNING FIELD-SYMBOL(<fs_lot_res>) INDEX lv_ilot.
          IF sy-subrc EQ 0.
            <fs_deep_lot>-posnr = <fs_lot_res>-posnr.
            <fs_deep_lot>-charg = <fs_lot_res>-charg.
          ENDIF.
        ENDLOOP.
      ENDLOOP.

      "Resultados
      LOOP AT it_result ASSIGNING FIELD-SYMBOL(<fs_result>).
        APPEND INITIAL LINE TO ir_deep_entity_mod-zet_result_mod_entset ASSIGNING FIELD-SYMBOL(<fs_deep_res>).
        MOVE-CORRESPONDING <fs_result> TO <fs_deep_res>.
      ENDLOOP.

     "Transfiere datos.
        copy_data_to_ref(
          EXPORTING
            is_data = ir_deep_entity_mod
          CHANGING
            cr_data = er_deep_entity
        ).


 	WHEN OTHERS.
 ENDCASE.




  endmethod.
ENDCLASS.