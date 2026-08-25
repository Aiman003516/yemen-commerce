# Yemen Commerce — Portable Handover Package

This package supports **Option C**: move the Yemen Commerce source and operating knowledge to a new Manus account and a new dedicated Supabase account/project. It is deliberately credential-free. Do not copy `.env` files, OAuth cookies, service-role keys, Manus connector files, database passwords, or customer/merchant evidence into Git or this handover folder.

| Portable asset | Source of truth | What the new environment does |
|---|---|---|
| Application source and Git history | Private GitHub repository `Aiman003516/yemen-commerce` | Grant the new GitHub identity access, then clone the repository into the new Manus project. |
| Product rules and roadmap | `master-plan-mobile-web.md`, `todo.md`, `shared/domain.ts`, `flutter_app/CONTRACTS.md` | Read before changing product rules, payment flows, or identity policy. |
| Current database shape | `drizzle/schema.ts` and `drizzle/*.sql` | Use as a migration reference; it is currently MySQL/TiDB-oriented and requires a deliberate PostgreSQL/Supabase translation. |
| Flutter client | `flutter_app/` | Run on Android, iOS, and Web; Flutter Web is the browser user interface. |
| Server/API | `server/`, `shared/`, `drizzle/` | Replace its current database and authentication integrations only through a planned Supabase migration. |

> **Important:** A new Manus account does not automatically receive this task’s conversation history, active connector state, project secrets, browser login state, Manus OAuth configuration, or database. The repository and this handover package are the portable record.

Read [NEW_MANUS_ACCOUNT_SETUP.md](NEW_MANUS_ACCOUNT_SETUP.md) first, then [SUPABASE_MIGRATION_PLAN.md](SUPABASE_MIGRATION_PLAN.md). Do not point the new project at the existing Supabase project from another application.
