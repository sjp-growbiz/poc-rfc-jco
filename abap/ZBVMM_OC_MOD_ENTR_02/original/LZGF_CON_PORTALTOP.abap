FUNCTION-POOL ZGF_CON_PORTAL.               "MESSAGE-ID ..

* INCLUDE LZGF_CON_PORTALD...                " Local class definition
DATA: gs_bdc          TYPE bdcdata.
DATA :gt_bdc TYPE STANDARD TABLE OF bdcdata.

TYPES: BEGIN OF lty_detallemod,
         vbeln TYPE vbeln,
         ebeln TYPE vbelv,
         ebelp TYPE c LENGTH 6,
         menge TYPE bstmg,
         meins TYPE bstme,
       END OF lty_detallemod.


DATA: ltd_entr_det_aux TYPE STANDARD TABLE OF lty_detallemod.
DATA: ls_detalle        LIKE LINE OF ltd_entr_det_aux.

*ZBVMM_OC_REGISTRO_ENTR02{
TYPES: BEGIN OF gty_likp,
         vbeln    TYPE likp-vbeln,
         lfdat    TYPE likp-lfdat,
         btgew    TYPE likp-btgew,
         anzpk    TYPE likp-anzpk,
         lfuhr    TYPE likp-lfuhr,
         bolnr    TYPE likp-bolnr,
         lifnr    TYPE likp-lifnr,
         verur    TYPE likp-verur,
         vpobjkey TYPE vekp-vpobjkey,
         vegr2    TYPE likp-vegr2,
         inhalt   TYPE likp-inhalt,
         zul_aufl TYPE likp-zul_aufl,
         zzlfstk  TYPE likp-zzlfstk,  "INSERT @JGRS 09.06.2022
       END OF gty_likp,

       BEGIN OF gty_vekp,
         venum    TYPE vekp-venum,
         brgew    TYPE vekp-brgew,
         vegr1    TYPE vekp-vegr1,
         vegr2    TYPE vekp-vegr2,
         laeng    TYPE vekp-laeng,
         breit    TYPE vekp-breit,
         hoehe    TYPE vekp-hoehe,
         inhalt   TYPE vekp-inhalt,
         vhilm_ku TYPE vekp-vhilm_ku,
         vpobjkey TYPE vekp-vpobjkey,
         zul_aufl TYPE vekp-zul_aufl,
         exidv    TYPE vekp-exidv,
       END OF gty_vekp,

       BEGIN OF gty_vepo,
         venum TYPE vepo-venum,
         vepos TYPE vepo-vepos,
         vbeln TYPE vepo-vbeln,
         posnr TYPE vepo-posnr,
         vemng TYPE vepo-vemng,
         matnr TYPE vepo-matnr,
         vemeh TYPE vepo-vemeh,
         altme TYPE vepo-altme,
       END OF gty_vepo,

       BEGIN OF gty_lips,
         vbeln TYPE lips-vbeln,
         posnr TYPE lips-posnr,
         matnr TYPE lips-matnr,
         werks TYPE lips-werks,
         lgort TYPE lips-lgort,
         vgbel TYPE lips-vgbel,
         brgew TYPE lips-brgew,
         gewei TYPE lips-gewei,
         vgpos TYPE lips-vgpos,
         lfimg TYPE lips-lfimg,
         meins TYPE lips-meins,
         vrkme TYPE lips-vrkme,
         ebelp TYPE ekpo-ebelp,
       END OF gty_lips,


       BEGIN OF gty_lips_02,
         vbeln TYPE lips-vbeln,
         posnr TYPE lips-posnr,
         matnr TYPE lips-matnr,
         werks TYPE lips-werks,
         lgort TYPE lips-lgort,
         charg TYPE lips-charg,
         lfimg TYPE lips-lfimg,
         meins TYPE lips-meins,
         vrkme TYPE lips-vrkme,
         umvkz TYPE lips-umvkz,
         umvkn TYPE lips-umvkn,
         brgew TYPE lips-brgew,
         gewei TYPE lips-gewei,
         vgbel TYPE lips-vgbel,
         vgpos TYPE lips-vgpos,
       END OF gty_lips_02,

       BEGIN OF gty_ekpo02,
         ebeln TYPE ekpo-ebeln,
         ebelp TYPE ekpo-ebelp,
         werks TYPE ekpo-werks,
         lgort TYPE ekpo-lgort,
       END OF gty_ekpo02,

       BEGIN OF gty_t001l,
         werks TYPE t001l-werks,
         lgort TYPE t001l-lgort,
         lgobe TYPE t001l-lgobe,
         xhupf TYPE t001l-xhupf,
       END OF gty_t001l,


       BEGIN OF gty_t001w,
         werks TYPE t001w-werks,
         name1 TYPE t001w-name1,
         lifnr TYPE t001w-lifnr,
         stras TYPE t001w-stras,
         ort01 TYPE t001w-ort01,
         adrnr TYPE t001w-adrnr,
       END OF gty_t001w,

       BEGIN OF gty_ekpo,
         ebeln     TYPE ekpo-ebeln,
         ebelp     TYPE ekpo-ebelp,
         bukrs     TYPE ekpo-bukrs,
         bstae     TYPE ekpo-bstae,
         bpumz     TYPE ekpo-bpumz,
         bpumn     TYPE ekpo-bpumn,
         umrez     TYPE  ekpo-umrez,
         umren     TYPE  ekpo-umren,
         zzlug_ent TYPE ekpo-zzlug_ent,
         afnam     TYPE ekpo-afnam, "INSERT @PM
         inco1      TYPE ekpo-inco1, "+@001
       END OF gty_ekpo,


       BEGIN OF gty_zadr,
         vbeln TYPE likp-vbeln,
         direc TYPE zed_direccion,
       END OF gty_zadr,

       BEGIN OF gty_lfa1,
         lifnr TYPE lfa1-lifnr,
         ort01 TYPE lfa1-ort01,
         ort02 TYPE lfa1-ort02,
         stras TYPE lfa1-stras,
         name1 TYPE lfa1-name1,
         stcd1 TYPE lfa1-stcd1, "@DL MEJORAS
       END OF gty_lfa1,

       BEGIN OF gty_tve2t,
         spras TYPE tve2t-spras,
         vegr2 TYPE tve2t-vegr2,
         bezei TYPE tve2t-bezei,
       END OF gty_tve2t,

       BEGIN OF gty_ekko,
         ebeln TYPE ekko-ebeln,
         ernam TYPE ekko-ernam,
         bsart TYPE ekko-bsart, "+@001
       END OF gty_ekko,

       BEGIN OF gty_adr6,
         smtp_addr TYPE adr6-smtp_addr,
         bname     TYPE usr21-bname,
       END OF gty_adr6,

       BEGIN OF gty_adrp,
         bname     TYPE usr21-bname,
         name_text TYPE adrp-name_text,
       END OF gty_adrp,

       BEGIN OF gty_makt,
         matnr TYPE makt-matnr,
         maktx TYPE makt-maktx,
       END OF gty_makt,

       BEGIN OF gty_marc,
         matnr TYPE marc-matnr,
         werks TYPE marc-werks,
         dispo TYPE marc-dispo,
       END OF gty_marc,

       BEGIN OF gty_pedpos,
         ebeln TYPE vgbel,
         ebelp TYPE vgpos,
       END OF gty_pedpos,

       BEGIN OF gty_hucomple,
         vhilm_ku TYPE vhilm_ku,
         exidv    TYPE exidv,
       END OF gty_hucomple,

       BEGIN OF gty_cons,
         campo      TYPE ZGE_T_CONSTANTES-campo,
         SIGN      TYPE ZGE_T_CONSTANTES-SIGN,
         OPT     TYPE ZGE_T_CONSTANTES-OPT,
         CORRELATIVO  TYPE ZGE_T_CONSTANTES-CORRELATIVO,
         LOW  TYPE ZGE_T_CONSTANTES-LOW,
         HIGH TYPE ZGE_T_CONSTANTES-HIGH,
       END OF gty_cons.

TYPES: BEGIN OF gty_reg_ent.
        INCLUDE STRUCTURE zbvmm_st_registro_ee.
TYPES: END OF gty_reg_ent.

TYPES: BEGIN OF gty_guarda_ent.
        INCLUDE STRUCTURE zbvmm_st_guardar_entrega.
TYPES: END OF gty_guarda_ent.

TYPES: BEGIN OF gty_emb_compl,
         vhilm_ku_p TYPE vhilm_ku.
        INCLUDE STRUCTURE  zbvmm_st_guardar_entrega_det.
TYPES: END OF gty_emb_compl.

TYPES: BEGIN OF gty_emb_compl_mod,
         vhilm_ku_p TYPE vhilm_ku.
        INCLUDE STRUCTURE  zbvmm_st_modificar_entrega_det.
TYPES: END OF gty_emb_compl_mod.

TYPES: BEGIN OF gty_emb_compl_recep,
         vhilm_ku_p TYPE vhilm_ku,
         marca_agre TYPE abap_bool.
        INCLUDE STRUCTURE  zbvmm_st_i_entr_det.
TYPES: END OF gty_emb_compl_recep.

TYPES: BEGIN OF gty_likps,
         vbeln    TYPE likp-vbeln,
         lfdat    TYPE likp-lfdat,
         btgew    TYPE likp-btgew,
         anzpk    TYPE likp-anzpk,
         lfuhr    TYPE likp-lfuhr,
         bolnr    TYPE likp-bolnr,
         lifnr    TYPE likp-lifnr,
         verur    TYPE likp-verur,
         vpobjkey TYPE vekp-vpobjkey,
         vegr2    TYPE likp-vegr2,
         inhalt   TYPE likp-inhalt,
         zul_aufl TYPE likp-zul_aufl,
         posnr    TYPE lips-posnr,
         matnr    TYPE lips-matnr,
         werks    TYPE lips-werks,
         lgort    TYPE lips-lgort,
         vgbel    TYPE lips-vgbel,
         brgew    TYPE lips-brgew,
         gewei    TYPE lips-gewei,
         vgpos    TYPE lips-vgpos,
         lfimg    TYPE lips-lfimg,
         meins    TYPE lips-meins,
         vrkme    TYPE lips-vrkme,
         ebelp    TYPE ekpo-ebelp,
       END OF gty_likps.

TYPES: BEGIN OF gty_t001wadr,
         werks      TYPE t001w-werks,
         name1      TYPE t001w-name1,
         lifnr      TYPE t001w-lifnr,
         stras      TYPE t001w-stras,
         ort01      TYPE t001w-ort01,
         adrnr      TYPE t001w-adrnr,
         street     TYPE adrc-street,
         str_suppl1 TYPE adrc-str_suppl1,
         city1      TYPE adrc-city1,
         city2      TYPE adrc-city2,
       END OF gty_t001wadr.

TYPES: BEGIN OF gty_mensajes.
        INCLUDE STRUCTURE zbvmm_st_result_re .
TYPES: END OF gty_mensajes.

TYPES: BEGIN OF gty_final.
        INCLUDE STRUCTURE zbvmm_entrega_re.
TYPES: END OF gty_final.

*BEGIN OF INSERT - @PMPD002 - 22.03.2022 17:28:23
TYPES: BEGIN OF ty_validacion,
         sign   TYPE ddsign,
         option TYPE ddoption,
         compar TYPE zosed_valor,
         posici TYPE i,           "zosed_valor,
         criter TYPE zosed_valor,
       END OF ty_validacion.

*{+@001
TYPES: BEGIN OF ty_cond_entr,
         inco1 TYPE tinct-inco1,
         bezei TYPE tinct-bezei,
       END OF ty_cond_entr.
*}+@001
CONSTANTS: gc_estr TYPE c LENGTH 1 VALUE '1',     "ESTRATEGICO
           gc_crit TYPE c LENGTH 1 VALUE '2',     "CRITICO
           gc_regu TYPE c LENGTH 1 VALUE '3',     "REGULARES
           gc_irre TYPE c LENGTH 1 VALUE '4',     "IRREGULARES

           gc_testr type c LENGTH 20 VALUE 'ESTRATÉGICOS',
           gc_tcrit type c LENGTH 20 VALUE 'CRÍTICO',
           gc_tregu type c LENGTH 20 VALUE 'REGULAR',
           gc_tirre type c LENGTH 20 VALUE 'IRREGULAR'.
*END OF INSERT - @PMPD002 - 22.03.2022 17:28:23


DATA: gr_vpobjkey TYPE RANGE OF vpobjkey,
      gr_vbeln    TYPE RANGE OF vbeln,
      gr_matnr    TYPE RANGE OF vepo-matnr,
      gr_posnr    TYPE RANGE OF vepo-posnr,
      gr_dispo    TYPE RANGE OF ZGE_T_CONSTANTES-low,
      gr_crit     TYPE RANGE OF ZGE_T_CONSTANTES-low,
      gr_regu     TYPE RANGE OF ZGE_T_CONSTANTES-low,
      gr_irre     TYPE RANGE OF ZGE_T_CONSTANTES-low,
      gr_estr     TYPE RANGE OF ZGE_T_CONSTANTES-low,
      gr_lifnr    TYPE RANGE OF lfa1-lifnr,
      gr_werks    TYPE RANGE OF lips-werks,
      gr_ernam    TYPE RANGE OF ekko-ernam,
      gr_vgbel    TYPE RANGE OF lips-vgbel,
      gr_venum    TYPE RANGE OF vekp-venum,
      gr_vegr2    TYPE RANGE OF vekp-vegr2,
      gr_lgort_tr TYPE RANGE OF t001l-lgort.

DATA: gv_vpobjkey TYPE string,
      gv_zadr     TYPE string,
      gv_peso     TYPE string,
      gv_crit     TYPE string,
      gv_regu     TYPE string,
      gv_irre     TYPE string,
      gv_estr     TYPE string,
      gv_a        TYPE string,
      gv_b        TYPE string,
      lv_pos      TYPE string,
      gv_envio    TYPE string,
      gv_e_bsart  TYPE esart,
      gv_recojo   TYPE string.

DATA: gv_key TYPE vpobjkey.


DATA: gv_ort01 TYPE lfa1-ort01,
      gv_ort02 TYPE lfa1-ort02,
      gv_stras TYPE lfa1-stras,
      gv_lifnr TYPE lfa1-lifnr,
      gv_meins TYPE lips-meins.

DATA: gv_error TYPE boolean.

DATA: gt_likp         TYPE STANDARD TABLE OF gty_likp,
      gt_likps        TYPE STANDARD TABLE OF gty_likps,
      gt_likps_aux    TYPE STANDARD TABLE OF gty_likps,
      gt_t001l        TYPE STANDARD TABLE OF gty_t001l,
      gt_t001wadr     TYPE STANDARD TABLE OF gty_t001wadr,
      gt_reg_ent      TYPE STANDARD TABLE OF gty_reg_ent,
      gt_vekp         TYPE STANDARD TABLE OF gty_vekp,
      gt_vepo         TYPE STANDARD TABLE OF gty_vepo,
      gt_lips         TYPE STANDARD TABLE OF gty_lips,
      gt_lips02       TYPE STANDARD TABLE OF gty_lips_02,
      gt_ekpo02       TYPE STANDARD TABLE OF gty_ekpo02,
      gt_t001l02      TYPE STANDARD TABLE OF gty_t001l,
      gt_t001w        TYPE STANDARD TABLE OF gty_t001w,
      gt_ekpo         TYPE STANDARD TABLE OF gty_ekpo,
      gt_zadr         TYPE STANDARD TABLE OF gty_zadr,
      gt_lfa1         TYPE STANDARD TABLE OF gty_lfa1,
      gt_tve2t        TYPE STANDARD TABLE OF gty_tve2t,
      gt_tve2t_2      TYPE STANDARD TABLE OF gty_tve2t,
      gt_ekko         TYPE STANDARD TABLE OF gty_ekko,
      gt_ekko_p       TYPE STANDARD TABLE OF gty_ekko,
      gt_adr6         TYPE STANDARD TABLE OF gty_adr6,
      gt_adrp         TYPE STANDARD TABLE OF gty_adrp,
      gt_makt         TYPE STANDARD TABLE OF gty_makt,
      gt_marc         TYPE STANDARD TABLE OF gty_marc,
      gt_makt_lips    TYPE STANDARD TABLE OF gty_makt,
      gt_marc_lips    TYPE STANDARD TABLE OF gty_marc,
      gt_final        TYPE STANDARD TABLE OF zbvmm_entrega_re,
      gt_final_aux    TYPE STANDARD TABLE OF zbvmm_entrega_re,
      gt_final_vepo   TYPE STANDARD TABLE OF zbvmm_entrega_re,
      gt_const        TYPE STANDARD TABLE OF gty_cons,
      gt_const_portal TYPE STANDARD TABLE OF gty_cons,
      gt_status       TYPE STANDARD TABLE OF zbvmm_estatus,
*      gt_condicion    TYPE STANDARD TABLE OF zbvmm_cond_entr, "-@001
      gt_condicion    TYPE STANDARD TABLE OF ty_cond_entr, "+@001
      gt_pedpos       TYPE STANDARD TABLE OF gty_pedpos,
      gt_mensajes     TYPE STANDARD TABLE OF gty_mensajes,
      gt_entrenohu    TYPE STANDARD TABLE OF zbvmm_entrenohu,
      gt_hucomple     TYPE STANDARD TABLE OF gty_hucomple,
      gt_embcomp      TYPE STANDARD TABLE OF zbvmm_emb_comp,
      gt_embcomp_aux2 TYPE STANDARD TABLE OF zbvmm_emb_comp,
      gt_embcomp_aux  TYPE STANDARD TABLE OF zbvmm_emb_comp,
      gtr_vali        TYPE STANDARD TABLE OF ty_validacion.          "INSERT - @PMPD002 - 22.03.2022


DATA: gt_entr_lot TYPE zbvmm_tt_guardar_entrega_det_m.   "lotes de la modificación

*      gr_matnr TYPE RANGE OF lips-matnr.



DATA: gwa_params  TYPE ctu_params,
      gt_messtab  LIKE bdcmsgcoll OCCURS 0 WITH HEADER LINE,
      gwa_messtab LIKE LINE OF gt_messtab.

FIELD-SYMBOLS: <fs_likp>  LIKE LINE OF gt_likp,
               <fs_likps> LIKE LINE OF gt_likps,
               <fs_rege>  LIKE LINE OF gt_reg_ent,
               <fs_vekp>  LIKE LINE OF gt_vekp,
               <fs_vepo>  LIKE LINE OF gt_vepo,
               <fs_lips>  LIKE LINE OF gt_lips,
               <fs_ekpo>  LIKE LINE OF gt_ekpo,
               <fs_zadr>  LIKE LINE OF gt_zadr,
               <fs_lfa1>  LIKE LINE OF gt_lfa1,
               <fs_tve2t> LIKE LINE OF gt_tve2t,
               <fs_ekko>  LIKE LINE OF gt_ekko,
               <fs_marc>  LIKE LINE OF gt_marc,
               <fs_t001w> LIKE LINE OF gt_t001w,
               <fs_final> LIKE LINE OF gt_final,
               <fs_makt>  LIKE LINE OF gt_makt,
               <fs_adr6>  LIKE LINE OF gt_adr6,
               <fs_const> LIKE LINE OF gt_const,
               <fs_1>     TYPE any,
               <fs_2>     TYPE any.

FIELD-SYMBOLS: <fs_vpobjkey> LIKE LINE OF gr_vpobjkey,
               <fs_vbeln>    LIKE LINE OF gr_vbeln,
               <fs_matnr>    LIKE LINE OF gr_matnr,
               <fs_posnr>    LIKE LINE OF gr_posnr,
               <fs_crit>     LIKE LINE OF gr_crit,
               <fs_regu>     LIKE LINE OF gr_regu,
               <fs_irre>     LIKE LINE OF gr_irre,
               <fs_estr>     LIKE LINE OF gr_estr.

TYPES: BEGIN OF gty_i_entr_det.
        INCLUDE STRUCTURE zbvmm_st_i_entr_det.
TYPES: END OF gty_i_entr_det.
DATA: gt_entrega_det TYPE STANDARD TABLE OF gty_i_entr_det.

*ZBVMM_OC_REGISTRO_ENTR02}

