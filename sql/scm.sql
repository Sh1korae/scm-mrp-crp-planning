/* Структура БД SCM/MRP. Вариант 22 */

/* 0. Очистка схемы */
/* drop schema if exists scm cascade; */


/* 1. Создание схемы */

create schema if not exists scm;

set search_path to scm;


/* 2. Таблица заказчиков */

create table if not exists scm.customers (
customer_id serial primary key,
customer_code varchar(30) not null unique,
customer_name varchar(255) not null,
customer_group varchar(100),
default_priority integer check (default_priority >= 1),
comment_text text,
created_at timestamp not null default current_timestamp
);

comment on table scm.customers is 'Справочник заказчиков';
comment on column scm.customers.customer_code is 'Короткий код заказчика';
comment on column scm.customers.customer_name is 'Наименование заказчика';
comment on column scm.customers.default_priority is 'Приоритет заказчика по умолчанию';


/* 3. Таблица материалов и продуктов */

create table if not exists scm.products (
product_id varchar(40) primary key,
product_name varchar(255) not null,
product_short_name varchar(100),
product_group varchar(100) not null,
product_usage_type varchar(30) not null,
base_uom varchar(20) not null default 'ton',
is_active boolean not null default true,
comment_text text,
created_at timestamp not null default current_timestamp,

constraint chk_products_usage_type
check (product_usage_type in (
'RAW',
'SEMI_FINISHED',
'FINISHED',
'SERVICE'
))
);

comment on table scm.products is 'Справочник материалов, полуфабрикатов и готовой продукции';
comment on column scm.products.product_id is 'Код материала';
comment on column scm.products.product_usage_type is 'Тип: сырье, полуфабрикат, готовая продукция или сервисная операция';


/* 4. Таблица производственных ресурсов */

create table if not exists scm.resources (
resource_id varchar(40) primary key,
resource_name varchar(255) not null,
resource_type varchar(100) not null,
capacity_ton_per_hour numeric(12,3) not null,
default_available_hours numeric(5,2) not null default 23,
is_active boolean not null default true,
comment_text text,
created_at timestamp not null default current_timestamp,

constraint chk_resources_capacity
check (capacity_ton_per_hour > 0),

constraint chk_resources_hours
check (default_available_hours > 0 and default_available_hours <= 24)
);

comment on table scm.resources is 'Справочник производственных агрегатов и их производительности';
comment on column scm.resources.capacity_ton_per_hour is 'Производительность ресурса, тонн в час';
comment on column scm.resources.default_available_hours is 'Доступная мощность в часах за сутки';


/* 5. Таблица сбытовых заказов */

create table if not exists scm.sales_orders (
sales_order_id varchar(30) primary key,

customer_id integer not null,
product_id varchar(40) not null,

unit_weight_ton numeric(12,3) not null,
ordered_weight_ton numeric(14,3) not null,
tolerance_ton numeric(12,3) not null default 0,

calculated_units integer,
calculated_weight_ton numeric(14,3),

original_due_date date not null,
due_date date not null,
release_date date,

priority integer not null,
order_status varchar(30) not null default 'NEW',

comment_text text,
created_at timestamp not null default current_timestamp,

constraint fk_sales_orders_customer
foreign key (customer_id)
references scm.customers(customer_id)
on update cascade
on delete restrict,

constraint fk_sales_orders_product
foreign key (product_id)
references scm.products(product_id)
on update cascade
on delete restrict,

constraint chk_sales_orders_unit_weight
check (unit_weight_ton > 0),

constraint chk_sales_orders_ordered_weight
check (ordered_weight_ton > 0),

constraint chk_sales_orders_tolerance
check (tolerance_ton >= 0),

constraint chk_sales_orders_priority
check (priority >= 1),

constraint chk_sales_orders_status
check (order_status in (
'NEW',
'CHECKED',
'PLANNED',
'CAPACITY_OK',
'LATE',
'COMPLETED',
'CANCELLED'
))
);

comment on table scm.sales_orders is 'Портфель сбытовых заказов';
comment on column scm.sales_orders.unit_weight_ton is 'Вес одной единицы продукции, тонн';
comment on column scm.sales_orders.ordered_weight_ton is 'Заказанный объем, тонн';
comment on column scm.sales_orders.calculated_units is 'Расчетное количество единиц продукции';
comment on column scm.sales_orders.calculated_weight_ton is 'Фактический вес после округления под кратность единицы';
comment on column scm.sales_orders.priority is 'Приоритет заказа: чем меньше число, тем выше приоритет';


/* 6. Таблица связей материалов */

