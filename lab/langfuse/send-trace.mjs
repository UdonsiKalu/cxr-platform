import { Langfuse } from "langfuse";
import { existsSync, readFileSync } from "fs";
import path from "path";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const keysPath = path.join(__dirname, "keys.env");

function loadKeys() {
  if (!existsSync(keysPath)) {
    return null;
  }
  const env = {};
  for (const line of readFileSync(keysPath, "utf8").split("\n")) {
    const t = line.trim();
    if (!t || t.startsWith("#")) continue;
    const i = t.indexOf("=");
    if (i === -1) continue;
    env[t.slice(0, i).trim()] = t.slice(i + 1).trim();
  }
  return env;
}

const keys = loadKeys();
if (!keys?.LANGFUSE_PUBLIC_KEY || !keys?.LANGFUSE_SECRET_KEY) {
  console.log(
    "SKIP  no lab/langfuse/keys.env — create project API keys in UI first"
  );
  process.exit(0);
}

const host = keys.LANGFUSE_HOST || "http://127.0.0.1:3100";
const client = new Langfuse({
  publicKey: keys.LANGFUSE_PUBLIC_KEY,
  secretKey: keys.LANGFUSE_SECRET_KEY,
  baseUrl: host,
});

const trace = client.trace({
  name: "cxr-sw18-golden-path",
  input: { feature: "doc-reasoning-sketch", claim_id: "demo-1" },
  metadata: { lab: "SW.18", syllabus: "M7.8" },
});

trace.generation({
  name: "mock-llm-call",
  model: "bootcamp-mock",
  input: "Summarize claim demo-1 for CXR bootcamp.",
  output: "Mock analysis OK — Langfuse trace captured.",
});

await client.shutdownAsync();
console.log("OK  Langfuse trace cxr-sw18-golden-path sent to", host);
