/*mrp-plan*/

SELECT
    m.sales_order_id AS "Заказ",
    c.customer_name AS "Заказчик",
    order_product.product_short_name AS "Готовая продукция",
    p.product_short_name AS "Материал",
    m.material_need_type AS "Тип потребности",
    m.operation_seq AS "Операция №",
    m.operation_name AS "Операция",
    r.resource_name AS "Ресурс",
    m.qty_units AS "Кол-во ед.",
    m.weight_ton AS "Вес, т",
    m.required_date AS "Требуется к дате",
    m.ready_date AS "Дата готовности",
    m.operation_hours AS "Фонд времени, ч",
    m.plan_status AS "Статус",
    m.calculation_note AS "Комментарий расчета"
FROM scm.mrp_plan m
JOIN scm.sales_orders so
    ON so.sales_order_id = m.sales_order_id
JOIN scm.customers c
    ON c.customer_id = so.customer_id
JOIN scm.products order_product
    ON order_product.product_id = so.product_id
JOIN scm.products p
    ON p.product_id = m.product_id
LEFT JOIN scm.resources r
    ON r.resource_id = m.resource_id
ORDER BY
    m.sales_order_id,
    m.operation_seq NULLS FIRST,
    m.plan_level;

/* сколько каждый агрегат обработал в тоннах */

SELECT
    r.resource_name AS "Агрегат",
    cl.operation_name AS "Операция",
    COUNT(DISTINCT cl.sales_order_id) AS "Количество заказов",
    ROUND(SUM(cl.load_weight_ton), 3) AS "Обработано, т",
    ROUND(SUM(cl.load_hours), 3) AS "Загрузка, ч"
FROM scm.crp_load cl
JOIN scm.resources r
    ON r.resource_id = cl.resource_id
GROUP BY
    r.resource_name,
    cl.operation_name
ORDER BY
    r.resource_name,
    cl.operation_name;

/* сколько каждый агрегат обработал в тоннах и штуках */

SELECT
    r.resource_name AS "Агрегат",
    m.operation_name AS "Операция",
    COUNT(DISTINCT m.sales_order_id) AS "Количество заказов",
    COALESCE(SUM(m.qty_units), 0) AS "Кол-во ед.",
    ROUND(SUM(m.weight_ton), 3) AS "Вес, т",
    ROUND(SUM(m.operation_hours), 3) AS "Фонд времени, ч"
FROM scm.mrp_plan m
LEFT JOIN scm.resources r
    ON r.resource_id = m.resource_id
WHERE m.resource_id IS NOT NULL
GROUP BY
    r.resource_name,
    m.operation_name
ORDER BY
    r.resource_name,
    m.operation_name;

/* агрегаты на заказ */

SELECT
    cl.sales_order_id AS "Заказ",
    c.customer_name AS "Заказчик",
    p.product_short_name AS "Готовая продукция",
    r.resource_name AS "Агрегат",
    cl.operation_name AS "Операция",
    cl.work_date AS "Дата работы",
    ROUND(cl.load_weight_ton, 3) AS "Обработано, т",
    ROUND(cl.load_hours, 3) AS "Загрузка, ч",
    cl.load_status AS "Статус загрузки"
FROM scm.crp_load cl
JOIN scm.sales_orders so
    ON so.sales_order_id = cl.sales_order_id
JOIN scm.customers c
    ON c.customer_id = so.customer_id
JOIN scm.products p
    ON p.product_id = so.product_id
JOIN scm.resources r
    ON r.resource_id = cl.resource_id
ORDER BY
    cl.sales_order_id,
    cl.work_date,
    r.resource_name;

/* производственный календарь */

SELECT
    pc.work_date AS "Дата",
    r.resource_name AS "Агрегат",
    pc.available_hours AS "Доступно, ч",
    pc.used_hours AS "Занято, ч",
    pc.available_hours - pc.used_hours AS "Остаток, ч",
    CASE
        WHEN pc.used_hours <= pc.available_hours THEN 'OK'
        ELSE 'OVERLOAD'
    END AS "Проверка ресурса"
FROM scm.production_calendar pc
JOIN scm.resources r
    ON r.resource_id = pc.resource_id
WHERE pc.used_hours > 0
ORDER BY
    pc.work_date,
    r.resource_name;

/* один заказ не больше 24 часов в день. */

SELECT
    cl.sales_order_id AS "Заказ",
    cl.work_date AS "Дата",
    ROUND(SUM(cl.load_hours), 3) AS "Загрузка заказа за день, ч",
    24 AS "Лимит, ч",
    ROUND(24 - SUM(cl.load_hours), 3) AS "Остаток до лимита, ч",
    CASE
        WHEN SUM(cl.load_hours) <= 24 THEN 'OK'
        ELSE 'ERROR'
    END AS "Проверка"
FROM scm.crp_load cl
GROUP BY
    cl.sales_order_id,
    cl.work_date
ORDER BY
    cl.work_date,
    cl.sales_order_id;