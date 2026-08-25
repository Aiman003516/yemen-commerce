import {
  boolean,
  index,
  int,
  mysqlEnum,
  mysqlTable,
  text,
  timestamp,
  uniqueIndex,
  varchar,
} from "drizzle-orm/mysql-core";

/** Template authentication identity. Marketplace roles live in userRoles so one person can hold customer and merchant contexts. */
export const users = mysqlTable("users", {
  id: int("id").autoincrement().primaryKey(),
  openId: varchar("openId", { length: 64 }).notNull().unique(),
  name: text("name"),
  email: varchar("email", { length: 320 }),
  loginMethod: varchar("loginMethod", { length: 64 }),
  role: mysqlEnum("role", ["user", "admin"]).default("user").notNull(),
  createdAt: timestamp("createdAt").defaultNow().notNull(),
  updatedAt: timestamp("updatedAt").defaultNow().onUpdateNow().notNull(),
  lastSignedIn: timestamp("lastSignedIn").defaultNow().notNull(),
});

export const markets = mysqlTable("markets", {
  id: int("id").autoincrement().primaryKey(),
  governorate: varchar("governorate", { length: 120 }).notNull(),
  city: varchar("city", { length: 120 }).notNull(),
  district: varchar("district", { length: 120 }),
  serviceArea: varchar("serviceArea", { length: 160 }),
  status: mysqlEnum("status", ["draft", "active", "paused"]).default("draft").notNull(),
  currency: varchar("currency", { length: 3 }).default("YER").notNull(),
  isPilot: boolean("isPilot").default(false).notNull(),
  createdAt: timestamp("createdAt").defaultNow().notNull(),
  updatedAt: timestamp("updatedAt").defaultNow().onUpdateNow().notNull(),
}, (table) => [
  uniqueIndex("markets_scope_unique").on(table.governorate, table.city, table.district, table.serviceArea),
  index("markets_status_idx").on(table.status),
]);

export const capabilities = mysqlTable("capabilities", {
  id: int("id").autoincrement().primaryKey(),
  key: varchar("key", { length: 80 }).notNull(),
  defaultEnabled: boolean("defaultEnabled").default(false).notNull(),
  createdAt: timestamp("createdAt").defaultNow().notNull(),
}, (table) => [uniqueIndex("capabilities_key_unique").on(table.key)]);

export const marketCapabilities = mysqlTable("marketCapabilities", {
  id: int("id").autoincrement().primaryKey(),
  marketId: int("marketId").notNull().references(() => markets.id),
  capabilityId: int("capabilityId").notNull().references(() => capabilities.id),
  enabled: boolean("enabled").default(false).notNull(),
  reasonAr: varchar("reasonAr", { length: 280 }),
  updatedAt: timestamp("updatedAt").defaultNow().onUpdateNow().notNull(),
}, (table) => [uniqueIndex("market_capability_unique").on(table.marketId, table.capabilityId)]);

export const marketPolicyVersions = mysqlTable("marketPolicyVersions", {
  id: int("id").autoincrement().primaryKey(),
  marketId: int("marketId").notNull().references(() => markets.id),
  key: varchar("key", { length: 80 }).notNull(),
  version: int("version").notNull(),
  valueJson: text("valueJson").notNull(),
  isActive: boolean("isActive").default(true).notNull(),
  effectiveFrom: timestamp("effectiveFrom"),
  createdAt: timestamp("createdAt").defaultNow().notNull(),
}, (table) => [
  uniqueIndex("market_policy_version_unique").on(table.marketId, table.key, table.version),
  index("market_policy_active_idx").on(table.marketId, table.key, table.isActive),
]);

export const userRoles = mysqlTable("userRoles", {
  id: int("id").autoincrement().primaryKey(),
  userId: int("userId").notNull().references(() => users.id),
  role: mysqlEnum("role", ["customer", "merchant", "admin"]).notNull(),
  marketId: int("marketId").references(() => markets.id),
  createdAt: timestamp("createdAt").defaultNow().notNull(),
}, (table) => [
  uniqueIndex("user_role_scope_unique").on(table.userId, table.role, table.marketId),
  index("user_roles_user_idx").on(table.userId),
]);

