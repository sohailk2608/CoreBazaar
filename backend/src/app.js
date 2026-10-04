import express from "express";
import helmet from "helmet";

export function createApp(pool, logger = console) {
  const app = express();

  app.disable("x-powered-by");
  app.use(helmet());
  app.use(express.json({ limit: "32kb" }));

  app.get("/health/live", (_request, response) => {
    response.status(200).json({ status: "ok" });
  });

  app.get("/health/ready", async (_request, response, next) => {
    try {
      await pool.query("SELECT 1");
      response.status(200).json({ status: "ready" });
    } catch (error) {
      next(error);
    }
  });

  app.get("/api/categories", async (_request, response, next) => {
    try {
      const result = await pool.query(
        `SELECT id, parent_id AS "parentId", name, slug
         FROM categories
         WHERE is_active = true
         ORDER BY sort_order, name`,
      );
      response.json({ data: result.rows });
    } catch (error) {
      next(error);
    }
  });

  app.get("/api/products", async (request, response, next) => {
    const rawLimit = request.query.limit ?? "24";
    const limit =
      typeof rawLimit === "string" && /^\d+$/.test(rawLimit)
        ? Number(rawLimit)
        : Number.NaN;
    if (!Number.isSafeInteger(limit) || limit < 1 || limit > 100) {
      response.status(400).json({ error: "limit must be an integer between 1 and 100" });
      return;
    }

    try {
      const result = await pool.query(
        `SELECT p.id, p.sku, p.title, p.description, p.brand,
                p.price_paise AS "pricePaise", p.currency,
                c.id AS "categoryId", c.name AS "categoryName"
         FROM products p
         JOIN categories c ON c.id = p.category_id
         WHERE p.status = 'active' AND c.is_active = true
         ORDER BY p.created_at DESC
         LIMIT $1`,
        [limit],
      );
      response.json({ data: result.rows });
    } catch (error) {
      next(error);
    }
  });

  app.use((error, _request, response, _next) => {
    logger.error("Request failed", error);
    if (response.headersSent) return;
    response.status(500).json({ error: "Internal server error" });
  });

  return app;
}
