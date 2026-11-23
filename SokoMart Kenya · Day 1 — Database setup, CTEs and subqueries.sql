--SokoMart Kenya · Day 1 — Database setup, CTEs and subqueries

-- Practice drills

--D1. List the products whose unit_price is above the average unit_price of all products. 
--Show the 10 most expensive, then on a second query the count.
select * from products p;

select p.product_id, p.product_name, p.category, p.unit_price
from products p 
where p.unit_price > (select AVG(p.unit_price )
from products p)
order by p.unit_price desc
limit 10;

select(select count(*) 
from products p 
where p.unit_price > (select AVG(p.unit_price )
from products p)) as above_average;

with products as
(select * from sokomart.products
where unit_price > (select avg(unit_price) from sokomart.products)
order by unit_price desc)
select count(*) from products;


--D2.	List customers living in Mombasa who placed at least one order (any status) in December 2025.
select * from customers c;

select customer_id, concat(first_name, ' ', last_name) as customer_name, email 
from customers c 
where county = 'Mombasa'
and customer_id in (select customer_id from orders 
where order_date between '2025-12-01' and '2025-12-31');

--D3. How many customers living in Kisumu have at least one payment with payment_status = 'failed'?
select * from customers c;
select * from payments p;
select * from orders o ;

select count(distinct c.customer_id ) as kisumu_customers
from customers c 
join orders o on o.customer_id  = c.customer_id
join payments p on p.order_id = o.order_id 
where c.county = 'Kisumu' and p.payment_status = 'failed';

select count(*)
from customers c
where exists (
    select 1 
    from orders o 
    join payments p on o.order_id = p.order_id
    where o.customer_id = c.customer_id
    and county = 'Kisumu'
    and payment_status = 'failed'
);

--D4. For each order_status, show the number of orders, the average number of lines per order 
--and the average number of units per order. Compute the per-order figures in a subquery in FROM.

select * from orders o;
select * from payments p;
select * from order_items oi;

select order_status, count(order_id) as order_number
from (select distinct o.order_status, oi.quantity, o.order_id
from order_items oi
join orders o on oi.order_id = o.order_id)
group by order_status;


--D5. Top 5 shipping counties by number of completed orders in 2026. Put the filtered orders in a CTE.	Single CTE

select * from orders o;

with total_orders as (
select order_id, shipping_county
from orders o 
where order_status = 'completed'
and order_date between '2026-01-01' and '2026-12-31')
select shipping_county, count(order_id) as completed_orders
from total_orders
group by shipping_county 
order by completed_orders desc 
limit 5;


--D6. For 2025: completed orders per month, the 2025 monthly average, 
--and whether each month is above average or at/below average. Use two CTEs (monthly counts, then the stats).
select * from orders o;

with monthly_counts as (
select 
extract(month from order_date) as order_month,
count(order_id) as completed_orders
from orders
where order_date >= '2025-01-01' 
and order_date < '2026-01-01'
and order_status = 'completed'
group by extract(month from order_date)
),
monthly_stats as (
select order_month, completed_orders,
avg(completed_orders) over() as monthly_avg
from monthly_counts
)
select 
order_month, completed_orders,
ROUND(monthly_avg, 2) as avg_monthly_2025,
    case 
        when completed_orders > monthly_avg then 'Above Average'
        else 'At or Below Average'
    end as performance_status
from monthly_stats
order by order_month;


--D7. Write sokomart.fn_order_count(p_customer_id INTEGER) RETURNS INTEGER — the number of orders 
--(any status) a customer has. Call it for customer 177 and for a customer that does not exist (-1).

select * from customers c;
select * from orders o;

create or replace function sokomart.fn_order_count(p_customer_id INTEGER)
returns INTEGER
language plpgsql
as $$
declare
    v_order_count INTEGER;
begin
    select COUNT(*)::INTEGER
    into v_order_count
    from orders
    where customer_id = p_customer_id;

    return COALESCE(v_order_count, 0);
end;
$$;

select sokomart.fn_order_count(177);

select sokomart.fn_order_count(-1);


--Write sokomart.sp_set_customer_status(p_customer_id INTEGER, p_status VARCHAR). It raises an exception 
--for a status other than active / inactive / suspended, and for a customer that does not exist. Inside BEGIN 
--… ROLLBACK, set customer 177 to suspended, show it, roll back, show it is active again. Then show the exception 
--for status 'vip'.	Stored procedure, RAISE EXCEPTION, CALL
select * from orders o;



create or replace procedure sokomart.sp_set_customer_status(
    p_customer_id INTEGER,
    p_status VARCHAR
)
language plpgsql
as $$
begin
    if p_status is null or p_status not in ('active', 'inactive', 'suspended') then
        raise exception 'Invalid status "%". Allowed values are: active, inactive, suspended.', p_status;
    end if;
    
    update customers
    set status = p_status
    where customer_id = p_customer_id;

    if not found then
        raise exception 'Customer with ID % does not exist.', p_customer_id;
    end if;
