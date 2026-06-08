-- SQL script to create the POS transaction RPC

CREATE OR REPLACE FUNCTION process_pos_sale(payload JSONB)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_sale_id UUID;
    v_sale_number VARCHAR;
    v_year_prefix VARCHAR;
    v_seq_val INT;
    v_item JSONB;
    v_product_id UUID;
    v_qty DECIMAL;
    v_sale_type VARCHAR;
    v_current_stock DECIMAL;
    v_col_to_deduct VARCHAR;
BEGIN
    -- 1. Generate Sale Number (e.g. 2026-00001)
    v_year_prefix := to_char(now(), 'YYYY');
    
    -- Create sequence if it doesn't exist for the year
    EXECUTE 'CREATE SEQUENCE IF NOT EXISTS sales_seq_' || v_year_prefix;
    v_seq_val := nextval('sales_seq_' || v_year_prefix);
    v_sale_number := v_year_prefix || '-' || lpad(v_seq_val::text, 5, '0');

    v_sale_type := payload->'sale'->>'sale_type';

    -- 2. Insert Sale
    INSERT INTO sales (
        sale_number,
        worker_id,
        client_id,
        sale_type,
        total_ht,
        tva_amount,
        timbre_fiscal,
        total_ttc,
        status,
        notes
    ) VALUES (
        v_sale_number,
        (payload->'sale'->>'worker_id')::UUID,
        NULLIF(payload->'sale'->>'client_id', '')::UUID,
        v_sale_type::sale_type_enum,
        (payload->'sale'->>'total_ht')::DECIMAL,
        (payload->'sale'->>'tva_amount')::DECIMAL,
        (payload->'sale'->>'timbre_fiscal')::DECIMAL,
        (payload->'sale'->>'total_ttc')::DECIMAL,
        'confirmed',
        payload->'sale'->>'notes'
    ) RETURNING id INTO v_sale_id;

    -- 3. Loop through items
    FOR v_item IN SELECT * FROM jsonb_array_elements(payload->'items')
    LOOP
        v_product_id := (v_item->>'product_id')::UUID;
        v_qty := (v_item->>'quantity')::DECIMAL;
        
        -- Determine which stock column to deduct
        IF v_sale_type = 'detail' THEN
            v_col_to_deduct := 'qty_detail';
        ELSE
            v_col_to_deduct := 'qty_gros';
        END IF;

        -- Check stock
        EXECUTE format('SELECT %I FROM stock WHERE product_id = $1 FOR UPDATE', v_col_to_deduct)
        INTO v_current_stock USING v_product_id;

        IF v_current_stock IS NULL OR v_current_stock < v_qty THEN
            RAISE EXCEPTION 'Insufficient stock for product % (Available: %, Requested: %)', v_product_id, v_current_stock, v_qty;
        END IF;

        -- Deduct stock
        EXECUTE format('UPDATE stock SET %I = %I - $1 WHERE product_id = $2', v_col_to_deduct, v_col_to_deduct)
        USING v_qty, v_product_id;

        -- Insert Sale Item
        INSERT INTO sale_items (
            sale_id,
            product_id,
            quantity,
            unit_price_ht,
            tva_rate,
            unit_price_ttc,
            total_ht,
            total_ttc,
            discount_percent
        ) VALUES (
            v_sale_id,
            v_product_id,
            v_qty,
            (v_item->>'unit_price_ht')::DECIMAL,
            (v_item->>'tva_rate')::DECIMAL,
            (v_item->>'unit_price_ttc')::DECIMAL,
            (v_item->>'total_ht')::DECIMAL,
            (v_item->>'total_ttc')::DECIMAL,
            (v_item->>'discount_percent')::DECIMAL
        );
    END LOOP;

    RETURN jsonb_build_object(
        'success', true,
        'sale_id', v_sale_id,
        'sale_number', v_sale_number
    );
EXCEPTION WHEN OTHERS THEN
    -- In Postgres, raising an exception in a function rolls back the transaction.
    RAISE EXCEPTION 'Transaction failed: %', SQLERRM;
END;
$$;
