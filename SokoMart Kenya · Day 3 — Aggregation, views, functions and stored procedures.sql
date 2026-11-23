-- SokoMart Kenya · Day 3 — Aggregation, views, functions and stored procedures

--Section C — Advanced aggregation with subqueries

--Question 11 — Customer tiers (Medium)

/*Scenario. The loyalty programme has four tiers by lifetime revenue:
Platinum ≥ KES 1,000,000; Gold ≥ 500,000; Silver ≥ 100,000; Bronze below 100,000.
Task. For customers with at least one completed order: compute lifetime revenue in an inner
derived table, assign the tier with CASE in a second derived table around it, then aggregate
per tier. revenue_share_pct is the tier's share of total completed revenue — compute that total
with a scalar subquery. Order from Platinum to Bronze.
Required concept. Nested derived tables, CASE, scalar subquery.
Expected output. tier, customer_count, min_spent, max_spent, avg_spent, revenue_share_pct (4 rows)*/

select 
    tiered_customers.tier,
    COUNT(*) as customer_count,
    MIN(tiered_customers.lifetime_revenue) as min_spent,
    MAX(tiered_customers.lifetime_revenue) as max_spent,
    ROUND(AVG(tiered_customers.lifetime_revenue), 2) as avg_spent,
    ROUND(
        100.0 * SUM(tiered_customers.lifetime_revenue) / (
            select SUM(oi2.line_total)
            from orders o2
            join order_items oi2 on o2.order_id = oi2.order_id
            where o2.order_status = 'completed'
        ), 
        2
    ) as revenue_share_pct
from (
    select 
        cust_rev.customer_id,
        cust_rev.lifetime_revenue,
        case 
            when cust_rev.lifetime_revenue >= 1000000 then 'Platinum'
            when cust_rev.lifetime_revenue >= 500000 then 'Gold'
            when cust_rev.lifetime_revenue >= 100000 then 'Silver'
            else 'Bronze'
        end as tier
    from (
        select 
            o.customer_id,
            SUM(oi.line_total) as lifetime_revenue
        from orders o
        join order_items oi on o.order_id = oi.order_id
        where o.order_status = 'completed'
        group by o.customer_id
    ) cust_rev
) tiered_customers
group by tiered_customers.tier
order by 
    case tiered_customers.tier
        when 'Platinum' then 1
        when 'Gold' then 2
        when 'Silver' then 3
        when 'Bronze' then 4
    end asc;


--Question 12 — What did Mombasa buy in October? (Medium)
/* Scenario. The Mombasa team wants a one-line shopping list per customer for October 2026.
Task. For customers living in Mombasa who have at least one non-cancelled order placed
in October 2026 (check this with EXISTS), list the distinct products on those October orders
as one string, alphabetical, separated by '; '. Order by product_count descending, then
customer_id. Second query: the number of customers that qualify.
Required concept. STRING_AGG(DISTINCT … ORDER BY …), EXISTS.
Expected output. customer_id, full_name, product_count, products_ordered*/

select 
    c.customer_id,
    c.first_name || ' ' || c.last_name as full_name,
    COUNT(DISTINCT p.product_name) as product_count,
    STRING_AGG(DISTINCT p.product_name, '; ' order by p.product_name asc) as products_ordered
from customers c
join orders o on c.customer_id = o.customer_id
join order_items oi on o.order_id = oi.order_id
join products p on oi.product_id = p.product_id
where c.county = 'Mombasa'
  and o.order_date >= '2026-10-01'
  and o.order_date < '2026-11-01'
  and o.order_status <> 'cancelled'
  and exists (
      select 1
      from sokomart.orders o2
      where o2.customer_id = c.customer_id
        and o2.order_date >= '2026-10-01'
        and o2.order_date < '2026-11-01'
        and o2.order_status <> 'cancelled'
  )
group by  c.customer_id, c.first_name, c.last_name
order by  product_count desc, c.customer_id asc;


select 
    COUNT(*) as qualifying_customers
from customers c
where c.county = 'Mombasa'
  and exists (
      select 1
      from orders o
      where o.customer_id = c.customer_id
        and o.order_date >= '2026-10-01'
        and o.order_date < '2026-11-01'
        and o.order_status <> 'cancelled'
  );


--Question 13 — Payment health by method, 2026 (Medium)
/*Scenario. The payments team suspects one channel fails more often than the others.
Task. Put 2026 payments (by payment_date) in a CTE. Per payment_method: total payments,
successful, failed, pending (each with COUNT(*) FILTER (WHERE …)), success rate %, and the total
amount of failed payments. Order by total_payments descending.
Required concept. FILTER clause, CTE.
Expected output. payment_method, total_payments, successful, failed, pending, success_rate_pct, failed_amount (4 rows)*/

