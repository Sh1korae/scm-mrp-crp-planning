/* Проверка количества строк */

select 'customers' as table_name, count(*) as rows_count
from scm.customers

union all

select 'products' as table_name, count(*) as rows_count
from scm.products

union all

select 'resources' as table_name, count(*) as rows_count
from scm.resources

union all

select 'sales_orders' as table_name, count(*) as rows_count
from scm.sales_orders

union all

select 'product_links' as table_name, count(*) as rows_count
from scm.product_links

union all

select 'standard_operations' as table_name, count(*) as rows_count
from scm.standard_operations

union all

select 'production_calendar' as table_name, count(*) as rows_count
from scm.production_calendar;


/* Отчет 1. Полный портфель заказов */

select so.sales_order_id as "Заказ",
c.customer_name as "Заказчик",
p.product_short_name as "Продукция",
so.unit_weight_ton as "Вес ед., т",
so.ordered_weight_ton as "Объем заказа, т",
so.tolerance_ton as "Допуск, т",
so.calculated_units as "Кол-во ед.",
so.calculated_weight_ton as "Факт. вес, т",
so.ordered_weight_ton - so.calculated_weight_ton as "Отклонение, т",
so.due_date as "Дата сдачи",
so.priority as "Приоритет",
so.order_status as "Статус"
from scm.sales_orders so
join scm.customers c on c.customer_id = so.customer_id
join scm.products p on p.product_id = so.product_id
order by so.sales_order_id;


/* Отчет 2. Заказы по датам сдачи */

select so.due_date as "Дата сдачи",
count(so.sales_order_id) as "Количество заказов",
sum(so.ordered_weight_ton) as "Объем заказов, т",
sum(so.calculated_weight_ton) as "Фактический вес, т",
min(so.priority) as "Минимальный приоритет",
max(so.priority) as "Максимальный приоритет"
from scm.sales_orders so
group by so.due_date
order by so.due_date;


/* Отчет 3. Заказы по видам продукции */

select p.product_short_name as "Продукция",
p.product_name as "Полное название",
count(so.sales_order_id) as "Количество заказов",
sum(so.ordered_weight_ton) as "Объем заказов, т",
sum(so.calculated_weight_ton) as "Фактический вес, т",
sum(so.calculated_units) as "Количество единиц",
round(sum(so.ordered_weight_ton) / sum(sum(so.ordered_weight_ton)) over () * 100, 2) as "Доля в портфеле, %"
from scm.sales_orders so
join scm.products p on p.product_id = so.product_id
group by p.product_short_name, p.product_name
order by sum(so.ordered_weight_ton) desc;


/* Отчет 4. Заказы по заказчикам */

select c.customer_name as "Заказчик",
c.customer_group as "Группа заказчика",
count(so.sales_order_id) as "Количество заказов",
sum(so.ordered_weight_ton) as "Объем заказов, т",
sum(so.calculated_weight_ton) as "Фактический вес, т",
min(so.due_date) as "Ближайшая дата сдачи",
min(so.priority) as "Приоритет"
from scm.sales_orders so
join scm.customers c on c.customer_id = so.customer_id
group by c.customer_name, c.customer_group
order by sum(so.ordered_weight_ton) desc;


/* Отчет 5. Заказы по приоритетам */

select so.priority as "Приоритет",
count(so.sales_order_id) as "Количество заказов",
sum(so.ordered_weight_ton) as "Объем заказов, т",
sum(so.calculated_weight_ton) as "Фактический вес, т",
min(so.due_date) as "Самая ранняя дата сдачи",
max(so.due_date) as "Самая поздняя дата сдачи"
from scm.sales_orders so
group by so.priority
order by so.priority;


/* Отчет 6. Порядок расчета заказов */

select row_number() over (order by so.priority, so.due_date, so.sales_order_id) as "Порядок расчета",
so.sales_order_id as "Заказ",
c.customer_name as "Заказчик",
p.product_short_name as "Продукция",
so.ordered_weight_ton as "Объем, т",
so.calculated_weight_ton as "Факт. вес, т",
so.due_date as "Дата сдачи",
so.priority as "Приоритет"
from scm.sales_orders so
join scm.customers c on c.customer_id = so.customer_id
join scm.products p on p.product_id = so.product_id
order by so.priority, so.due_date, so.sales_order_id;


/* Отчет 7. Проверка допуска по заказам */

select so.sales_order_id as "Заказ",
c.customer_name as "Заказчик",
p.product_short_name as "Продукция",
so.ordered_weight_ton as "Заказано, т",
so.unit_weight_ton as "Вес ед., т",
so.calculated_units as "Кол-во ед.",
so.calculated_weight_ton as "Факт. вес, т",
so.ordered_weight_ton - so.calculated_weight_ton as "Отклонение, т",
so.tolerance_ton as "Допуск, т",
case
when abs(so.ordered_weight_ton - so.calculated_weight_ton) <= so.tolerance_ton then 'OK'
else 'ERROR'
end as "Проверка допуска"
from scm.sales_orders so
join scm.customers c on c.customer_id = so.customer_id
join scm.products p on p.product_id = so.product_id
order by so.sales_order_id;


/* Отчет 8. Итоговая проверка портфеля */

select count(*) as "Количество заказов",
count(distinct customer_id) as "Количество заказчиков",
count(distinct product_id) as "Количество видов продукции",
sum(ordered_weight_ton) as "Общий объем заказов, т",
sum(calculated_weight_ton) as "Общий фактический вес, т",
sum(ordered_weight_ton - calculated_weight_ton) as "Общее отклонение, т",
min(due_date) as "Самая ранняя дата сдачи",
max(due_date) as "Самая поздняя дата сдачи"
from scm.sales_orders;


