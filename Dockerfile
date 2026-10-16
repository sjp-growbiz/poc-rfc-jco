# ---------------------------------------------------------------- build
# El JDK de compilación se puede cambiar para comparar comportamientos.
ARG JDK=21
FROM eclipse-temurin:${JDK}-jdk-jammy AS build
WORKDIR /src
COPY pom.xml .
COPY libs ./libs
RUN --mount=type=cache,target=/root/.m2 \
    apt-get update && apt-get install -y --no-install-recommends maven \
 && rm -rf /var/lib/apt/lists/*
# Proxy TLS corporativo (Cisco Umbrella, Zscaler y similares): si la red
# intercepta HTTPS, Maven no valida repo.maven.apache.org y el build muere con
# PKIX. Dejar los certificados de la CA en certs/*.pem y se añaden al truststore
# del JDK. El comodín hace el paso opcional: sin certs/ el bucle no itera.
COPY pom.xml cert[s]/* /tmp/certs/
RUN rm -f /tmp/certs/pom.xml \
 && for c in /tmp/certs/*.pem; do \
      [ -e "$c" ] || continue; \
      keytool -importcert -noprompt -trustcacerts -cacerts -storepass changeit \
              -alias "$(basename "$c" .pem)" -file "$c"; \
    done

COPY src ./src
RUN --mount=type=cache,target=/root/.m2 mvn -B -DskipTests package

# ---------------------------------------------------------------- runtime
ARG JDK=21
FROM eclipse-temurin:${JDK}-jre-jammy

# glibc, no musl: libsapjco3.so está enlazada contra glibc y en Alpine
# falla con UnsatisfiedLinkError.

# curl para el healthcheck y para diagnosticar la red desde dentro del contenedor
RUN apt-get update && apt-get install -y --no-install-recommends curl iputils-ping \
 && rm -rf /var/lib/apt/lists/*

# La librería nativa de JCo NO va en el classpath: va en java.library.path.
# Descargarla del SAP Support Portal (Linux x86_64, misma versión que el jar)
# y dejarla en native/libsapjco3.so antes de construir.
COPY native/libsapjco3.so /usr/local/lib/
RUN ldconfig

# sapjco3.jar va fuera del jar ejecutable y con su nombre original: JCo aborta
# si detecta que su archivo fue renombrado o reempaquetado (ver pom.xml).
COPY libs/sapjco3.jar /app/lib/sapjco3.jar

COPY --from=build /src/target/poc-rfc-jco.jar /app/app.jar
WORKDIR /app
EXPOSE 8080

ENV JAVA_TOOL_OPTIONS="-Djava.library.path=/usr/local/lib -Dloader.path=/app/lib -Dfile.encoding=UTF-8"
ENTRYPOINT ["java","-jar","/app/app.jar"]