export const merchants = mysqlTable("merchants", {
  id: int("id").autoincrement().primaryKey(),
  ownerUserId: int("ownerUserId").notNull().references(() => users.id),
  marketId: int("marketId").notNull().references(() => markets.id),
  phone: varchar("phone", { length: 32 }).notNull(),
  ownerName: varchar("ownerName", { length: 160 }).notNull(),
  verificationStatus: mysqlEnum("verificationStatus", ["draft", "pending", "verified", "rejected"]).default("draft").notNull(),
  createdAt: timestamp("createdAt").defaultNow().notNull(),
  updatedAt: timestamp("updatedAt").defaultNow().onUpdateNow().notNull(),
}, (table) => [
  index("merchants_owner_idx").on(table.ownerUserId),
  index("merchants_market_idx").on(table.marketId),
]);

export const shops = mysqlTable("shops", {
  id: int("id").autoincrement().primaryKey(),
  merchantId: int("merchantId").notNull().references(() => merchants.id),
  marketId: int("marketId").notNull().references(() => markets.id),
  name: varchar("name", { length: 160 }).notNull(),
  slug: varchar("slug", { length: 180 }).notNull(),
  description: text("description"),
  areaLabel: varchar("areaLabel", { length: 160 }),
  logoUrl: varchar("logoUrl", { length: 1024 }),
  coverUrl: varchar("coverUrl", { length: 1024 }),
  accentColor: varchar("accentColor", { length: 16 }).default("#006A63").notNull(),
  contactRoute: varchar("contactRoute", { length: 280 }),
  collectionInstructions: text("collectionInstructions"),
  status: mysqlEnum("status", ["draft", "pending", "approved", "suspended"]).default("draft").notNull(),
  createdAt: timestamp("createdAt").defaultNow().notNull(),
  updatedAt: timestamp("updatedAt").defaultNow().onUpdateNow().notNull(),
}, (table) => [
  uniqueIndex("shops_slug_unique").on(table.slug),
  index("shops_market_status_idx").on(table.marketId, table.status),
  index("shops_merchant_idx").on(table.merchantId),
]);

export const categories = mysqlTable("categories", {
  id: int("id").autoincrement().primaryKey(),
  marketId: int("marketId").references(() => markets.id),
  nameAr: varchar("nameAr", { length: 120 }).notNull(),
  nameEn: varchar("nameEn", { length: 120 }),
  slug: varchar("slug", { length: 140 }).notNull(),
  isActive: boolean("isActive").default(true).notNull(),
  createdAt: timestamp("createdAt").defaultNow().notNull(),
}, (table) => [
  uniqueIndex("categories_slug_market_unique").on(table.marketId, table.slug),
  index("categories_market_active_idx").on(table.marketId, table.isActive),
]);

export const products = mysqlTable("products", {
  id: int("id").autoincrement().primaryKey(),
  shopId: int("shopId").notNull().references(() => shops.id),
  categoryId: int("categoryId").references(() => categories.id),
  name: varchar("name", { length: 180 }).notNull(),
  description: text("description"),
  priceMinor: int("priceMinor").notNull(),
  currency: varchar("currency", { length: 3 }).default("YER").notNull(),
  stockQuantity: int("stockQuantity").default(0).notNull(),
  imageUrl: varchar("imageUrl", { length: 1024 }),
  status: mysqlEnum("status", ["draft", "active", "archived", "out_of_stock"]).default("draft").notNull(),
  createdAt: timestamp("createdAt").defaultNow().notNull(),
  updatedAt: timestamp("updatedAt").defaultNow().onUpdateNow().notNull(),
}, (table) => [
  index("products_shop_status_idx").on(table.shopId, table.status),
  index("products_category_idx").on(table.categoryId),
]);

export const shopFulfilmentMethods = mysqlTable("shopFulfilmentMethods", {
  id: int("id").autoincrement().primaryKey(),
  shopId: int("shopId").notNull().references(() => shops.id),
  method: mysqlEnum("method", ["collection", "digital", "seller_arranged"]).notNull(),
  instructions: text("instructions"),
  isActive: boolean("isActive").default(true).notNull(),
}, (table) => [uniqueIndex("shop_fulfilment_method_unique").on(table.shopId, table.method)]);