with payments_2026 as (
    select 
        payment_id,
        payment_method,
        payment_status,
        amount
    from payments
    where payment_date >= '2026-01-01'
      and payment_date < '2027-01-01'
)
select 
    payment_method,
    COUNT(*) as total_payments,
    COUNT(*) FILTER (where payment_status = 'completed') as successful,
    COUNT(*) FILTER (where payment_status = 'failed') as failed,
    COUNT(*) FILTER (where payment_status = 'pending') as pending,
    ROUND(
        100.0 * COUNT(*) filter (where payment_status = 'completed') / NULLIF(COUNT(*), 0), 
        2
    ) as success_rate_pct,
    COALESCE(SUM(amount) FILTER (where payment_status = 'failed'), 0) as failed_amount
from payments_2026
group by payment_method
order by total_payments desc;


--Question 14 — Which departments carry the profit? (Medium)
/*Scenario. The board asks which categories earned more gross profit than the average
category in 2025.
Task. CTE with 2025 revenue and gross profit per category. Return only the categories whose
gross profit is above the average category gross profit (use a scalar subquery on the CTE —
not a hard-coded number). Show the margin and how far above the average each one is, in %.
Order by gross_profit descending.
Required concept. CTE + scalar subqueries in SELECT and WHERE.
Expected output. category, revenue, gross_profit, margin_pct, avg_category_gross_profit, pct_above_avg*/


with category_profit_2025 as (
    select 
        p.category,
        SUM(oi.line_total) as revenue,
        SUM(oi.line_total) - SUM(oi.quantity * p.cost_price) as gross_profit
    from sokomart.products p
    join sokomart.order_items oi on p.product_id = oi.product_id
    join sokomart.orders o on oi.order_id = o.order_id
    where o.order_status = 'completed'
      and o.order_date >= '2025-01-01'
      and o.order_date < '2026-01-01'
    group by p.category
)
select 
    category,
    revenue,
    gross_profit,
    ROUND(100.0 * gross_profit / NULLIF(revenue, 0), 2) as margin_pct,
    ROUND((select AVG(gross_profit) from category_profit_2025), 2) as avg_category_gross_profit,
    ROUND(
        100.0 * (gross_profit - (select AVG(gross_profit) from category_profit_2025)) 
        / NULLIF((select AVG(gross_profit) from category_profit_2025), 0), 
        2
    ) as pct_above_avg
from category_profit_2025
where gross_profit > (
    select AVG(gross_profit) 
    from category_profit_2025
)
order by gross_profit desc;



--Question 15 — One sales table with subtotals (Hard)
/*Scenario. Regional heads want 2026 revenue for Nairobi, Mombasa, Kisumu, Nakuru and Uasin Gishu
by category, with county subtotals, category subtotals and a grand total — in one query.
Task. CTE with the 2026 completed order lines for those five shipping counties. Aggregate
with GROUPING SETS ((county, category), (county), (category), ()). Label each row with
GROUPING(): county x category, county total, category total, grand total; show
ALL COUNTIES / ALL CATEGORIES instead of NULL. order_count = distinct orders.
Required concept. GROUPING SETS, GROUPING().
Expected output. grouping_level, county, category, revenue, order_count (36 rows)*/

with regional_lines_2026 as (
    select 
        o.shipping_county as county,
        p.category,
        o.order_id,
        oi.line_total
    from orders o
    join order_items oi on o.order_id = oi.order_id
    join products p on oi.product_id = p.product_id
    where o.order_status = 'completed'
      and o.order_date >= '2026-01-01'
      and o.order_date < '2027-01-01'
      and o.shipping_county in ('Nairobi', 'Mombasa', 'Kisumu', 'Nakuru', 'Uasin Gishu')
)
select 
    case 
        when GROUPING(county) = 0 and GROUPING(category) = 0 then 'county x category'
        when GROUPING(county) = 0 and GROUPING(category) = 1 then 'county total'
        when GROUPING(county) = 1 and GROUPING(category) = 0 then 'category total'
        else 'grand total'
    end as grouping_level,
    case 
        when GROUPING(county) = 1 then 'ALL COUNTIES'
        else county
    end as county,
    case 
        when GROUPING(category) = 1 then 'ALL CATEGORIES'
        else category
    end as category,
    SUM(line_total) as revenue,
    COUNT(distinct order_id) as order_count
