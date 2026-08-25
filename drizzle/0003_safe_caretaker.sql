CREATE TABLE `otpProviderConfigurations` (
	`id` int AUTO_INCREMENT NOT NULL,
	`marketId` int NOT NULL,
	`providerKey` varchar(80) NOT NULL,
	`providerType` enum('carrier','aggregator') NOT NULL,
	`displayName` varchar(160) NOT NULL,
	`status` enum('disabled','pending_activation','active','paused') NOT NULL DEFAULT 'disabled',
	`senderId` varchar(32),
	`deliveryReportsEnabled` boolean NOT NULL DEFAULT false,
	`rateLimitPerMinute` int NOT NULL DEFAULT 0,
	`createdAt` timestamp NOT NULL DEFAULT (now()),
	`updatedAt` timestamp NOT NULL DEFAULT (now()) ON UPDATE CURRENT_TIMESTAMP,
	CONSTRAINT `otpProviderConfigurations_id` PRIMARY KEY(`id`),
	CONSTRAINT `otp_provider_market_key_unique` UNIQUE(`marketId`,`providerKey`)
);
--> statement-breakpoint
ALTER TABLE `merchants` ADD `phoneVerificationStatus` enum('unverified','pending','verified') DEFAULT 'unverified' NOT NULL;--> statement-breakpoint
ALTER TABLE `merchants` ADD `phoneVerifiedAt` timestamp;--> statement-breakpoint
ALTER TABLE `otpProviderConfigurations` ADD CONSTRAINT `otpProviderConfigurations_marketId_markets_id_fk` FOREIGN KEY (`marketId`) REFERENCES `markets`(`id`) ON DELETE no action ON UPDATE no action;--> statement-breakpoint
CREATE INDEX `otp_provider_market_status_idx` ON `otpProviderConfigurations` (`marketId`,`status`);