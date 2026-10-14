const fs = require("fs");
const path = require("path");

const root = path.resolve(__dirname, "..");
const argPath = process.argv[2];
if (!argPath) {
  console.error("Usage: node scripts/mcp-deploy-from-json.cjs <payload.json>");
  process.exit(1);
}
const payload = JSON.parse(fs.readFileSync(path.resolve(root, argPath), "utf8"));
const outPath = path.join(root, ".mcp-deploy-last-args.json");
fs.writeFileSync(outPath, JSON.stringify(payload));
console.log(
  JSON.stringify({
    ok: true,
    name: payload.name,
    verify_jwt: payload.verify_jwt,
    entrypoint_path: payload.entrypoint_path,
    files: payload.files.map((f) => f.name),
    bytes: Buffer.byteLength(JSON.stringify(payload)),
    outPath,
  }),
);