TYPES: BEGIN OF gty_entr_sin_oc,
         flag        TYPE char01,
         lifnr       TYPE zbvmms_entrega_cab-lifnr,
         name1       TYPE zbvmms_entrega_cab-name1,
         vbeln       TYPE zbvmms_entrega_cab-vbeln,
         bukrs       TYPE zbvmms_entrega_cab-bukrs,
         butxt       TYPE zbvmms_entrega_cab-butxt,
         werks       TYPE zbvmms_entrega_cab-werks,
         wname1      TYPE zbvmms_entrega_cab-wname1,
         lgort       TYPE zbvmms_entrega_cab-lgort,
         lgobe       TYPE zbvmms_entrega_cab-lgobe,
         anzpk       TYPE zbvmms_entrega_cab-anzpk,
         codarea     TYPE zbvmms_entrega_cab-codarea,
         descarea    TYPE zbvmms_entrega_cab-descarea,
         motivo      TYPE zbvmms_entrega_cab-motivo,
         motivootros TYPE zbvmms_entrega_cab-motivootros,
         descmotivos TYPE zbvmms_entrega_cab-descmotivos,
         smtpaddrdf  TYPE zbvmms_entrega_cab-smtpaddrdf,
         bolnr       TYPE zbvmms_entrega_cab-bolnr,
         cod         TYPE zbvmms_entrega_cab-cod,
         descrip     TYPE zbvmms_entrega_cab-descrip,
         ernam       TYPE zbvmms_entrega_cab-ernam,
         ernam2      TYPE zbvmms_entrega_cab-ernam2,
         idate       TYPE zbvmms_entrega_cab-idate,
         codcond     TYPE zbvmms_entrega_cab-codcond,
         desccond    TYPE zbvmms_entrega_cab-desccond,
         printer     TYPE zbvmms_entrega_cab-printer,
         xhupf       TYPE zbvmms_entrega_cab-xhupf,
         idate2      TYPE zbvmms_entrega_cab-idate2,
         werksf      TYPE zbvmms_entrega_cab-werksf,
         name1wf     TYPE zbvmms_entrega_cab-name1wf,
         smtpaddrp   TYPE zbvmms_entrega_cab-smtpaddrp,
         ernamur     TYPE zbvmms_entrega_cab-ernamur,
         fecharec    TYPE zbvmms_entrega_cab-fecharec,
