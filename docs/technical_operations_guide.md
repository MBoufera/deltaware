# Deltaware - Technical Operations Guide
**Version:** 1.0.0
**Architecture:** Serverless (Flutter Client + Supabase PostgreSQL)

## System Architecture
Deltaware has been engineered to operate without a traditional middleware API server (like Python/FastAPI) to minimize deployment complexity and latency.
- **Frontend:** Flutter Application running natively on Windows (C++) and Android.
- **Backend & Database:** Supabase (PostgreSQL 15+).
- **Communication:** The application communicates directly with the database via the Supabase Client SDK, utilizing highly secure PostgREST endpoints.
- **Authentication:** Handled entirely by Supabase GoTrue.
- **Business Logic:** Complex aggregations and secure operations are handled natively inside PostgreSQL using Remote Procedure Calls (RPC) written in PL/pgSQL.

## Security Model (Row Level Security - RLS)
Because the client application talks directly to the database, security is enforced strictly at the database layer using RLS.
- Only authenticated users can read/write data.
- The `user_permissions` table is checked by RLS policies before allowing a worker to perform sensitive operations (e.g., `can_cancel_sales`, `can_manage_products`).
- Bypassing the app UI to run raw API calls will still fail if the user's Auth Token does not satisfy the RLS policies.

## Key RPC Functions
All complex computations occur inside Supabase. Do not attempt to modify these unless you understand PL/pgSQL.
- `process_pos_sale`: The core transactional engine. It deducts stock, creates the sale record, inserts items, and records the snapshot price.
- `get_analytics`: The reporting engine. It aggregates revenue and computes true Gross Profit (Bénéfice Brut) by cross-referencing sale snapshots against the current inventory `prix_achat_super_gros`.
- `get_workers` / `update_worker_permissions`: Securely manages user accounts without exposing the private `auth.users` schema.

## Database Maintenance
### 1. Backups
- **Point-in-Time Recovery (PITR):** It is highly recommended to enable PITR in your Supabase Dashboard. This allows you to restore the database to any exact second in time in the event of accidental data deletion.
- **Manual Backups:** You can manually export the database using `pg_dump`:
  ```bash
  pg_dump --clean --if-exists --quote-all-identifiers -h aws-0-eu-central-1.pooler.supabase.com -p 5432 -U postgres.your_project_ref your_database > backup.sql
  ```

### 2. Adding a New Worker
Because we use a serverless architecture, you must invite new workers securely:
1. Log into your Supabase Dashboard.
2. Go to **Authentication > Users**.
3. Click **Invite User** and send an invitation to their email address.
4. Once the worker accepts the invite and sets their password, they will appear in the Deltaware Admin Dashboard under the **Workers** tab.
5. You can then use the app to assign their specific permissions.

### 3. Resetting Worker Passwords
1. Go to Supabase Dashboard > **Authentication > Users**.
2. Click the `...` menu next to the user.
3. Select **Send Password Reset**.

## Troubleshooting
**1. The Analytics Dashboard is showing incorrect profit margins.**
- Verify that the `prix_achat_super_gros` (cost price) was correctly set for the products sold *at the time of the sale*. If a product was sold before its cost price was properly entered, the profit calculation for that specific sale will be inaccurate. The analytics engine is mathematically exact; it only outputs what was inputted.

**2. Workers cannot log in.**
- Ensure they have completed the email verification step. If you want to bypass email verification for your internal store staff, disable "Confirm Email" in Supabase Dashboard > Authentication > Providers > Email.

**3. Printed Invoices have the wrong Company Name/RC.**
- Log into the Deltaware Admin Dashboard.
- Navigate to **Settings**.
- Update the Company Identity block. The PDF generator pulls from this database table live. There is no need to restart the application.
