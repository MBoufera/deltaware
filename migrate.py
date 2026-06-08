import psycopg2

print("Connecting to Supabase PostgreSQL...")
conn = psycopg2.connect(
    host="aws-0-eu-west-1.pooler.supabase.com",
    database="postgres",
    user="postgres.dggulctustnlfyadcanx",
    password="DeltawareStationary2026",
    port="5432"
)
conn.autocommit = True
cur = conn.cursor()

print("Reading admin_rpc.sql...")
with open('admin_rpc.sql', 'r', encoding='utf-8') as file:
    sql = file.read()

print("Executing migration...")
cur.execute(sql)

print("Migration completed successfully!")
cur.close()
conn.close()
