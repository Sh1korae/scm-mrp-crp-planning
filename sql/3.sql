

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


