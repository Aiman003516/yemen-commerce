import { and, desc, eq, like, or } from "drizzle-orm";
import { z } from "zod";
import { categories, products, shops } from "../../drizzle/schema";
import { publicProcedure, router } from "../_core/trpc";
import { getDb } from "../db";
import { ensureIbbMarket } from "../marketplace/access";

const unavailable = () => new Error("قاعدة البيانات غير متاحة حالياً.");

export const catalogRouter = router({
  categories: publicProcedure.input(z.object({ marketId: z.number().int().positive().optional() })).query(async ({ input }) => {
    const db = await getDb();
    if (!db) throw unavailable();
    const market = input.marketId ? null : await ensureIbbMarket();
    return db.select().from(categories).where(and(eq(categories.marketId, input.marketId ?? market!.id), eq(categories.isActive, true)));
  }),
  shops: publicProcedure.input(z.object({ marketId: z.number().int().positive().optional(), query: z.string().trim().max(120).optional() })).query(async ({ input }) => {
    const db = await getDb();
    if (!db) throw unavailable();
    const market = input.marketId ? null : await ensureIbbMarket();
    const where = input.query
      ? and(eq(shops.marketId, input.marketId ?? market!.id), eq(shops.status, "approved"), or(like(shops.name, `%${input.query}%`), like(shops.areaLabel, `%${input.query}%`)))
      : and(eq(shops.marketId, input.marketId ?? market!.id), eq(shops.status, "approved"));
    return db.select().from(shops).where(where).orderBy(desc(shops.createdAt));
  }),
  shopBySlug: publicProcedure.input(z.object({ slug: z.string().min(1).max(180) })).query(async ({ input }) => {
    const db = await getDb();
    if (!db) throw unavailable();
    const [shop] = await db.select().from(shops).where(and(eq(shops.slug, input.slug), eq(shops.status, "approved"))).limit(1);
    if (!shop) return null;
    const items = await db.select().from(products).where(and(eq(products.shopId, shop.id), eq(products.status, "active"))).orderBy(desc(products.createdAt));
    return { shop, products: items };
  }),
  products: publicProcedure.input(z.object({ marketId: z.number().int().positive().optional(), query: z.string().trim().max(120).optional(), categoryId: z.number().int().positive().optional() })).query(async ({ input }) => {
    const db = await getDb();
    if (!db) throw unavailable();
    const market = input.marketId ? null : await ensureIbbMarket();
    const filters = [eq(shops.marketId, input.marketId ?? market!.id), eq(shops.status, "approved"), eq(products.status, "active")];
    if (input.categoryId) filters.push(eq(products.categoryId, input.categoryId));
    if (input.query) filters.push(or(like(products.name, `%${input.query}%`), like(products.description, `%${input.query}%`))!);
    return db.select({ product: products, shopName: shops.name, shopSlug: shops.slug, shopAccentColor: shops.accentColor })
      .from(products)
      .innerJoin(shops, eq(products.shopId, shops.id))
      .where(and(...filters))
      .orderBy(desc(products.createdAt));
  }),
});
