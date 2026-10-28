/* Финальная проверка готовности проекта к презентации */

set search_path to scm;


/* 1. Проверка количества строк в основных таблицах */

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
from scm.production_calendar

union all

select 'mrp_plan' as table_name, count(*) as rows_count
from scm.mrp_plan

union all

select 'crp_load' as table_name, count(*) as rows_count
from scm.crp_load;


/* 2. Проверка портфеля заказов */

select count(*) as orders_count,
sum(ordered_weight_ton) as total_ordered_weight_ton,
sum(calculated_weight_ton) as total_calculated_weight_ton,
sum(ordered_weight_ton - calculated_weight_ton) as total_difference_ton
from scm.sales_orders;


/* 3. Проверка допуска по заказам */

select sales_order_id as "Заказ",
ordered_weight_ton as "Заказано, т",
unit_weight_ton as "Вес единицы, т",
calculated_units as "Кол-во ед.",
calculated_weight_ton as "Факт. вес, т",
ordered_weight_ton - calculated_weight_ton as "Отклонение, т",
tolerance_ton as "Допуск, т",
case
when abs(ordered_weight_ton - calculated_weight_ton) <= tolerance_ton then 'OK'
else 'ERROR'
end as "Проверка допуска"
from scm.sales_orders
order by sales_order_id;


/* 4. Проверка наличия MRP-плана по каждому заказу */

select so.sales_order_id as "Заказ",
count(m.mrp_plan_id) as "Количество строк MRP",
case
when count(m.mrp_plan_id) > 0 then 'OK'
else 'NO MRP'
end as "Проверка"
from scm.sales_orders so
left join scm.mrp_plan m on m.sales_order_id = so.sales_order_id
group by so.sales_order_id
order by so.sales_order_id;


/* 5. Проверка наличия готовой продукции по каждому заказу */

select so.sales_order_id as "Заказ",
count(m.mrp_plan_id) as "Строк готовой продукции",
case
when count(m.mrp_plan_id) > 0 then 'OK'
else 'NO FINISHED GOOD'
end as "Проверка"
from scm.sales_orders so
left join scm.mrp_plan m on m.sales_order_id = so.sales_order_id
and m.material_need_type = 'FINISHED_GOOD'
group by so.sales_order_id
order by so.sales_order_id;


/* 6. Проверка наличия потребности в слябе по каждому заказу */

select so.sales_order_id as "Заказ",
count(m.mrp_plan_id) as "Строк потребности в слябе",
case
when count(m.mrp_plan_id) > 0 then 'OK'
else 'NO SLAB'
end as "Проверка"
from scm.sales_orders so
left join scm.mrp_plan m on m.sales_order_id = so.sales_order_id
and m.product_id = 'SLAB'
group by so.sales_order_id
order by so.sales_order_id;


/* 7. Проверка отсутствия перегрузки ресурсов */

select pc.work_date as "Дата",
r.resource_name as "Ресурс",
pc.available_hours as "Доступно, ч",
pc.used_hours as "Занято, ч",
pc.available_hours - pc.used_hours as "Остаток, ч"
from scm.production_calendar pc
join scm.resources r on r.resource_id = pc.resource_id
where pc.used_hours > pc.available_hours
order by pc.work_date, r.resource_name;


/* 8. Проверка фактической загрузки ресурсов */

select pc.work_date as "Дата",
r.resource_name as "Ресурс",
pc.available_hours as "Доступно, ч",
pc.used_hours as "Занято, ч",
pc.available_hours - pc.used_hours as "Остаток, ч"
from scm.production_calendar pc
join scm.resources r on r.resource_id = pc.resource_id
where pc.used_hours > 0
order by pc.work_date, r.resource_name;


/* 9. Проверка дат запуска заказов */

select so.sales_order_id as "Заказ",
c.customer_name as "Заказчик",
p.product_short_name as "Продукция",
so.release_date as "Дата запуска",
so.due_date as "Дата сдачи",
so.priority as "Приоритет",
so.order_status as "Статус",
case
when so.release_date is not null and so.order_status = 'PLANNED' then 'OK'
else 'ERROR'
end as "Проверка"
from scm.sales_orders so
join scm.customers c on c.customer_id = so.customer_id
join scm.products p on p.product_id = so.product_id
order by so.priority, so.due_date, so.sales_order_id;


