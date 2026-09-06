# Aquí va la librería nativa de JCo

Este directorio está vacío a propósito. `libsapjco3.so` es software licenciado
por SAP y no se versiona ni se redistribuye.

## Qué descargar

Del SAP Support Portal, con usuario S:

- Página del producto: https://support.sap.com/en/product/connectors/jco.html
- Sección de descargas: https://support.sap.com/en/product/connectors/jco.html?anchorId=section_2129803369
- Ruta directa en el Software Center: SAP Software Download Center → Support Packages and Patches
  → By Category → Additional Components → SAP JAVA CONNECTOR → SAP JCO 3.1

Elegir la plataforma **LINUX ON X86_64 64BIT**
(salvo que el servidor sea de otra arquitectura: comprobar con `uname -m`).

## Qué hacer con el paquete

El `.zip` o `.tgz` trae el `sapjco3.jar` y la `libsapjco3.so`.

Lo hace `../setup.sh`:

```bash
./setup.sh ../sapjco31P_14-70004517.zip
```

Extrae el jar y la `.so` del mismo paquete, con lo que quedan alineados por
construcción. JCo verifica que coincidan y se niega a arrancar si no lo hacen.

El paquete que ya está en el repositorio raíz es **3.1.14, linuxx86_64**,
verificado como ELF x86-64.

## Por qué no está en el classpath

JCo carga la nativa desde `java.library.path`, no desde el classpath. En los
proyectos actuales la `sapjco3.dll` está en `src/main/resources`, y desde ahí
JCo no la encuentra.
