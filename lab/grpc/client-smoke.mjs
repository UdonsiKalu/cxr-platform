import grpc from "@grpc/grpc-js";
import protoLoader from "@grpc/proto-loader";
import path from "path";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const PROTO_PATH = path.join(__dirname, "cxr_claim.proto");
const target = process.env.GRPC_TARGET || "127.0.0.1:50051";

const packageDefinition = protoLoader.loadSync(PROTO_PATH, {
  keepCase: true,
  longs: String,
  enums: String,
  defaults: true,
  oneofs: true,
});

const cxr = grpc.loadPackageDefinition(packageDefinition).cxr.v1;
const client = new cxr.ClaimAnalysis(
  target,
  grpc.credentials.createInsecure()
);

function call(method, request) {
  return new Promise((resolve, reject) => {
    client[method](request, (err, response) => {
      if (err) reject(err);
      else resolve(response);
    });
  });
}

const status = await call("GetClaimStatus", { claim_id: "demo-1" });
if (status.status !== "ok") {
  console.error("FAIL GetClaimStatus:", status);
  process.exit(1);
}
console.log("OK  GetClaimStatus demo-1 →", status.status);

const analyzed = await call("AnalyzeClaim", {
  claim_id: "demo-1",
  content: "SW.16 golden-path fixture",
});
if (analyzed.status !== "ok" || !analyzed.summary) {
  console.error("FAIL AnalyzeClaim:", analyzed);
  process.exit(1);
}
console.log("OK  AnalyzeClaim demo-1 →", analyzed.status, `(latency_ms=${analyzed.latency_ms})`);
