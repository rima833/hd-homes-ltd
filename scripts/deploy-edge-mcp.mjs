import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { StreamableHTTPClientTransport } from "@modelcontextprotocol/sdk/client/streamableHttp.js";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(__dirname, "..");
const projectRef = "wbonjdqsifwsawhhxygl";
const fn = process.argv[2];

if (!fn || !["process-email-queue", "send-test-email"].includes(fn)) {
  console.error("Usage: node scripts/deploy-edge-mcp.mjs <process-email-queue|send-test-email>");
  process.exit(1);
}

const payloadPath = path.join(root, `.mcp-deploy-${fn === "process-email-queue" ? "pq" : "st"}.json`);
const payload = JSON.parse(fs.readFileSync(payloadPath, "utf8"));

const transport = new StreamableHTTPClientTransport(
  new URL(`https://mcp.supabase.com/mcp?project_ref=${projectRef}`),
);

const client = new Client({ name: "deploy-edge-mcp", version: "1.0.0" }, { capabilities: {} });
await client.connect(transport);

const result = await client.callTool({
  name: "deploy_edge_function",
  arguments: payload,
});

console.log(JSON.stringify(result, null, 2));
await client.close();
