/* 04_mrp_crp_calculation.sql. Вариант 22 */

set search_path to scm;


/* 1. Проверка заказов */

do $$
declare
v_bad_orders text;

begin

select string_agg(sales_order_id, ', ')
into v_bad_orders
from scm.sales_orders
where abs(ordered_weight_ton - calculated_weight_ton) > tolerance_ton;

if v_bad_orders is not null then
raise exception 'MRP/CRP-расчет остановлен. Заказы не проходят проверку допуска: %',
v_bad_orders;
end if;

end $$;


/* 2. Очистка старых результатов */

delete from scm.crp_load;
delete from scm.mrp_plan;

update scm.production_calendar
set used_hours = 0;

update scm.sales_orders
set order_status = 'CHECKED',
release_date = null;


/* 3. Основной расчет MRP/CRP */

do $$
declare
v_order record;
v_op record;

v_target_seq integer;
v_operation_count integer;

v_unit_weight numeric(12,3);

v_required_output_weight numeric(14,3);
v_output_weight numeric(14,3);
v_raw_input_weight numeric(14,3);
v_input_weight numeric(14,3);
v_load_weight numeric(14,3);

v_output_units integer;
v_input_units integer;

v_operation_hours numeric(12,3);
v_remaining_hours numeric(12,3);

v_day_free_hours numeric(12,3);
v_hours_to_place numeric(12,3);

v_order_day_used_hours numeric(12,3);
v_order_day_free_hours numeric(12,3);
v_order_day_limit_hours numeric(12,3) := 24;

v_planning_date date;
v_current_date date;
v_ready_date date;
v_start_date date;

v_calendar_id bigint;
v_default_available numeric(8,3);

v_plan_status varchar(30);

v_min_planning_date date;
v_max_shift_days integer := 120;

begin

for v_order in
select so.sales_order_id,
so.product_id,
so.unit_weight_ton,
so.calculated_units,
so.calculated_weight_ton,
so.due_date,
so.priority
from scm.sales_orders so
order by so.priority, so.due_date, so.sales_order_id
loop

v_unit_weight := v_order.unit_weight_ton;

v_target_seq :=
case v_order.product_id
when 'HR_COIL' then 10
when 'HR_PICKLED_COIL' then 20
when 'CR_COIL' then 30
when 'GALV_COIL' then 40
when 'GALV_CUT_COIL' then 50
else null
end;

if v_target_seq is null then
raise exception 'Для заказа % не найден маршрут по продукту %',
v_order.sales_order_id,
v_order.product_id;
end if;


drop table if exists tmp_order_operations;

create temp table tmp_order_operations as
select row_number() over (order by route.operation_seq)::integer as op_order,
route.operation_id,
route.operation_code,
route.operation_name,
route.output_product_id,
route.input_product_id,
route.operation_seq,
route.resource_id,
route.resource_name,
route.capacity_ton_per_hour,
route.yield_rate,
route.setup_hours,
route.is_final_operation
from (
select so.operation_id,
so.operation_code,
so.operation_name,
so.output_product_id,
so.input_product_id,
so.operation_seq,
so.resource_id,
r.resource_name,
r.capacity_ton_per_hour,
so.yield_rate,
so.setup_hours,
so.is_final_operation
from scm.standard_operations so
join scm.resources r on r.resource_id = so.resource_id
where so.is_final_operation = false
and so.operation_seq <= v_target_seq

union all

select so.operation_id,
so.operation_code,
so.operation_name,
so.output_product_id,
so.input_product_id,
so.operation_seq,
so.resource_id,
r.resource_name,
r.capacity_ton_per_hour,
so.yield_rate,
so.setup_hours,
so.is_final_operation
from scm.standard_operations so
join scm.resources r on r.resource_id = so.resource_id
where so.is_final_operation = true
and so.output_product_id = v_order.product_id
) route
order by route.operation_seq;


select count(*)
into v_operation_count
from tmp_order_operations;

if v_operation_count = 0 then
raise exception 'Для заказа % не сформирован маршрут операций',
v_order.sales_order_id;
end if;


v_required_output_weight := v_order.calculated_weight_ton;
v_planning_date := v_order.due_date;
v_min_planning_date := v_order.due_date - v_max_shift_days;


/* Обратный расчет */

for v_op in
select *
from tmp_order_operations
order by op_order desc
loop

