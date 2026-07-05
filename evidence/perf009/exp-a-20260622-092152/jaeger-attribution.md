# PERF-009 extract — Experiment A @ 20260622-092152

Fast candidates: 80 | Slow candidates: 80

| Span | Fast (median ms) | Slow (median ms) | Δ slow − fast |
|------|------------------|------------------|---------------|
| UI POST (root) | 148.4 | 793.7 | +645.3 |
| UI route handler | 145.3 | 791.0 | +645.7 |
| UI → analyzer HTTP (fetch) | 144.1 | 789.6 | +645.5 |
| HTTP/client wait (fetch − analyze_request) | 47.5 | 664.8 | +617.3 |
| analyzer_service.analyze_request | 92.9 | 121.2 | +28.3 |
| claim_analysis | 90.7 | 116.2 | +25.5 |
| archetype_reasoning | 22.6 | 58.5 | +35.9 |
| context_builder | 27.0 | 59.2 | +32.2 |
| policy extraction (context.7_policy*) | 25.2 | 58.0 | +32.8 |
| retrieval | 0.0 | 0.0 | +0.0 |
| LLM / Ollama (llm_inference*) | 0.0 | 0.0 | +0.0 |
| save_result | 0.0 | 0.1 | +0.1 |
