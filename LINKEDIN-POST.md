# LinkedIn post draft — Mariana Audit release

Three variants. Pick one or remix.

---

## Variant 1 — Short, builder-style (recommended for LinkedIn)

Esta semana descubrí un XSS explotable en producción en una herramienta que usa mi equipo todos los días.

CVSS 8.0. Cualquier usuario registrado podía subir un SVG con `<script>` embebido, pegar la URL en una tarjeta, y exfiltrar el JWT de la víctima cuando lo abriera.

Mitigado el mismo día. Cuatro capas de defensa, cinco tests de regresión, deploy verificado en producción.

Y otro hallazgo paralelo: la base de datos en Supabase Free sin backups automáticos. Catástrofe latente para una herramienta crítica del equipo. Mitigado también el mismo día: cron diario con `pg_dump` a Cloudflare R2.

¿Cómo? Una sesión de Claude Code aplicando una metodología que he ido refinando estas semanas — auditoría "Fosa de las Marianas" — sobre 13 dimensiones (seguridad, accesibilidad, performance, BD, arquitectura, cumplimiento RGPD, ops…) con citas verificables, severidades calibradas (CVSS, WCAG, artículos legales específicos) y playbooks de mitigación validados en producción.

He empaquetado el proceso completo como un skill público de Claude Code, MIT, con los playbooks que ya cazaron bichos reales.

🔗 https://github.com/ibaifernandez/mariana-audit

Si construyes algo serio con Claude Code, esto te va a doler bien. Y luego, bien.

#ClaudeCode #SoftwareAudit #CyberSecurity #GDPR #AGLAYA

---

## Variant 2 — Story arc, Sebastián-Marroquín-style

Cuento corto:

Lunes — añado una librería de uploads a una herramienta interna de AGLAYA.
Martes — me siento con Claude Code a hacer una auditoría profunda del repo.
Martes 17:49 — Claude me dice "espera, esto es CRÍTICO INMEDIATO. CVSS 8.0. Cualquier usuario registrado puede robar la sesión de cualquier otro."
Martes 18:30 — fix aplicado, 5 tests de regresión, deploy verificado.
Martes 18:45 — segundo CRÍTICO: la base de datos en Supabase Free sin backups. "Si Supabase se cae, perdemos todo el trabajo del equipo."
Martes 22:00 — cron de backup diario corriendo, restore drill ejecutado, todo verde.

Una jornada.

Lo que aprendí:

1️⃣ El grafo de conocimiento del código (vía graphify) hace que la auditoría sea 66× más barata en tokens que `grep`-eando archivos.

2️⃣ Las severidades sin rúbrica son opinión. CVSS, WCAG y artículos legales específicos son la única forma de defender una afirmación.

3️⃣ El patrón "auditar → mitigar → verificar → commitear con trazabilidad" se puede empaquetar en un skill reutilizable.

Lo hice. Lo publico hoy, MIT, en GitHub.

🔗 https://github.com/ibaifernandez/mariana-audit

Si construyes producto, tu próxima sesión de Claude Code merece pasar por aquí.

#ClaudeCode #ProductEngineering #CyberSecurity #GDPR #AGLAYA

---

## Variant 3 — Technical, for engineering audience

Acabo de publicar `mariana-audit`: un skill de Claude Code para auditar repos en profundidad.

13 dimensiones cubiertas:
- Seguridad (CVSS 3.1 + OWASP Top 10 2021)
- Accesibilidad (WCAG 2.1 A/AA/AAA)
- Performance (Core Web Vitals, bundle size, server timing)
- SEO técnico
- Bases de datos (RLS, índices, backups, RTO/RPO)
- Arquitectura y deuda técnica (vía graphify: god nodes, cohesión, complejidad)
- Cumplimiento legal (GDPR, Ley 21.719 Chile, LGPD Brasil, CCPA — con artículos específicos)
- Cookies + consent
- DPAs + transferencias internacionales
- DevOps + CI
- Despliegue + observabilidad
- Documentación + ADRs
- Mantenibilidad

Particularidades:

✅ Potenciado por graphify — consulta un grafo de conocimiento del código en vez de grep raw. Métrica integrada del "graph leverage ratio".

✅ Cross-canon inheritance — si auditas múltiples repos del mismo grafo global, los patrones cazados se heredan como hipótesis a verificar. Cada audit posterior es más rápido y barato.

✅ Tres modos: `report`, `mitigate` (aplica playbooks validados in-flight), `case-by-case`.

✅ Playbooks empíricamente validados — no son teoría. Cada uno tiene un SHA de commit real donde funcionó en producción.

✅ Gate de cooldown — no desperdicia tokens corriendo audits redundantes. Compara fecha del último audit + actividad de commits.

✅ Honesty rules estrictas — `[NO VERIFICABLE]` es un estado de primera clase. No se inventan CVSS ni criterios WCAG.

✅ MIT.

🔗 https://github.com/ibaifernandez/mariana-audit

Validado en producción contra una app Express + Supabase + React multi-tenant. Cazó 2 CRÍTICOS (XSS CVSS 8.0 + ausencia de backups en Supabase Free) en la primera corrida, ambos mitigados ese mismo día con playbooks que ahora vienen incluidos en el skill.

Contribuciones bienvenidas, especialmente playbooks nuevos para patrones CRÍTICO.

#ClaudeCode #SoftwareEngineering #SecurityEngineering #ApplicationSecurity #GDPR #OpenSource
