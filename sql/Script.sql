update scm.sales_orders
set ordered_weight_ton = 3000,
calculated_units = floor(3000 / unit_weight_ton)::integer,
calculated_weight_ton = floor(3000 / unit_weight_ton)::integer * unit_weight_ton,
order_status = 'CHECKED',
release_date = null,
where sales_order_id = 'SO1005';

select sales_order_id,
ordered_weight_ton,
unit_weight_ton,
calculated_units,
calculated_weight_ton,
ordered_weight_ton - calculated_weight_ton as difference_ton,
tolerance_ton,
case
when abs(ordered_weight_ton - calculated_weight_ton) <= tolerance_ton then 'OK'
else 'ERROR'
end as tolerance_check
from scm.sales_orders
where sales_order_id = 'SO1005';



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