create table if not exists scm.product_links (
product_link_id bigserial primary key,

output_product_id varchar(40) not null,
input_product_id varchar(40) not null,

operation_seq integer not null,
qty_ratio numeric(14,6) not null default 1,
yield_rate numeric(8,5) not null default 1,

valid_from date not null default date '2025-01-01',
valid_to date,

comment_text text,
created_at timestamp not null default current_timestamp,

constraint fk_product_links_output_product
foreign key (output_product_id)
references scm.products(product_id)
on update cascade
on delete restrict,

constraint fk_product_links_input_product
foreign key (input_product_id)
references scm.products(product_id)
on update cascade
on delete restrict,

constraint chk_product_links_qty_ratio
check (qty_ratio > 0),

constraint chk_product_links_yield_rate
check (yield_rate > 0 and yield_rate <= 1),

constraint chk_product_links_not_same
check (output_product_id <> input_product_id),

constraint uq_product_links
unique (output_product_id, input_product_id, operation_seq)
);

comment on table scm.product_links is 'Иерархия материалов: какой входной материал нужен для получения выходного материала';
comment on column scm.product_links.output_product_id is 'Материал, который получается после операции';
comment on column scm.product_links.input_product_id is 'Материал, который требуется на входе операции';
comment on column scm.product_links.yield_rate is 'Коэффициент выхода годного';


/* 7. Таблица стандартных операций */

create table if not exists scm.standard_operations (
operation_id bigserial primary key,

operation_code varchar(50) not null unique,
operation_name varchar(255) not null,

output_product_id varchar(40) not null,
input_product_id varchar(40),

operation_seq integer not null,
resource_id varchar(40) not null,

yield_rate numeric(8,5) not null default 1,
setup_hours numeric(8,3) not null default 0,

is_final_operation boolean not null default false,
comment_text text,
created_at timestamp not null default current_timestamp,

constraint fk_standard_operations_output_product
foreign key (output_product_id)
references scm.products(product_id)
on update cascade
on delete restrict,

constraint fk_standard_operations_input_product
foreign key (input_product_id)
references scm.products(product_id)
on update cascade
on delete restrict,

constraint fk_standard_operations_resource
foreign key (resource_id)
references scm.resources(resource_id)
on update cascade
on delete restrict,

constraint chk_standard_operations_seq
check (operation_seq >= 1),

constraint chk_standard_operations_yield_rate
check (yield_rate > 0 and yield_rate <= 1),

constraint chk_standard_operations_setup_hours
check (setup_hours >= 0),

constraint uq_standard_operations_product_seq
unique (output_product_id, operation_seq)
);

comment on table scm.standard_operations is 'Стандартные операции маршрута производства';
comment on column scm.standard_operations.operation_seq is 'Порядок операции в маршруте';
comment on column scm.standard_operations.resource_id is 'Ресурс, на котором выполняется операция';
comment on column scm.standard_operations.yield_rate is 'Коэффициент выхода годного операции';


/* 8. Производственный календарь */

create table if not exists scm.production_calendar (
calendar_id bigserial primary key,

resource_id varchar(40) not null,
work_date date not null,

available_hours numeric(8,3) not null default 23,
used_hours numeric(8,3) not null default 0,

comment_text text,
created_at timestamp not null default current_timestamp,

constraint fk_production_calendar_resource
foreign key (resource_id)
references scm.resources(resource_id)
on update cascade
on delete restrict,

constraint chk_production_calendar_available_hours
check (available_hours >= 0 and available_hours <= 24),

constraint chk_production_calendar_used_hours
check (used_hours >= 0),

constraint chk_production_calendar_used_not_more_available
check (used_hours <= available_hours),

constraint uq_production_calendar_resource_date
unique (resource_id, work_date)
);

comment on table scm.production_calendar is 'Календарь доступной мощности ресурсов по датам';
comment on column scm.production_calendar.available_hours is 'Доступные часы ресурса в конкретную дату';
comment on column scm.production_calendar.used_hours is 'Уже занятая мощность ресурса в конкретную дату';


/* 9. Таблица MRP-плана */