export const paymentMethods = mysqlTable("paymentMethods", {
  id: int("id").autoincrement().primaryKey(),
  merchantId: int("merchantId").notNull().references(() => merchants.id),
  name: varchar("name", { length: 120 }).notNull(),
  mode: mysqlEnum("mode", ["manual", "provider_api"]).default("manual").notNull(),
  accountHolderName: varchar("accountHolderName", { length: 160 }).notNull(),
  receivingIdentifier: varchar("receivingIdentifier", { length: 220 }).notNull(),
  currency: varchar("currency", { length: 3 }).default("YER").notNull(),
  exactAmountRequired: boolean("exactAmountRequired").default(true).notNull(),
  customerInstructions: text("customerInstructions").notNull(),
  proofRequirement: mysqlEnum("proofRequirement", ["none", "reference", "screenshot", "both"]).default("both").notNull(),
  providerVerification: mysqlEnum("providerVerification", ["manual_only", "pending", "verified"]).default("manual_only").notNull(),
  isActive: boolean("isActive").default(true).notNull(),
  createdAt: timestamp("createdAt").defaultNow().notNull(),
  updatedAt: timestamp("updatedAt").defaultNow().onUpdateNow().notNull(),
}, (table) => [index("payment_methods_merchant_active_idx").on(table.merchantId, table.isActive)]);

export const carts = mysqlTable("carts", {
  id: int("id").autoincrement().primaryKey(),
  customerUserId: int("customerUserId").notNull().references(() => users.id),
  marketId: int("marketId").notNull().references(() => markets.id),
  createdAt: timestamp("createdAt").defaultNow().notNull(),
  updatedAt: timestamp("updatedAt").defaultNow().onUpdateNow().notNull(),
}, (table) => [uniqueIndex("carts_customer_market_unique").on(table.customerUserId, table.marketId)]);

export const cartItems = mysqlTable("cartItems", {
  id: int("id").autoincrement().primaryKey(),
  cartId: int("cartId").notNull().references(() => carts.id),
  productId: int("productId").notNull().references(() => products.id),
  quantity: int("quantity").notNull(),
  createdAt: timestamp("createdAt").defaultNow().notNull(),
  updatedAt: timestamp("updatedAt").defaultNow().onUpdateNow().notNull(),
}, (table) => [uniqueIndex("cart_product_unique").on(table.cartId, table.productId)]);

export const checkoutSessions = mysqlTable("checkoutSessions", {
  id: int("id").autoincrement().primaryKey(),
  customerUserId: int("customerUserId").notNull().references(() => users.id),
  marketId: int("marketId").notNull().references(() => markets.id),
  status: mysqlEnum("status", ["created", "completed", "cancelled"]).default("created").notNull(),
  createdAt: timestamp("createdAt").defaultNow().notNull(),
});

export const merchantOrders = mysqlTable("merchantOrders", {
  id: int("id").autoincrement().primaryKey(),
  checkoutSessionId: int("checkoutSessionId").notNull().references(() => checkoutSessions.id),
  merchantId: int("merchantId").notNull().references(() => merchants.id),
  shopId: int("shopId").notNull().references(() => shops.id),
  customerUserId: int("customerUserId").notNull().references(() => users.id),
  marketId: int("marketId").notNull().references(() => markets.id),
  orderReference: varchar("orderReference", { length: 48 }).notNull(),
  currency: varchar("currency", { length: 3 }).default("YER").notNull(),
  subtotalMinor: int("subtotalMinor").notNull(),
  feeMinor: int("feeMinor").default(0).notNull(),
  taxMinor: int("taxMinor").default(0).notNull(),
  totalMinor: int("totalMinor").notNull(),
  paymentMethodName: varchar("paymentMethodName", { length: 120 }).notNull(),
  accountHolderName: varchar("accountHolderName", { length: 160 }).notNull(),
  receivingIdentifier: varchar("receivingIdentifier", { length: 220 }).notNull(),
  paymentInstructions: text("paymentInstructions").notNull(),
  proofRequirement: mysqlEnum("proofRequirement", ["none", "reference", "screenshot", "both"]).notNull(),
  paymentStatus: mysqlEnum("paymentStatus", ["awaiting_payment", "payment_under_review", "paid", "rejected", "cancelled"]).default("awaiting_payment").notNull(),
  fulfilmentMethod: mysqlEnum("fulfilmentMethod", ["collection", "digital", "seller_arranged"]).notNull(),
  fulfilmentInstructions: text("fulfilmentInstructions"),
  fulfilmentStatus: mysqlEnum("fulfilmentStatus", ["pending", "ready", "arranged", "completed", "cancelled"]).default("pending").notNull(),
  createdAt: timestamp("createdAt").defaultNow().notNull(),
  updatedAt: timestamp("updatedAt").defaultNow().onUpdateNow().notNull(),
}, (table) => [
  uniqueIndex("merchant_orders_reference_unique").on(table.orderReference),
  index("merchant_orders_merchant_status_idx").on(table.merchantId, table.paymentStatus),
  index("merchant_orders_customer_idx").on(table.customerUserId),
  index("merchant_orders_session_idx").on(table.checkoutSessionId),
]);

