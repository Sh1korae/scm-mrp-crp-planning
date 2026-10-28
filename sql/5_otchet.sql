/* Этап 7. Представления для итогового MRP-плана */

set search_path to scm;


/* 1. Детальный MRP-план */

create or replace view scm.v_mrp_plan_detail as
select m.mrp_plan_id,
m.sales_order_id,
c.customer_name,
so.priority,
so.due_date,
so.release_date,
order_product.product_short_name as order_product,
p.product_id,
p.product_short_name as material_name,
p.product_group,
m.material_need_type,
m.plan_level,
m.operation_seq,
m.operation_name,
r.resource_name,
m.qty_units,
m.weight_ton,
m.required_date,
m.ready_date,
m.operation_hours,
m.plan_status,
m.calculation_note
from scm.mrp_plan m
join scm.sales_orders so on so.sales_order_id = m.sales_order_id
join scm.customers c on c.customer_id = so.customer_id
join scm.products order_product on order_product.product_id = so.product_id
join scm.products p on p.product_id = m.product_id
left join scm.resources r on r.resource_id = m.resource_id;


/* 2. MRP-план по материалам и датам */

create or replace view scm.v_mrp_plan_by_material_date as
select p.product_id,
p.product_short_name as material_name,
p.product_group,
m.ready_date,
count(distinct m.sales_order_id) as orders_count,
sum(m.qty_units) as total_units,
round(sum(m.weight_ton), 3) as total_weight_ton
from scm.mrp_plan m
join scm.products p on p.product_id = m.product_id
group by p.product_id, p.product_short_name, p.product_group, m.ready_date;


/* 3. Сводная потребность по материалам */

create or replace view scm.v_mrp_plan_by_material_total as
select p.product_id,
p.product_short_name as material_name,
p.product_group,
count(distinct m.sales_order_id) as orders_count,
sum(m.qty_units) as total_units,
round(sum(m.weight_ton), 3) as total_weight_ton,
min(m.ready_date) as first_ready_date,
max(m.ready_date) as last_ready_date
from scm.mrp_plan m
join scm.products p on p.product_id = m.product_id
group by p.product_id, p.product_short_name, p.product_group;


/* 4. Сводный MRP-план по заказам */

create or replace view scm.v_mrp_plan_by_order as
select so.sales_order_id,
c.customer_name,
p.product_short_name as order_product,
so.calculated_weight_ton,
count(m.mrp_plan_id) as mrp_rows_count,
round(sum(m.weight_ton), 3) as total_route_weight_ton,
min(m.ready_date) as mrp_start_date,
so.release_date,
so.due_date,
so.priority,
so.order_status
from scm.sales_orders so
join scm.customers c on c.customer_id = so.customer_id
join scm.products p on p.product_id = so.product_id
join scm.mrp_plan m on m.sales_order_id = so.sales_order_id
group by so.sales_order_id,
c.customer_name,
p.product_short_name,
so.calculated_weight_ton,
so.release_date,
so.due_date,
so.priority,
so.order_status;


/* 5. Потребность в сырье */

create or replace view scm.v_mrp_raw_material_need as
select m.sales_order_id,
c.customer_name,
p.product_short_name as order_product,
so.calculated_weight_ton,
m.qty_units as raw_units,
m.weight_ton as slab_weight_ton,
m.ready_date as raw_need_date
from scm.mrp_plan m
join scm.sales_orders so on so.sales_order_id = m.sales_order_id
join scm.customers c on c.customer_id = so.customer_id
join scm.products p on p.product_id = so.product_id
where m.product_id = 'SLAB';


select *
from scm.v_mrp_plan_detail
order by sales_order_id, operation_seq nulls first, plan_level;

select *
from scm.v_mrp_plan_by_material_date
order by ready_date, material_name;

select *
from scm.v_mrp_plan_by_material_total
order by total_weight_ton desc;

select *
from scm.v_mrp_plan_by_order
order by priority, due_date;

select *
from scm.v_mrp_raw_material_need
order by raw_need_date, sales_order_id;


/* MRP-план в формате календаря */ 

select material_name as "Материал",
ready_date as "Дата",
orders_count as "Кол-во заказов",
total_units as "Кол-во ед.",
total_weight_ton as "Потребность, т"
from scm.v_mrp_plan_by_material_date
order by ready_date, material_name;

SELECT
    so.sales_order_id,
    COUNT(m.mrp_plan_id) AS finished_good_rows
FROM scm.sales_orders so
LEFT JOIN scm.mrp_plan m
    ON m.sales_order_id = so.sales_order_id
   AND m.material_need_type = 'FINISHED_GOOD'
GROUP BY
    so.sales_order_id
HAVING COUNT(m.mrp_plan_id) = 0;