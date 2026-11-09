# ADR-010: Backend en Laravel 13 (PHP 8.3)

- **Estado:** Aceptada

## Contexto

El documento de análisis contempló evaluar entre Spring Boot (Java) y Laravel (PHP) en la semana 1 para construir la API REST.

## Alternativas

- Spring Boot (Java).
- Laravel 13 (PHP 8.3).

## Decisión

Implementar la API en Laravel 13 con PHP 8.3, tokens personales estilo Sanctum con expiración de 24 h, validación mediante reglas declarativas, Eloquent ORM y pruebas automatizadas en PHPUnit.

## Consecuencias

- Menor sobrecarga de configuración, migraciones versionadas portables y formateo estático PSR-12 integrado con Laravel Pint.