if v_op.is_final_operation = true then

v_output_weight := v_required_output_weight;
v_raw_input_weight := v_required_output_weight;
v_input_units := ceil(v_raw_input_weight / v_unit_weight)::integer;
v_input_weight := v_input_units * v_unit_weight;
v_load_weight := v_input_weight;

else

v_output_weight := v_required_output_weight;
v_raw_input_weight := round(v_output_weight / v_op.yield_rate, 3);
v_input_units := ceil(v_raw_input_weight / v_unit_weight)::integer;
v_input_weight := v_input_units * v_unit_weight;
v_load_weight := v_input_weight;
v_required_output_weight := v_input_weight;

end if;

v_output_units := ceil(v_output_weight / v_unit_weight)::integer;

v_operation_hours := round((v_load_weight / v_op.capacity_ton_per_hour) + v_op.setup_hours, 3);

v_remaining_hours := v_operation_hours;
v_ready_date := v_planning_date;
v_current_date := v_planning_date;
v_start_date := v_planning_date;


/* Размещение загрузки */

while v_remaining_hours > 0 loop

if v_current_date < v_min_planning_date then
raise exception 'MRP/CRP-расчет остановлен. Заказ %, операция %, ресурс %. Расчет ушел раньше допустимой даты %. Проверьте объем заказа или календарь мощностей.',
v_order.sales_order_id,
v_op.operation_name,
v_op.resource_id,
v_min_planning_date;
end if;

v_calendar_id := null;
v_day_free_hours := null;
v_order_day_used_hours := 0;
v_order_day_free_hours := 0;

select pc.calendar_id,
pc.available_hours - pc.used_hours
into v_calendar_id,
v_day_free_hours
from scm.production_calendar pc
where pc.resource_id = v_op.resource_id
and pc.work_date = v_current_date
for update;

if v_calendar_id is null then

select r.default_available_hours
into v_default_available
from scm.resources r
where r.resource_id = v_op.resource_id;

insert into scm.production_calendar (
resource_id,
work_date,
available_hours,
used_hours,
comment_text
)
values (
v_op.resource_id,
v_current_date,
v_default_available,
0,
'Дата добавлена автоматически при MRP/CRP-расчете'
)
returning calendar_id,
available_hours - used_hours
into v_calendar_id,
v_day_free_hours;

end if;

select coalesce(sum(cl.load_hours), 0)
into v_order_day_used_hours
from scm.crp_load cl
where cl.sales_order_id = v_order.sales_order_id
and cl.work_date = v_current_date;

v_order_day_free_hours := v_order_day_limit_hours - v_order_day_used_hours;

if v_day_free_hours <= 0 then
v_current_date := v_current_date - 1;
continue;
end if;

if v_order_day_free_hours <= 0 then
v_current_date := v_current_date - 1;
continue;
end if;

v_hours_to_place := least(v_remaining_hours, v_day_free_hours, v_order_day_free_hours);

if v_hours_to_place <= 0 then
v_current_date := v_current_date - 1;
continue;
end if;

insert into scm.crp_load (
sales_order_id,
resource_id,
work_date,
operation_seq,
operation_name,
load_hours,
load_weight_ton,
load_status,
comment_text
)
values (
v_order.sales_order_id,
v_op.resource_id,
v_current_date,
v_op.operation_seq,
v_op.operation_name,
v_hours_to_place,
round(v_load_weight * v_hours_to_place / nullif(v_operation_hours, 0), 3),
case
when v_current_date = v_ready_date then 'OK'
else 'SHIFTED'
end,
'Загрузка рассчитана с учетом лимита 24 часа на заказ в сутки'
);

update scm.production_calendar
set used_hours = used_hours + v_hours_to_place
where calendar_id = v_calendar_id;

v_remaining_hours := round(v_remaining_hours - v_hours_to_place, 3);
v_start_date := v_current_date;

if v_remaining_hours > 0 then
v_current_date := v_current_date - 1;
end if;

end loop;


v_plan_status :=
case
when v_start_date < v_ready_date then 'CAPACITY_SHIFTED'
else 'CAPACITY_OK'
end;


