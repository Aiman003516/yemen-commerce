CREATE TABLE `auditEvents` (
	`id` int AUTO_INCREMENT NOT NULL,
	`actorUserId` int,
	`action` varchar(120) NOT NULL,
	`resourceType` varchar(80) NOT NULL,
	`resourceId` varchar(80),
	`metadataJson` text,
	`createdAt` timestamp NOT NULL DEFAULT (now()),
	CONSTRAINT `auditEvents_id` PRIMARY KEY(`id`)
);
--> statement-breakpoint
CREATE TABLE `capabilities` (
	`id` int AUTO_INCREMENT NOT NULL,
	`key` varchar(80) NOT NULL,
	`defaultEnabled` boolean NOT NULL DEFAULT false,
	`createdAt` timestamp NOT NULL DEFAULT (now()),
	CONSTRAINT `capabilities_id` PRIMARY KEY(`id`),
	CONSTRAINT `capabilities_key_unique` UNIQUE(`key`)
);
--> statement-breakpoint
CREATE TABLE `cartItems` (
	`id` int AUTO_INCREMENT NOT NULL,
	`cartId` int NOT NULL,
	`productId` int NOT NULL,
	`quantity` int NOT NULL,
	`createdAt` timestamp NOT NULL DEFAULT (now()),
	`updatedAt` timestamp NOT NULL DEFAULT (now()) ON UPDATE CURRENT_TIMESTAMP,
	CONSTRAINT `cartItems_id` PRIMARY KEY(`id`),
	CONSTRAINT `cart_product_unique` UNIQUE(`cartId`,`productId`)
);
--> statement-breakpoint
CREATE TABLE `carts` (
	`id` int AUTO_INCREMENT NOT NULL,
	`customerUserId` int NOT NULL,
	`marketId` int NOT NULL,
	`createdAt` timestamp NOT NULL DEFAULT (now()),
	`updatedAt` timestamp NOT NULL DEFAULT (now()) ON UPDATE CURRENT_TIMESTAMP,
	CONSTRAINT `carts_id` PRIMARY KEY(`id`),
	CONSTRAINT `carts_customer_market_unique` UNIQUE(`customerUserId`,`marketId`)
);
--> statement-breakpoint
CREATE TABLE `categories` (
	`id` int AUTO_INCREMENT NOT NULL,
	`marketId` int,
	`nameAr` varchar(120) NOT NULL,
	`nameEn` varchar(120),
	`slug` varchar(140) NOT NULL,
	`isActive` boolean NOT NULL DEFAULT true,
	`createdAt` timestamp NOT NULL DEFAULT (now()),
	CONSTRAINT `categories_id` PRIMARY KEY(`id`),
	CONSTRAINT `categories_slug_market_unique` UNIQUE(`marketId`,`slug`)
);
--> statement-breakpoint
CREATE TABLE `checkoutSessions` (
	`id` int AUTO_INCREMENT NOT NULL,
	`customerUserId` int NOT NULL,
	`marketId` int NOT NULL,
	`status` enum('created','completed','cancelled') NOT NULL DEFAULT 'created',
	`createdAt` timestamp NOT NULL DEFAULT (now()),
	CONSTRAINT `checkoutSessions_id` PRIMARY KEY(`id`)
);
--> statement-breakpoint
CREATE TABLE `marketCapabilities` (
	`id` int AUTO_INCREMENT NOT NULL,
	`marketId` int NOT NULL,
	`capabilityId` int NOT NULL,
	`enabled` boolean NOT NULL DEFAULT false,
	`reasonAr` varchar(280),
	`updatedAt` timestamp NOT NULL DEFAULT (now()) ON UPDATE CURRENT_TIMESTAMP,
	CONSTRAINT `marketCapabilities_id` PRIMARY KEY(`id`),
	CONSTRAINT `market_capability_unique` UNIQUE(`marketId`,`capabilityId`)
);
--> statement-breakpoint
CREATE TABLE `markets` (
	`id` int AUTO_INCREMENT NOT NULL,
	`governorate` varchar(120) NOT NULL,
	`city` varchar(120) NOT NULL,
	`district` varchar(120),
	`serviceArea` varchar(160),
	`status` enum('draft','active','paused') NOT NULL DEFAULT 'draft',
	`currency` varchar(3) NOT NULL DEFAULT 'YER',
	`isPilot` boolean NOT NULL DEFAULT false,
	`createdAt` timestamp NOT NULL DEFAULT (now()),
	`updatedAt` timestamp NOT NULL DEFAULT (now()) ON UPDATE CURRENT_TIMESTAMP,
	CONSTRAINT `markets_id` PRIMARY KEY(`id`),
	CONSTRAINT `markets_scope_unique` UNIQUE(`governorate`,`city`,`district`,`serviceArea`)
);
--> statement-breakpoint
CREATE TABLE `merchantOrderItems` (
	`id` int AUTO_INCREMENT NOT NULL,
	`merchantOrderId` int NOT NULL,
	`productId` int NOT NULL,
	`productName` varchar(180) NOT NULL,
	`unitPriceMinor` int NOT NULL,
	`quantity` int NOT NULL,
	`lineTotalMinor` int NOT NULL,
	CONSTRAINT `merchantOrderItems_id` PRIMARY KEY(`id`)
);
--> statement-breakpoint
CREATE TABLE `merchantOrders` (
	`id` int AUTO_INCREMENT NOT NULL,
	`checkoutSessionId` int NOT NULL,
	`merchantId` int NOT NULL,
	`shopId` int NOT NULL,
	`customerUserId` int NOT NULL,
	`marketId` int NOT NULL,
	`orderReference` varchar(48) NOT NULL,
	`currency` varchar(3) NOT NULL DEFAULT 'YER',
	`subtotalMinor` int NOT NULL,
	`feeMinor` int NOT NULL DEFAULT 0,
	`taxMinor` int NOT NULL DEFAULT 0,
	`totalMinor` int NOT NULL,
	`paymentMethodName` varchar(120) NOT NULL,
	`accountHolderName` varchar(160) NOT NULL,
	`receivingIdentifier` varchar(220) NOT NULL,
	`paymentInstructions` text NOT NULL,
	`proofRequirement` enum('none','reference','screenshot','both') NOT NULL,
	`paymentStatus` enum('awaiting_payment','payment_under_review','paid','rejected','cancelled') NOT NULL DEFAULT 'awaiting_payment',
	`fulfilmentMethod` enum('collection','digital','seller_arranged') NOT NULL,
	`fulfilmentInstructions` text,
	`fulfilmentStatus` enum('pending','ready','arranged','completed','cancelled') NOT NULL DEFAULT 'pending',
	`createdAt` timestamp NOT NULL DEFAULT (now()),
	`updatedAt` timestamp NOT NULL DEFAULT (now()) ON UPDATE CURRENT_TIMESTAMP,
	CONSTRAINT `merchantOrders_id` PRIMARY KEY(`id`),
	CONSTRAINT `merchant_orders_reference_unique` UNIQUE(`orderReference`)
);
--> statement-breakpoint
CREATE TABLE `merchants` (
	`id` int AUTO_INCREMENT NOT NULL,
	`ownerUserId` int NOT NULL,
	`marketId` int NOT NULL,
	`phone` varchar(32) NOT NULL,
	`ownerName` varchar(160) NOT NULL,
	`verificationStatus` enum('draft','pending','verified','rejected') NOT NULL DEFAULT 'draft',
	`createdAt` timestamp NOT NULL DEFAULT (now()),
	`updatedAt` timestamp NOT NULL DEFAULT (now()) ON UPDATE CURRENT_TIMESTAMP,
	CONSTRAINT `merchants_id` PRIMARY KEY(`id`)
);
--> statement-breakpoint
CREATE TABLE `orderStatusHistory` (
	`id` int AUTO_INCREMENT NOT NULL,
	`merchantOrderId` int NOT NULL,
	`actorUserId` int,
	`eventType` varchar(80) NOT NULL,
	`previousValue` varchar(120),
	`nextValue` varchar(120),
	`reason` text,
	`createdAt` timestamp NOT NULL DEFAULT (now()),
	CONSTRAINT `orderStatusHistory_id` PRIMARY KEY(`id`)
);
--> statement-breakpoint
CREATE TABLE `paymentClaims` (
	`id` int AUTO_INCREMENT NOT NULL,
	`merchantOrderId` int NOT NULL,
	`customerUserId` int NOT NULL,
	`transactionReference` varchar(180),
	`reviewNote` text,
	`reviewedByUserId` int,
	`reviewedAt` timestamp,
	`createdAt` timestamp NOT NULL DEFAULT (now()),
	CONSTRAINT `paymentClaims_id` PRIMARY KEY(`id`)
);
--> statement-breakpoint
CREATE TABLE `paymentMethods` (
	`id` int AUTO_INCREMENT NOT NULL,
	`merchantId` int NOT NULL,
	`name` varchar(120) NOT NULL,
	`mode` enum('manual','provider_api') NOT NULL DEFAULT 'manual',
	`accountHolderName` varchar(160) NOT NULL,
	`receivingIdentifier` varchar(220) NOT NULL,
	`currency` varchar(3) NOT NULL DEFAULT 'YER',
	`exactAmountRequired` boolean NOT NULL DEFAULT true,
	`customerInstructions` text NOT NULL,
	`proofRequirement` enum('none','reference','screenshot','both') NOT NULL DEFAULT 'both',
	`providerVerification` enum('manual_only','pending','verified') NOT NULL DEFAULT 'manual_only',
	`isActive` boolean NOT NULL DEFAULT true,
	`createdAt` timestamp NOT NULL DEFAULT (now()),
	`updatedAt` timestamp NOT NULL DEFAULT (now()) ON UPDATE CURRENT_TIMESTAMP,
	CONSTRAINT `paymentMethods_id` PRIMARY KEY(`id`)
);
--> statement-breakpoint
CREATE TABLE `paymentProofs` (
	`id` int AUTO_INCREMENT NOT NULL,
	`paymentClaimId` int NOT NULL,
	`storageKey` varchar(512) NOT NULL,
	`mimeType` varchar(120) NOT NULL,
	`originalName` varchar(260),
	`createdAt` timestamp NOT NULL DEFAULT (now()),
	CONSTRAINT `paymentProofs_id` PRIMARY KEY(`id`)
);
--> statement-breakpoint
CREATE TABLE `products` (
	`id` int AUTO_INCREMENT NOT NULL,
	`shopId` int NOT NULL,
	`categoryId` int,
	`name` varchar(180) NOT NULL,
	`description` text,
	`priceMinor` int NOT NULL,
	`currency` varchar(3) NOT NULL DEFAULT 'YER',
	`stockQuantity` int NOT NULL DEFAULT 0,
	`imageUrl` varchar(1024),
	`status` enum('draft','active','archived','out_of_stock') NOT NULL DEFAULT 'draft',
	`createdAt` timestamp NOT NULL DEFAULT (now()),
	`updatedAt` timestamp NOT NULL DEFAULT (now()) ON UPDATE CURRENT_TIMESTAMP,
	CONSTRAINT `products_id` PRIMARY KEY(`id`)
);
--> statement-breakpoint
CREATE TABLE `reports` (
	`id` int AUTO_INCREMENT NOT NULL,
	`reporterUserId` int NOT NULL,
	`merchantOrderId` int,
	`shopId` int,
	`category` varchar(80) NOT NULL,
	`description` text NOT NULL,
	`status` enum('open','reviewing','resolved','dismissed') NOT NULL DEFAULT 'open',
	`createdAt` timestamp NOT NULL DEFAULT (now()),
	`updatedAt` timestamp NOT NULL DEFAULT (now()) ON UPDATE CURRENT_TIMESTAMP,
	CONSTRAINT `reports_id` PRIMARY KEY(`id`)
);
--> statement-breakpoint
CREATE TABLE `shopFulfilmentMethods` (
	`id` int AUTO_INCREMENT NOT NULL,
	`shopId` int NOT NULL,
	`method` enum('collection','digital','seller_arranged') NOT NULL,
	`instructions` text,
	`isActive` boolean NOT NULL DEFAULT true,
	CONSTRAINT `shopFulfilmentMethods_id` PRIMARY KEY(`id`),
	CONSTRAINT `shop_fulfilment_method_unique` UNIQUE(`shopId`,`method`)
);
--> statement-breakpoint
CREATE TABLE `shops` (
	`id` int AUTO_INCREMENT NOT NULL,
	`merchantId` int NOT NULL,
	`marketId` int NOT NULL,
	`name` varchar(160) NOT NULL,
	`slug` varchar(180) NOT NULL,
	`description` text,
	`areaLabel` varchar(160),
	`logoUrl` varchar(1024),
	`coverUrl` varchar(1024),
	`accentColor` varchar(16) NOT NULL DEFAULT '#006A63',
	`contactRoute` varchar(280),
	`collectionInstructions` text,
	`status` enum('draft','pending','approved','suspended') NOT NULL DEFAULT 'draft',
	`createdAt` timestamp NOT NULL DEFAULT (now()),
	`updatedAt` timestamp NOT NULL DEFAULT (now()) ON UPDATE CURRENT_TIMESTAMP,
	CONSTRAINT `shops_id` PRIMARY KEY(`id`),
	CONSTRAINT `shops_slug_unique` UNIQUE(`slug`)
);
--> statement-breakpoint
CREATE TABLE `userRoles` (
	`id` int AUTO_INCREMENT NOT NULL,
	`userId` int NOT NULL,
	`role` enum('customer','merchant','admin') NOT NULL,
	`marketId` int,
	`createdAt` timestamp NOT NULL DEFAULT (now()),
	CONSTRAINT `userRoles_id` PRIMARY KEY(`id`),
	CONSTRAINT `user_role_scope_unique` UNIQUE(`userId`,`role`,`marketId`)
);
--> statement-breakpoint
ALTER TABLE `auditEvents` ADD CONSTRAINT `auditEvents_actorUserId_users_id_fk` FOREIGN KEY (`actorUserId`) REFERENCES `users`(`id`) ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE `cartItems` ADD CONSTRAINT `cartItems_cartId_carts_id_fk` FOREIGN KEY (`cartId`) REFERENCES `carts`(`id`) ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE `cartItems` ADD CONSTRAINT `cartItems_productId_products_id_fk` FOREIGN KEY (`productId`) REFERENCES `products`(`id`) ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE `carts` ADD CONSTRAINT `carts_customerUserId_users_id_fk` FOREIGN KEY (`customerUserId`) REFERENCES `users`(`id`) ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE `carts` ADD CONSTRAINT `carts_marketId_markets_id_fk` FOREIGN KEY (`marketId`) REFERENCES `markets`(`id`) ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE `categories` ADD CONSTRAINT `categories_marketId_markets_id_fk` FOREIGN KEY (`marketId`) REFERENCES `markets`(`id`) ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE `checkoutSessions` ADD CONSTRAINT `checkoutSessions_customerUserId_users_id_fk` FOREIGN KEY (`customerUserId`) REFERENCES `users`(`id`) ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE `checkoutSessions` ADD CONSTRAINT `checkoutSessions_marketId_markets_id_fk` FOREIGN KEY (`marketId`) REFERENCES `markets`(`id`) ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE `marketCapabilities` ADD CONSTRAINT `marketCapabilities_marketId_markets_id_fk` FOREIGN KEY (`marketId`) REFERENCES `markets`(`id`) ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE `marketCapabilities` ADD CONSTRAINT `marketCapabilities_capabilityId_capabilities_id_fk` FOREIGN KEY (`capabilityId`) REFERENCES `capabilities`(`id`) ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE `merchantOrderItems` ADD CONSTRAINT `merchantOrderItems_merchantOrderId_merchantOrders_id_fk` FOREIGN KEY (`merchantOrderId`) REFERENCES `merchantOrders`(`id`) ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE `merchantOrderItems` ADD CONSTRAINT `merchantOrderItems_productId_products_id_fk` FOREIGN KEY (`productId`) REFERENCES `products`(`id`) ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE `merchantOrders` ADD CONSTRAINT `merchantOrders_checkoutSessionId_checkoutSessions_id_fk` FOREIGN KEY (`checkoutSessionId`) REFERENCES `checkoutSessions`(`id`) ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE `merchantOrders` ADD CONSTRAINT `merchantOrders_merchantId_merchants_id_fk` FOREIGN KEY (`merchantId`) REFERENCES `merchants`(`id`) ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE `merchantOrders` ADD CONSTRAINT `merchantOrders_shopId_shops_id_fk` FOREIGN KEY (`shopId`) REFERENCES `shops`(`id`) ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE `merchantOrders` ADD CONSTRAINT `merchantOrders_customerUserId_users_id_fk` FOREIGN KEY (`customerUserId`) REFERENCES `users`(`id`) ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE `merchantOrders` ADD CONSTRAINT `merchantOrders_marketId_markets_id_fk` FOREIGN KEY (`marketId`) REFERENCES `markets`(`id`) ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE `merchants` ADD CONSTRAINT `merchants_ownerUserId_users_id_fk` FOREIGN KEY (`ownerUserId`) REFERENCES `users`(`id`) ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE `merchants` ADD CONSTRAINT `merchants_marketId_markets_id_fk` FOREIGN KEY (`marketId`) REFERENCES `markets`(`id`) ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE `orderStatusHistory` ADD CONSTRAINT `orderStatusHistory_merchantOrderId_merchantOrders_id_fk` FOREIGN KEY (`merchantOrderId`) REFERENCES `merchantOrders`(`id`) ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE `orderStatusHistory` ADD CONSTRAINT `orderStatusHistory_actorUserId_users_id_fk` FOREIGN KEY (`actorUserId`) REFERENCES `users`(`id`) ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE `paymentClaims` ADD CONSTRAINT `paymentClaims_merchantOrderId_merchantOrders_id_fk` FOREIGN KEY (`merchantOrderId`) REFERENCES `merchantOrders`(`id`) ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE `paymentClaims` ADD CONSTRAINT `paymentClaims_customerUserId_users_id_fk` FOREIGN KEY (`customerUserId`) REFERENCES `users`(`id`) ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE `paymentClaims` ADD CONSTRAINT `paymentClaims_reviewedByUserId_users_id_fk` FOREIGN KEY (`reviewedByUserId`) REFERENCES `users`(`id`) ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE `paymentMethods` ADD CONSTRAINT `paymentMethods_merchantId_merchants_id_fk` FOREIGN KEY (`merchantId`) REFERENCES `merchants`(`id`) ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE `paymentProofs` ADD CONSTRAINT `paymentProofs_paymentClaimId_paymentClaims_id_fk` FOREIGN KEY (`paymentClaimId`) REFERENCES `paymentClaims`(`id`) ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE `products` ADD CONSTRAINT `products_shopId_shops_id_fk` FOREIGN KEY (`shopId`) REFERENCES `shops`(`id`) ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE `products` ADD CONSTRAINT `products_categoryId_categories_id_fk` FOREIGN KEY (`categoryId`) REFERENCES `categories`(`id`) ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE `reports` ADD CONSTRAINT `reports_reporterUserId_users_id_fk` FOREIGN KEY (`reporterUserId`) REFERENCES `users`(`id`) ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE `reports` ADD CONSTRAINT `reports_merchantOrderId_merchantOrders_id_fk` FOREIGN KEY (`merchantOrderId`) REFERENCES `merchantOrders`(`id`) ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE `reports` ADD CONSTRAINT `reports_shopId_shops_id_fk` FOREIGN KEY (`shopId`) REFERENCES `shops`(`id`) ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE `shopFulfilmentMethods` ADD CONSTRAINT `shopFulfilmentMethods_shopId_shops_id_fk` FOREIGN KEY (`shopId`) REFERENCES `shops`(`id`) ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE `shops` ADD CONSTRAINT `shops_merchantId_merchants_id_fk` FOREIGN KEY (`merchantId`) REFERENCES `merchants`(`id`) ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE `shops` ADD CONSTRAINT `shops_marketId_markets_id_fk` FOREIGN KEY (`marketId`) REFERENCES `markets`(`id`) ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE `userRoles` ADD CONSTRAINT `userRoles_userId_users_id_fk` FOREIGN KEY (`userId`) REFERENCES `users`(`id`) ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE `userRoles` ADD CONSTRAINT `userRoles_marketId_markets_id_fk` FOREIGN KEY (`marketId`) REFERENCES `markets`(`id`) ON DELETE no action ON UPDATE no action;--> statement-breakpoint
CREATE INDEX `audit_events_resource_idx` ON `auditEvents` (`resourceType`,`resourceId`);--> statement-breakpoint
CREATE INDEX `audit_events_actor_idx` ON `auditEvents` (`actorUserId`);--> statement-breakpoint
CREATE INDEX `categories_market_active_idx` ON `categories` (`marketId`,`isActive`);--> statement-breakpoint
CREATE INDEX `markets_status_idx` ON `markets` (`status`);--> statement-breakpoint
CREATE INDEX `merchant_orders_merchant_status_idx` ON `merchantOrders` (`merchantId`,`paymentStatus`);--> statement-breakpoint
CREATE INDEX `merchant_orders_customer_idx` ON `merchantOrders` (`customerUserId`);--> statement-breakpoint
CREATE INDEX `merchant_orders_session_idx` ON `merchantOrders` (`checkoutSessionId`);--> statement-breakpoint
CREATE INDEX `merchants_owner_idx` ON `merchants` (`ownerUserId`);--> statement-breakpoint
CREATE INDEX `merchants_market_idx` ON `merchants` (`marketId`);--> statement-breakpoint
CREATE INDEX `order_history_order_idx` ON `orderStatusHistory` (`merchantOrderId`);--> statement-breakpoint
CREATE INDEX `payment_methods_merchant_active_idx` ON `paymentMethods` (`merchantId`,`isActive`);--> statement-breakpoint
CREATE INDEX `products_shop_status_idx` ON `products` (`shopId`,`status`);--> statement-breakpoint
CREATE INDEX `products_category_idx` ON `products` (`categoryId`);--> statement-breakpoint
CREATE INDEX `shops_market_status_idx` ON `shops` (`marketId`,`status`);--> statement-breakpoint
CREATE INDEX `shops_merchant_idx` ON `shops` (`merchantId`);--> statement-breakpoint
CREATE INDEX `user_roles_user_idx` ON `userRoles` (`userId`);