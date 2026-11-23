-- SokoMart Kenya · Day 4 — Optimisation, transactions and business insights

-- Section E — Optimisation and transactions
/* Question 21 — Read a query plan (Medium)
Scenario. The Kisumu dashboard query feels slow.
Task. Run EXPLAIN (ANALYZE, BUFFERS) on this query, then run the query itself:

sql
Copy code
SELECT c.customer_id, c.first_name, c.last_name, SUM(i.line_total) AS revenue
FROM sokomart.customers c
JOIN sokomart.orders o      ON o.customer_id = c.customer_id
JOIN sokomart.order_items i ON i.order_id = o.order_id
WHERE c.county = 'Kisumu'
  AND o.order_status = 'completed'
  AND o.order_date >= '2026-09-01' AND o.order_date < '2026-10-01'
GROUP BY c.customer_id, c.first_name, c.last_name
ORDER BY revenue DESC;
In your SQL file, under the plan, add a comment block filling in this table from your plan:
top_node | join_methods_used | scan_on_orders | scan_on_customers | estimated_vs_actual_rows_orders | planning_ms | execution_ms | result_rows.
Required concept. EXPLAIN ANALYZE, BUFFERS.
Expected output. The plan (screenshot) + the filled-in table + the query's row count.*/

EXPLAIN (ANALYZE, BUFFERS)
SELECT c.customer_id, c.first_name, c.last_name, SUM(i.line_total) AS revenue
FROM sokomart.customers c
JOIN sokomart.orders o      ON o.customer_id = c.customer_id
JOIN sokomart.order_items i ON i.order_id = o.order_id
WHERE c.county = 'Kisumu'
  AND o.order_status = 'completed'
  AND o.order_date >= '2026-09-01' AND o.order_date < '2026-10-01'
GROUP BY c.customer_id, c.first_name, c.last_name
ORDER BY revenue DESC;


SELECT c.customer_id, c.first_name, c.last_name, SUM(i.line_total) AS revenue
FROM sokomart.customers c
JOIN sokomart.orders o      ON o.customer_id = c.customer_id
JOIN sokomart.order_items i ON i.order_id = o.order_id
WHERE c.county = 'Kisumu'
  AND o.order_status = 'completed'
  AND o.order_date >= '2026-09-01' AND o.order_date < '2026-10-01'
GROUP BY c.customer_id, c.first_name, c.last_name
ORDER BY revenue DESC;

/*
top_node | join_methods_used | scan_on_orders | scan_on_customers | estimated_vs_actual_rows_orders | planning_ms | execution_ms | result_rows
---------+-------------------+----------------+-------------------+---------------------------------+-------------+--------------+------------
Sort     | Hash Join, Nested loop    | Seq Scan  | Seq Scan    | est=... vs act=...              | 0.527 ms      | 7.270 ms       | 91
*/


--Question 22 — Prove the indexes help (Hard)
/* Scenario. You must convince the team lead that 05_indexes.sql is worth deploying.
Task.
(a) Drop the indexes (the commented DROP INDEX block at the bottom of 05_indexes.sql) and run
ANALYZE. Run EXPLAIN ANALYZE on: (1) SELECT order_id, order_date, total_amount FROM sokomart.orders WHERE customer_id = 408 ORDER BY order_date; (2) SELECT * FROM sokomart.payments WHERE order_id = 25000;
(3) SELECT order_id, quantity, line_total FROM sokomart.order_items WHERE product_id = 71;
(b) Run 05_indexes.sql again, and repeat the three plans.
(c) Create a partial index idx_orders_pending_date on orders(order_date) WHERE order_status = 'pending',
show a plan that uses it for WHERE order_status = 'pending' AND order_date < '2026-10-25', and compare its
size with idx_orders_order_date using pg_relation_size.
Record a comparison table in a comment: query | scan_before | execution_ms_before | scan_after | execution_ms_after | rows.
Required concept. Index design, before/after plans, partial index.
Expected output. 6 plans + the partial-index plan + partial_index_size, full_index_size + the comparison table.*/

-- Drop custom indexes, run ANALYZE, and capture "Before" plans

