/* Этап 4. Заполнение справочников. Вариант 22 */

set search_path to scm;



insert into scm.customers (
customer_code,
customer_name,
customer_group,
default_priority,
comment_text
)
values
('PMH', 'ПМХ', 'Металлургия', 2, 'Заказчик из варианта 22'),
('NLMK_EUROPE', 'НЛМК Европа', 'Металлургия', 1, 'Заказчик из варианта 22'),
('TMK', 'ТМК', 'Трубная промышленность', 2, 'Заказчик из варианта 22'),
('SETL_GROUP', 'Setl Group', 'Строительство', 5, 'Заказчик из варианта 22'),
('SINARA', 'Синара', 'Машиностроение', 3, 'Заказчик из варианта 22'),
('AVTOVAZ', 'АвтоВАЗ', 'Автомобилестроение', 4, 'Заказчик из варианта 22'),
('KTZ', 'KTZ', 'Транспортное машиностроение', 3, 'Заказчик из варианта 22'),
('VAI', 'VAI', 'Промышленное оборудование', 2, 'Заказчик из варианта 22')
on conflict (customer_code) do update set
customer_name = excluded.customer_name,
customer_group = excluded.customer_group,
default_priority = excluded.default_priority,
comment_text = excluded.comment_text;


/* 2. Заполнение products */

insert into scm.products (
product_id,
product_name,
product_short_name,
product_group,
product_usage_type,
base_uom,
is_active,
comment_text
)
values
('SLAB', 'Сляб', 'Сляб', 'Сырье', 'RAW', 'ton', true, 'Исходный материал для горячей прокатки'),
('HR_COIL', 'Горячекатаный рулон', 'Рулон г/к', 'Горячекатаный прокат', 'FINISHED', 'ton', true, 'Может быть готовой продукцией или полуфабрикатом для травления'),
('HR_PICKLED_COIL', 'Горячекатаный травленый рулон', 'Рулон г/к травл.', 'Горячекатаный травленый прокат', 'FINISHED', 'ton', true, 'Может быть готовой продукцией или полуфабрикатом для холодной прокатки'),
('CR_COIL', 'Холоднокатаный рулон', 'Рулон х/к', 'Холоднокатаный прокат', 'FINISHED', 'ton', true, 'Может быть готовой продукцией или полуфабрикатом для оцинкования'),
('GALV_COIL', 'Холоднокатаный оцинкованный рулон', 'Рулон х/к оцинк.', 'Оцинкованный прокат', 'FINISHED', 'ton', true, 'Может быть готовой продукцией или полуфабрикатом для резки'),
('GALV_CUT_COIL', 'Холоднокатаный оцинкованный резаный рулон', 'Рулон х/к оцинк. рез.', 'Оцинкованный резаный прокат', 'FINISHED', 'ton', true, 'Готовая продукция после операции резки')
on conflict (product_id) do update set
product_name = excluded.product_name,
product_short_name = excluded.product_short_name,
product_group = excluded.product_group,
product_usage_type = excluded.product_usage_type,
base_uom = excluded.base_uom,
is_active = excluded.is_active,
comment_text = excluded.comment_text;


/* 3. Заполнение resources */

insert into scm.resources (
resource_id,
resource_name,
resource_type,
capacity_ton_per_hour,
default_available_hours,
is_active,
comment_text
)
values
('R_HOT_ROLLING', 'Прокатный стан г/п', 'Горячая прокатка', 160, 23, true, 'Производительность по варианту 22: 160 т/ч'),
('R_COLD_ROLLING', 'Прокатный стан х/п', 'Холодная прокатка', 200, 23, true, 'Производительность по варианту 22: 200 т/ч'),
('R_CUTTING', 'Агрегат резки', 'Резка', 170, 23, true, 'Производительность по варианту 22: 170 т/ч'),
('R_PACKING', 'Линия упаковки', 'Упаковка', 180, 23, true, 'Производительность по варианту 22: 180 т/ч'),
('R_PICKLING', 'Агрегат травления', 'Травление', 180, 23, true, 'Производительность по варианту 22: 180 т/ч'),
('R_GALVANIZING', 'Линия оцинкования', 'Оцинкование', 100, 23, true, 'Производительность по варианту 22: 100 т/ч')
on conflict (resource_id) do update set
resource_name = excluded.resource_name,
resource_type = excluded.resource_type,
capacity_ton_per_hour = excluded.capacity_ton_per_hour,
default_available_hours = excluded.default_available_hours,
is_active = excluded.is_active,
comment_text = excluded.comment_text;


