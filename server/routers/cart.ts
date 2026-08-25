import { and, eq, inArray } from "drizzle-orm";
import { TRPCError } from "@trpc/server";
import { nanoid } from "nanoid";
import { z } from "zod";
import {
  cartItems,
  carts,
  checkoutSessions,
  merchantOrderItems,
  merchantOrders,
  paymentMethods,
  products,
  shopFulfilmentMethods,
  shops,
} from "../../drizzle/schema";
import { protectedProcedure, router } from "../_core/trpc";
import { getDb } from "../db";
import { getActiveMarket, writeAuditEvent } from "../marketplace/access";

const fulfilmentInput = z.enum(["collection", "digital", "seller_arranged"]);

function unavailable() {
  return new TRPCError({ code: "INTERNAL_SERVER_ERROR", message: "قاعدة البيانات غير متاحة حالياً." });
}

async function getOrCreateCart(customerUserId: number, marketId: number) {
  const db = await getDb();
  if (!db) throw unavailable();
  let [cart] = await db.select().from(carts).where(and(eq(carts.customerUserId, customerUserId), eq(carts.marketId, marketId))).limit(1);
  if (!cart) {
    await db.insert(carts).values({ customerUserId, marketId });
    [cart] = await db.select().from(carts).where(and(eq(carts.customerUserId, customerUserId), eq(carts.marketId, marketId))).limit(1);
  }
  if (!cart) throw unavailable();
  return cart;
}

async function buildCart(customerUserId: number, marketId: number) {
  const db = await getDb();
  if (!db) throw unavailable();
  const cart = await getOrCreateCart(customerUserId, marketId);
  const rows = await db.select({
    cartItem: cartItems,
    product: products,
    shop: shops,
  }).from(cartItems)
    .innerJoin(products, eq(cartItems.productId, products.id))
    .innerJoin(shops, eq(products.shopId, shops.id))
    .where(eq(cartItems.cartId, cart.id));

  const shopIds = Array.from(new Set(rows.map((row) => row.shop.id)));
  const fulfilment = shopIds.length
    ? await db.select().from(shopFulfilmentMethods).where(and(inArray(shopFulfilmentMethods.shopId, shopIds), eq(shopFulfilmentMethods.isActive, true)))
    : [];
  const methodsByShop = new Map<number, Array<{ method: "collection" | "digital" | "seller_arranged"; instructions: string | null }>>();
  for (const row of fulfilment) {
    methodsByShop.set(row.shopId, [...(methodsByShop.get(row.shopId) ?? []), { method: row.method, instructions: row.instructions }]);
  }

  const groups = new Map<number, {
    merchantId: number; shop: typeof rows[number]["shop"]; subtotalMinor: number;
    items: Array<{ id: number; productId: number; name: string; quantity: number; unitPriceMinor: number; lineTotalMinor: number; stockQuantity: number; status: string }>;
  }>();
  for (const row of rows) {
    const group = groups.get(row.shop.id) ?? { merchantId: row.shop.merchantId, shop: row.shop, subtotalMinor: 0, items: [] };
    const lineTotalMinor = row.product.priceMinor * row.cartItem.quantity;
    group.subtotalMinor += lineTotalMinor;
    group.items.push({
      id: row.cartItem.id,
      productId: row.product.id,
      name: row.product.name,
      quantity: row.cartItem.quantity,
      unitPriceMinor: row.product.priceMinor,
      lineTotalMinor,
      stockQuantity: row.product.stockQuantity,
      status: row.product.status,
    });
    groups.set(row.shop.id, group);
  }
  const merchantIds = Array.from(new Set(Array.from(groups.values()).map((group) => group.merchantId)));
  const activePaymentMethods = merchantIds.length
    ? await db.select({ id: paymentMethods.id, merchantId: paymentMethods.merchantId, name: paymentMethods.name }).from(paymentMethods).where(and(inArray(paymentMethods.merchantId, merchantIds), eq(paymentMethods.isActive, true), eq(paymentMethods.mode, "manual")))
    : [];
  const paymentMethodsByMerchant = new Map<number, Array<{ id: number; name: string }>>();
  for (const method of activePaymentMethods) {
    paymentMethodsByMerchant.set(method.merchantId, [...(paymentMethodsByMerchant.get(method.merchantId) ?? []), { id: method.id, name: method.name }]);
  }
  return {
    id: cart.id,
    marketId,
    groups: Array.from(groups.values()).map((group) => ({
      ...group,
      feeMinor: 0,
      taxMinor: 0,
      totalMinor: group.subtotalMinor,
      fulfilmentMethods: methodsByShop.get(group.shop.id) ?? [],
      paymentMethods: paymentMethodsByMerchant.get(group.merchantId) ?? [],
    })),
  };
}