DROP INDEX IF EXISTS sokomart.idx_orders_customer_id;
DROP INDEX IF EXISTS sokomart.idx_orders_customer_date;
DROP INDEX IF EXISTS sokomart.idx_orders_order_date;
DROP INDEX IF EXISTS sokomart.idx_orders_status;
DROP INDEX IF EXISTS sokomart.idx_orders_pending_date;
DROP INDEX IF EXISTS sokomart.idx_payments_order_id;
DROP INDEX IF EXISTS sokomart.idx_order_items_product_id;
DROP INDEX IF EXISTS sokomart.idx_order_items_order_id;

ANALYZE sokomart.orders;
ANALYZE sokomart.payments;
ANALYZE sokomart.order_items;

-- Query 1 (Before): Customer orders sorted by date
EXPLAIN ANALYZE
SELECT order_id, order_date, total_amount
FROM sokomart.orders
WHERE customer_id = 408
ORDER BY order_date;

-- Query 2 (Before): Payments lookup by order_id
EXPLAIN ANALYZE
SELECT *
FROM sokomart.payments
WHERE order_id = 25000;

-- Query 3 (Before): Order items lookup by product_id
EXPLAIN ANALYZE
SELECT order_id, quantity, line_total
FROM sokomart.order_items
WHERE product_id = 71;


-- PART (b): Recreate indexes (05_indexes.sql), run ANALYZE, and capture "After" plans

CREATE INDEX IF NOT EXISTS idx_orders_customer_date
    ON sokomart.orders (customer_id, order_date);

CREATE INDEX IF NOT EXISTS idx_orders_order_date
    ON sokomart.orders (order_date);

CREATE INDEX IF NOT EXISTS idx_payments_order_id
    ON sokomart.payments (order_id);

CREATE INDEX IF NOT EXISTS idx_order_items_product_id
    ON sokomart.order_items (product_id);

ANALYZE sokomart.orders;
ANALYZE sokomart.payments;
ANALYZE sokomart.order_items;

-- Query 1 (After)
EXPLAIN ANALYZE
SELECT order_id, order_date, total_amount
FROM sokomart.orders
WHERE customer_id = 408
ORDER BY order_date;

-- Query 2 (After)
EXPLAIN ANALYZE
SELECT *
FROM sokomart.payments
WHERE order_id = 25000;

-- Query 3 (After)
EXPLAIN ANALYZE
SELECT order_id, quantity, line_total
FROM sokomart.order_items
WHERE product_id = 71;

-- PART (c): Partial index, verification plan, and index size comparison

DROP INDEX IF EXISTS sokomart.idx_orders_pending_date;

CREATE INDEX idx_orders_pending_date
    ON sokomart.orders (order_date)
    WHERE order_status = 'pending';

ANALYZE sokomart.orders;

-- Plan proving PostgreSQL uses idx_orders_pending_date
EXPLAIN ANALYZE
SELECT order_id, customer_id, order_date, total_amount
FROM sokomart.orders
WHERE order_status = 'pending'
  AND order_date < '2026-10-25';

-- Compare size of partial index vs full order_date index
SELECT 
    pg_size_pretty(pg_relation_size('sokomart.idx_orders_pending_date')) AS partial_index_size,
    pg_size_pretty(pg_relation_size('sokomart.idx_orders_order_date')) AS full_index_size;


/*

-- COMPARISON TABLE (Fill in your measured values from Parts a & b)

query                                     | scan_before | execution_ms_before | scan_after        | execution_ms_after | rows
------------------------------------------+-------------+---------------------+-------------------+--------------------+-----
Q1: orders WHERE customer_id = 408        | Seq Scan    | 0.079 ms              | Index Scan        | 0.113 ms             | 11
Q2: payments WHERE order_id = 25000       | Seq Scan    | 0.057 ms              | Index Scan        | 0.068 ms             | 1
Q3: order_items WHERE product_id = 71     | Seq Scan    | 0.649 ms              | Bitmap Heap Scan  | 0.499 ms             | 358
*/


-- Question 23 — Transactions you can see (Medium)
/* Scenario. The merchandising team wants to try out price and stock changes safely.
Task.
(a) Show the average Beauty price. BEGIN; cut every Beauty price by 10% (round to 2 dp); show the
average inside the transaction; ROLLBACK; show it is back to the original.
(b) Show stock for products 59 and 166. BEGIN; add 40 units to product 59 and insert an
audit_logs row recording the restock; SAVEPOINT after_restock; set product 166's stock to 0 by
mistake; show both; ROLLBACK TO SAVEPOINT after_restock; COMMIT. Show that 59 kept its +40 and 166 is unchanged.
(c) BEGIN; add 1 to product 166's stock; then try to set it to −5 (breaks chk_products_stock);
COMMIT. Show the error, that COMMIT reported ROLLBACK, and that product 166's stock is unchanged.
Required concept. BEGIN / COMMIT / ROLLBACK / SAVEPOINT / ROLLBACK TO SAVEPOINT, aborted transactions.
Expected output. before/inside/after values for each part, and the error message in (c).*/


