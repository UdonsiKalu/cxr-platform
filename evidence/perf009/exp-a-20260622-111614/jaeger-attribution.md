# PERF-009 extract — Experiment A @ 20260622-111614

Fast candidates: 80 | Slow candidates: 80

| Span | Fast (median ms) | Slow (median ms) | Δ slow − fast |
|------|------------------|------------------|---------------|
| UI POST (root) | 147.0 | 789.3 | +642.3 |
| UI route handler | 143.0 | 785.2 | +642.2 |
| UI → analyzer HTTP (fetch) | 141.5 | 783.8 | +642.3 |
| HTTP/client wait (fetch − analyze_request) | 32.5 | 567.5 | +535.0 |
| analyzer_service.analyze_request | 114.3 | 248.5 | +134.2 |
| claim_analysis | 112.2 | 246.8 | +134.6 |
| archetype_reasoning | 45.0 | 121.1 | +76.1 |
| context_builder | 65.7 | 144.8 | +79.1 |
| policy extraction (context.7_policy*) | 63.1 | 142.5 | +79.4 |
| retrieval | 0.0 | 0.1 | +0.1 |
| LLM / Ollama (llm_inference*) | 0.1 | 0.0 | -0.1 |
| save_result | 0.1 | 0.1 | +0.0 |
