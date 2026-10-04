import assert from "node:assert/strict";
import { after, before, beforeEach, test } from "node:test";
import { createApp } from "../src/app.js";
import { parsePort } from "../src/config.js";

const calls = [];
let queryResult;
let queryError;
let server;
let baseUrl;

const pool = {
  async query(...args) {
    calls.push(args);
    if (queryError) throw queryError;
    return queryResult;
  },
};

const logger = {
  error() {},
};

before(async () => {
  server = createApp(pool, logger).listen(0, "127.0.0.1");
  await new Promise((resolve, reject) => {
    server.once("listening", resolve);
    server.once("error", reject);
  });
  baseUrl = `http://127.0.0.1:${server.address().port}`;
});

after(async () => {
  await new Promise((resolve, reject) => {
    server.close((error) => (error ? reject(error) : resolve()));
  });
});

beforeEach(() => {
  calls.length = 0;
  queryResult = { rows: [] };
  queryError = null;
});

test("liveness endpoint does not require a database query", async () => {
  const response = await fetch(`${baseUrl}/health/live`);

  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), { status: "ok" });
  assert.equal(calls.length, 0);
});

test("readiness endpoint checks database connectivity", async () => {
  const response = await fetch(`${baseUrl}/health/ready`);

  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), { status: "ready" });
  assert.deepEqual(calls, [["SELECT 1"]]);
});

test("readiness returns 500 when the database is unavailable", async () => {
  queryError = new Error("database unavailable");
  const response = await fetch(`${baseUrl}/health/ready`);

  assert.equal(response.status, 500);
  assert.deepEqual(await response.json(), { error: "Internal server error" });
});

test("categories endpoint returns active category rows", async () => {
  queryResult = { rows: [{ id: "cat-1", parentId: null, name: "Computer Parts", slug: "computer-parts" }] };
  const response = await fetch(`${baseUrl}/api/categories`);

  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), { data: queryResult.rows });
  assert.match(calls[0][0], /WHERE is_active = true/);
});

test("products endpoint uses the default limit and parameterized query", async () => {
  queryResult = { rows: [{ id: "product-1", pricePaise: 12999 }] };
  const response = await fetch(`${baseUrl}/api/products`);

  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), { data: queryResult.rows });
  assert.deepEqual(calls[0][1], [24]);
  assert.match(calls[0][0], /LIMIT \$1/);
});

test("products endpoint accepts a valid limit", async () => {
  const response = await fetch(`${baseUrl}/api/products?limit=100`);

  assert.equal(response.status, 200);
  assert.deepEqual(calls[0][1], [100]);
});

test("products endpoint rejects invalid limits without querying the database", async (t) => {
  for (const limit of ["0", "101", "-1", "1.5", "abc", "9007199254740992", "1&limit=2"]) {
    await t.test(`limit=${limit}`, async () => {
      calls.length = 0;
      const response = await fetch(`${baseUrl}/api/products?limit=${encodeURIComponent(limit)}`);

      assert.equal(response.status, 400);
      assert.deepEqual(await response.json(), {
        error: "limit must be an integer between 1 and 100",
      });
      assert.equal(calls.length, 0);
    });
  }
});

test("database errors do not expose internal details", async () => {
  queryError = new Error("private database detail");
  const response = await fetch(`${baseUrl}/api/products?limit=1`);

  assert.equal(response.status, 500);
  assert.deepEqual(await response.json(), { error: "Internal server error" });
});

test("products endpoint rejects duplicate limit parameters", async () => {
  const response = await fetch(`${baseUrl}/api/products?limit=1&limit=2`);

  assert.equal(response.status, 400);
  assert.equal(calls.length, 0);
});

test("parsePort accepts a valid port", () => {
  assert.equal(parsePort("8080"), 8080);
});

test("parsePort rejects malformed and out-of-range values", () => {
  for (const value of ["", "0", "65536", "8080abc", "1.5", "-1"]) {
    assert.throws(() => parsePort(value), /PORT must be a valid TCP port/);
  }
});
