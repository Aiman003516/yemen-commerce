CREATE TABLE `marketPolicyVersions` (
	`id` int AUTO_INCREMENT NOT NULL,
	`marketId` int NOT NULL,
	`key` varchar(80) NOT NULL,
	`version` int NOT NULL,
	`valueJson` text NOT NULL,
	`isActive` boolean NOT NULL DEFAULT true,
	`effectiveFrom` timestamp,
	`createdAt` timestamp NOT NULL DEFAULT (now()),
	CONSTRAINT `marketPolicyVersions_id` PRIMARY KEY(`id`),
	CONSTRAINT `market_policy_version_unique` UNIQUE(`marketId`,`key`,`version`)
);
--> statement-breakpoint
ALTER TABLE `marketPolicyVersions` ADD CONSTRAINT `marketPolicyVersions_marketId_markets_id_fk` FOREIGN KEY (`marketId`) REFERENCES `markets`(`id`) ON DELETE no action ON UPDATE no action;--> statement-breakpoint
CREATE INDEX `market_policy_active_idx` ON `marketPolicyVersions` (`marketId`,`key`,`isActive`);