from regional_lines_2026
group by GROUPING sets (
    (county, category),
    (county),
    (category),
    ()
)
order by 
    GROUPING(county) asc,
    county asc,
    GROUPING(category) asc,
    category asc;


--Section D — Views, functions, stored procedures and triggers

/* Question 16 — Customer summary view and monthly category materialized view (Medium)
Scenario. Analysts keep rewriting the same customer and category queries.
Task.
(a) Create the view sokomart.v_customer_purchase_summary, built on CTEs, with one row for
every customer — including the ones with no completed orders (0 orders, 0 spent, NULL dates).
days_since_last_order is counted to 31 October 2026. Then: the top 10 customers living in
Kiambu by lifetime_spent; and a query returning the number of rows in the view and the number
of customers with completed_orders = 0.
(b) Create the materialized view sokomart.mv_monthly_category_sales: one row per month and
category for completed orders, with a unique index on (sales_month, category). Show the
December 2025 rows ordered by revenue.
Required concept. CREATE VIEW over CTEs + LEFT JOIN; CREATE MATERIALIZED VIEW.
Expected output.
(a) customer_id, full_name, county, registration_date, completed_orders, lifetime_spent, avg_order_value, 
first_order_date, last_order_date, days_since_last_order
(b) sales_month, category, orders, units_sold, revenue, gross_profit*/


create or replace view sokomart.v_customer_purchase_summary as
with order_revenues as (
    select 
        o.order_id,
        o.customer_id,
        o.order_date,
        SUM(oi.line_total) as order_revenue
    from orders o
    join order_items oi on o.order_id = oi.order_id
    where o.order_status = 'completed'
    group by o.order_id, o.customer_id, o.order_date
),
customer_stats as (
    select 
        customer_id,
        COUNT(*) as completed_orders,
        SUM(order_revenue) as lifetime_spent,
        ROUND(AVG(order_revenue), 2) as avg_order_value,
        MIN(order_date) as first_order_date,
        MAX(order_date) as last_order_date
    from order_revenues
   group by customer_id
)
select 
    c.customer_id,
    c.first_name || ' ' || c.last_name as full_name,
    c.county,
    c.registration_date,
    COALESCE(cs.completed_orders, 0) as completed_orders,
    COALESCE(cs.lifetime_spent, 0) as lifetime_spent,
    COALESCE(cs.avg_order_value, 0) as avg_order_value,
    cs.first_order_date,
    cs.last_order_date,
    ('2026-10-31'::DATE - cs.last_order_date::DATE) as days_since_last_order
from customers c
left join customer_stats cs on c.customer_id = cs.customer_id;

select *
from sokomart.v_customer_purchase_summary
where county = 'Kiambu'
order by lifetime_spent desc, customer_id asc
limit 10;

select 
    COUNT(*) as total_customers_in_view,
    COUNT(*) filter (where completed_orders = 0) as zero_completed_order_customers
from sokomart.v_customer_purchase_summary;



DROP MATERIALIZED VIEW IF EXISTS sokomart.mv_monthly_category_sales;

CREATE MATERIALIZED VIEW sokomart.mv_monthly_category_sales as
select 
    TO_CHAR(DATE_TRUNC('month', o.order_date), 'YYYY-MM') as sales_month,
    p.category,
    COUNT(distinct o.order_id) as orders,
    SUM(oi.quantity) as units_sold,
    SUM(oi.line_total) as revenue,
    SUM(oi.line_total) - SUM(oi.quantity * p.cost_price) as gross_profit
from orders o
join order_items oi on o.order_id = oi.order_id
join products p on oi.product_id = p.product_id
where o.order_status = 'completed'
group by DATE_TRUNC('month', o.order_date), p.category;


CREATE UNIQUE INDEX idx_mv_monthly_category_sales_month_cat
    on sokomart.mv_monthly_category_sales (sales_month, category);


select 
    sales_month,
    category,
    orders,
    units_sold,
    revenue,
    gross_profit
from sokomart.mv_monthly_category_sales
where sales_month = '2025-12'
order by revenue desc;


