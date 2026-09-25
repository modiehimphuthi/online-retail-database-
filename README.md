# Online Retail SQL Database

A relational database design for an online retail business, built in SQL Server as a self-directed learning project covering schema design, constraints, indexing, and query patterns from basic `SELECT` statements through window functions and transactions.

## Overview

This project models the core of an online retail system, customers place orders, orders contain multiple products, and payments are recorded against orders. The schema is normalized to avoid data duplication, with foreign keys and constraints enforcing data integrity at the database level rather than relying on application code.

## Entity-Relationship Summary

```
Customers (1) ───< Orders (1) ───< OrderItems >─── (1) Products
                       │
                       └───< Payments
```

- One customer can place many orders (`Orders.customer_id` → `Customers.customer_id`)
- One order can contain many products, and one product can appear in many orders — resolved through the `OrderItems` junction table
- One order can have multiple payments recorded against it (`Payments.order_id` → `Orders.order_id`)

## Tables

| Table | Purpose |
|---|---|
| `Customers` | One row per customer - name, email (unique), signup date, city |
| `Products` | One row per sellable product - name, category, price, stock quantity |
| `Orders` | One row per order - links to a customer, tracks status and order date |
| `OrderItems` | Junction table resolving the many-to-many relationship between orders and products; records quantity and the price *at the time of sale* |
| `Payments` | One row per payment made against an order |

## Design Decisions

**Normalization.** Customer details live only in `Customers`, product details only in `Products`. Every other table references them by ID rather than repeating that data, so an update (e.g. a customer's email) only ever needs to happen in one place. 

**`unit_price` is stored on `OrderItems`, not looked up from `Products`.** Product prices change over time; an order placed six months ago should still reflect what the customer actually paid, not today's current price. Capturing price at the point of sale keeps historical orders accurate.

**Foreign keys are explicitly indexed.** SQL Server automatically indexes primary keys, but *not* foreign keys. Since foreign key columns (`Orders.customer_id`, `OrderItems.order_id`, `OrderItems.product_id`, `Payments.order_id`) are joined on constantly in reporting queries, each one has an explicit index to avoid full table scans on those joins.

**`CHECK` constraints enforce business rules at the database level**, so invalid data is rejected regardless of what application or script is writing to the table:
- `Products.price > 0` and `Products.stock_quantity >= 0` — no free/negative-priced products, stock can never go negative
- `OrderItems.quantity > 0` and `unit_price > 0`
- `Orders.status` restricted to a fixed set of valid values (`pending`, `processing`, `delivered`, `cancelled`)
- `Payments.payment_method` restricted to a fixed set (`card`, `eft`, `cash`, `instant_eft`)

**Foreign key columns are `NOT NULL` by deliberate choice, not by default.** Unlike primary keys (which SQL Server always forces to be `NOT NULL`), foreign keys are nullable unless stated otherwise. Here, an `OrderItems` row is never allowed to exist without a valid order and product attached, so both are explicitly required.

**Script is safely re-runnable.** Each `CREATE TABLE` is preceded by `IF OBJECT_ID(...) IS NOT NULL DROP TABLE`, so the script can be run repeatedly from a clean state without manual cleanup — a common pattern for compatibility with SQL Server versions before `DROP TABLE IF EXISTS` existed.

## What's Included

- Full schema (`CREATE TABLE` statements with keys, constraints, and indexes)
- Sample data across all five tables
- Verification queries demonstrating:
  - `UNION ALL` for row-count checks across tables
  - `LEFT JOIN ... WHERE ... IS NULL` to find orders with no recorded payment
  - A `RANK() OVER (...)` window function ranking customers by total spend

## How to Run

- **Locally:** SQL Server Management Studio (SSMS) or Azure Data Studio

Run the script top to bottom — it drops any existing tables with the same names first, then creates the schema, inserts sample data, and runs the verification queries.

## Planned: Data Modeling Phase

Redesigning this schema as a simple star schema to practice dimensional modeling:

- One fact table (likely `FactOrders` or `FactOrderItems`)
- 2–3 dimension tables (e.g. `DimCustomer`, `DimProduct`, `DimDate`)
- Applying SCD Type 1/2 concepts where relevant (e.g. tracking customer address changes)

## Possible Extensions

- A `Categories` table with a self-referencing `parent_category_id`, to practice recursive CTEs for arbitrary-depth category hierarchies
- A reporting `VIEW` layer summarizing customer lifetime value or monthly sales
- Stored procedures for common operations (e.g. placing an order, wrapped in a transaction to guarantee the order, its items, and the stock update all succeed or fail together)
