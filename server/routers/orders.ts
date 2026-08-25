import { desc, eq } from "drizzle-orm";
import { merchantOrders } from "../../drizzle/schema";
import { protectedProcedure, router } from "../_core/trpc";
import { getDb } from "../db";
import { requireMerchant } from "../marketplace/access";

export const ordersRouter = router({
  mine: protectedProcedure.query(async ({ ctx }) => {
    const db = await getDb();
    if (!db) throw new Error("قاعدة البيانات غير متاحة حالياً.");
    return db.select().from(merchantOrders).where(eq(merchantOrders.customerUserId, ctx.user.id)).orderBy(desc(merchantOrders.createdAt));
  }),
  merchantMine: protectedProcedure.query(async ({ ctx }) => {
    const db = await getDb();
    if (!db) throw new Error("قاعدة البيانات غير متاحة حالياً.");
    const merchant = await requireMerchant(ctx.user.id);
    return db.select().from(merchantOrders).where(eq(merchantOrders.merchantId, merchant.id)).orderBy(desc(merchantOrders.createdAt));
  }),
});