-- Question 17 — Function: customer spend for a date range (Medium)
/* Scenario. Customer care needs "how much has this customer spent between these dates?" on demand.
Task. Write sokomart.fn_customer_spend(p_customer_id INTEGER, p_start_date DATE, p_end_date DATE) RETURNS NUMERIC — 
completed revenue for orders placed from p_start_date to p_end_date
inclusive of the whole end day. Return 0 (not NULL) when there is nothing. Raise an exception
when the end date is before the start date. Then:

Call it for customer 4000 for: 2025; Jan–Oct 2026; 1 Jan 2025–31 Oct 2026; December 2025; and for customer -1.
Show that the all-time value equals lifetime_spent for customer 4000 in your Q16 view.
Use it inside a query: top 5 customers living in Nairobi by December 2025 spend.
Show the exception for ('2026-02-01', '2026-01-01').
Required concept. PL/pgSQL function with parameters, validation, RAISE EXCEPTION.
Expected output. (1) five numbers; (2) customer_id, lifetime_spent, fn_value, matches;
(3) customer_id, full_name, december_2025_spend; (4) the error message.*/


CREATE OR REPLACE FUNCTION sokomart.fn_customer_spend(
    p_customer_id INTEGER,
    p_start_date DATE,
    p_end_date DATE
)
returns NUMERIC
language plpgsql
as $$
declare
    v_total_spend NUMERIC;
begin
    if p_end_date < p_start_date then
        raise exception 'End date (%) cannot be before start date (%).', p_end_date, p_start_date;
    end if;

    select COALESCE(SUM(oi.line_total), 0)
    into v_total_spend
    from sokomart.orders o
    join sokomart.order_items oi on o.order_id = oi.order_id
    where o.customer_id = p_customer_id
      and o.order_status = 'completed'
      and o.order_date >= p_start_date
      and o.order_date < (p_end_date + INTERVAL '1 day');

    return v_total_spend;
end;
$$;


select 
    sokomart.fn_customer_spend(4000, '2025-01-01', '2025-12-31') as spend_2025,
    sokomart.fn_customer_spend(4000, '2026-01-01', '2026-10-31') as spend_jan_oct_2026,
    sokomart.fn_customer_spend(4000, '2025-01-01', '2026-10-31') as spend_all_time,
    sokomart.fn_customer_spend(4000, '2025-12-01', '2025-12-31') as spend_dec_2025,
    sokomart.fn_customer_spend(-1, '2025-01-01', '2026-10-31') as spend_nonexistent;

select 
    customer_id,
    lifetime_spent,
    sokomart.fn_customer_spend(customer_id, '2025-01-01', '2026-10-31') as fn_value,
    (lifetime_spent = sokomart.fn_customer_spend(customer_id, '2025-01-01', '2026-10-31')) as matches
from sokomart.v_customer_purchase_summary
where customer_id = 4000;

select 
    customer_id,
    first_name || ' ' || last_name as full_name,
    sokomart.fn_customer_spend(customer_id, '2025-12-01', '2025-12-31') as december_2025_spend
from sokomart.customers
where county = 'Nairobi'
order by december_2025_spend desc, customer_id asc
limit 5;


SELECT sokomart.fn_customer_spend(4000, '2026-02-01', '2026-01-01');



--Question 18 — Procedure: change a price and keep its history (Medium)
/* Scenario. The supplier of Pwani Golden Cooking Oil 3L (product 71) has raised prices.
Every price change must be recorded.
Task. Write sokomart.sp_update_product_price(p_product_id INTEGER, p_new_price NUMERIC, p_reason VARCHAR).
It must: lock the product row (SELECT … FOR UPDATE); raise an exception if the product does not
exist, if the new price is ≤ 0, or if it is below the product's cost_price; update
products.unit_price; insert a row into product_price_history (old price, new price, reason);
and insert a row into audit_logs (table_name = 'products', action = 'UPDATE', old and new
price as JSONB). Then:

Show product 71's price and cost. CALL the procedure to set it to KES 1,099.00, reason
'Supplier price increase - Nov 2026'. Show the new price, the history row and the audit row.
CALL it with KES 500.00 and show it is rejected and that no extra history row was written.
Required concept. Stored procedure, FOR UPDATE, validation, writing to several tables.
Expected output. product_id, product_name, unit_price, cost_price (before/after);
price_history_id, product_id, old_price, new_price, change_reason; table_name, record_id, action, old_data, new_data.*/


CREATE OR REPLACE PROCEDURE sokomart.sp_update_product_price(
    p_product_id INTEGER,
    p_new_price NUMERIC,
    p_reason VARCHAR
)
language plpgsql
as $$
declare
    v_old_price NUMERIC;
    v_cost_price NUMERIC;
