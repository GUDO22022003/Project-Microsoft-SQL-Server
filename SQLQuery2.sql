select * from Orders
select * from Returns
select * from Managers
select * from profiles


select distinct shipping_mode from Orders

--- Kết hợp 4 bảng
--- Request 1: tìm vùng có hiệu suất kinh doanh tốt nhất --> Dựa trên total profit, total revenue và return rate
	select o.region, m.manager_name, round(sum(o.profit),1,1) as total_profit, round(sum(value),1,1) as total_revenue, 
	round(cast(count(r.order_id) as decimal(10,2))*100/cast(count(o.order_id) as decimal(10,2)),2,1) as return_rate
	from Orders as o
	left join Profiles as p on o.region=p.province
	left join Returns as r on o.order_id=r.order_id
	left join Managers as m on m.manager_name=p.manager
	group by o.region, m.manager_name

--- Request 2: Phân khúc khách hàng mang lại lợi nhuận nhiều nhất và ít trả lại hàng nhất 
	select o.customer_segment, round(sum(o.profit),2,1) as total_profit, 
	round(cast(count(r.order_id) as decimal(10,2))*100/cast(count(o.order_id) as decimal(10,2)),2,1) as return_rate
	from Orders as o left join Returns as r on o.order_id=r.order_id
	group by o.customer_segment
	order by total_profit desc, return_rate asc

--- Request 3: phương thức vận chuyển hiệu quả về cost và time
	With ship as (select order_Date, shipping_date, shipping_mode, round(avg(shipping_cost),2,1) as avg_cost, 
	datediff(day, orders.order_date,orders.shipping_date) as day_ship from Orders 
	group by order_date, shipping_date, shipping_mode)
	select ship.shipping_mode, avg_cost, day_ship from ship
	inner join (
	select ship.shipping_mode, min(ship.day_ship) as min_day_ship from ship
	group by ship.shipping_mode
	) as min_ship
	on min_ship.shipping_mode=ship.shipping_mode and min_ship.min_day_ship=ship.day_ship 
	inner join 
	(
	select ship.shipping_mode, min(ship.avg_cost) as min_cost from ship
	group by ship.shipping_mode) as min_cost
	on min_cost.min_cost=ship.avg_cost and min_cost.shipping_mode=ship.shipping_mode

--- Request 4: tìm mối tương quan giữa chiết khấu và lợi nhuận 
	With discount as (
		select order_id, discount, profit,
		case 
		when discount < 0.05 then '0%-5%'
		when discount between 0.05 and 0.1 then '5%-10%'
		when discount between 0.1 and 0.15 then '10%-15%'
		when discount > 0.15 then '>15%'
		end as discount_rage
		from Orders
		group by order_id, discount, profit
		)
		select discount_rage, round(avg(profit),2,1) as avg_profit from discount
		group by discount_rage

--- Request 5: phân tích RFM (recency, frequency, monetary) để phân loại khách hàng 

		With RFM as 
		( 
		select o.customer_name, datediff(day, max(o.order_Date), getdate()) as Rencency, count(o.order_id) as Frequency, sum(value) as Monetary from orders as o
		group by o.customer_name
		),	--- Recency: tính số ngày kể từ lần mua gần nhất 
			--- Frequency: tính tổng số đơn hàng đặt bởi mỗi khách hàng 
			--- Monetary: tính tổng giá trị đơn hàng của mỗi khách hàng
		RFM_Score as (select cr.customer_name, cr.Rencency, cr.Frequency, cr.Monetary,
		NTILE(5) over (order by cr.Rencency desc) as Rencency_Score,
		NTILE(5) over (order by cr.Frequency desc) as Frequency_Score,
		NTILE(5) over (order by cr.Monetary desc) as Monetary_Score
		from RFM as cr) --- Phân loại khách hàng từ 1-5 trong RFM
		select *, 
		case
		when rc.rencency_score = 5 and rc.Frequency_Score =5 and rc.Monetary_Score =5 then 'Champions'
		when rc.rencency_score >=4 and rc.Frequency_Score >=4 then 'Loyal Customer'
		when rc.rencency_score = 5 and rc.Frequency_Score = 1 then 'Pontential Loyalist'
		when rc.rencency_score <=2 and rc.Frequency_Score >=3  then 'At Risk'
		when rc.rencency_score <=2 and rc.Frequency_Score <=2  then 'Can not lose them'
		else 'Lost'
		End as Customer_segment
		from RFM_Score as rc

--- Request 6: phân tích cohort để đánh giá tỉ lệ giữ chân khách hàng 
	With customer_cohort as 
	( 
	select customer_name, FIRST_VALUE(order_date) over (Partition by customer_name order by order_date asc) as Cohort_date from Orders 
	),--- Xác định cohort của khách hàng dựa trên tháng họ đặt đơn hàng đầu tiên
	Cohort_month as 
	(
	select cc.customer_name, cc.cohort_date, EOMONTH(o.order_date) as cohort_month
	from customer_cohort as cc
	inner join Orders as o on o.customer_name=cc.customer_name
	) --- Xác định ngày&tháng cuối cùng mà khách hàng đặt hàng 
	,
	Cohort_retention as 
	(
	select cm.cohort_date, cm.cohort_month,
	count(distinct cm.customer_name) as cohort_size,
	count(distinct o.customer_name) as Returning_customer
		from cohort_month as cm
		left join Orders as o on o.customer_name=cm.customer_name and cm.cohort_month=EOMONTH(o.order_date)
		group by cm.cohort_date, cm.cohort_month
	) --- Xác định số lượng khách hàng duy nhất trong mỗi cohort và số lượng khách hàng quay lại trong mỗi cohort
	select 
	cr.cohort_date, 
	cr.cohort_month,
	cr.cohort_size,
	cr.returning_customer,
	round((cr.returning_customer*100)/cohort_size,0,1) as retention_rate
	from Cohort_retention as cr --- Xác định tỉ lệ quay lại trong mỗi cohort

--- Request 7: Phân tích mức độ hiệu quả của từng quản lí dựa trên số lượng đơn hàng và tỉ lệ trả lại 
	select m.manager_name, m.manager_level,
	count(distinct o.order_id) as total_order,
	count(distinct r.order_id) as total_return,
	round(count(distinct (cast(r.order_id as decimal(10,2))))*100/count(distinct (cast(o.order_id as decimal(10,2)))),1,1) as return_rate
	from Orders as o
	left join profiles as p on o.province=p.province
	left join returns as r on o.order_id=r.order_id
	left join managers as m on p.manager=m.manager_name
	group by m.manager_name, m.manager_level
	order by total_order desc