end;
$$;

begin;
    call sokomart.sp_set_customer_status(177, 'suspended');
    select customer_id, order_status as status_during_tx
    from orders o 
    where customer_id = 177;
rollback;

select customer_id, order_status as status_after_rollback
from orders o 
where customer_id = 177;

call sokomart.sp_set_customer_status(177, 'vip');


rollback;


--D9. Beauty products whose stock_quantity is below the average Beauty stock. Put the Beauty products 
-- in a CTE and compare with a scalar subquery on that CTE.
select * from products p;

with beauty_products as (
select product_id, product_name, category, stock_quantity
from products
where category = 'Beauty'
)
select product_id, product_name, category, stock_quantity
from beauty_products
where stock_quantity < (
select AVG(stock_quantity) 
from beauty_products
)
order by stock_quantity asc;


--D10. Write sokomart.sp_county_summary(IN p_county VARCHAR, OUT p_customers INTEGER, 
-- OUT p_revenue NUMERIC) returning the number of customers living in the county and their 
-- completed revenue. CALL sokomart.sp_county_summary('Nakuru', NULL, NULL);


create or replace procedure sokomart.sp_county_summary(
    in p_county VARCHAR,
    out p_customers INTEGER,
    out p_revenue NUMERIC
)
language plpgsql
as $$
begin
    select COUNT(*)::INTEGER
    into p_customers
    from sokomart.customers
    where county = p_county;
    
    select COALESCE(SUM(o.total_amount), 0)
    into p_revenue
    from orders o
    join customers c on o.customer_id = c.customer_id
    where c.county = p_county
    and order_status = 'completed';
end;
$$;

call sokomart.sp_county_summary('Nakuru', NULL, NULL);



--Section A — CTEs and subqueries

--Question 1 — Big spenders of 2025 (Medium)
/*Scenario. Marketing wants to invite 2025's above-average customers to a loyalty launch.
Task. In a CTE, compute each customer's 2025 revenue (completed orders placed in 2025).
List the customers whose 2025 revenue is above the average 2025 revenue of customers who
bought in 2025. Get the average with a subquery (or a second CTE) over the first CTE — not
a hard-coded number. Order by total_spent_2025 descending. Then, in a second query, give
the number of customers who bought in 2025, the average, and the number of rows your main
query returns.*/
select * from customers c;


with customer_2025_revenue as (
    select 
        c.customer_id,
        concat(c.first_name, ' ', c.last_name ) as customer_name,
        c.county,
        SUM(o.total_amount) as total_spent_2025
    from customers c
    join orders o on c.customer_id = o.customer_id
    where o.order_date >= '2025-01-01'
      and o.order_date < '2026-01-01'
      and o.order_status = 'completed'
    group by c.customer_id, customer_name , c.county
)
select 
    customer_id,
    customer_name ,
    county,
    ROUND(total_spent_2025, 2) as total_spent_2025,
    ROUND((select AVG(total_spent_2025) from customer_2025_revenue), 2) as avg_spent_2025,
    ROUND(total_spent_2025 - (select AVG(total_spent_2025) from customer_2025_revenue), 2) as amount_above_avg
from customer_2025_revenue
where total_spent_2025 > (
    select AVG(total_spent_2025) 
    from customer_2025_revenue
)
order by total_spent_2025 desc;


with customer_2025_revenue as (
    select 
        c.customer_id,
        SUM(o.total_amount) as total_spent_2025
    from customers c
    join orders o on c.customer_id = o.customer_id
    where o.order_date >= '2025-01-01'
      and o.order_date < '2026-01-01'
      and o.order_status = 'completed'
    group by c.customer_id
)
select 
    COUNT(*) as total_2025_customers,
    ROUND(AVG(total_spent_2025), 2) as avg_spent_2025,
    COUNT(*) filter (
        where total_spent_2025 > (select AVG(total_spent_2025) from customer_2025_revenue)
    ) as above_avg_customer_count
from customer_2025_revenue;


--Question 2 — Premium-priced products (Medium)
/* Scenario. The pricing team wants every active product that is priced above the average
price of its own category.
Task. Use a correlated subquery that computes the category average for each product's
category (average over all products in the category, any status). Show the gap. Order by
category, then price_gap descending. Add a second query counting the rows per category.*/
select * from products p;

select p.product_id, p.product_name, p.category,
p.unit_price,
    ROUND((
        select AVG(p2.unit_price)
        from products p2
        where p2.category = p.category
    ), 2) as category_avg_price,
    ROUND(p.unit_price - (
        select AVG(p2.unit_price)
        from products p2
        where p2.category = p.category
    ), 2) as price_gap
