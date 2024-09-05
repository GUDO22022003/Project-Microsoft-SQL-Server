select * from Managers
select * from Orders
select * from Profiles
select * from returns

--- tính tổng doanh thu theo tháng năm và tháng 
select year(order_date) as "năm" , month(order_date) as "tháng" , round(sum(value),0) as total_revenue from Orders
group by year(order_date), month(order_date)
order by "năm", "tháng"

--- tính số đơn hàng phân theo phương thức vận chuyển --> Xem xét loại phương thức vận chuyển nào được ưu tiên nhất
select shipping_mode as "phương thức vận chuyển", count(order_id) as "tổng đơn hàng" from Orders
group by shipping_mode 
order by "tổng đơn hàng" desc

--- tính đơn hàng, doanh thu và chi phí theo province và region
select province, region, count(order_id) as total_order, round(sum(value),0) as total_value, round(sum(profit),0) as total_profit from Orders
group by province, region 
order by province

--- Request 2: Tỉ lệ trả hàng theo sản phẩm --> xác định loại sản phẩm nào có tỉ lệ trả hàng cao nhất
	-- tính tổng số đơn hàng được đặt phân theo product_category
	select product_category, count(order_id) as total_order into B from Orders
	group by product_category
	order by total_order desc
		--tính tổng số đơn hàng trả lại theo product_category
	select o.product_category, count(r.order_id) as total_order_return into A from orders as o
	join returns as r
	on r.order_id=o.order_id
	group by o.product_category
	-- Tính tỉ lệ đơn hàng trả lại 
	select a.product_category, round(a.total_order_return*100/b.total_order,1,1) as return_rate from A as a
	join B as b
	on a.product_category = b.product_category
	--> sản phẩm furniture có tỉ lệ trả hàng cao nhất: 11%

--- Request 3:phân tích doanh thu theo mức ưu tiên đơn hàng --> xem mức ưu tiên có ảnh hưởng đến doanh thu hay không
	-- Tính tổng doanh thu cho mỗi mức ưu tiên
	select order_priority, round(sum(value),1,1) as total_revenue from orders
	group by order_priority
	order by total_revenue desc
	---> mức ưu tiên là low thì có tổng doanh thu cao nhất 

	
--- Request 4: xác định khách hàng có doanh thu cao nhất theo vùng 
	-- tính tổng doanh thu cho mỗi khách hàng 
	WITH RankedCustomerRevenue AS (
	SELECT Region, Customer_name, SUM(Value) AS CustomerRevenue,
	ROW_NUMBER() OVER (PARTITION BY Region ORDER BY SUM(Value) DESC) AS Rank
	FROM Orders
	GROUP BY Region, Customer_name)
	SELECT Region, Customer_name, CustomerRevenue
	FROM RankedCustomerRevenue
	order by region

	select * from orders
select * from returns

--- request 5: tính tỉ lệ hoàn trả đơn hàng theo từng phân khúc

With A as (select customer_segment, count(r.order_id) as total_Return from returns as r 
join orders as o on o.order_id = r.order_id group by customer_segment), 
B as (select customer_segment, count(order_id) as total_order from orders group by customer_segment)
select a.Customer_segment, ROUND(CAST(total_Return AS DECIMAL(10,2)) * 100 / CAST(total_order AS DECIMAL(10,2)),2,1) as return_Rate from A left join B
on a.customer_segment=b.customer_segment

--- request 6: tính tỉ lệ hoàn trả đơn hàng theo mỗi vùng (region)
with A as (select region, count(r.order_id) as total_return from returns as r join orders as o on o.order_id=r.order_id group by region), 
B as (Select region, count(order_id) total_order from orders group by region)
select a.region, round(cast(total_return as decimal(10,2))*100/cast(total_order as decimal (10,2)),2) as return_rate from A left join B
on a.region = b.region


--- Request 7: tìm sản phẩm có tổng số đơn hàng trả cao nhất trong mỗi phân khúc khách hàng 
With A as (select o.customer_segment, o.product_name, count(r.order_id) as total_return from orders as o
join returns as r 
on o.order_id=r.order_id
group by o.customer_segment, o.product_name) --- Tính tổng đơn hàng trả lại 
select a.customer_segment, a.product_name, total_return from A
inner join (
    SELECT
        Customer_segment,
        MAX(total_return) AS MaxReturnedOrders
    FROM A
    GROUP BY Customer_segment
) AS max_returned_orders 
    ON a.Customer_segment = max_returned_orders.Customer_segment 
    AND a.total_return = max_returned_orders.MaxReturnedOrders
ORDER BY a.Customer_segment

--- Request 7: tìm khách hàng có đơn hàng trả lại nhiều hơn mức trung bình của nhóm khách hàng có cùng phân khúc
	With A as (select o.customer_name, o.customer_segment, count(r.order_id) as total_return from Orders as o 
	left join Returns as r on r.order_id=o.order_id group by o.customer_name, o.customer_segment),
	B as (select a.customer_segment, avg(total_return) as avg_return from A group by a.customer_segment)
	select a.customer_name, a.customer_segment, a.total_return from A as a left join B as b 
	on a.customer_segment=b.customer_segment
	where total_return > avg_return

--- Request 8: Tìm sản phẩm có tỉ lệ trả cao nhất của mỗi vùng 
		With A as (select region, product_name, round(count(r.ordeR_id)*100/count(o.order_id),2,1) as return_rate
	from Orders as o 
	left join Returns as r on o.order_id=r.order_id group by region, product_name ) --- tìm vùng, tên sản phẩm, tỉ lệ trả đơn hàng
	Select a.region, a.product_name, return_rate from A
	inner join 
	(
	select region, max(return_rate) as max_return from A group by region
	) as max_return_order
	on a.region= max_return_order.region and a.return_rate= max_return_order.max_return
	order by region asc --- tìm đơn sản phẩm của mỗi vùng có tỉ lệ trả cao nhất

--- Request 9: Tính tổng lợi nhuận từ các đơn hàng được trả lại, phân loại theo ưu tiên của đơn hàng 
	select o.order_priority, round(sum(profit),2,1) as total_profit from Orders as o left join Returns as r
	on o.order_id = r.order_id
	group by o.order_priority
	order by total_profit desc

--- Request 10: Tìm những đơn hàng được trả lại có giá trị cao nhất trong mỗi tháng
	With A as (
	select year(o.order_Date) as "năm", MONTH(o.order_date) as "tháng", o.order_id, round(sum(Value),0,1) as total_value from Orders as o 
	inner join Returns as r on r.order_id=o.order_id
	group by year(o.order_Date), MONTH(o.order_date), o.order_id
	)
	select a."năm", a."tháng", order_id, total_value from A 
	inner join (select "năm", "tháng", max(total_value) as max_total_value from A group by "năm", "tháng") as max_value
	on max_value."năm"=a."năm" and max_value."tháng"=a."tháng" and max_value.max_total_value=a.total_value
	order by "năm", "tháng" asc
	