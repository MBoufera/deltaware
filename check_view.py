import psycopg2

def main():
    conn = psycopg2.connect(
        host="aws-0-eu-west-1.pooler.supabase.com",
        database="postgres",
        user="postgres.dggulctustnlfyadcanx",
        password="DeltawareStationary2026",
        port="5432"
    )
    cur = conn.cursor()
    
    cur.execute("SELECT * FROM public.client_debts_view")
    rows = cur.fetchall()
    if not rows:
        print("client_debts_view is empty")
    for row in rows:
        print(row)
        
    cur.close()
    conn.close()

if __name__ == "__main__":
    main()
