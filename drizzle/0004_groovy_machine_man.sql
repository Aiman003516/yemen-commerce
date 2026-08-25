CREATE TABLE `identityEvidence` (
	`id` int AUTO_INCREMENT NOT NULL,
	`identityCaseId` int NOT NULL,
	`kind` enum('passport','selfie') NOT NULL,
	`storageKey` varchar(1024) NOT NULL,
	`mimeType` varchar(80) NOT NULL,
	`originalName` varchar(180) NOT NULL,
	`createdAt` timestamp NOT NULL DEFAULT (now()),
	CONSTRAINT `identityEvidence_id` PRIMARY KEY(`id`),
	CONSTRAINT `identity_evidence_kind_unique` UNIQUE(`identityCaseId`,`kind`)
);
--> statement-breakpoint
CREATE TABLE `identityVerificationCases` (
	`id` int AUTO_INCREMENT NOT NULL,
	`merchantId` int NOT NULL,
	`submittedByUserId` int NOT NULL,
	`consentAt` timestamp NOT NULL,
	`status` enum('draft','submitted','under_review','verified','rejected','expired') NOT NULL DEFAULT 'draft',
	`reviewedByUserId` int,
	`reviewedAt` timestamp,
	`decisionNote` text,
	`retentionUntil` timestamp,
	`createdAt` timestamp NOT NULL DEFAULT (now()),
	`updatedAt` timestamp NOT NULL DEFAULT (now()) ON UPDATE CURRENT_TIMESTAMP,
	CONSTRAINT `identityVerificationCases_id` PRIMARY KEY(`id`),
	CONSTRAINT `identity_case_merchant_unique` UNIQUE(`merchantId`)
);
--> statement-breakpoint
ALTER TABLE `identityEvidence` ADD CONSTRAINT `identityEvidence_identityCaseId_identityVerificationCases_id_fk` FOREIGN KEY (`identityCaseId`) REFERENCES `identityVerificationCases`(`id`) ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE `identityVerificationCases` ADD CONSTRAINT `identityVerificationCases_merchantId_merchants_id_fk` FOREIGN KEY (`merchantId`) REFERENCES `merchants`(`id`) ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE `identityVerificationCases` ADD CONSTRAINT `identityVerificationCases_submittedByUserId_users_id_fk` FOREIGN KEY (`submittedByUserId`) REFERENCES `users`(`id`) ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE `identityVerificationCases` ADD CONSTRAINT `identityVerificationCases_reviewedByUserId_users_id_fk` FOREIGN KEY (`reviewedByUserId`) REFERENCES `users`(`id`) ON DELETE no action ON UPDATE no action;--> statement-breakpoint
CREATE INDEX `identity_case_status_idx` ON `identityVerificationCases` (`status`);