import os
from supabase import create_client, Client
from dotenv import load_dotenv

load_dotenv()
url = os.environ.get("SUPABASE_URL")
key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY")

if not url or not key:
    print("Missing credentials in .env")
    exit(1)

supabase: Client = create_client(url, key)

print("--- SALES ---")
sales = supabase.table('sales').select('*').limit(1).execute()
if sales.data:
    print(list(sales.data[0].keys()))
else:
    print("No sales data")

print("\n--- CLIENTS ---")
clients = supabase.table('clients').select('*').limit(1).execute()
if clients.data:
    print(list(clients.data[0].keys()))
else:
    print("No clients data")

print("\n--- TABLES ---")
# Not simple to get all tables with supabase-py, so just checking common names
for t in ['client_payments', 'payments', 'transactions']:
    try:
        res = supabase.table(t).select('*').limit(1).execute()
        print(f"{t}: exists")
    except Exception as e:
        print(f"{t}: does not exist or error: {e}")