insert into scm.mrp_plan (
sales_order_id,
product_id,
plan_level,
operation_seq,
material_need_type,
qty_units,
weight_ton,
required_date,
ready_date,
resource_id,
operation_name,
operation_hours,
plan_status,
calculation_note
)
values (
v_order.sales_order_id,
v_op.output_product_id,
v_op.op_order,
v_op.operation_seq,
case
when v_op.is_final_operation = true then 'FINISHED_GOOD'
else 'OUTPUT'
end,
case
when v_op.is_final_operation = true then v_order.calculated_units
else v_output_units
end,
v_output_weight,
v_planning_date,
v_ready_date,
v_op.resource_id,
v_op.operation_name,
v_operation_hours,
v_plan_status,
concat(
'MRP/CRP расчет. Выходной вес: ',
v_output_weight,
' т; сырой вход: ',
v_raw_input_weight,
' т; вход после округления вверх до кратности ',
v_unit_weight,
' т = ',
v_input_weight,
' т. Ограничение: не более 24 ч на заказ в сутки.'
)
);

v_planning_date := v_start_date;

end loop;


/* Потребность в слябе */

insert into scm.mrp_plan (
sales_order_id,
product_id,
plan_level,
operation_seq,
material_need_type,
qty_units,
weight_ton,
required_date,
ready_date,
resource_id,
operation_name,
operation_hours,
plan_status,
calculation_note
)
values (
v_order.sales_order_id,
'SLAB',
0,
null,
'INPUT',
ceil(v_required_output_weight / v_unit_weight)::integer,
v_required_output_weight,
v_planning_date,
v_planning_date,
null,
'Потребность в слябе',
null,
'PLANNED',
concat(
'Сырьевая потребность после обратного MRP-расчета. Вес единицы: ',
v_unit_weight,
' т. Ограничение 24 ч на заказ в сутки учтено в CRP.'
)
);


update scm.sales_orders
set release_date = v_planning_date,
order_status = 'PLANNED'
where sales_order_id = v_order.sales_order_id;


raise notice 'Заказ % рассчитан. Дата сдачи: %, дата запуска: %',
v_order.sales_order_id,
v_order.due_date,
v_planning_date;

end loop;

end $$;


/* 4. Проверка количества строк */

select 'mrp_plan' as table_name, count(*) as rows_count
from scm.mrp_plan

union all

select 'crp_load' as table_name, count(*) as rows_count
from scm.crp_load

union all

select 'production_calendar_with_load' as table_name, count(*) as rows_count
from scm.production_calendar
where used_hours > 0;


/* 5. Проверка перегрузки ресурсов */

select pc.work_date,
r.resource_name,
pc.available_hours,
pc.used_hours,
pc.available_hours - pc.used_hours as remaining_hours
from scm.production_calendar pc
join scm.resources r on r.resource_id = pc.resource_id
where pc.used_hours > pc.available_hours
order by pc.work_date, r.resource_name;


/* 6. Проверка лимита 24 часа на заказ в день */

select cl.sales_order_id as "Заказ",
cl.work_date as "Дата",
round(sum(cl.load_hours), 3) as "Загрузка заказа за день, ч",
24 as "Лимит, ч",
round(24 - sum(cl.load_hours), 3) as "Остаток до лимита, ч",
case
when sum(cl.load_hours) <= 24 then 'OK'
else 'ERROR'
end as "Проверка"
from scm.crp_load cl
group by cl.sales_order_id, cl.work_date
order by cl.work_date, cl.sales_order_id;


/* 7. Нарушения лимита 24 часа */

select cl.sales_order_id as "Заказ",
cl.work_date as "Дата",
round(sum(cl.load_hours), 3) as "Загрузка заказа за день, ч",
24 as "Лимит, ч",
round(24 - sum(cl.load_hours), 3) as "Остаток до лимита, ч"
from scm.crp_load cl
group by cl.sales_order_id, cl.work_date
having sum(cl.load_hours) > 24
order by cl.work_date, cl.sales_order_id;


/* 8. Проверка дат запуска */

select so.sales_order_id as "Заказ",
c.customer_name as "Заказчик",
p.product_short_name as "Продукция",
so.calculated_weight_ton as "Плановый вес сдачи, т",
so.release_date as "Дата запуска",
so.due_date as "Дата сдачи",
so.priority as "Приоритет",
so.order_status as "Статус"
from scm.sales_orders so
join scm.customers c on c.customer_id = so.customer_id
join scm.products p on p.product_id = so.product_id
order by so.priority, so.due_date, so.sales_order_id;