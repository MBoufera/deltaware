-- Fix PostgrestException code 42702:
-- "column reference 'created_at' is ambiguous"
-- In the Top Workers subquery, 'created_at' was unqualified while JOINing
-- sales (s) and profiles (p), both of which have a 'created_at' column.
-- Fix: qualify all created_at references with the 's.' alias.

CREATE OR REPLACE FUNCTION public.get_deep_analytics(
    start_date timestamp with time zone,
    end_date   timestamp with time zone,
    p_store_id UUID DEFAULT NULL
) RETURNS json
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
  result             JSON;
  kpis               JSON;
  timeline           JSON;
  top_workers        JSON;
  top_products       JSON;
  category_breakdown JSON;
BEGIN
  -- 1. KPIs
  SELECT json_build_object(
    'total_revenue_ht', COALESCE(SUM(total_ht), 0),
    'gross_profit',     COALESCE(SUM(total_ht), 0) * 0.25,
    'sales_count',      COUNT(*),
    'margin_percent',   25.0
  ) INTO kpis
  FROM sales
  WHERE created_at >= start_date
    AND created_at <= end_date
    AND (p_store_id IS NULL OR store_id = p_store_id);

  -- 2. Timeline (Daily revenue)
  SELECT COALESCE(json_agg(row_to_json(t)), '[]'::json) INTO timeline
  FROM (
    SELECT
      TO_CHAR(DATE(created_at), 'YYYY-MM-DD') AS date_label,
      SUM(total_ht)          AS revenue_ht,
      SUM(total_ht) * 0.25   AS gross_profit
    FROM sales
    WHERE created_at >= start_date
      AND created_at <= end_date
      AND (p_store_id IS NULL OR store_id = p_store_id)
    GROUP BY DATE(created_at)
    ORDER BY DATE(created_at)
  ) t;

  -- 3. Top Workers
  SELECT COALESCE(json_agg(row_to_json(w)), '[]'::json) INTO top_workers
  FROM (
    SELECT
      p.full_name AS name,
      SUM(s.total_ht) AS revenue_ht
    FROM sales s
    JOIN profiles p ON s.worker_id = p.id
    WHERE s.created_at >= start_date          -- FIX: was unqualified 'created_at'
      AND s.created_at <= end_date            -- FIX: was unqualified 'created_at'
      AND (p_store_id IS NULL OR s.store_id = p_store_id)
    GROUP BY p.id, p.full_name
    ORDER BY revenue_ht DESC
    LIMIT 5
  ) w;

  -- 4. Top Products
  SELECT COALESCE(json_agg(row_to_json(tp)), '[]'::json) INTO top_products
  FROM (
    SELECT
      p.name_fr,
      SUM(si.quantity)  AS qty_sold,
      SUM(si.total_ht)  AS revenue_ht
    FROM sale_items si
    JOIN sales    s ON si.sale_id    = s.id
    JOIN products p ON si.product_id = p.id
    WHERE s.created_at >= start_date
      AND s.created_at <= end_date
      AND (p_store_id IS NULL OR s.store_id = p_store_id)
    GROUP BY p.id, p.name_fr
    ORDER BY revenue_ht DESC
    LIMIT 10
  ) tp;

  -- 5. Category Breakdown
  SELECT COALESCE(json_agg(row_to_json(cb)), '[]'::json) INTO category_breakdown
  FROM (
    SELECT
      c.name_fr AS category_name,
      SUM(si.total_ht)  AS revenue_ht,
      SUM(si.quantity)  AS qty_sold
    FROM sale_items si
    JOIN sales      s ON si.sale_id    = s.id
    JOIN products   p ON si.product_id = p.id
    JOIN categories c ON p.category_id = c.id
    WHERE s.created_at >= start_date
      AND s.created_at <= end_date
      AND (p_store_id IS NULL OR s.store_id = p_store_id)
    GROUP BY c.id, c.name_fr
    ORDER BY revenue_ht DESC
  ) cb;

  -- Combine into final result
  result := json_build_object(
    'kpi',                kpis,
    'timeline',           timeline,
    'top_workers',        top_workers,
    'top_products',       top_products,
    'category_breakdown', category_breakdown
  );

  RETURN result;
END;
$$;
