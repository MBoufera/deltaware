-- Enable UUID extension if not already enabled
create extension if not exists "uuid-ossp";

-- 1. PRODUCTS TABLE
create table if not exists products (
  id uuid default uuid_generate_v4() primary key,
  name text not null,
  barcode text,
  category text,
  purchase_price numeric not null default 0,
  wholesale_margin numeric not null default 0,
  retail_multiplier numeric not null default 1.30,
  tva numeric not null default 19,
  wholesale_price numeric not null default 0,
  retail_price numeric not null default 0,
  stock integer not null default 0,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 2. CLIENTS TABLE (CRM)
create table if not exists clients (
  id uuid default uuid_generate_v4() primary key,
  name text not null,
  phone text,
  debt_balance numeric not null default 0,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 3. SALES TABLE (Transactions)
create table if not exists sales (
  id uuid default uuid_generate_v4() primary key,
  client_id uuid references clients(id) on delete set null,
  total_amount numeric not null,
  payment_status text not null default 'paid', -- 'paid' or 'credit'
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 4. SALE ITEMS TABLE (Products sold in a transaction)
create table if not exists sale_items (
  id uuid default uuid_generate_v4() primary key,
  sale_id uuid references sales(id) on delete cascade not null,
  product_id uuid references products(id) on delete restrict not null,
  quantity integer not null,
  unit_price numeric not null,
  subtotal numeric not null
);

-- Optional: Create basic RLS policies allowing all operations for MVP
alter table products enable row level security;
alter table clients enable row level security;
alter table sales enable row level security;
alter table sale_items enable row level security;

create policy "Enable all for authenticated users only on products" on products for all to authenticated using (true) with check (true);
create policy "Enable all for authenticated users only on clients" on clients for all to authenticated using (true) with check (true);
create policy "Enable all for authenticated users only on sales" on sales for all to authenticated using (true) with check (true);
create policy "Enable all for authenticated users only on sale_items" on sale_items for all to authenticated using (true) with check (true);

-- Also allow anon for now so the app works easily during dev without strict auth
create policy "Enable all for anon on products" on products for all to anon using (true) with check (true);
create policy "Enable all for anon on clients" on clients for all to anon using (true) with check (true);
create policy "Enable all for anon on sales" on sales for all to anon using (true) with check (true);
create policy "Enable all for anon on sale_items" on sale_items for all to anon using (true) with check (true);