export const merchantOrderItems = mysqlTable("merchantOrderItems", {
  id: int("id").autoincrement().primaryKey(),
  merchantOrderId: int("merchantOrderId").notNull().references(() => merchantOrders.id),
  productId: int("productId").notNull().references(() => products.id),
  productName: varchar("productName", { length: 180 }).notNull(),
  unitPriceMinor: int("unitPriceMinor").notNull(),
  quantity: int("quantity").notNull(),
  lineTotalMinor: int("lineTotalMinor").notNull(),
});

export const paymentClaims = mysqlTable("paymentClaims", {
  id: int("id").autoincrement().primaryKey(),
  merchantOrderId: int("merchantOrderId").notNull().references(() => merchantOrders.id),
  customerUserId: int("customerUserId").notNull().references(() => users.id),
  transactionReference: varchar("transactionReference", { length: 180 }),
  reviewNote: text("reviewNote"),
  reviewedByUserId: int("reviewedByUserId").references(() => users.id),
  reviewedAt: timestamp("reviewedAt"),
  createdAt: timestamp("createdAt").defaultNow().notNull(),
});

export const paymentProofs = mysqlTable("paymentProofs", {
  id: int("id").autoincrement().primaryKey(),
  paymentClaimId: int("paymentClaimId").notNull().references(() => paymentClaims.id),
  storageKey: varchar("storageKey", { length: 512 }).notNull(),
  mimeType: varchar("mimeType", { length: 120 }).notNull(),
  originalName: varchar("originalName", { length: 260 }),
  createdAt: timestamp("createdAt").defaultNow().notNull(),
});

export const orderStatusHistory = mysqlTable("orderStatusHistory", {
  id: int("id").autoincrement().primaryKey(),
  merchantOrderId: int("merchantOrderId").notNull().references(() => merchantOrders.id),
  actorUserId: int("actorUserId").references(() => users.id),
  eventType: varchar("eventType", { length: 80 }).notNull(),
  previousValue: varchar("previousValue", { length: 120 }),
  nextValue: varchar("nextValue", { length: 120 }),
  reason: text("reason"),
  createdAt: timestamp("createdAt").defaultNow().notNull(),
}, (table) => [index("order_history_order_idx").on(table.merchantOrderId)]);

export const reports = mysqlTable("reports", {
  id: int("id").autoincrement().primaryKey(),
  reporterUserId: int("reporterUserId").notNull().references(() => users.id),
  merchantOrderId: int("merchantOrderId").references(() => merchantOrders.id),
  shopId: int("shopId").references(() => shops.id),
  category: varchar("category", { length: 80 }).notNull(),
  description: text("description").notNull(),
  status: mysqlEnum("status", ["open", "reviewing", "resolved", "dismissed"]).default("open").notNull(),
  createdAt: timestamp("createdAt").defaultNow().notNull(),
  updatedAt: timestamp("updatedAt").defaultNow().onUpdateNow().notNull(),
});

export const auditEvents = mysqlTable("auditEvents", {
  id: int("id").autoincrement().primaryKey(),
  actorUserId: int("actorUserId").references(() => users.id),
  action: varchar("action", { length: 120 }).notNull(),
  resourceType: varchar("resourceType", { length: 80 }).notNull(),
  resourceId: varchar("resourceId", { length: 80 }),
  metadataJson: text("metadataJson"),
  createdAt: timestamp("createdAt").defaultNow().notNull(),
}, (table) => [
  index("audit_events_resource_idx").on(table.resourceType, table.resourceId),
  index("audit_events_actor_idx").on(table.actorUserId),
]);

export type User = typeof users.$inferSelect;
export type InsertUser = typeof users.$inferInsert;
