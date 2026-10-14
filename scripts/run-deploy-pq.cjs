const fs = require("fs");
const path = require("path");
const root = path.resolve(__dirname, "..");
const args = JSON.parse(
  fs.readFileSync(path.join(root, ".deploy-pq-v9-args.json"), "utf8"),
);
fs.writeFileSync(
  path.join(root, ".deploy-pq-v10-payload.json"),
  JSON.stringify({
    name: args.name,
    entrypoint_path: args.entrypoint_path,
    verify_jwt: args.verify_jwt,
    files: args.files.map((f) => ({
      name: f.name,
      contentLength: f.content.length,
      hasWrap: f.content.includes("wrapEmailHtml"),
      hasQueue: f.content.includes("notification_delivery"),
    })),
  }),
);
console.log("payload_ok");
