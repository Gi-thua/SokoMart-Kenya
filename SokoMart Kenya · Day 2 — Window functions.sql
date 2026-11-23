-- SokoMart Kenya · Day 2 — Window functions

--Section B — Window functions

/* Question 6 — County leaderboards (Medium)
Scenario. Each county manager wants their top 3 customers by lifetime revenue.
Task. Compute every customer's lifetime revenue (completed orders), rank customers within
their county with DENSE_RANK(), and keep ranks 1–3. Order by county, rank, customer_id.
Required concept. DENSE_RANK() OVER (PARTITION BY … ORDER BY …) over a CTE.
Expected output. county, county_rank, customer_id, full_name, total_spent*/

with customer_lifetime_revenue as (
    select 
        c.customer_id,
        c.first_name || ' ' || c.last_name as full_name,
        c.county,
        SUM(oi.line_total) as total_spent
    from sokomart.customers c
    join sokomart.orders o on c.customer_id = o.customer_id
    join sokomart.order_items oi on o.order_id = oi.order_id
    where o.order_status = 'completed'
    group by c.customer_id, c.first_name, c.last_name, c.county
),
ranked_customers as (
    select 
        county,
        DENSE_RANK() over (
            partition by county 
            order by total_spent desc
        ) as county_rank,
        customer_id,
        full_name,
        total_spent
    from customer_lifetime_revenue
)
select 
    county,
    county_rank,
    customer_id,
    full_name,
    total_spent
from ranked_customers
where county_rank <= 3
order by county asc, county_rank asc, customer_id asc;


--Question 7 — Best sellers per category, 2025 (Medium)
/* Scenario. Category buyers are planning 2026 stock and want 2025's top 3 products in each category.
Task. 2025 revenue and units sold per product (completed orders in 2025), numbered within
category by revenue with ROW_NUMBER() (tie-break on product_id). Keep 1–3.
Required concept. ROW_NUMBER() top-N per group.
Expected output. category, rank_in_category, product_id, product_name, revenue, units_sold (15 rows)*/


with product_2025_sales as (
    select  
        p.category,
        p.product_id,
        p.product_name,
        SUM(oi.line_total) as revenue,
        SUM(oi.quantity) as units_sold
    from products p
    join order_items oi on p.product_id = oi.product_id
    join orders o on oi.order_id = o.order_id
    where o.order_status = 'completed'
      and o.order_date >= '2025-01-01'
      and o.order_date < '2026-01-01'
    group by p.category, p.product_id, p.product_name
),
ranked_products as (
    select 
        category,
        ROW_NUMBER() over (
            partition by category 
            order by revenue desc, product_id asc
        ) as rank_in_category,
        product_id,
        product_name,
        revenue,
        units_sold
    from product_2025_sales
)
select 
    category,
    rank_in_category,
    product_id,
    product_name,
    revenue,
    units_sold
from ranked_products
where rank_in_category <= 3
order by category asc, rank_in_category asc;


--Question 8 — Month-over-month growth (Medium)
/*Scenario. The CEO's dashboard shows revenue growth versus the previous month.
Task. Monthly revenue for every month in the data (January 2025 – October 2026), the
previous month's revenue with LAG(), and growth %. The first month has no previous month (NULL).
Required concept. LAG(), NULLIF to avoid division by zero.
Expected output. month, revenue, prev_month_revenue, growth_pct (22 rows)*/

with monthly_revenue as (
    select 
        DATE_TRUNC('month', o.order_date) as month_date,
        SUM(oi.line_total) as revenue
    from orders o
    join order_items oi on o.order_id = oi.order_id
    where o.order_status = 'completed'
      and o.order_date >= '2025-01-01'
      and o.order_date < '2026-11-01'
    group by DATE_TRUNC('month', o.order_date)
),
lagged_revenue as (
    select 
        month_date,
        revenue,
        LAG(revenue) over (order by month_date asc) as prev_month_revenue
    from monthly_revenue
)
select 
    TO_CHAR(month_date, 'YYYY-MM') as month,
    revenue,
    prev_month_revenue,
    ROUND(
        100.0 * (revenue - prev_month_revenue) / NULLIF(prev_month_revenue, 0), 
        2
    ) as growth_pct
