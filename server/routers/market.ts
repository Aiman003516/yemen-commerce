import { z } from "zod";
import { publicProcedure, router } from "../_core/trpc";
import { ensureIbbMarket, getActiveMarket, getActiveMarketPolicies, getMarketCapabilities } from "../marketplace/access";

export const marketRouter = router({
  active: publicProcedure.query(async () => {
    const ibb = await ensureIbbMarket();
    return { ...ibb, apiVersion: "v1" as const };
  }),
  capabilities: publicProcedure.input(z.object({ marketId: z.number().int().positive().optional() }).optional()).query(async ({ input }) => {
    const market = input?.marketId
      ? undefined
      : await ensureIbbMarket();
    return getMarketCapabilities(input?.marketId ?? market!.id);
  }),
  policies: publicProcedure.input(z.object({ marketId: z.number().int().positive().optional() }).optional()).query(async ({ input }) => {
    const market = await getActiveMarket(input?.marketId);
    return getActiveMarketPolicies(market.id);
  }),
});
