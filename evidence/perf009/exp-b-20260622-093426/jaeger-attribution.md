# PERF-009 extract — Experiment B @ 20260622-093426

Fast candidates: 80 | Slow candidates: 80

| Span | Fast (median ms) | Slow (median ms) | Δ slow − fast |
|------|------------------|------------------|---------------|
| UI POST (root) | 148.3 | 792.0 | +643.7 |
| UI route handler | 145.7 | 790.2 | +644.5 |
| UI → analyzer HTTP (fetch) | 144.6 | 779.7 | +635.1 |
| HTTP/client wait (fetch − analyze_request) | 109.3 | 674.1 | +564.8 |
| analyzer_service.analyze_request | 30.1 | 103.3 | +73.2 |
| claim_analysis | 28.7 | 98.5 | +69.8 |
| archetype_reasoning | 22.3 | 57.6 | +35.3 |
| context_builder | 4.2 | 39.0 | +34.8 |
| policy extraction (context.7_policy*) | 2.4 | 37.4 | +35.0 |
| retrieval | 0.0 | 0.0 | +0.0 |
| LLM / Ollama (llm_inference*) | 0.0 | 0.0 | +0.0 |
| save_result | 0.0 | 0.1 | +0.1 |
