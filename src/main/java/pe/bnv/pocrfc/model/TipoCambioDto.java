package pe.bnv.pocrfc.model;

import java.math.BigDecimal;

/** Una fila de T_TCURR. */
public record TipoCambioDto(
        String fecha,          // GDATU
        String monedaOrigen,   // FCURR
        String monedaDestino,  // TCURR
        BigDecimal tipoCambio  // UKURS
) {}