*********Detalle
         numemb      TYPE c LENGTH 35,
         tipoemb     TYPE c LENGTH 5,
         desctipoemb TYPE c LENGTH 20,
         ubiemb      TYPE c LENGTH 5,
         descubiemb  TYPE c LENGTH 20,
         inhalt      TYPE c LENGTH 40,
         peso        TYPE c LENGTH 18,
         largo       TYPE c LENGTH 18,
         ancho       TYPE c LENGTH 18,
         altura      TYPE c LENGTH 18,
         item        TYPE c LENGTH 3,
         maktx       TYPE c LENGTH 40,
         vemng       TYPE c LENGTH 20,
         meins       TYPE c LENGTH 3,
         msehl       TYPE c LENGTH 30,
         obsmat      TYPE c LENGTH 80,
         gewei       TYPE c LENGTH 3,
       END OF gty_entr_sin_oc.

TYPES: BEGIN OF gty_entrega_change,
         vbeln   TYPE vbeln,
         lfdat   TYPE lfdat,
         lfuhr   TYPE lfuhr,
         bolnr   TYPE bolnr,
         zzlfstk TYPE ze_lfstk,
         bolnrx  TYPE abap_bool,
         datex   TYPE abap_bool,
         statusx TYPE abap_bool,
         param   TYPE ZGE_T_CONSTANTES-low,
       END OF gty_entrega_change.