export const cartRouter = router({
  get: protectedProcedure.input(z.object({ marketId: z.number().int().positive().optional() })).query(async ({ ctx, input }) => {
    const market = await getActiveMarket(input.marketId);
    return buildCart(ctx.user.id, market.id);
  }),
  addItem: protectedProcedure.input(z.object({ productId: z.number().int().positive(), quantity: z.number().int().min(1).max(99), marketId: z.number().int().positive().optional() })).mutation(async ({ ctx, input }) => {
    const db = await getDb();
    if (!db) throw unavailable();
    const market = await getActiveMarket(input.marketId);
    const [product] = await db.select({ product: products, shop: shops }).from(products).innerJoin(shops, eq(products.shopId, shops.id))
      .where(and(eq(products.id, input.productId), eq(products.status, "active"), eq(shops.status, "approved"), eq(shops.marketId, market.id))).limit(1);
    if (!product) throw new TRPCError({ code: "NOT_FOUND", message: "المنتج غير متاح في هذا السوق." });
    if (product.product.stockQuantity < input.quantity) throw new TRPCError({ code: "BAD_REQUEST", message: "الكمية المطلوبة غير متاحة حالياً." });
    const cart = await getOrCreateCart(ctx.user.id, market.id);
    const [existing] = await db.select().from(cartItems).where(and(eq(cartItems.cartId, cart.id), eq(cartItems.productId, input.productId))).limit(1);
    const nextQuantity = (existing?.quantity ?? 0) + input.quantity;
    if (nextQuantity > product.product.stockQuantity) throw new TRPCError({ code: "BAD_REQUEST", message: "الكمية الإجمالية تتجاوز المخزون المتاح." });
    if (existing) await db.update(cartItems).set({ quantity: nextQuantity }).where(eq(cartItems.id, existing.id));
    else await db.insert(cartItems).values({ cartId: cart.id, productId: input.productId, quantity: input.quantity });
    await writeAuditEvent({ actorUserId: ctx.user.id, action: "cart.item_added", resourceType: "cart", resourceId: cart.id, metadata: { productId: input.productId, quantity: input.quantity } });
    return buildCart(ctx.user.id, market.id);
  }),
  updateItem: protectedProcedure.input(z.object({ cartItemId: z.number().int().positive(), quantity: z.number().int().min(1).max(99) })).mutation(async ({ ctx, input }) => {
    const db = await getDb();
    if (!db) throw unavailable();
    const [row] = await db.select({ cartItem: cartItems, cart: carts, product: products }).from(cartItems)
      .innerJoin(carts, eq(cartItems.cartId, carts.id)).innerJoin(products, eq(cartItems.productId, products.id))
      .where(eq(cartItems.id, input.cartItemId)).limit(1);
    if (!row || row.cart.customerUserId !== ctx.user.id) throw new TRPCError({ code: "NOT_FOUND", message: "عنصر السلة غير موجود." });
    if (input.quantity > row.product.stockQuantity) throw new TRPCError({ code: "BAD_REQUEST", message: "الكمية المطلوبة غير متاحة حالياً." });
    await db.update(cartItems).set({ quantity: input.quantity }).where(eq(cartItems.id, row.cartItem.id));
    return buildCart(ctx.user.id, row.cart.marketId);
  }),
  removeItem: protectedProcedure.input(z.object({ cartItemId: z.number().int().positive() })).mutation(async ({ ctx, input }) => {
    const db = await getDb();
    if (!db) throw unavailable();
    const [row] = await db.select({ cartItem: cartItems, cart: carts }).from(cartItems).innerJoin(carts, eq(cartItems.cartId, carts.id)).where(eq(cartItems.id, input.cartItemId)).limit(1);
    if (!row || row.cart.customerUserId !== ctx.user.id) throw new TRPCError({ code: "NOT_FOUND", message: "عنصر السلة غير موجود." });
    await db.delete(cartItems).where(eq(cartItems.id, row.cartItem.id));
    return buildCart(ctx.user.id, row.cart.marketId);
  }),
  checkout: protectedProcedure.input(z.object({
    marketId: z.number().int().positive().optional(),
    fulfilmentByShop: z.array(z.object({ shopId: z.number().int().positive(), method: fulfilmentInput })).min(1),
    paymentMethodByMerchant: z.array(z.object({ merchantId: z.number().int().positive(), paymentMethodId: z.number().int().positive() })).min(1),
  })).mutation(async ({ ctx, input }) => {
    const db = await getDb();
    if (!db) throw unavailable();
    const market = await getActiveMarket(input.marketId);
    const cart = await buildCart(ctx.user.id, market.id);
    if (!cart.groups.length) throw new TRPCError({ code: "BAD_REQUEST", message: "السلة فارغة." });

    const fulfilmentByShop = new Map<number, "collection" | "digital" | "seller_arranged">(input.fulfilmentByShop.map((item) => [item.shopId, item.method]));
    const paymentByMerchant = new Map<number, number>(input.paymentMethodByMerchant.map((item) => [item.merchantId, item.paymentMethodId]));
    const orders = await db.transaction(async (tx) => {
      await tx.insert(checkoutSessions).values({ customerUserId: ctx.user.id, marketId: market.id });
      const [session] = await tx.select().from(checkoutSessions).where(and(eq(checkoutSessions.customerUserId, ctx.user.id), eq(checkoutSessions.marketId, market.id))).orderBy(checkoutSessions.id).limit(1);
      if (!session) throw unavailable();
      const created: Array<{ id: number; orderReference: string; merchantId: number; totalMinor: number }> = [];

      for (const group of cart.groups) {
        const selectedMethod = fulfilmentByShop.get(group.shop.id);
        const availableFulfilment = group.fulfilmentMethods.find((item: { method: "collection" | "digital" | "seller_arranged"; instructions: string | null }) => item.method === selectedMethod);
        if (!selectedMethod || !availableFulfilment) throw new TRPCError({ code: "BAD_REQUEST", message: `اختر طريقة استلام متاحة لمتجر ${group.shop.name}.` });
        const paymentMethodId = paymentByMerchant.get(group.merchantId);
        if (!paymentMethodId) throw new TRPCError({ code: "BAD_REQUEST", message: `اختر طريقة دفع لمتجر ${group.shop.name}.` });
        const [method] = await tx.select().from(paymentMethods).where(and(eq(paymentMethods.id, paymentMethodId), eq(paymentMethods.merchantId, group.merchantId), eq(paymentMethods.isActive, true))).limit(1);
        if (!method || method.mode !== "manual") throw new TRPCError({ code: "BAD_REQUEST", message: "طريقة الدفع غير متاحة أو غير معتمدة." });
        for (const item of group.items) {
          if (item.status !== "active" || item.stockQuantity < item.quantity) throw new TRPCError({ code: "BAD_REQUEST", message: `المنتج ${item.name} لم يعد متاحاً بالكمية المطلوبة.` });
        }
        const orderReference = `YC-${nanoid(10).toUpperCase()}`;
        await tx.insert(merchantOrders).values({
          checkoutSessionId: session.id,
          merchantId: group.merchantId,
          shopId: group.shop.id,
          customerUserId: ctx.user.id,
          marketId: market.id,
          orderReference,
          currency: method.currency,
          subtotalMinor: group.subtotalMinor,
          feeMinor: 0,
          taxMinor: 0,
          totalMinor: group.totalMinor,
          paymentMethodName: method.name,
          accountHolderName: method.accountHolderName,
          receivingIdentifier: method.receivingIdentifier,
          paymentInstructions: method.customerInstructions,
          proofRequirement: method.proofRequirement,
          fulfilmentMethod: selectedMethod,
          fulfilmentInstructions: availableFulfilment.instructions,
        });
        const [order] = await tx.select().from(merchantOrders).where(eq(merchantOrders.orderReference, orderReference)).limit(1);
        if (!order) throw unavailable();
        await tx.insert(merchantOrderItems).values(group.items.map((item: { productId: number; name: string; quantity: number; unitPriceMinor: number; lineTotalMinor: number }) => ({ merchantOrderId: order.id, productId: item.productId, productName: item.name, unitPriceMinor: item.unitPriceMinor, quantity: item.quantity, lineTotalMinor: item.lineTotalMinor })));
        for (const item of group.items) await tx.update(products).set({ stockQuantity: item.stockQuantity - item.quantity }).where(eq(products.id, item.productId));
        created.push({ id: order.id, orderReference, merchantId: group.merchantId, totalMinor: group.totalMinor });
      }
      await tx.delete(cartItems).where(eq(cartItems.cartId, cart.id));
      return created;
    });
    for (const order of orders) await writeAuditEvent({ actorUserId: ctx.user.id, action: "checkout.merchant_order_created", resourceType: "merchant_order", resourceId: order.id, metadata: { orderReference: order.orderReference, merchantId: order.merchantId } });
    return { checkoutSessionCreated: true, orders };
  }),
});