/* 4. Заполнение sales_orders */

with src as (
select *
from (
values
('SO1001', 'PMH', 'CR_COIL', 9.000, 2500.000, 10.000, date '2025-04-21', 2),
('SO1002', 'NLMK_EUROPE', 'CR_COIL', 6.000, 1100.000, 10.000, date '2025-04-19', 1),
('SO1003', 'TMK', 'HR_PICKLED_COIL', 15.000, 1500.000, 20.000, date '2025-04-28', 2),
('SO1004', 'SETL_GROUP', 'GALV_COIL', 9.000, 3000.000, 10.000, date '2025-04-30', 5),
('SO1005', 'SINARA', 'GALV_CUT_COIL', 10.000, 1000.000, 10.000, date '2025-04-14', 3),
('SO1006', 'AVTOVAZ', 'CR_COIL', 13.000, 5000.000, 15.000, date '2025-04-10', 4),
('SO1007', 'KTZ', 'HR_COIL', 9.000, 3100.000, 10.000, date '2025-04-05', 3),
('SO1008', 'VAI', 'GALV_CUT_COIL', 13.000, 3200.000, 15.000, date '2025-04-12', 2)
) as t (
sales_order_id,
customer_code,
product_id,
unit_weight_ton,
ordered_weight_ton,
tolerance_ton,
due_date,
priority
)
)
insert into scm.sales_orders (
sales_order_id,
customer_id,
product_id,
unit_weight_ton,
ordered_weight_ton,
tolerance_ton,
calculated_units,
calculated_weight_ton,
original_due_date,
due_date,
release_date,
priority,
order_status,
comment_text
)
select src.sales_order_id,
c.customer_id,
src.product_id,
src.unit_weight_ton,
src.ordered_weight_ton,
src.tolerance_ton,
floor(src.ordered_weight_ton / src.unit_weight_ton)::integer as calculated_units,
floor(src.ordered_weight_ton / src.unit_weight_ton)::integer * src.unit_weight_ton as calculated_weight_ton,
src.due_date as original_due_date,
src.due_date as due_date,
null as release_date,
src.priority,
'CHECKED' as order_status,
'Сбытовой заказ варианта 22' as comment_text
from src
join scm.customers c on c.customer_code = src.customer_code
on conflict (sales_order_id) do update set
customer_id = excluded.customer_id,
product_id = excluded.product_id,
unit_weight_ton = excluded.unit_weight_ton,
ordered_weight_ton = excluded.ordered_weight_ton,
tolerance_ton = excluded.tolerance_ton,
calculated_units = excluded.calculated_units,
calculated_weight_ton = excluded.calculated_weight_ton,
original_due_date = excluded.original_due_date,
due_date = excluded.due_date,
release_date = excluded.release_date,
priority = excluded.priority,
order_status = excluded.order_status,
comment_text = excluded.comment_text;


/* 5. Заполнение product_links */

insert into scm.product_links (
output_product_id,
input_product_id,
operation_seq,
qty_ratio,
yield_rate,
valid_from,
valid_to,
comment_text
)
values
('HR_COIL', 'SLAB', 10, 1, 0.984, date '2025-01-01', null, 'Для получения горячекатаного рулона требуется сляб'),
('HR_PICKLED_COIL', 'HR_COIL', 20, 1, 1.000, date '2025-01-01', null, 'Для получения травленого рулона требуется горячекатаный рулон'),
('CR_COIL', 'HR_PICKLED_COIL', 30, 1, 0.995, date '2025-01-01', null, 'Для получения холоднокатаного рулона требуется горячекатаный травленый рулон'),
('GALV_COIL', 'CR_COIL', 40, 1, 0.995, date '2025-01-01', null, 'Для получения оцинкованного рулона требуется холоднокатаный рулон'),
('GALV_CUT_COIL', 'GALV_COIL', 50, 1, 0.984, date '2025-01-01', null, 'Для получения оцинкованного резаного рулона требуется оцинкованный рулон')
on conflict (output_product_id, input_product_id, operation_seq) do update set
qty_ratio = excluded.qty_ratio,
yield_rate = excluded.yield_rate,
valid_from = excluded.valid_from,
valid_to = excluded.valid_to,
comment_text = excluded.comment_text;


/* 6. Заполнение standard_operations */

