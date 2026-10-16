FUNCTION ZBVMM_OC_ELIM_ENTR_ERROR.
*"----------------------------------------------------------------------
*"*"Interfase local
*"  IMPORTING
*"     VALUE(I_VBELN) TYPE  VBELN OPTIONAL
*"  EXPORTING
*"     VALUE(E_MESSAGE) TYPE  BAPI_MSG
*"  TABLES
*"      T_RESULT TYPE  ZBVMM_TT_CONFIRMAR_RESULTADO
*"----------------------------------------------------------------------

  DATA: lw_exidv          TYPE vekp-exidv,
        ls_header_data    TYPE bapiibdlvhdrchg,
        ls_header_control TYPE bapiibdlvhdrctrlchg,
        lt_uekes          TYPE TABLE OF uekes,
        ls_uekes          LIKE LINE OF  lt_uekes,
        ls_ekes           TYPE ekes,
        ls_return2        TYPE bapiret2,
        i_msg             TYPE natxt,
        it_result         TYPE STANDARD TABLE OF  ZBVMM_ST_RESULT.


  DATA: lt_return     TYPE STANDARD TABLE OF bapiret2,
        lt_extension2 TYPE STANDARD TABLE OF bapiext.

  SELECT exidv,vpobjkey
    FROM vekp
    INTO TABLE @DATA(lt_vekp)
    WHERE vpobjkey EQ @i_vbeln
      AND status NE '0060'.
  IF sy-subrc EQ 0.

    LOOP AT lt_vekp ASSIGNING FIELD-SYMBOL(<f_vekp>).
      lw_exidv = <f_vekp>-exidv.

      IF lw_exidv NE space.
        CALL FUNCTION 'BAPI_HU_DELETE_FROM_DEL'
          EXPORTING
            delivery = i_vbeln
            hukey    = lw_exidv
          TABLES
            return   = lt_return.

        READ TABLE lt_return ASSIGNING FIELD-SYMBOL(<fs_return>)
                             WITH KEY type = 'S'.
        IF sy-subrc EQ 0.
           PERFORM commit_wait.
        ENDIF.
        "Verificar errores.
         PERFORM carga_errores TABLES lt_return
                                      it_result.


      ENDIF.
    ENDLOOP.
  ENDIF.

  REFRESH: lt_return.
  ls_header_data-deliv_numb     = i_vbeln.
  ls_header_control-deliv_numb  = i_vbeln.
  ls_header_control-dlv_del     = 'X'.

  CALL FUNCTION 'BAPI_INB_DELIVERY_CHANGE'
    EXPORTING
      header_data    = ls_header_data
      header_control = ls_header_control
      delivery       = i_vbeln
    TABLES
      extension2     = lt_extension2
      return         = lt_return.

IF sy-subrc EQ 0.

  IF lt_return IS INITIAL.
     PERFORM commit_wait.
     PERFORM del_entrega USING i_vbeln.

     APPEND INITIAL LINE TO  it_result ASSIGNING FIELD-SYMBOL(<fs_result>).
     <fs_result>-codigo = '999'.
     <fs_result>-type = 'S'.
     <fs_result>-msg = text-013.

  ELSE.
        "Verificar errores.
         PERFORM carga_errores TABLES lt_return
                                      it_result.
  ENDIF.


    SELECT vbelv, posnv INTO TABLE @DATA(ltd_lips)
           FROM lips WHERE vbeln = @i_vbeln.
    IF sy-subrc = 0.
      SELECT * INTO TABLE @DATA(ltd_ekes)
               FROM ekes
               FOR ALL ENTRIES IN @ltd_lips
               WHERE ebeln = @ltd_lips-vbelv
                 AND ebelp = @ltd_lips-posnv+1(5).
      DELETE ltd_ekes WHERE xblnr(10) =  i_vbeln.
      SORT ltd_ekes BY ebeln ebelp.
      LOOP AT ltd_ekes INTO ls_ekes.
        MOVE-CORRESPONDING ls_ekes TO ls_uekes.
        ls_uekes-xblnr = i_vbeln.
        ls_uekes-kz    = 'U'.
        APPEND ls_uekes TO lt_uekes.
        AT END OF ebeln.
          DELETE ADJACENT DUPLICATES FROM lt_uekes COMPARING ebeln ebelp.
          IF lt_uekes[] IS NOT INITIAL.
            CALL FUNCTION 'ME_CONFIRMATION_UPDATE'
              EXPORTING
                i_ebeln = ls_ekes-ebeln "purchase ORDER NUMBER IS the KEY FOR the fumo(fuba)
              TABLES
                xekes   = lt_uekes.

            IF sy-subrc = 0.
              CALL FUNCTION 'BAPI_TRANSACTION_COMMIT'
                EXPORTING
                  wait   = 'X'
                IMPORTING
                  return = ls_return2.
            ENDIF.
          ENDIF.
          FREE lt_uekes.
          CLEAR lt_uekes.
        ENDAT.
      ENDLOOP.
    ENDIF.
  ENDIF.

  IF it_result IS NOT INITIAL.
     LOOP AT it_result ASSIGNING <fs_result>.
          APPEND INITIAL LINE TO t_result ASSIGNING FIELD-SYMBOL(<fs_resultados>).
          MOVE-CORRESPONDING <fs_result> TO <fs_result>.
     ENDLOOP.
  ENDIF.



ENDFUNCTION.