/* 10. Итоговая проверка ошибок */

select 'orders_without_mrp' as check_name, count(*) as error_count
from (
select so.sales_order_id
from scm.sales_orders so
left join scm.mrp_plan m on m.sales_order_id = so.sales_order_id
group by so.sales_order_id
having count(m.mrp_plan_id) = 0
) t

union all

select 'orders_without_finished_good' as check_name, count(*) as error_count
from (
select so.sales_order_id
from scm.sales_orders so
left join scm.mrp_plan m on m.sales_order_id = so.sales_order_id
and m.material_need_type = 'FINISHED_GOOD'
group by so.sales_order_id
having count(m.mrp_plan_id) = 0
) t

union all

select 'orders_without_slab' as check_name, count(*) as error_count
from (
select so.sales_order_id
from scm.sales_orders so
left join scm.mrp_plan m on m.sales_order_id = so.sales_order_id
and m.product_id = 'SLAB'
group by so.sales_order_id
having count(m.mrp_plan_id) = 0
) t

union all

select 'mrp_rows_without_ready_date' as check_name, count(*) as error_count
from scm.mrp_plan
where ready_date is null

union all

select 'mrp_rows_with_wrong_weight' as check_name, count(*) as error_count
from scm.mrp_plan
where weight_ton <= 0

union all

select 'resource_overloads' as check_name, count(*) as error_count
from scm.production_calendar
where used_hours > available_hours

union all

select 'orders_without_release_date' as check_name, count(*) as error_count
from scm.sales_orders
where release_date is null;


select m.sales_order_id as "Заказ",
c.customer_name as "Заказчик",
order_product.product_short_name as "Готовая продукция",
p.product_short_name as "Материал",
m.material_need_type as "Тип потребности",
m.operation_seq as "Операция №",
m.operation_name as "Операция",
r.resource_name as "Ресурс",
m.qty_units as "Кол-во ед.",
m.weight_ton as "Вес, т",
m.ready_date as "Дата готовности",
m.operation_hours as "Фонд времени, ч",
m.plan_status as "Статус"
from scm.mrp_plan m
join scm.sales_orders so on so.sales_order_id = m.sales_order_id
join scm.customers c on c.customer_id = so.customer_id
join scm.products order_product on order_product.product_id = so.product_id
join scm.products p on p.product_id = m.product_id
left join scm.resources r on r.resource_id = m.resource_id
order by m.sales_order_id, m.operation_seq nulls first, m.plan_level;

select r.resource_name as "Агрегат",
cl.operation_name as "Операция",
count(distinct cl.sales_order_id) as "Количество заказов",
round(sum(cl.load_weight_ton), 3) as "Произведено / обработано, т",
round(sum(cl.load_hours), 3) as "Загрузка, ч"
from scm.crp_load cl
join scm.resources r on r.resource_id = cl.resource_id
group by r.resource_name, cl.operation_name
order by r.resource_name, cl.operation_name;

select cl.sales_order_id as "Заказ",
c.customer_name as "Заказчик",
p.product_short_name as "Готовая продукция",
r.resource_name as "Агрегат",
cl.operation_name as "Операция",
cl.work_date as "Дата работы",
round(cl.load_weight_ton, 3) as "Обработано, т",
round(cl.load_hours, 3) as "Загрузка, ч",
cl.load_status as "Статус загрузки"
from scm.crp_load cl
join scm.sales_orders so on so.sales_order_id = cl.sales_order_id
join scm.customers c on c.customer_id = so.customer_id
join scm.products p on p.product_id = so.product_id
join scm.resources r on r.resource_id = cl.resource_id
order by cl.sales_order_id, cl.work_date, r.resource_name;


select 'orders_with_daily_load_over_24h' as check_name,
count(*) as error_count
from (
select cl.sales_order_id,
cl.work_date
from scm.crp_load cl
group by cl.sales_order_id, cl.work_date
having sum(cl.load_hours) > 24
) t;