/* VIEW для отчетов */

create or replace view scm.v_report_orders_detail as
select so.sales_order_id,
c.customer_name,
c.customer_group,
p.product_id,
p.product_short_name,
p.product_name,
so.unit_weight_ton,
so.ordered_weight_ton,
so.tolerance_ton,
so.calculated_units,
so.calculated_weight_ton,
so.ordered_weight_ton - so.calculated_weight_ton as difference_ton,
so.due_date,
so.priority,
so.order_status
from scm.sales_orders so
join scm.customers c on c.customer_id = so.customer_id
join scm.products p on p.product_id = so.product_id;


create or replace view scm.v_report_orders_by_due_date as
select so.due_date,
count(so.sales_order_id) as orders_count,
sum(so.ordered_weight_ton) as total_ordered_weight_ton,
sum(so.calculated_weight_ton) as total_calculated_weight_ton,
sum(so.ordered_weight_ton - so.calculated_weight_ton) as total_difference_ton,
min(so.priority) as min_priority,
max(so.priority) as max_priority
from scm.sales_orders so
group by so.due_date;


create or replace view scm.v_report_orders_by_product as
select p.product_id,
p.product_short_name,
p.product_name,
p.product_group,
count(so.sales_order_id) as orders_count,
sum(so.ordered_weight_ton) as total_ordered_weight_ton,
sum(so.calculated_weight_ton) as total_calculated_weight_ton,
sum(so.calculated_units) as total_units,
round(sum(so.ordered_weight_ton) / sum(sum(so.ordered_weight_ton)) over () * 100, 2) as portfolio_share_percent
from scm.sales_orders so
join scm.products p on p.product_id = so.product_id
group by p.product_id, p.product_short_name, p.product_name, p.product_group;


create or replace view scm.v_report_orders_by_customer as
select c.customer_id,
c.customer_name,
c.customer_group,
count(so.sales_order_id) as orders_count,
sum(so.ordered_weight_ton) as total_ordered_weight_ton,
sum(so.calculated_weight_ton) as total_calculated_weight_ton,
min(so.due_date) as earliest_due_date,
max(so.due_date) as latest_due_date,
min(so.priority) as best_priority
from scm.sales_orders so
join scm.customers c on c.customer_id = so.customer_id
group by c.customer_id, c.customer_name, c.customer_group;


create or replace view scm.v_report_orders_by_priority as
select so.priority,
count(so.sales_order_id) as orders_count,
sum(so.ordered_weight_ton) as total_ordered_weight_ton,
sum(so.calculated_weight_ton) as total_calculated_weight_ton,
min(so.due_date) as earliest_due_date,
max(so.due_date) as latest_due_date
from scm.sales_orders so
group by so.priority;


create or replace view scm.v_report_mrp_order_sequence as
select row_number() over (order by so.priority, so.due_date, so.sales_order_id) as calculation_order,
so.sales_order_id,
c.customer_name,
p.product_short_name,
so.ordered_weight_ton,
so.calculated_weight_ton,
so.due_date,
so.priority
from scm.sales_orders so
join scm.customers c on c.customer_id = so.customer_id
join scm.products p on p.product_id = so.product_id;


set search_path to scm;

select case r.resource_id
when 'R_HOT_ROLLING' then 'HRM'
when 'R_PICKLING' then 'PCL'
when 'R_COLD_ROLLING' then 'CRM'
when 'R_GALVANIZING' then 'ZINC'
when 'R_CUTTING' then 'CUT'
when 'R_PACKING' then 'PACK'
else r.resource_id
end as "Агрегат",
r.resource_name as "Название агрегата",
pc.work_date as "Дата",
round(pc.used_hours, 6) as "Загрузка, ч",
pc.available_hours as "Доступно, ч",
round(pc.available_hours - pc.used_hours, 6) as "Остаток, ч",
case
when pc.used_hours > pc.available_hours then 'OVERLOAD'
when pc.used_hours = pc.available_hours then 'FULL'
when pc.used_hours > 0 then 'LOAD'
else 'EMPTY'
end as "Статус"
from scm.production_calendar pc
join scm.resources r on r.resource_id = pc.resource_id
where pc.work_date between date '2025-04-01' and date '2025-04-30'
order by case r.resource_id
when 'R_HOT_ROLLING' then 1
when 'R_PICKLING' then 2
when 'R_COLD_ROLLING' then 3
when 'R_GALVANIZING' then 4
when 'R_CUTTING' then 5
when 'R_PACKING' then 6
else 99
end,
pc.work_date;

select cl.sales_order_id as "Заказ",
cl.work_date as "Дата",
cl.resource_id as "resource_id",
r.resource_name as "Агрегат",
round(sum(cl.load_hours), 3) as "Загрузка на агрегате, ч",
round(
sum(sum(cl.load_hours)) over (
partition by cl.sales_order_id, cl.work_date
),
3
) as "Загрузка заказа за день, ч",
24 as "Лимит, ч",
round(
24 - sum(sum(cl.load_hours)) over (
partition by cl.sales_order_id, cl.work_date
),
3
) as "Остаток до лимита, ч",
case
when sum(sum(cl.load_hours)) over (
partition by cl.sales_order_id, cl.work_date
) <= 24 then 'OK'
else 'ERROR'
end as "Проверка"
from scm.crp_load cl
join scm.resources r on r.resource_id = cl.resource_id
group by cl.sales_order_id, cl.work_date, cl.resource_id, r.resource_name
order by cl.work_date, cl.sales_order_id, cl.resource_id;