begin
    if p_new_price is null or p_new_price <= 0 then
        raise exception 'New price (%) must be greater than 0.', p_new_price;
    end if;

    select unit_price, cost_price
    into v_old_price, v_cost_price
    from sokomart.products
    where product_id = p_product_id
    for update;

    
    if not found then
        raise exception 'Product with ID % does not exist.', p_product_id;
    end if;

    
    if p_new_price < v_cost_price then
        raise exception 'New price (%) cannot be below product cost price (%).', p_new_price, v_cost_price;
    end if;

    
    update sokomart.products
    set unit_price = p_new_price
    where product_id = p_product_id;

    
    insert into sokomart.product_price_history (
        product_id,
        old_price,
        new_price,
        change_reason
    )
    values (
        p_product_id,
        v_old_price,
        p_new_price,
        p_reason
    );

    
    insert into sokomart.audit_logs (
        table_name,
        record_id,
        action,
        old_data,
        new_data
    )
    values (
        'products',
        p_product_id,
        'UPDATE',
        jsonb_build_object('unit_price', v_old_price),
        jsonb_build_object('unit_price', p_new_price)
    );
end;
$$;


select 
    product_id,
    product_name,
    unit_price,
    cost_price
from sokomart.products
where product_id = 71;


call sokomart.sp_update_product_price(71, 1099.00, 'Supplier price increase - Nov 2026');


select 
    product_id,
    product_name,
    unit_price,
    cost_price
from sokomart.products
where product_id = 71;

select 
    price_history_id,
    product_id,
    old_price,
    new_price,
    change_reason
from sokomart.product_price_history
where product_id = 71
order by price_history_id desc;

select 
    table_name,
    record_id,
    action,
    old_data,
    new_data
FROM sokomart.audit_logs
WHERE table_name = 'products'
  AND record_id = 71
ORDER BY audit_id DESC;


CALL sokomart.sp_update_product_price(71, 500.00, 'Below cost test');


SELECT 
    price_history_id,
    product_id,
    old_price,
    new_price,
    change_reason
FROM sokomart.product_price_history
WHERE product_id = 71
ORDER BY price_history_id DESC;



--Question 19 — Trigger + procedure: order status changes are always logged (Hard)
/* Scenario. Disputes keep coming up about who changed an order's status and when.
Task.
(a) Write a trigger function and the trigger trg_orders_status_audit (AFTER INSERT OR UPDATE OF order_status ON 
sokomart.orders FOR EACH ROW). On insert it writes an order_status_history
row with old_status NULL; on an update that actually changes the status it writes the old and
new status. Both cases also write an audit_logs row.
(b) Write sokomart.sp_update_order_status(p_order_id INTEGER, p_new_status VARCHAR) that allows
only pending → completed, pending → cancelled and completed → returned, and raises an exception
for anything else. When an order becomes completed its payment becomes successful; when it becomes
cancelled an unpaid payment becomes failed.
(c) Prove it on order 48882 (pending): show order + payment status, CALL the procedure to
complete it, show both again, the history row and the audit row. Then run a plain UPDATE setting it
to returned and show that the trigger logged that too. Then run an UPDATE that sets
shipping_county = shipping_county and show that no new history row appeared (still 2).
Finally show the exception for CALL sokomart.sp_update_order_status(49961, 'completed') (a cancelled order).
Required concept. Trigger function, TG_OP, OLD/NEW, IS DISTINCT FROM; procedure with rules.
Expected output. order_id, order_status, payment_status; order_id, old_status, new_status;
table_name, record_id, action, old_data, new_data; the error message.*/


CREATE OR REPLACE FUNCTION sokomart.fn_orders_status_audit()
returns trigger
language plpgsql
as $$
begin
    if TG_OP = 'INSERT' then
        
        insert into sokomart.order_status_history (
            order_id,
            old_status,
            new_status
        )
        values (
            NEW.order_id,
            NULL,
            NEW.order_status
        );

        insert into sokomart.audit_logs (
            table_name,
            record_id,
            action,
            old_data,
            new_data
        )
        values (
            'orders',
            NEW.order_id,
            'INSERT',
            NULL,
            jsonb_build_object('order_status', NEW.order_status)
        );

    ELSIF TG_OP = 'UPDATE' THEN
        
        IF OLD.order_status IS DISTINCT FROM NEW.order_status THEN
            INSERT INTO sokomart.order_status_history (
                order_id,
                old_status,
                new_status
            )
            VALUES (
                NEW.order_id,
                OLD.order_status,
                NEW.order_status
            );

            INSERT INTO sokomart.audit_logs (
                table_name,
                record_id,
                action,
                old_data,
                new_data
            )
            VALUES (
                'orders',
                NEW.order_id,
                'UPDATE',
                jsonb_build_object('order_status', OLD.order_status),
                jsonb_build_object('order_status', NEW.order_status)
            );
        END IF;
    END IF;

    RETURN NEW;
