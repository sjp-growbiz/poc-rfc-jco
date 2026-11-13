# Réplica de prepare_data + agregar_mat (LZGF_CON_PORTALF01) para ZET_MOSTRAR_REGISTROSet.
def armar(lips, vepo, corregido=False):
    final = []
    for l in lips:                                   # LOOP AT gt_likps
        R = dict(posnr=l["posnr"], vgpos=l["vgpos"], matnr=l["matnr"], hu="")
        final.append(R); idx_actual = len(final) - 1
        final_vepo = []                              # REFRESH gt_final_vepo
        for n, v in enumerate([v for v in vepo if v["posnr"] == l["posnr"]]):
            if n == 0:
                R["hu"] = v["hu"]; final_vepo.append(dict(R))
            else:
                final_vepo.append(dict(R, hu=v["hu"]))
        if final_vepo:                               # PERFORM agregar_mat
            tabix = None
            for fv in final_vepo:
                if corregido:
                    tabix = idx_actual
                else:                                # READ TABLE gt_final WITH KEY zvbeln zvgpos zebeln zmatnr
                    tabix = next(i for i, f in enumerate(final) if f["vgpos"] == fv["vgpos"] and f["matnr"] == fv["matnr"])
                final.append(fv)
            del final[tabix]                         # DELETE gt_final INDEX lv_tabix
    return final

# Entrega como la 1800133298: agua, 2 vencimientos = 2 posiciones (@007); lote A en bulto 1, lote B en bulto 2
lips = [dict(posnr="000010", vgpos="000010", matnr="AGUA"), dict(posnr="000020", vgpos="000010", matnr="AGUA")]
vepo = [dict(posnr="000010", hu="BULTO 1"), dict(posnr="000020", hu="BULTO 2")]
for etiqueta, c in (("HOY", False), ("CORREGIDO", True)):
    filas = armar(lips, vepo, c)
    print(etiqueta.ljust(10), [(f["posnr"], f["hu"]) for f in filas], "-> bultos:", sorted({f["hu"] for f in filas}))
