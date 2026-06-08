-- SQL script to create the Analytics RPC

CREATE OR REPLACE FUNCTION get_analytics(start_date TIMESTAMP, end_date TIMESTAMP)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_sales_count INT;
    v_total_revenue_ht DECIMAL;
    v_total_tva DECIMAL;
    v_total_timbre DECIMAL;
    v_total_revenue_ttc DECIMAL;
    v_total_cost_price DECIMAL;
    v_gross_profit DECIMAL;
    v_timeline JSONB;
    v_top_workers JSONB;
    v_top_products JSONB;
BEGIN
    -- 1. Global KPIs
    SELECT 
        COUNT(*),
        COALESCE(SUM(total_ht), 0),
        COALESCE(SUM(tva_amount), 0),
        COALESCE(SUM(timbre_fiscal), 0),
        COALESCE(SUM(total_ttc), 0)
    INTO
        v_sales_count, v_total_revenue_ht, v_total_tva, v_total_timbre, v_total_revenue_ttc
    FROM sales
    WHERE created_at >= start_date AND created_at <= end_date AND status = 'confirmed';

    -- 2. Calculate Total Cost Price (Prix d'achat)
    SELECT COALESCE(SUM(si.quantity * pp.prix_achat_super_gros), 0)
    INTO v_total_cost_price
    FROM sale_items si
    JOIN sales s ON s.id = si.sale_id
    JOIN product_pricing pp ON pp.product_id = si.product_id
    WHERE s.created_at >= start_date AND s.created_at <= end_date AND s.status = 'confirmed';

    v_gross_profit := v_total_revenue_ht - v_total_cost_price;

    -- 3. Timeline (Daily Revenue & Profit)
    SELECT jsonb_agg(timeline_row) INTO v_timeline
    FROM (
        SELECT 
            TO_CHAR(DATE(s.created_at), 'YYYY-MM-DD') as date_label,
            COALESCE(SUM(s.total_ht), 0) as revenue_ht,
            COALESCE(SUM(s.total_ht) - SUM(
                (SELECT COALESCE(SUM(si.quantity * pp.prix_achat_super_gros), 0)
                 FROM sale_items si 
                 JOIN product_pricing pp ON pp.product_id = si.product_id
                 WHERE si.sale_id = s.id)
            ), 0) as gross_profit
        FROM sales s
        WHERE s.created_at >= start_date AND s.created_at <= end_date AND s.status = 'confirmed'
        GROUP BY DATE(s.created_at)
        ORDER BY DATE(s.created_at)
    ) timeline_row;

    -- 4. Top Workers
    SELECT jsonb_agg(worker_row) INTO v_top_workers
    FROM (
        SELECT 
            u.id,
            COALESCE(u.raw_user_meta_data->>'full_name', u.email) as name,
            COUNT(s.id) as sales_count,
            COALESCE(SUM(s.total_ht), 0) as revenue_ht
        FROM auth.users u
        JOIN sales s ON s.worker_id = u.id
        WHERE s.created_at >= start_date AND s.created_at <= end_date AND s.status = 'confirmed'
        GROUP BY u.id, u.email, u.raw_user_meta_data->>'full_name'
        ORDER BY revenue_ht DESC
        LIMIT 5
    ) worker_row;

    -- 5. Top Products
    SELECT jsonb_agg(product_row) INTO v_top_products
    FROM (
        SELECT 
            p.id,
            p.name_fr,
            SUM(si.quantity) as qty_sold,
            SUM(si.total_ht) as revenue_ht
        FROM products p
        JOIN sale_items si ON si.product_id = p.id
        JOIN sales s ON s.id = si.sale_id
        WHERE s.created_at >= start_date AND s.created_at <= end_date AND s.status = 'confirmed'
        GROUP BY p.id, p.name_fr
        ORDER BY revenue_ht DESC
        LIMIT 5
    ) product_row;

    RETURN jsonb_build_object(
        'kpi', jsonb_build_object(
            'sales_count', v_sales_count,
            'total_revenue_ht', v_total_revenue_ht,
            'total_cost_price', v_total_cost_price,
            'gross_profit', v_gross_profit,
            'margin_percent', CASE WHEN v_total_revenue_ht > 0 THEN (v_gross_profit / v_total_revenue_ht) * 100 ELSE 0 END
        ),
        'timeline', COALESCE(v_timeline, '[]'::jsonb),
        'top_workers', COALESCE(v_top_workers, '[]'::jsonb),
        'top_products', COALESCE(v_top_products, '[]'::jsonb)
    );
END;
$$;
