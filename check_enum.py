import psycopg2

conn = psycopg2.connect(host='aws-0-eu-west-1.pooler.supabase.com', database='postgres', user='postgres.dggulctustnlfyadcanx', password='DeltawareStationary2026', port='5432')
cur = conn.cursor()
cur.execute("SELECT unnest(enum_range(NULL::sale_status))")
for row in cur.fetchall():
    print(row[0])
