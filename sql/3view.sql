SELECT *
FROM scm.v_report_orders_detail
ORDER BY sales_order_id;
SELECT *
FROM scm.v_report_orders_by_due_date
ORDER BY due_date;
SELECT *
FROM scm.v_report_orders_by_product
ORDER BY total_ordered_weight_ton DESC;
SELECT *
FROM scm.v_report_orders_by_customer
ORDER BY total_ordered_weight_ton DESC;
SELECT *
FROM scm.v_report_orders_by_priority
ORDER BY priority;
SELECT *
FROM scm.v_report_mrp_order_sequence
ORDER BY calculation_order;