-- Test 10% Beauty price cut inside a transaction and ROLLBACK

-- 1. Show average Beauty price BEFORE
SELECT 
    ROUND(AVG(unit_price), 2) AS avg_beauty_price_before
FROM sokomart.products
WHERE category = 'Beauty';

-- 2. Highlight from BEGIN to ROLLBACK 
BEGIN;

    UPDATE sokomart.products
    SET unit_price = ROUND(unit_price * 0.90, 2)
    WHERE category = 'Beauty';

    -- Show average Beauty price INSIDE the transaction
    SELECT 
        ROUND(AVG(unit_price), 2) AS avg_beauty_price_inside_tx
    FROM sokomart.products
    WHERE category = 'Beauty';

ROLLBACK;

-- 3. Show average Beauty price AFTER rollback (back to original)
SELECT 
    ROUND(AVG(unit_price), 2) AS avg_beauty_price_after_rollback
FROM sokomart.products
WHERE category = 'Beauty';


-- SAVEPOINT and ROLLBACK TO SAVEPOINT

-- 1. Show stock for products 59 and 166 BEFORE
SELECT 
    product_id,
    product_name,
    stock_quantity AS stock_before
FROM sokomart.products
WHERE product_id IN (59, 166)
ORDER BY product_id;

-- 2. Highlight from BEGIN to COMMIT 
BEGIN;

    -- Restock product 59 by +40 units
    UPDATE sokomart.products
    SET stock_quantity = stock_quantity + 40
    WHERE product_id = 59;

    -- Record the restock in audit_logs
    INSERT INTO sokomart.audit_logs (
        table_name,
        record_id,
        action,
        old_data,
        new_data
    )
    SELECT 
        'products',
        product_id,
        'UPDATE',
        jsonb_build_object('stock_quantity', stock_quantity - 40, 'reason', 'Restock +40 units'),
        jsonb_build_object('stock_quantity', stock_quantity, 'reason', 'Restock +40 units')
    FROM sokomart.products
    WHERE product_id = 59;

    SAVEPOINT after_restock;

    -- Mistakenly set product 166's stock to 0
    UPDATE sokomart.products
    SET stock_quantity = 0
    WHERE product_id = 166;

    -- Show both stocks INSIDE the transaction (after mistake)
    SELECT 
        product_id,
        product_name,
        stock_quantity AS stock_inside_tx_before_sp_rollback
    FROM sokomart.products
    WHERE product_id IN (59, 166)
    ORDER BY product_id;

    -- Undo only the mistake on product 166 while keeping product 59's restock + audit log
    ROLLBACK TO SAVEPOINT after_restock;

COMMIT;

-- 3. Show stock for products 59 and 166 AFTER commit (59 kept +40, 166 unchanged)
SELECT 
    product_id,
    product_name,
    stock_quantity AS stock_after_commit
FROM sokomart.products
WHERE product_id IN (59, 166)
ORDER BY product_id;


-- PART (c): Aborted transaction due to CHECK constraint (chk_products_stock)

-- 1. Show product 166's stock BEFORE
SELECT 
    product_id,
    product_name,
    stock_quantity AS stock_before_part_c
FROM sokomart.products
WHERE product_id = 166;

-- 2. Run these statements one by one 
BEGIN;

UPDATE sokomart.products
SET stock_quantity = stock_quantity + 1
WHERE product_id = 166;

-- This violates chk_products_stock (stock_quantity >= 0) and puts the transaction in an aborted state
UPDATE sokomart.products
SET stock_quantity = -5
WHERE product_id = 166;

-- Because the transaction is aborted, PostgreSQL executes COMMIT as a ROLLBACK
COMMIT;

-- 3. Show product 166's stock AFTER (neither +1 nor -5 was saved)
SELECT 
    product_id,
    product_name,
    stock_quantity AS stock_after_part_c
FROM sokomart.products
WHERE product_id = 166;


rollback;

--Question 24 — Clean up the duplicate payments (Hard)

