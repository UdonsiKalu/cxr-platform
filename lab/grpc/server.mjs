import grpc from "@grpc/grpc-js";
import protoLoader from "@grpc/proto-loader";
import { ReflectionService } from "@grpc/reflection";
import path from "path";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const PROTO_PATH = path.join(__dirname, "cxr_claim.proto");

const packageDefinition = protoLoader.loadSync(PROTO_PATH, {
  keepCase: true,
  longs: String,
  enums: String,
  defaults: true,
  oneofs: true,
});

const cxr = grpc.loadPackageDefinition(packageDefinition).cxr.v1;

const claims = {
  "demo-1": {
    status: "ok",
    summary: "SW.16 gRPC lab — analyzed claim (matches GraphQL/Kafka fixtures)",
  },
  "demo-2": {
    status: "review",
    summary: "Pending policy check",
  },
};

function getClaimStatus(call, callback) {
  const { claim_id } = call.request;
  const row = claims[claim_id];
  if (!row) {
    callback({
      code: grpc.status.NOT_FOUND,
      message: `claim ${claim_id} not found`,
    });
    return;
  }
  callback(null, {
    claim_id,
    status: row.status,
    summary: row.summary,
  });
}

function analyzeClaim(call, callback) {
  const start = Date.now();
  const { claim_id } = call.request;
  const row = claims[claim_id] ?? {
    status: "ok",
    summary: `Mock analyze for ${claim_id}`,
  };
  callback(null, {
    claim_id,
    status: row.status,
    summary: row.summary,
    latency_ms: Date.now() - start + 42,
  });
}

const server = new grpc.Server();
server.addService(cxr.ClaimAnalysis.service, {
  GetClaimStatus: getClaimStatus,
  AnalyzeClaim: analyzeClaim,
});

const reflection = new ReflectionService(packageDefinition);
reflection.addToServer(server);

const port = process.env.GRPC_PORT || "50051";
const bindTarget = `0.0.0.0:${port}`;

    server.bindAsync(
  bindTarget,
  grpc.ServerCredentials.createInsecure(),
  (err, boundPort) => {
    if (err) {
      console.error(err);
      process.exit(1);
    }
    console.log(`ClaimAnalysis gRPC ready on ${bindTarget} (bound ${boundPort})`);
  }
);
