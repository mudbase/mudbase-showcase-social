package dev.mudbase.showcase.social;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.context.properties.ConfigurationPropertiesScan;

/**
 * Mudbase Showcase — Social: a realtime micro-blog served entirely by Mudbase
 * (cloud.mudbase.dev) — auth, database, no custom backend of any kind. This Spring Boot +
 * Thymeleaf app is the Java reimplementation of the reference Next.js app at ../web - same Mudbase
 * project, same four collections, same business rules; see plan/build-plan.md for what
 * deliberately differs (no realtime layer, no registration UI) and why.
 */
@SpringBootApplication
@ConfigurationPropertiesScan
public class SocialApplication {

  public static void main(String[] args) {
    SpringApplication.run(SocialApplication.class, args);
  }
}
