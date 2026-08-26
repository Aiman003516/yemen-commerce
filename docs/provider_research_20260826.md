# Provider-ready expansion research notes

## WhatsApp Business Platform

The official WhatsApp Business Developer Hub states that the platform supports automation and integration, free test numbers, code samples, webhooks, a sandbox, API reference, opt-in guidance, pricing information, and policy enforcement documentation. This supports a provider-ready messaging module with a mock adapter now and a gated live adapter later. The app must still require a business account, approved sender, template/opt-in compliance, webhook signature verification, pricing review, and secret management before activation.

Source: https://whatsappbusiness.com/developers/developer-hub/

## Product decision

Provider-dependent modules should be represented by explicit adapter status values such as `mock`, `manual`, `configured`, `pending_approval`, and `blocked`. Mock/demo pages may show realistic seeded data, but all actions must visibly state that they do not send messages, create shipments, reserve funds, verify payments, or produce provider-side records until the corresponding adapter is configured and approved.
