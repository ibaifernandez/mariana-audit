{
  "schema_version": "1.0",
  "audit_id": "<repo>-YYYY-MM-DD-mariana",
  "started_at": "YYYY-MM-DDTHH:MM:SSZ",
  "finished_at": "YYYY-MM-DDTHH:MM:SSZ",
  "auditor": "mariana-audit skill v1",
  "mode": "report | mitigate | case-by-case",
  "repo": {
    "path": "/absolute/path",
    "remote": "https://github.com/owner/repo",
    "commit_at_start": "<sha>",
    "commit_at_end": "<sha>"
  },
  "graphify": {
    "local_graph": "graphify-out/graph.json",
    "local_graph_node_count": 0,
    "global_published": true,
    "global_tag": "<tag>",
    "graph_stale_warning": false
  },
  "scope": {
    "stack_archetype": "saas | static-vitrina | cli-library | public-api | internal-tool",
    "dimensions": {
      "A_producto": { "applicable": true, "reason": "" },
      "B_backend": { "applicable": true, "reason": "" },
      "C_legal": { "applicable": true, "reason": "" },
      "D_ops": { "applicable": true, "reason": "" }
    }
  },
  "fases_completed": ["0", "A", "B", "C", "D", "E"],
  "summary": {
    "critical_total": 0,
    "critical_mitigated_during_audit": 0,
    "critical_open": 0,
    "high": 0,
    "medium": 0,
    "low": 0,
    "info": 0,
    "no_verificable": 0
  },
  "findings": [
    {
      "id": "B-CRIT-01",
      "fase": "B",
      "dimension": "security",
      "title": "XSS via SVG upload",
      "description": "Multer accepts SVG without fileFilter; served via express.static under same origin as app.",
      "severity": "CRITICAL",
      "severity_score": 8.0,
      "severity_metadata": {
        "cvss_3_1_vector": "AV:N/AC:L/PR:L/UI:R/S:C/C:H/I:H/A:L",
        "owasp_2021": "A03",
        "attacker_level": "Authenticated User",
        "user_interaction_required": true,
        "scope_changed": true,
        "impact": { "C": "High", "I": "High", "A": "Low" }
      },
      "evidence": [
        {
          "type": "code-read",
          "file": "server/routes/uploads.js",
          "line": 18,
          "snippet": "const upload = multer({ storage, limits: { fileSize: 50 * 1024 * 1024 } });"
        },
        {
          "type": "code-read",
          "file": "server/app.js",
          "line": 77,
          "snippet": "app.use('/uploads', express.static(path.join(__dirname, 'uploads')));"
        },
        {
          "type": "code-read",
          "file": "netlify.toml",
          "line": null,
          "snippet": "[[redirects]] from = '/uploads/*' to = 'https://<railway>/uploads/:splat'"
        }
      ],
      "evidence_source": "code-read",
      "remediation": {
        "playbook": "playbooks/xss-svg-upload.md",
        "effort_hours": 4,
        "status": "MITIGATED",
        "mitigation_sha": "402b0d7",
        "mitigation_date": "2026-05-27T20:00:00Z",
        "verification": "smoke test passed + 5 regression tests added + prod redeploy verified"
      },
      "cross_canon": {
        "similar_pattern_in": [],
        "inherits_from": null
      },
      "priority": "P0",
      "sprint": "Sprint 1 (closed)"
    },
    {
      "id": "C-01",
      "fase": "C",
      "dimension": "legal",
      "title": "App lacks dedicated privacy policy",
      "description": "Public app served at <domain> has no privacy policy page; landing returns SPA catch-all to root.",
      "severity": "CRITICAL",
      "severity_score": null,
      "severity_metadata": {
        "regulation": "GDPR",
        "article": "GDPR Art. 13",
        "additional_articles": ["GDPR Art. 14", "Ley 21.719 Art. 14 ter"],
        "data_subjects_affected": "all users (EU + Chile + others)",
        "fine_exposure": "up to 4% global revenue or €20M (GDPR); up to 5,000 UTM (Ley 21.719)"
      },
      "evidence": [
        {
          "type": "manual-verification",
          "url": "https://<app>/privacy",
          "result": "404 / SPA catch-all"
        }
      ],
      "evidence_source": "manual-verification",
      "remediation": {
        "playbook": null,
        "effort_hours": 6,
        "external_resource_required": true,
        "external_resource": "Legal review (€500-1500)",
        "status": "OPEN"
      },
      "cross_canon": {
        "similar_pattern_in": [],
        "inherits_from": null
      },
      "priority": "P0",
      "sprint": "Sprint 1"
    }
  ],
  "cross_canon_inheritance_used": [
    {
      "current_finding_id": "B-CRIT-02",
      "inherited_from_repo": "<other-repo-tag>",
      "inherited_from_finding_id": "<other-finding-id>",
      "reason": "same Supabase Free + no backup pattern"
    }
  ],
  "no_verificable_items": [
    {
      "id": "A-NV-01",
      "description": "Core Web Vitals (LCP/INP/CLS) for production",
      "reason": "Requires Lighthouse run against deploy with auth session",
      "recommended_external_action": "Run PageSpeed Insights manually against logged-in pages"
    }
  ],
  "external_resources_required": [
    {
      "type": "legal",
      "description": "Privacy policy drafting + review",
      "estimated_cost_eur": 1000
    },
    {
      "type": "tooling",
      "description": "axe-core + Stark for full a11y verification",
      "estimated_cost_eur": 0
    },
    {
      "type": "service-upgrade",
      "description": "Supabase Pro $25/mo for PITR",
      "estimated_cost_eur_monthly": 25
    }
  ]
}
