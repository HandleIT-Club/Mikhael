# Contribuir a Mikhael

¡Gracias por tu interés en contribuir! Mikhael es un asistente personal de IA de código abierto, y cualquier mejora —por pequeña que sea— es bienvenida.

## Cómo empezar

1. **Hacé un fork** del repositorio en GitHub.
2. **Cloná tu fork** localmente:
   ```bash
   git clone https://github.com/tu-usuario/mikhael.git
   cd mikhael
   ```
3. **Configurá el entorno**:
   ```bash
   bundle install
   cp .env.example .env   # completá con tus keys de desarrollo
   bin/rails db:setup
   ```
4. **Creá una rama** desde `main` con un nombre descriptivo:
   ```bash
   git checkout -b feature/mi-mejora
   # o
   git checkout -b fix/descripcion-del-bug
   ```
5. **Hacé tus cambios**, commiteá y pusheá tu rama a tu fork.
6. **Abrí un Pull Request** contra `main` de este repositorio.

## Requisitos para que un PR sea aceptado

Antes de abrir el PR, asegurate de que todo esto pase:

```bash
bundle exec rspec          # todos los tests en verde
bundle exec rubocop        # sin ofensas de estilo
bundle exec brakeman -q    # sin advertencias de seguridad
```

### Tests

- **Todo cambio de comportamiento requiere tests.** Si agregás una feature, escribí los specs. Si corregís un bug, escribí un test que hubiera detectado ese bug.
- Los tests van en `spec/` siguiendo la estructura existente (`spec/services/`, `spec/operations/`, `spec/models/`, etc.).
- No se aceptan PRs que bajen la cobertura de casos críticos sin justificación.

### Estilo

- Seguimos la configuración de RuboCop del proyecto (`.rubocop.yml`).
- Sin `binding.pry`, `puts` de debug ni código comentado en el diff final.
- Commits en inglés o español, lo que prefieras, pero descriptivos.

### Seguridad

- No incluyas API keys, tokens ni secretos en el código ni en los tests.
- Si encontrás una vulnerabilidad de seguridad, **no abras un issue público** — escribime directamente.

## Qué tipo de contribuciones se valoran

- Nuevos providers de IA (si tienen API compatible con OpenAI)
- Mejoras al sistema de fallback entre modelos
- Nuevas integraciones (dispositivos, protocolos)
- Corrección de bugs con test incluido
- Mejoras de documentación y ejemplos
- Traducciones de la UI

## Qué no entra en el scope del proyecto

- Funcionalidades que requieran exponer Mikhael a internet (no hay servidor público por diseño)
- Dependencias pesadas sin justificación clara
- Cambios que rompan la compatibilidad con el flujo de instalación simple (`bin/mikhael`)

## Proceso de revisión

- Los PRs se revisan tan pronto como sea posible.
- Si un PR lleva más de 7 días sin actividad después del feedback, puede cerrarse.
- Un PR aprobado se mergea con **squash** para mantener el historial limpio.

---

Ante cualquier duda, abrí un [issue](https://github.com/nicolassnavarro/mikhael/issues) y con gusto lo charlamos.
