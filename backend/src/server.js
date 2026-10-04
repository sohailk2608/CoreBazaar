import { createApp } from "./app.js";
import { parsePort } from "./config.js";
import pg from "pg";

const { Pool } = pg;
const port = parsePort(process.env.PORT ?? "8080");
const databaseUrl = process.env.DATABASE_URL;

if (!databaseUrl) {
  throw new Error("DATABASE_URL is required");
}

const pool = new Pool({ connectionString: databaseUrl });
const app = createApp(pool);
const server = app.listen(port, "0.0.0.0", () => {
  console.log(`CoreBazaar API listening on ${port}`);
});

async function shutdown(signal) {
  console.log(`Received ${signal}; closing server`);
  server.close(async (error) => {
    if (error) {
      console.error("Failed to close HTTP server", error);
      process.exitCode = 1;
    }
    try {
      await pool.end();
    } catch (poolError) {
      console.error("Failed to close database pool", poolError);
      process.exitCode = 1;
    }
  });
}

process.on("SIGTERM", () => void shutdown("SIGTERM"));
process.on("SIGINT", () => void shutdown("SIGINT"));
