  method /IWBEP/IF_MGW_APPL_SRV_RUNTIME~CREATE_DEEP_ENTITY.
*    DATA: ir_deep_entity  TYPE zcl_zbvmm_web_oc_gu_01_mpc_ext=>ts_deep_entity. "-@003 tipo del servicio V1
    DATA: ir_deep_entity  TYPE zcl_zbvmm_web_oc_guard_mpc_ext=>ts_deep_entity.  "+@003 tipo propio de la V2
    CASE iv_entity_set_name.
*-------------------------------------------------------------------------*
*  When EntitySet 'HeaderSet' is been invoked via service Url
*-------------------------------------------------------------------------*
      WHEN 'ZETCABECERASet'.

        CALL METHOD me->custome_create_deep_entity
          EXPORTING
            iv_entity_name          = iv_entity_name
            iv_entity_set_name      = iv_entity_set_name
            iv_source_name          = iv_source_name
            it_key_tab              = it_key_tab
            it_navigation_path      = it_navigation_path
            io_expand               = io_expand
            io_tech_request_context = io_tech_request_context
            io_data_provider        = io_data_provider
          IMPORTING
            er_deep_entity          = ir_deep_entity.

        copy_data_to_ref(
        EXPORTING
         is_data = ir_deep_entity
        CHANGING
         cr_data = er_deep_entity
        ).

    ENDCASE.
  endmethod.
