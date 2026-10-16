package pe.bnv.pocrfc.model;

import java.math.BigDecimal;
import java.time.LocalDate;

/**
 * Una fila de T_TCURR.
 *
 * {@code fecha} es el GDATU ya decodificado; sale como ISO-8601 (2020-09-07).
 * {@code gdatu} conserva el valor crudo tal como lo manda SAP, que es la forma
 * invertida: 99999999 menos la fecha. Se mantiene porque esta es una sonda de
 * diagnóstico y conviene poder cotejar contra lo que se ve en SE16.
 */
public record TipoCambioDto(
        LocalDate fecha,       // GDATU decodificado
        String gdatu,          // GDATU crudo, como viaja por RFC
        String monedaOrigen,   // FCURR
        String monedaDestino,  // TCURR
        BigDecimal tipoCambio  // UKURS
) {}