from products p
where p.product_status  = 'active'
  and p.unit_price > (
      select AVG(p2.unit_price)
      from products p2
      where p2.category = p.category
  )
order by p.category asc, price_gap desc;



select 
    p.category,
    COUNT(*) as premium_product_count
from products p
where p.product_status  = 'active'
  and p.unit_price > (
      select AVG(p2.unit_price)
      from products p2
      where p2.category = p.category
  )
group by p.category
order by p.category asc;



--Question 3 — 2026 monthly profit and loss (Medium)
/*Scenario. Finance needs a monthly P&L for January–October 2026.
Task. Build it with at least three chained CTEs: (1) the completed order lines with
their month and line cost; (2) monthly revenue and cost; (3) gross profit. Final SELECT adds
the margin. One row per month, in month order.*/

with completed_order_lines as (
    select 
        extract(month from o.order_date)::INTEGER as order_month,
        oi.quantity * oi.unit_price as line_revenue,
        oi.quantity * p.cost_price as line_cost
    from orders o
    join order_items oi on o.order_id = oi.order_id
    join products p on oi.product_id = p.product_id
    where o.order_date >= '2026-01-01'
      and o.order_date < '2026-11-01'
      and o.order_status = 'completed'
),
monthly_revenue_and_cost as (
    select 
        order_month,
        SUM(line_revenue) as total_revenue,
        SUM(line_cost) as total_cost
   from completed_order_lines
    group by order_month
),
monthly_gross_profit as (
    select 
        order_month,
        total_revenue,
        total_cost,
        total_revenue - total_cost as gross_profit
    from monthly_revenue_and_cost
)
select 
    order_month,
    ROUND(total_revenue, 2) as total_revenue,
    ROUND(total_cost, 2) as total_cost,
    ROUND(gross_profit, 2) as gross_profit,
    ROUND((gross_profit / NULLIF(total_revenue, 0)) * 100, 2) as gross_margin_pct
from monthly_gross_profit
order by order_month asc;


--Question 4 — Cross-category shoppers in Nakuru (Medium)
/*Scenario. The Nakuru regional manager wants customers who already shop across several
departments, for a bundle campaign.
Task. In a derived table (a subquery in FROM), compute for every customer the number of
distinct product categories in their completed orders and their total revenue. Join it to
customers and keep customers living in Nakuru with 3 or more categories. Order by
category_count descending, then total_spent descending. Second query: how many Nakuru
customers qualify, and how many of them bought from all five categories.
Required concept. Derived table, COUNT(DISTINCT …).
Expected output. customer_id, full_name, county, category_count, total_spent*/
select * from customers c;


select 
    c.customer_id,
    concat(c.first_name, ' ', c.last_name ) as customer_name,
    c.county,
    cust_stats.category_count,
    ROUND(cust_stats.total_spent, 2) as total_spent
from customers c
join (
    select 
        o.customer_id,
        COUNT(distinct p.category) as category_count,
        SUM(oi.quantity * oi.unit_price) as total_spent
    from orders o
    join order_items oi on o.order_id = oi.order_id
    join products p on oi.product_id = p.product_id
    where o.order_status = 'completed'
    group by o.customer_id
) cust_stats on c.customer_id = cust_stats.customer_id
where c.county = 'Nakuru'
  and cust_stats.category_count >= 3
order by cust_stats.category_count desc, cust_stats.total_spent desc;



select * from orders o;
select 
    COUNT(*) as qualifying_nakuru_customers,
    COUNT(*) filter (where cust_stats.category_count = 5) as all_five_categories_count
from customers c
join (
    select 
        o.customer_id,
        COUNT(distinct p.category) as category_count
    from orders o
    join order_items oi on o.order_id = oi.order_id
    join products p on oi.product_id = p.product_id
    where o.order_status = 'completed'
    group by o.customer_id
) cust_stats on c.customer_id = cust_stats.customer_id
where c.county = 'Nakuru'
  and cust_stats.category_count >= 3;


--Question 5 — Products nobody has ordered (Easy)
/*Scenario. The warehouse is reviewing shelf space: which products have never appeared on
any order (any status)?
Task. Use NOT EXISTS (or LEFT JOIN … IS NULL). NOT IN is not allowed — it returns
nothing at all if the subquery ever yields a NULL. Order by category, then product name.
Required concept. Anti-join with NOT EXISTS.*/

select p.product_id, p.product_name, p.category,
p.unit_price, p.stock_quantity
from products p
where not exists (
    select 1
    from order_items oi
    where oi.product_id = p.product_id
)
order by p.category asc, p.product_name asc;




































