insert into scm.standard_operations (
operation_code,
operation_name,
output_product_id,
input_product_id,
operation_seq,
resource_id,
yield_rate,
setup_hours,
is_final_operation,
comment_text
)
values
('OP_010_HOT_ROLLING', 'Горячая прокатка', 'HR_COIL', 'SLAB', 10, 'R_HOT_ROLLING', 0.984, 0, false, 'Операция получения горячекатаного рулона из сляба'),
('OP_020_PICKLING', 'Травление', 'HR_PICKLED_COIL', 'HR_COIL', 20, 'R_PICKLING', 1.000, 0, false, 'Операция травления горячекатаного рулона'),
('OP_030_COLD_ROLLING', 'Холодная прокатка', 'CR_COIL', 'HR_PICKLED_COIL', 30, 'R_COLD_ROLLING', 0.995, 0, false, 'Операция получения холоднокатаного рулона'),
('OP_040_GALVANIZING', 'Оцинкование', 'GALV_COIL', 'CR_COIL', 40, 'R_GALVANIZING', 0.995, 0, false, 'Операция получения холоднокатаного оцинкованного рулона'),
('OP_050_CUTTING', 'Резка', 'GALV_CUT_COIL', 'GALV_COIL', 50, 'R_CUTTING', 0.984, 0, false, 'Операция резки оцинкованного рулона'),
('OP_090_PACK_HR_COIL', 'Упаковка горячекатаного рулона', 'HR_COIL', 'HR_COIL', 90, 'R_PACKING', 1.000, 0, true, 'Финальная упаковка горячекатаного рулона'),
('OP_090_PACK_HR_PICKLED_COIL', 'Упаковка горячекатаного травленого рулона', 'HR_PICKLED_COIL', 'HR_PICKLED_COIL', 90, 'R_PACKING', 1.000, 0, true, 'Финальная упаковка горячекатаного травленого рулона'),
('OP_090_PACK_CR_COIL', 'Упаковка холоднокатаного рулона', 'CR_COIL', 'CR_COIL', 90, 'R_PACKING', 1.000, 0, true, 'Финальная упаковка холоднокатаного рулона'),
('OP_090_PACK_GALV_COIL', 'Упаковка оцинкованного рулона', 'GALV_COIL', 'GALV_COIL', 90, 'R_PACKING', 1.000, 0, true, 'Финальная упаковка оцинкованного рулона'),
('OP_090_PACK_GALV_CUT_COIL', 'Упаковка оцинкованного резаного рулона', 'GALV_CUT_COIL', 'GALV_CUT_COIL', 90, 'R_PACKING', 1.000, 0, true, 'Финальная упаковка оцинкованного резаного рулона')
on conflict (operation_code) do update set
operation_name = excluded.operation_name,
output_product_id = excluded.output_product_id,
input_product_id = excluded.input_product_id,
operation_seq = excluded.operation_seq,
resource_id = excluded.resource_id,
yield_rate = excluded.yield_rate,
setup_hours = excluded.setup_hours,
is_final_operation = excluded.is_final_operation,
comment_text = excluded.comment_text;


/* 7. Заполнение production_calendar */

insert into scm.production_calendar (
resource_id,
work_date,
available_hours,
used_hours,
comment_text
)
select r.resource_id,
d::date as work_date,
r.default_available_hours as available_hours,
0 as used_hours,
'Календарь мощности для варианта 22' as comment_text
from scm.resources r
cross join generate_series(
date '2025-03-20',
date '2025-04-30',
interval '1 day'
) as d
on conflict (resource_id, work_date) do update set
available_hours = excluded.available_hours,
used_hours = excluded.used_hours,
comment_text = excluded.comment_text;


/* 8. Финальная проверка количества строк */

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


select product_id,
product_name,
product_short_name,
product_group,
product_usage_type
from scm.products
order by product_id;


select so.sales_order_id,
c.customer_name,
p.product_short_name,
so.unit_weight_ton,
so.ordered_weight_ton,
so.tolerance_ton,
so.calculated_units,
so.calculated_weight_ton,
so.due_date,
so.priority,
so.order_status
from scm.sales_orders so
join scm.customers c on c.customer_id = so.customer_id
join scm.products p on p.product_id = so.product_id
order by so.sales_order_id;


select sales_order_id,
ordered_weight_ton,
calculated_weight_ton,
ordered_weight_ton - calculated_weight_ton as difference_ton,
tolerance_ton,
case
when abs(ordered_weight_ton - calculated_weight_ton) <= tolerance_ton then 'OK'
else 'ERROR'
end as tolerance_check
from scm.sales_orders
order by sales_order_id;


select *
from production_calendar pc;