/* Scenario. Some settlement files were sent twice (or three times), so payment_staging has
duplicate rows. Finance must not double-count them.
Task. A duplicate is a row with the same payment_id, order_id, payment_date, payment_method, amount, payment_status, transaction_reference as an earlier row. Keep the first-loaded copy (earliest
loaded_at, then lowest staging_id).
(a) Count the duplicated payments, the extra rows to delete and the most copies of one payment.
(b) List the first 10 rows that will be deleted, with their copy number (ROW_NUMBER()).
(c) Show row count and distinct payment_id count. In a transaction: delete the extra rows using
the ROW_NUMBER() CTE; check that rows = distinct payments and that the staged amount equals the sum of
the same payments in sokomart.payments; then COMMIT.
(d) Add a unique index on payment_staging(payment_id) and show that re-inserting a payment now fails.
Touch only payment_staging.
Required concept. ROW_NUMBER() dedup, DELETE … USING, transaction, unique index.
Expected output. (a) duplicated_payments, extra_rows_to_delete, max_copies;
(b) staging_id, payment_id, transaction_reference, amount, source_file, loaded_at, copy_no;
(c) staging_rows_before, distinct_payments_before / staging_rows_after, distinct_payments_after, staged_amount_after, same_payments_in_payments_table;
(d) the error message.*/


-- PART (a): Count duplicated payments, extra rows to delete, and max copies

WITH duplicate_groups AS (
    SELECT 
        payment_id,
        COUNT(*) AS copy_count
    FROM sokomart.payment_staging
    GROUP BY 
        payment_id,
        order_id,
        payment_date,
        payment_method,
        amount,
        payment_status,
        transaction_reference
    HAVING COUNT(*) > 1
)
SELECT 
    COUNT(*) AS duplicated_payments,
    COALESCE(SUM(copy_count - 1), 0) AS extra_rows_to_delete,
    COALESCE(MAX(copy_count), 0) AS max_copies
FROM duplicate_groups;



-- PART (b): List the first 10 rows that will be deleted with copy_no
WITH ranked_staging AS (
    SELECT 
        staging_id,
        payment_id,
        transaction_reference,
        amount,
        source_file,
        loaded_at,
        ROW_NUMBER() OVER (
            PARTITION BY 
                payment_id,
                order_id,
                payment_date,
                payment_method,
                amount,
                payment_status,
                transaction_reference
            ORDER BY loaded_at ASC, staging_id ASC
        ) AS copy_no
    FROM sokomart.payment_staging
)
SELECT 
    staging_id,
    payment_id,
    transaction_reference,
    amount,
    source_file,
    loaded_at,
    copy_no
FROM ranked_staging
WHERE copy_no > 1
ORDER BY payment_id ASC, copy_no ASC, staging_id ASC
LIMIT 10;


-- PART (c): Deduplicate inside a transaction, verify counts & amount, and COMMIT

-- 1. Show row count and distinct payment_id count BEFORE
SELECT 
    COUNT(*) AS staging_rows_before,
    COUNT(DISTINCT payment_id) AS distinct_payments_before
FROM sokomart.payment_staging;

-- 2. Highlight from BEGIN to COMMIT 
BEGIN;

    WITH ranked_staging AS (
        SELECT 
            staging_id,
            ROW_NUMBER() OVER (
                PARTITION BY 
                    payment_id,
                    order_id,
                    payment_date,
                    payment_method,
                    amount,
                    payment_status,
                    transaction_reference
                ORDER BY loaded_at ASC, staging_id ASC
            ) AS copy_no
        FROM sokomart.payment_staging
    )
    DELETE FROM sokomart.payment_staging ps
    USING ranked_staging rs
    WHERE ps.staging_id = rs.staging_id
      AND rs.copy_no > 1;

    -- Verify counts and reconcile staged amount against sokomart.payments BEFORE committing
    SELECT 
        COUNT(*) AS staging_rows_after,
        COUNT(DISTINCT payment_id) AS distinct_payments_after,
        SUM(amount) AS staged_amount_after,
        (
            SELECT SUM(p.amount)
            FROM sokomart.payments p
            WHERE p.payment_id IN (SELECT payment_id FROM sokomart.payment_staging)
        ) AS same_payments_in_payments_table
    FROM sokomart.payment_staging;

COMMIT;


-- PART (d): Add unique index on payment_staging(payment_id) & test duplicate insert