from lagged_revenue
order by month_date asc;


--Question 9 — Is each order bigger than the last? (Hard)

/* Scenario. Customer success in Nyeri wants to see whether customers are spending more or
less per order through 2026.
Task. For customers living in Nyeri, list every completed order placed in 2026, with
the customer's previous 2026 completed order amount (total_amount), the change, and a
direction label first order / up / down / same. Order by customer, then order date. Then a
summary query: total rows, distinct customers, first orders, orders bigger than the previous,
orders smaller than the previous.
Required concept. LAG() OVER (PARTITION BY customer_id ORDER BY order_date).
Expected output. customer_id, order_id, order_date, total_amount, previous_order_amount, change_amount, direction*/

with nyeri_orders_2026 as (
    select 
        o.customer_id,
        o.order_id,
        o.order_date,
        o.total_amount,
        LAG(o.total_amount) over (
            partition by o.customer_id 
            order by o.order_date asc, o.order_id asc
        ) as previous_order_amount
    from sokomart.orders o
    join sokomart.customers c on o.customer_id = c.customer_id
    where c.county = 'Nyeri'
      and o.order_status = 'completed'
      and o.order_date >= '2026-01-01'
      and o.order_date < '2027-01-01'
)
select 
    customer_id,
    order_id,
    order_date,
    total_amount,
    previous_order_amount,
    total_amount - previous_order_amount as change_amount,
    case 
        when previous_order_amount IS NULL THEN 'first order'
        when total_amount > previous_order_amount then 'up'
        when total_amount < previous_order_amount then 'down'
        else 'same'
    end as direction
from nyeri_orders_2026
order by  customer_id asc, order_date asc, order_id asc;



with nyeri_orders_2026 as (
    select 
        o.customer_id,
        o.order_id,
        o.order_date,
        o.total_amount,
        LAG(o.total_amount) over (
            partition by o.customer_id 
            order by o.order_date asc, o.order_id asc
        ) as previous_order_amount
    from sokomart.orders o
    join sokomart.customers c on o.customer_id = c.customer_id
    where c.county = 'Nyeri'
      and o.order_status = 'completed'
      and o.order_date >= '2026-01-01'
      and o.order_date < '2027-01-01'
)
select 
    COUNT(*) as total_rows,
    COUNT(distinct customer_id) as distinct_customers,
    COUNT(*) FILTER (WHERE previous_order_amount IS NULL) as first_orders,
    COUNT(*) FILTER (WHERE total_amount > previous_order_amount) as orders_bigger_than_previous,
    COUNT(*) FILTER (WHERE total_amount < previous_order_amount) as orders_smaller_than_previous
from nyeri_orders_2026;


--Question 10 — Year-to-date revenue (Medium)
/*Scenario. Finance reports cumulative revenue that restarts every January.
Task. Monthly revenue with a running total that resets each calendar year, and a second running
total that never resets. Use an explicit frame (ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW).
Required concept. SUM() OVER (PARTITION BY year ORDER BY month ROWS …).
Expected output. year, month, monthly_revenue, running_revenue_ytd, running_revenue_all_time (22 rows)*/

with monthly_revenue_cte as (
    select 
        extract (year from o.order_date)::INTEGER as year,
        DATE_TRUNC('month', o.order_date) as month_date,
        SUM(oi.line_total) as monthly_revenue
    from sokomart.orders o
    join sokomart.order_items oi on o.order_id = oi.order_id
    where o.order_status = 'completed'
      and o.order_date >= '2025-01-01'
      and o.order_date < '2026-11-01'
    group by extract (year from o.order_date)::INTEGER, DATE_TRUNC('month', o.order_date)
)
select 
    year,
    TO_CHAR(month_date, 'YYYY-MM') as month,
    monthly_revenue,
    SUM(monthly_revenue) over (
        partition by year 
        order by month_date asc 
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) as running_revenue_ytd,
    SUM(monthly_revenue) over (
        order by month_date asc 
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) as running_revenue_all_time
from monthly_revenue_cte
order by month_date asc;





