create table if not exists scm.mrp_plan (
mrp_plan_id bigserial primary key,

sales_order_id varchar(30) not null,
product_id varchar(40) not null,

plan_level integer not null default 0,
operation_seq integer,

material_need_type varchar(30) not null default 'OUTPUT',

qty_units numeric(14,3),
weight_ton numeric(14,3) not null,

required_date date,
ready_date date not null,

resource_id varchar(40),
operation_name varchar(255),
operation_hours numeric(12,3),

plan_status varchar(30) not null default 'PLANNED',
calculation_note text,
created_at timestamp not null default current_timestamp,

constraint fk_mrp_plan_sales_order
foreign key (sales_order_id)
references scm.sales_orders(sales_order_id)
on update cascade
on delete cascade,

constraint fk_mrp_plan_product
foreign key (product_id)
references scm.products(product_id)
on update cascade
on delete restrict,

constraint fk_mrp_plan_resource
foreign key (resource_id)
references scm.resources(resource_id)
on update cascade
on delete restrict,

constraint chk_mrp_plan_level
check (plan_level >= 0),

constraint chk_mrp_plan_weight
check (weight_ton > 0),

constraint chk_mrp_plan_operation_hours
check (operation_hours is null or operation_hours >= 0),

constraint chk_mrp_plan_material_need_type
check (material_need_type in (
'DEMAND',
'INPUT',
'OUTPUT',
'FINISHED_GOOD'
)),

constraint chk_mrp_plan_status
check (plan_status in (
'PLANNED',
'CAPACITY_OK',
'CAPACITY_SHIFTED',
'LATE',
'DONE'
))
);

comment on table scm.mrp_plan is 'Результат MRP-расчета по материалам, датам и операциям';
comment on column scm.mrp_plan.plan_level is 'Уровень в иерархии материалов';
comment on column scm.mrp_plan.material_need_type is 'Тип потребности: спрос, вход, выход, готовая продукция';
comment on column scm.mrp_plan.weight_ton is 'Вес потребности, тонн';
comment on column scm.mrp_plan.ready_date is 'Дата готовности материала';


/* 10. Таблица CRP-загрузки */

create table if not exists scm.crp_load (
crp_load_id bigserial primary key,

sales_order_id varchar(30) not null,
resource_id varchar(40) not null,

work_date date not null,
operation_seq integer,
operation_name varchar(255),

load_hours numeric(12,3) not null,
load_weight_ton numeric(14,3),

load_status varchar(30) not null default 'OK',
comment_text text,
created_at timestamp not null default current_timestamp,

constraint fk_crp_load_sales_order
foreign key (sales_order_id)
references scm.sales_orders(sales_order_id)
on update cascade
on delete cascade,

constraint fk_crp_load_resource
foreign key (resource_id)
references scm.resources(resource_id)
on update cascade
on delete restrict,

constraint chk_crp_load_hours
check (load_hours >= 0),

constraint chk_crp_load_weight
check (load_weight_ton is null or load_weight_ton >= 0),

constraint chk_crp_load_status
check (load_status in (
'OK',
'SHIFTED',
'OVERLOAD',
'LATE'
))
);

comment on table scm.crp_load is 'Загрузка производственных ресурсов по датам';
comment on column scm.crp_load.load_hours is 'Сколько часов занимает операция на ресурсе';
comment on column scm.crp_load.load_weight_ton is 'Вес материала, обработанный на ресурсе';


/* 11. Индексы */

create index if not exists idx_sales_orders_due_date
on scm.sales_orders(due_date);

create index if not exists idx_sales_orders_priority_due_date
on scm.sales_orders(priority, due_date);

create index if not exists idx_sales_orders_customer
on scm.sales_orders(customer_id);

create index if not exists idx_sales_orders_product
on scm.sales_orders(product_id);

create index if not exists idx_product_links_output
on scm.product_links(output_product_id);

create index if not exists idx_product_links_input
on scm.product_links(input_product_id);

create index if not exists idx_standard_operations_output_seq
on scm.standard_operations(output_product_id, operation_seq);

create index if not exists idx_production_calendar_resource_date
on scm.production_calendar(resource_id, work_date);

create index if not exists idx_mrp_plan_order
on scm.mrp_plan(sales_order_id);

create index if not exists idx_mrp_plan_product_date
on scm.mrp_plan(product_id, ready_date);

create index if not exists idx_crp_load_resource_date
on scm.crp_load(resource_id, work_date);


/* 12. Представления для проверки */

create or replace view scm.v_database_tables as
select table_schema,
table_name
from information_schema.tables
where table_schema = 'scm'
order by table_name;


create or replace view scm.v_sales_orders_base as
select so.sales_order_id,
c.customer_name,
p.product_name,
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
join scm.products p on p.product_id = so.product_id;


create or replace view scm.v_resource_calendar as
select pc.work_date,
r.resource_id,
r.resource_name,
pc.available_hours,
pc.used_hours,
pc.available_hours - pc.used_hours as remaining_hours
from scm.production_calendar pc
join scm.resources r on r.resource_id = pc.resource_id;


/* 13. Финальная проверка */

select table_name
from information_schema.tables
where table_schema = 'scm'
order by table_name;