DATA:   g_error           TYPE abap_bool,
        g_marc_nohu       TYPE abap_bool,
        g_texto_error     TYPE bapi_msg,
        g_msg             TYPE bapi_msg, "natxt,
        g_msgid           TYPE sy-msgid, "symsgid,
        g_msgno           TYPE sy-msgno, "symsgno,
        g_m1              TYPE sy-msgv1,
        g_m2              TYPE sy-msgv2,
        g_m3              TYPE sy-msgv3,
        g_m4              TYPE sy-msgv4,
        gs_entrega_change TYPE gty_entrega_change,
*          gs_entrega_change_bolnr TYPE gty_entrega_change_bolnr,
        g_ok              TYPE abap_bool,
        g_syno0           TYPE abap_bool,
        g_pesototal       TYPE gsgew,
        gv_msg(220)       TYPE c,
        gt_result         TYPE STANDARD TABLE OF zbvmm_st_result_planificacion,
        gt_emb_compl      TYPE STANDARD TABLE OF gty_emb_compl,
        gt_emb_compl_mod  TYPE STANDARD TABLE OF gty_emb_compl_mod, "MP
        gt_emb_compl_re   TYPE STANDARD TABLE OF gty_emb_compl_recep. "MP

TYPES: INBDELIVDETAIL_TYPE LIKE BBP_INBD_D OCCURS 0.
TYPES: RETURN_TYPE LIKE BAPIRETURN OCCURS 0.
*{+@001
  TYPES: BEGIN OF gty_executed,
           doc_nr     TYPE msr_doc_nr,
           doc_item   TYPE msr_doc_item,
         END OF gty_executed.
  DATA: lv_doc_type TYPE msr_doc_type,
        lt_executed TYPE STANDARD TABLE OF gty_executed.
*}+@001
DEFINE mac_conv_msg.

  CALL FUNCTION 'BAPI_MESSAGE_GETDETAIL'
     EXPORTING
        id                 = &1-id
        number             = &1-number
        language           = 'S'
        textformat         = 'ASC'
*        linkpattern        =
        message_v1         = &1-message_v1
        message_v2         = &1-message_v2
        message_v3         = &1-message_v3
        message_v4         = &1-message_v4
*                        language_iso       =
     IMPORTING
        message            = &2
*                        RETURN             =
*                      TABLES
*                        TEXT               =
                               .

END-OF-DEFINITION.
DEFINE mac_ap_table.
  LOOP AT &1 ASSIGNING <fs_1>.
    APPEND INITIAL LINE TO &2 ASSIGNING <fs_2>.
    MOVE-CORRESPONDING <fs_1> TO <fs_2>.
  ENDLOOP.

END-OF-DEFINITION.
DEFINE mac_sort_range.
  SORT &1.
  DELETE ADJACENT DUPLICATES FROM &1 COMPARING low.
END-OF-DEFINITION.
