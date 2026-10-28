select 'mrp_plan' as table_name, count(*) as rows_count
from scm.mrp_plan

union all

select 'crp_load' as table_name, count(*) as rows_count
from scm.crp_load

union all

select 'sales_orders_planned' as table_name, count(*) as rows_count
from scm.sales_orders
where order_status = 'PLANNED';



/*  SQL-отчеты по итоговому MRP-плану. Вариант 22 */

set search_path to scm;


/* Отчет 1. Детальный MRP-план по всем заказам */

select m.sales_order_id as "Заказ",
c.customer_name as "Заказчик",
order_product.product_short_name as "Готовая продукция",
p.product_short_name as "Материал",
m.material_need_type as "Тип потребности",
m.plan_level as "Уровень",
m.operation_seq as "Операция №",
m.operation_name as "Операция",
r.resource_name as "Ресурс",
m.qty_units as "Кол-во ед.",
m.weight_ton as "Вес, т",
m.required_date as "Требуется к дате",
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


/*
Вывод:
Детальный MRP-план показывает полную структуру потребности по каждому заказу.
Для каждого заказа отражены исходное сырье, промежуточные материалы, готовая продукция,
операции, ресурсы, даты готовности и фонд времени.
*/


/* Отчет 2. MRP-план по материалам и датам готовности */

select p.product_short_name as "Материал",
p.product_group as "Группа материала",
m.ready_date as "Дата готовности",
count(distinct m.sales_order_id) as "Количество заказов",
coalesce(sum(m.qty_units), 0) as "Кол-во ед.",
round(sum(m.weight_ton), 3) as "Потребность, т"
from scm.mrp_plan m
join scm.products p on p.product_id = m.product_id
group by p.product_short_name, p.product_group, m.ready_date
order by m.ready_date, p.product_short_name;


/*
Вывод:
Отчет показывает, какие материалы должны быть доступны к конкретным датам.
Он используется для контроля готовности сырья, полуфабрикатов и готовой продукции.
*/


/* Отчет 3. Сводная месячная потребность по материалам */

select p.product_id as "Код материала",
p.product_short_name as "Материал",
p.product_group as "Группа материала",
count(distinct m.sales_order_id) as "Количество заказов",
coalesce(sum(m.qty_units), 0) as "Кол-во ед.",
round(sum(m.weight_ton), 3) as "Потребность, т",
min(m.ready_date) as "Первая дата готовности",
max(m.ready_date) as "Последняя дата готовности"
from scm.mrp_plan m
join scm.products p on p.product_id = m.product_id
group by p.product_id, p.product_short_name, p.product_group
order by sum(m.weight_ton) desc;


/*
Вывод:
Сводная месячная потребность показывает общий объем сырья,
полуфабрикатов и готовой продукции, необходимый для выполнения заказов.
*/


/* Отчет 4. Потребность в исходном сырье */

select m.sales_order_id as "Заказ",
c.customer_name as "Заказчик",
order_product.product_short_name as "Готовая продукция",
so.calculated_weight_ton as "Плановый вес сдачи, т",
m.qty_units as "Кол-во ед. сырья",
m.weight_ton as "Потребность в слябе, т",
m.ready_date as "Дата потребности"
from scm.mrp_plan m
join scm.sales_orders so on so.sales_order_id = m.sales_order_id
join scm.customers c on c.customer_id = so.customer_id
join scm.products order_product on order_product.product_id = so.product_id
where m.product_id = 'SLAB'
order by m.ready_date, m.sales_order_id;


/*
Вывод:
Отчет показывает потребность в слябе по каждому заказу.
Потребность рассчитана обратным ходом от готовой продукции с учетом коэффициентов выхода годного.
*/


/* Отчет 5. Сводный MRP-план по заказам */

select so.sales_order_id as "Заказ",
c.customer_name as "Заказчик",
p.product_short_name as "Готовая продукция",
so.calculated_weight_ton as "Плановый вес сдачи, т",
count(m.mrp_plan_id) as "Количество строк MRP",
round(sum(m.weight_ton), 3) as "Суммарная потребность по маршруту, т",
min(m.ready_date) as "Дата запуска по MRP",
so.release_date as "Дата запуска в заказе",
so.due_date as "Дата сдачи",
so.priority as "Приоритет",
so.order_status as "Статус"
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
so.order_status
order by so.priority, so.due_date, so.sales_order_id;


/*
Вывод:
Сводный MRP-план показывает итоговую потребность по каждому заказу:
количество строк MRP, суммарный вес материалов по маршруту, дату запуска и дату сдачи.
*/


/* Отчет 6. MRP-план по готовой продукции */

select m.sales_order_id as "Заказ",
c.customer_name as "Заказчик",
p.product_short_name as "Готовая продукция",
m.qty_units as "Кол-во ед.",
m.weight_ton as "Вес готовой продукции, т",
m.ready_date as "Дата готовности",
so.due_date as "Дата сдачи",
m.operation_name as "Финальная операция",
m.plan_status as "Статус"
from scm.mrp_plan m
join scm.sales_orders so on so.sales_order_id = m.sales_order_id
join scm.customers c on c.customer_id = so.customer_id
join scm.products p on p.product_id = m.product_id
where m.material_need_type = 'FINISHED_GOOD'
order by so.due_date, m.sales_order_id;


/*
Вывод:
MRP-план по готовой продукции подтверждает, что по каждому заказу сформирована финальная потребность.
Вес готовой продукции соответствует плановому весу сдачи.
*/


/* Отчет 7. Проверка полноты MRP-плана по заказам */

select so.sales_order_id as "Заказ",
c.customer_name as "Заказчик",
p.product_short_name as "Продукция",
count(m.mrp_plan_id) as "Количество строк MRP",
case
when count(m.mrp_plan_id) > 0 then 'OK'
else 'NO MRP'
end as "Проверка"
from scm.sales_orders so
join scm.customers c on c.customer_id = so.customer_id
join scm.products p on p.product_id = so.product_id
left join scm.mrp_plan m on m.sales_order_id = so.sales_order_id
group by so.sales_order_id, c.customer_name, p.product_short_name
order by so.sales_order_id;


/*
Вывод:
Если по всем заказам указано OK, значит каждый заказ был включен в MRP-расчет.
*/


/* Отчет 8. Проверка соответствия готовой продукции заказам */

select so.sales_order_id as "Заказ",
c.customer_name as "Заказчик",
p.product_short_name as "Продукция",
so.calculated_weight_ton as "Плановый вес сдачи, т",
m.weight_ton as "Вес в MRP, т",
so.calculated_weight_ton - m.weight_ton as "Разница, т",
case
when so.calculated_weight_ton = m.weight_ton then 'OK'
else 'ERROR'
end as "Проверка"
from scm.sales_orders so
join scm.customers c on c.customer_id = so.customer_id
join scm.products p on p.product_id = so.product_id
join scm.mrp_plan m on m.sales_order_id = so.sales_order_id
and m.material_need_type = 'FINISHED_GOOD'
order by so.sales_order_id;


/*
Вывод:
Проверка показывает, совпадает ли вес готовой продукции в MRP-плане
с плановым весом сдачи в портфеле заказов.
*/


/* Финальная проверка */

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
where weight_ton <= 0;


/*
Вывод:
В корректном результате по всем строкам error_count должен быть равен 0.
Это означает, что MRP-план сформирован полностью и не содержит критических ошибок.
*/

