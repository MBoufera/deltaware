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
    
    print("--- SALES COLUMNS ---")
    cur.execute("SELECT column_name, data_type FROM information_schema.columns WHERE table_name = 'sales'")
    for row in cur.fetchall():
        print(f"{row[0]}: {row[1]}")
        
    print("\n--- CLIENTS COLUMNS ---")
    cur.execute("SELECT column_name, data_type FROM information_schema.columns WHERE table_name = 'clients'")
    for row in cur.fetchall():
        print(f"{row[0]}: {row[1]}")
        
    print("\n--- ALL TABLES ---")
    cur.execute("SELECT table_name FROM information_schema.tables WHERE table_schema = 'public'")
    for row in cur.fetchall():
        print(row[0])
        
    cur.close()
    conn.close()

if __name__ == "__main__":
    main()