DROP INDEX IF EXISTS sokomart.idx_payment_staging_payment_id;

CREATE UNIQUE INDEX idx_payment_staging_payment_id
    ON sokomart.payment_staging (payment_id);

-- Attempt to re-insert an existing payment_id (run separately in DBeaver to capture error)
INSERT INTO sokomart.payment_staging (
    payment_id,
    order_id,
    payment_date,
    payment_method,
    amount,
    payment_status,
    transaction_reference,
    source_file
)
SELECT 
    payment_id,
    order_id,
    payment_date,
    payment_method,
    amount,
    payment_status,
    transaction_reference,
    'duplicate_test_file.csv'
FROM sokomart.payment_staging
LIMIT 1;


-- Question 25 — Three months in a row (Hard)

/* Scenario. Retention wants customers who bought (completed orders) in at least 3 consecutive
calendar months — the habit the subscription offer is aimed at.
Task. Build distinct customer-months in a CTE, find runs of consecutive months (gaps-and-islands:
month − ROW_NUMBER() months is constant along a run, or use LAG), and for each qualifying customer
return their longest run (earliest one if tied). Show the top 10 by streak_length (then customer_id),
and a second query with the number of qualifying customers and the longest streak in the data.
Required concept. Chained CTEs + window functions (gaps and islands).
Expected output. customer_id, full_name, county, streak_start_month, streak_end_month, streak_length;
then customers_with_3plus_streak, longest_streak.*/

WITH customer_months AS (
    -- CTE 1: Distinct calendar months with at least one completed order per customer
    SELECT DISTINCT
        o.customer_id,
        DATE_TRUNC('month', o.order_date)::DATE AS order_month
    FROM sokomart.orders o
    WHERE o.order_status = 'completed'
),
month_islands AS (
    -- CTE 2: Subtract row number (in months) from order_month; consecutive months share the same island_id
    SELECT 
        customer_id,
        order_month,
        (order_month - (ROW_NUMBER() OVER (
            PARTITION BY customer_id 
            ORDER BY order_month ASC
        ) * INTERVAL '1 month'))::DATE AS island_id
    FROM customer_months
),
customer_streaks AS (
    -- CTE 3: Collapse each island into its start month, end month, and streak length
    SELECT 
        customer_id,
        MIN(order_month) AS start_date,
        MAX(order_month) AS end_date,
        COUNT(*)::INTEGER AS streak_length
    FROM month_islands
    GROUP BY customer_id, island_id
    HAVING COUNT(*) >= 3
),
longest_customer_streak AS (
    -- CTE 4: Pick each qualifying customer's longest run (earliest streak if tied)
    SELECT 
        customer_id,
        start_date,
        end_date,
        streak_length,
        ROW_NUMBER() OVER (
            PARTITION BY customer_id 
            ORDER BY streak_length DESC, start_date ASC
        ) AS rn
    FROM customer_streaks
)
SELECT 
    c.customer_id,
    c.first_name || ' ' || c.last_name AS full_name,
    c.county,
    TO_CHAR(lcs.start_date, 'YYYY-MM') AS streak_start_month,
    TO_CHAR(lcs.end_date, 'YYYY-MM') AS streak_end_month,
    lcs.streak_length
FROM longest_customer_streak lcs
JOIN sokomart.customers c ON lcs.customer_id = c.customer_id
WHERE lcs.rn = 1
ORDER BY lcs.streak_length DESC, c.customer_id ASC
LIMIT 10;


WITH customer_months AS (
    SELECT DISTINCT
        o.customer_id,
        DATE_TRUNC('month', o.order_date)::DATE AS order_month
    FROM sokomart.orders o
    WHERE o.order_status = 'completed'
),
month_islands AS (
    SELECT 
        customer_id,
        order_month,
        (order_month - (ROW_NUMBER() OVER (
            PARTITION BY customer_id 
            ORDER BY order_month ASC
        ) * INTERVAL '1 month'))::DATE AS island_id
    FROM customer_months
),
customer_streaks AS (
    SELECT 
        customer_id,
        COUNT(*)::INTEGER AS streak_length
    FROM month_islands
    GROUP BY customer_id, island_id
    HAVING COUNT(*) >= 3
)
SELECT 
    COUNT(DISTINCT customer_id) AS customers_with_3plus_streak,
    COALESCE(MAX(streak_length), 0) AS longest_streak
FROM customer_streaks;



