END;
$$;


DROP TRIGGER IF EXISTS trg_orders_status_audit ON sokomart.orders;

CREATE TRIGGER trg_orders_status_audit
AFTER INSERT OR UPDATE OF order_status ON sokomart.orders
FOR EACH ROW
EXECUTE FUNCTION sokomart.fn_orders_status_audit();



CREATE OR REPLACE PROCEDURE sokomart.sp_update_order_status(
    p_order_id INTEGER,
    p_new_status VARCHAR
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_current_status VARCHAR;
    v_target_status VARCHAR := LOWER(TRIM(p_new_status));
BEGIN
    SELECT order_status
    INTO v_current_status
    FROM sokomart.orders
    WHERE order_id = p_order_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Order with ID % does not exist.', p_order_id;
    END IF;

    
    IF NOT (
        (v_current_status = 'pending' AND v_target_status IN ('completed', 'cancelled'))
        OR
        (v_current_status = 'completed' AND v_target_status = 'returned')
    ) THEN
        RAISE EXCEPTION 'Invalid status transition from "%" to "%" for order %.',
            v_current_status, p_new_status, p_order_id;
    END IF;

    
    UPDATE sokomart.orders
    SET order_status = v_target_status
    WHERE order_id = p_order_id;

    
    IF v_target_status = 'completed' THEN
        UPDATE sokomart.payments
        SET payment_status = 'successful'
        WHERE order_id = p_order_id;

    ELSIF v_target_status = 'cancelled' THEN
        UPDATE sokomart.payments
        SET payment_status = 'failed'
        WHERE order_id = p_order_id
          AND payment_status <> 'successful';
    END IF;
END;
$$;



SELECT 
    o.order_id,
    o.order_status,
    p.payment_status
FROM sokomart.orders o
LEFT JOIN sokomart.payments p ON o.order_id = p.order_id
WHERE o.order_id = 48882;


CALL sokomart.sp_update_order_status(48882, 'completed');


SELECT 
    o.order_id,
    o.order_status,
    p.payment_status
FROM sokomart.orders o
LEFT JOIN sokomart.payments p ON o.order_id = p.order_id
WHERE o.order_id = 48882;

SELECT 
    order_id,
    old_status,
    new_status
FROM sokomart.order_status_history
WHERE order_id = 48882;

SELECT 
    table_name,
    record_id,
    action,
    old_data,
    new_data
FROM sokomart.audit_logs
WHERE table_name = 'orders'
  AND record_id = 48882;

UPDATE sokomart.orders
SET order_status = 'returned'
WHERE order_id = 48882;

SELECT 
    order_id,
    old_status,
    new_status
FROM sokomart.order_status_history
WHERE order_id = 48882;

SELECT 
    table_name,
    record_id,
    action,
    old_data,
    new_data
FROM sokomart.audit_logs
WHERE table_name = 'orders'
  AND record_id = 48882;


UPDATE sokomart.orders
SET shipping_county = shipping_county
WHERE order_id = 48882;

SELECT 
    order_id,
    old_status,
    new_status
FROM sokomart.order_status_history
WHERE order_id = 48882;


CALL sokomart.sp_update_order_status(49961, 'completed');


--Question 20 — Procedure: place an order atomically (Hard) 
/* Scenario. The new checkout service will call one database procedure to place an order. Either the
whole order is saved — order, lines, payment, stock — or nothing is.
Task. Write
sokomart.sp_place_order(p_customer_id INTEGER, p_product_ids INTEGER[], p_quantities INTEGER[], p_payment_method VARCHAR, 
INOUT p_order_id INTEGER DEFAULT NULL). It must:

reject a customer who does not exist or is not active, and arrays of different lengths;
insert the order (pending, today, shipping_county = the customer's county);
for each product, decrease stock with a conditional UPDATE (… WHERE stock_quantity >= qty AND product_status = 'active'); 
if no row was updated, RAISE EXCEPTION with the product id, requested
and available quantity — this undoes everything done so far;
insert each order line at the product's current price, no discount;
set delivery_fee with the SokoMart rule (docs/data_dictionary.md: free from KES 5,000 of items;
otherwise Nairobi 200, Kiambu/Kajiado/Machakos 250, elsewhere 350) and total_amount;
insert a pending payment for the full amount (a transaction reference for every method except cash on delivery);
return the new order_id.
Then:
Show products 6, 73, 82 (price, stock). CALL sokomart.sp_place_order(177, ARRAY[6,73,82], ARRAY[1,2,3], 'M-Pesa', NULL);
Show the order (with its items total), its lines, its payment, the new stock, and the status-history row your Q19 trigger 
wrote.
Show the order count and stock for products 6 and 59. CALL sokomart.sp_place_order(408, ARRAY[6,59], ARRAY[1,2], 'card', 
NULL);
(product 59 has only 1 unit). Show the error, then show the order count and both stock levels unchanged.
Complete your new order with sp_update_order_status, REFRESH MATERIALIZED VIEW CONCURRENTLY 
sokomart.mv_monthly_category_sales, 
and show the November 2026 rows that now exist.
Required concept. Atomic stored procedure, arrays, INOUT, RETURNING … INTO, conditional update as a stock lock, 
materialized view refresh.
Expected output. order_id, customer_id, order_status, shipping_county, delivery_fee, total_amount, items_total;
order_id, product_id, quantity, unit_price, line_total; order_id, payment_method, amount, payment_status, has_reference;
the error message; sales_month, category, orders, units_sold, revenue, gross_profit.*/


CREATE OR REPLACE PROCEDURE sokomart.sp_place_order(
    p_customer_id INTEGER,
    p_product_ids INTEGER[],
    p_quantities INTEGER[],
    p_payment_method VARCHAR,
    INOUT p_order_id INTEGER DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_customer_status VARCHAR;
    v_shipping_county VARCHAR;
    v_idx INTEGER;
    v_product_id INTEGER;
    v_qty INTEGER;
    v_unit_price NUMERIC;
    v_avail_stock INTEGER;
    v_items_total NUMERIC := 0;
    v_delivery_fee NUMERIC := 0;
    v_total_amount NUMERIC := 0;
    v_tx_ref VARCHAR;
BEGIN
    
    SELECT customer_status, county
    INTO v_customer_status, v_shipping_county
    FROM sokomart.customers
    WHERE customer_id = p_customer_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Customer with ID % does not exist.', p_customer_id;
    END IF;

    IF v_customer_status <> 'active' THEN
        RAISE EXCEPTION 'Customer % is not active (current status: %).', p_customer_id, v_customer_status;
    END IF;

    
    IF p_product_ids IS NULL OR p_quantities IS NULL
       OR COALESCE(array_length(p_product_ids, 1), 0) = 0
       OR array_length(p_product_ids, 1) IS DISTINCT FROM array_length(p_quantities, 1) THEN
        RAISE EXCEPTION 'Product IDs and quantities arrays must be non-empty and have identical lengths.';
    END IF;

    
    INSERT INTO sokomart.orders (
        customer_id,
        order_date,
        order_status,
        shipping_county,
        delivery_fee,
        total_amount
    )
    VALUES (
        p_customer_id,
        CURRENT_TIMESTAMP,
        'pending',
        v_shipping_county,
        0,
        0
    )
    RETURNING order_id INTO p_order_id;

    
    FOR v_idx IN 1 .. array_length(p_product_ids, 1) LOOP
        v_product_id := p_product_ids[v_idx];
        v_qty := p_quantities[v_idx];

        IF v_qty IS NULL OR v_qty <= 0 THEN
            RAISE EXCEPTION 'Quantity for product % must be greater than 0 (got %).', v_product_id, v_qty;
        END IF;

        
        UPDATE sokomart.products
        SET stock_quantity = stock_quantity - v_qty
        WHERE product_id = v_product_id
          AND stock_quantity >= v_qty
          AND product_status = 'active'
        RETURNING unit_price INTO v_unit_price;

        
        IF NOT FOUND THEN
            SELECT stock_quantity
            INTO v_avail_stock
            FROM sokomart.products
            WHERE product_id = v_product_id;

            IF NOT FOUND THEN
                RAISE EXCEPTION 'Product with ID % does not exist.', v_product_id;
            ELSE
                RAISE EXCEPTION 'Insufficient stock or inactive status for product %: requested %, available %.',
                    v_product_id, v_qty, COALESCE(v_avail_stock, 0);
            END IF;
        END IF;

        
        INSERT INTO sokomart.order_items (
            order_id,
            product_id,
            quantity,
            unit_price,
            discount,
            line_total
        )
        VALUES (
            p_order_id,
            v_product_id,
            v_qty,
            v_unit_price,
            0,
            v_qty * v_unit_price
        );

        v_items_total := v_items_total + (v_qty * v_unit_price);
    END LOOP;

    
    IF v_items_total >= 5000 THEN
        v_delivery_fee := 0;
    ELSIF v_shipping_county = 'Nairobi' THEN
        v_delivery_fee := 200;
    ELSIF v_shipping_county IN ('Kiambu', 'Kajiado', 'Machakos') THEN
        v_delivery_fee := 250;
    ELSE
        v_delivery_fee := 350;
    END IF;

    v_total_amount := v_items_total + v_delivery_fee;

    
    UPDATE sokomart.orders
    SET delivery_fee = v_delivery_fee,
        total_amount = v_total_amount
    WHERE order_id = p_order_id;

    
    IF LOWER(TRIM(p_payment_method)) IN ('cash on delivery', 'cod') THEN
        v_tx_ref := NULL;
    ELSE
        v_tx_ref := 'TXN-' || p_order_id || '-' || EXTRACT(EPOCH FROM CLOCK_TIMESTAMP())::BIGINT;
    END IF;

    INSERT INTO sokomart.payments (
        order_id,
        payment_date,
        payment_method,
        amount,
        payment_status,
        transaction_reference
    )
    VALUES (
        p_order_id,
        CURRENT_TIMESTAMP,
        p_payment_method,
        v_total_amount,
        'pending',
        v_tx_ref
    );
END;
$$;




-- Show products 6, 73, 82 (price & stock) BEFORE placing order
SELECT product_id, product_name, unit_price, stock_quantity
FROM sokomart.products
WHERE product_id IN (6, 73, 82)
ORDER BY product_id;

-- Place order for customer 177
CALL sokomart.sp_place_order(177, ARRAY[6, 73, 82], ARRAY[1, 2, 3], 'M-Pesa', NULL);

-- Show the newly created order (with items_total), its lines, payment, new stock, and Q19 trigger history
SELECT 
    o.order_id,
    o.customer_id,
    o.order_status,
    o.shipping_county,
    o.delivery_fee,
    o.total_amount,
    SUM(oi.line_total) AS items_total
FROM sokomart.orders o
JOIN sokomart.order_items oi ON o.order_id = oi.order_id
WHERE o.order_id = (SELECT MAX(order_id) FROM sokomart.orders WHERE customer_id = 177)
GROUP BY o.order_id, o.customer_id, o.order_status, o.shipping_county, o.delivery_fee, o.total_amount;

SELECT 
    order_id,
    product_id,
    quantity,
    unit_price,
    line_total
FROM sokomart.order_items
WHERE order_id = (SELECT MAX(order_id) FROM sokomart.orders WHERE customer_id = 177)
ORDER BY product_id;

SELECT 
    order_id,
    payment_method,
    amount,
    payment_status,
    (transaction_reference IS NOT NULL) AS has_reference
FROM sokomart.payments
WHERE order_id = (SELECT MAX(order_id) FROM sokomart.orders WHERE customer_id = 177);

SELECT product_id, product_name, unit_price, stock_quantity
FROM sokomart.products
WHERE product_id IN (6, 73, 82)
ORDER BY product_id;

SELECT order_id, old_status, new_status
FROM sokomart.order_status_history
WHERE order_id = (SELECT MAX(order_id) FROM sokomart.orders WHERE customer_id = 177);


-- Show order count and stock for products 6 and 59 BEFORE
SELECT COUNT(*) AS total_orders FROM sokomart.orders;

SELECT product_id, product_name, stock_quantity
FROM sokomart.products
WHERE product_id IN (6, 59)
ORDER BY product_id;

CALL sokomart.sp_place_order(408, ARRAY[6, 59], ARRAY[1, 2], 'card', NULL);


SELECT COUNT(*) AS total_orders FROM sokomart.orders;

SELECT product_id, product_name, stock_quantity
FROM sokomart.products
WHERE product_id IN (6, 59)
ORDER BY product_id;



CALL sokomart.sp_update_order_status(
    (SELECT MAX(order_id) FROM sokomart.orders WHERE customer_id = 177),
    'completed'
);

REFRESH MATERIALIZED VIEW CONCURRENTLY sokomart.mv_monthly_category_sales;

SELECT 
    sales_month,
    category,
    orders,
    units_sold,
    revenue,
    gross_profit
FROM sokomart.mv_monthly_category_sales
WHERE sales_month = '2026-11'
ORDER BY revenue DESC;






























