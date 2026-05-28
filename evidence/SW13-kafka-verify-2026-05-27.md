# SW.13 Kafka verify — 2026-05-27

- Timestamp: `2026-05-27T16:53:06-05:00`
- Stack start command: `./scripts/06-kafka-up.sh`
- Result: Kafka and Zookeeper containers created and started successfully.

## Runtime checks

- `docker ps` shows:
  - `cxr-ops-lab-kafka-1` up with `0.0.0.0:9092->9092/tcp`
  - `cxr-ops-lab-zookeeper-1` up
- Kafka topic create/list check:
  - Created topic: `cxr.claims.events`
  - Verified topic exists in `kafka-topics --list`

## Notes

- Initial run pulled Kafka/Zookeeper images (first-time cold pull).
- Kafka warning about `.` and `_` topic naming is informational; current topic was created successfully.
