package pe.bnv.pocrfc;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import pe.bnv.pocrfc.config.JCoProperties;

@SpringBootApplication
@EnableConfigurationProperties(JCoProperties.class)
public class PocRfcApplication {
    public static void main(String[] args) {
        SpringApplication.run(PocRfcApplication.class, args);
    }
}
