use flipkart_project;
show tables;

# Task 1 – Data Cleaning & Preparation
-- 1.1 Identify and Delete Duplicate Order_ID records
-- To identify duplicate (order_id with >1 Count)

select * from flipkart_orders;
SELECT Order_ID, Count(*) as Row_no
FROM flipkart_orders
Group by order_id
Having count(*)>1;

-- 1.2 Replace NULL Traffic_Delay_Min with Average Delay for that Route

select * from flipkart_routes;

Update flipkart_routes r
JOIN (Select route_id, AVG(Traffic_Delay_Min) AS Avg_delay
from flipkart_routes WHERE Traffic_Delay_Min is NOT NULL
Group by Route_id) as Avg_table
on r.route_id = avg_table.Route_id
SET r.Traffic_Delay_Min= avg_table.avg_delay
Where r.Traffic_Delay_Min is NULL;


-- 1.3 Convert all date columns into YYYY-MM-DD format using SQL functions.

UPDATE flipkart_orders
SET 
    order_date = str_to_date(order_date, '%Y-%m-%d'),
    Expected_Delivery_Date = str_to_date(Expected_Delivery_Date, '%Y-%m-%d'),
    Actual_Delivery_Date = str_to_date(Actual_Delivery_Date, '%Y-%m-%d');
    
 UPDATE flipkart_shipmenttracking
SET 
    Checkpoint_time = str_to_date(checkpoint_time, '%Y-%m-%d %H:%i:%s');


select * from flipkart_shipmenttracking;
describe flipkart_orders;
select * from flipkart_orders;

-- 1.4 Ensure that no Actual_Delivery_Date is before Order_Date (flag such records).

SELECT 
    CASE
        WHEN Actual_Delivery_Date < Order_Date THEN 'Invalid'
        ELSE 'Valid'
    END AS Delivery_Flag,
    COUNT(*) AS Total_Orders
FROM flipkart_orders
GROUP BY Delivery_Flag;


# Task 2- Delivery Delay Analysis
-- 2.1 Calculate delivery delay (in days) for each order 

SELECT 
    order_id,
    order_date,
    Expected_Delivery_Date,
    Actual_Delivery_Date,
    DATEDIFF(Actual_Delivery_Date, Expected_Delivery_Date) AS Delivery_Delay_Days
FROM flipkart_orders;

-- 2.2 Find Top 10 delayed routes based on average delay days. 

Select Route_id, 
Avg(DATEDIFF(Actual_Delivery_Date, Expected_Delivery_Date)) AS Average_Delay_Days 
From flipkart_orders
Group by Route_id
Order by Average_delay_days DESC LIMIT 10;

-- 2.3 Use window functions to rank all orders by delay within each warehouse. 

SELECT 
    Warehouse_ID,
    Order_ID,
    Route_ID,
    DATEDIFF(Actual_Delivery_Date, Expected_Delivery_Date) AS Delay_Days,
    RANK() OVER (
        PARTITION BY Warehouse_ID
        ORDER BY DATEDIFF(Actual_Delivery_Date, Expected_Delivery_Date) DESC
    ) AS Delay_Rank
FROM flipkart_orders;


# Task 3- Route Optimization Insights
-- 3.1 For each route, calculate: 
-- ○ Average delivery time (in days). 

SELECT route_id,
ROUND(AVG(DATEDIFF(actual_delivery_date, order_date)),2) AS Avg_delivery_time_days
FROM flipkart_orders
GROUP BY route_id
ORDER BY Avg_delivery_time_days;

-- ○ Average traffic delay. 

Select * from flipkart_routes;
SELECT Route_id, AVG(traffic_delay_min) AS Avg_Traffic_Delay_Min
FROM flipkart_routes
GROUP BY Route_id;

-- ○ Distance-to-time efficiency ratio: Distance_KM / Average_Travel_Time_Min.
 
SELECT Route_ID, Distance_km/Average_travel_time_min as Efficiency_ratio 
FROM flipkart_routes
ORDER BY Efficiency_Ratio ASC;
 
-- 3.2 Identify 3 routes with the worst efficiency ratio. 
 
SELECT 
    Route_ID,
    ROUND(Distance_KM / Average_Travel_Time_Min, 3) AS Efficiency_Ratio
FROM flipkart_routes
ORDER BY Efficiency_Ratio ASC
LIMIT 3;

-- 3.3 Find routes with >20% delayed shipments. 
 
SELECT Route_id, count(*) as Total_Shipment,
SUM(CASE WHEN Actual_Delivery_Date > Expected_Delivery_Date THEN 1 ELSE 0 END) AS Delayed_Shipments,
ROUND((SUM(CASE WHEN Actual_Delivery_Date > Expected_Delivery_Date THEN 1 ELSE 0 
END)/ Count(*))* 100,2) as Delay_Shipment_Percentage
FROM flipkart_orders 
GROUP BY Route_id
HAVING Delay_shipment_percentage >20
ORDER BY Delay_shipment_percentage;
 
-- 3.4 Recommend potential routes for optimization.
SELECT Round(Avg(Distance_km/Average_travel_time_min),3) as Avg_Efficiency_ratio FROM flipkart_routes;

SELECT o.Route_ID, r.Start_Location, r.End_Location,
Round(Avg(datediff(Actual_Delivery_Date,Order_date)),2) AS Avg_Delivery_Time_Days,
Round(Avg(r.Traffic_Delay_Min),2) AS Avg_Traffic_Delay_Min,
Round(Avg(Distance_km/Average_travel_time_min),3) as Efficiency_ratio,
Round((Sum(Case When Actual_Delivery_date > Expected_Delivery_date THEN 1 ELSE 0 END)/ Count(*))*100,2)
AS Delay_Percentage FROM flipkart_orders o
JOIN flipkart_routes r 
ON o.route_id = r.route_id
GROUP BY o.route_id, r.Start_Location, r.End_Location
HAVING Efficiency_ratio < 2.6 AND Delay_Percentage >20
ORDER BY Delay_Percentage DESC;
    
 
# Task 4: Warehouse Performance
-- 4.1 Find the top 3 warehouses with the highest average processing time. 
 
select * from flipkart_warehouses;
 
SELECT Warehouse_ID, Warehouse_Name,
ROUND(AVG(Average_Processing_Time_Min), 2) AS Avg_Processing_Time
FROM flipkart_warehouses
GROUP BY Warehouse_ID, Warehouse_Name
ORDER BY Avg_Processing_Time DESC LIMIT 3;

-- 4.2 Calculate total vs. delayed shipments for each warehouse.

SELECT Warehouse_id, count(*) as Total_shipment,
Sum(case when Actual_Delivery_Date > Expected_Delivery_Date THEN 1 ELSE 0 END) AS Delayed_Shipments,
COUNT(*) - SUM(CASE WHEN Actual_Delivery_Date > Expected_Delivery_Date THEN 1 ELSE 0 END) AS OnTime_Shipment
FROM flipkart_orders 
GROUP BY Warehouse_ID
ORDER BY Delayed_Shipments DESC;

-- 4.3 Use CTEs to find bottleneck warehouses where processing time > global average. 

;With Global_Avg as
(Select Avg(Average_Processing_Time_min) AS Global_Avg_Processing_Time from flipkart_warehouses)
Select w.Warehouse_ID, w.warehouse_name, w.Average_Processing_Time_min, g.Global_Avg_Processing_Time 
FROM flipkart_warehouses w
CROSS JOIN Global_avg g
WHERE w.Average_Processing_Time_Min > g.Global_Avg_Processing_Time;

-- 4.4 Rank warehouses based on on-time delivery percentage.

SELECT Warehouse_id, 
count(*) as Total_Delivery,
SUM(Case When Actual_Delivery_Date <= Expected_Delivery_Date THEN 1 ELSE 0 END) AS OnTime_Delivery,
Round(SUM(Case When Actual_Delivery_Date <= Expected_Delivery_Date THEN 1 ELSE 0 END)* 100 / COUNT(*), 2)
AS On_Time_Delivery_Percentage,
RANK() OVER (ORDER BY ROUND(SUM(CASE WHEN Actual_Delivery_Date <= Expected_Delivery_Date THEN 1 ELSE 0 END)
 * 100 / COUNT(*), 2) DESC) AS Warehouse_Rank
FROM flipkart_orders 
GROUP BY Warehouse_ID
ORDER BY On_Time_Delivery_Percentage DESC;

# Task 5: Delivery Agent Performance
-- 5.1 Rank agents (per route) by on-time delivery percentage  
 
select * from flipkart_deliveryagents;
 
SELECT agent_id, agent_name, route_id, on_time_delivery_percentage, 
RANK() OVER(partition by route_id order by on_time_delivery_percentage desc) as Route_rank
FROM flipkart_deliveryagents
ORDER BY Route_ID, Route_Rank;



-- 5.2 Find agents with on-time % < 80%. 

SELECT agent_id, agent_name, On_Time_Delivery_Percentage
FROM flipkart_deliveryagents
WHERE On_Time_Delivery_Percentage <80
ORDER BY On_Time_Delivery_Percentage;
 
 
-- 5.3 Compare average speed of top 5 vs bottom 5 agents using subqueries.

SELECT Round(AVG(Avg_Speed_KMPH),2) as Top5_Avg_speed
FROM (Select Agent_id, Agent_name, Avg_speed_kmph from flipkart_deliveryagents
ORDER BY Avg_speed_kmph DESC LIMIT 5) AS Top5_Speed;

SELECT Round(AVG(Avg_Speed_KMPH),2) as Bottom5Avg_speed
FROM (Select Agent_id, Agent_name, Avg_speed_kmph from flipkart_deliveryagents
ORDER BY Avg_speed_kmph LIMIT 5) AS Bottom5_speed ;

-- 5.4 Suggest training or workload balancing strategies for low performers 

/* # Training Strategies:
--> Conduct 1-on-1 review sessions focusing on reasons for delay (traffic hotspots, route familiarity, time management).
--> Assign mentors from top-performing agents (on-time > 90%).
--> Conduct route optimization and navigation training to help agents choose faster and more efficient paths.

# Workload Balancing Strategies:
--> Reassign part of congested or long-distance routes from low performers to agents with higher efficiency.
--> Implement rotational delivery scheduling to balance workload during peak demand periods.
--> Distribute deliveries evenly based on agents’ average speed and years of experience to ensure fair workload. */

# Task 6: Shipment Tracking Analytics
-- 6.1  For each order, list the last checkpoint and time.

select * from flipkart_shipmenttracking;

SELECT order_id, checkpoint, checkpoint_time
FROM ( Select order_id, checkpoint, checkpoint_time,
ROW_NUMBER() OVER (PARTITION BY order_ID ORDER BY Checkpoint_Time DESC) AS RowNumber
FROM flipkart_shipmenttracking) as Ranked
WHERE RowNumber =1;

-- 6.2 Find the most common delay reasons (excluding None). 

SELECT Delay_reason,
Count(*) as Delay_Reason_count
FROM flipkart_shipmenttracking
WHERE delay_reason IS NOT NULL
AND Delay_Reason <> 'None'
Group by Delay_reason
Order by Delay_Reason_count DESC;

-- 6.3 Identify orders with >2 delayed checkpoints 

SELECT order_id, count(*) as Delayed_checkpoints
FROM flipkart_shipmenttracking
WHERE Delay_Minutes > 0
GROUP BY order_id
HAVING Count(*) >2
ORDER BY Delayed_Checkpoints DESC;

# Task 7: Advanced KPI Reporting
-- Calculate KPIs using SQL queries:
-- 7.1 Average Delivery Delay per Region (Start_Location)

Select * from flipkart_orders;
SELECT r.start_location as Region,
ROUND(AVG(DATEDIFF(o.Actual_Delivery_Date, o.Expected_Delivery_Date)), 2) AS Avg_Delivery_Delay_Days
FROM flipkart_orders o
JOIN flipkart_routes r 
ON o.Route_ID = r.Route_ID
GROUP BY r.Start_Location
ORDER BY Avg_Delivery_Delay_Days DESC;

-- 7.2 On-Time Delivery % = (Total On-Time Deliveries / Total Deliveries) * 100.

SELECT r.start_location as Region, 
Count(*) as Total_Deliveries,
SUM(Case When Actual_Delivery_Date <= Expected_Delivery_Date THEN 1 ELSE 0 END) AS Total_OnTime_Deliveries,
Round(SUM(Case When Actual_Delivery_Date <= Expected_Delivery_Date THEN 1 ELSE 0 END)/Count(*)*100,2)
As On_Time_Delivery_Percentage
From flipkart_orders o
JOIN flipkart_routes r
ON o.Route_ID = r.Route_ID
GROUP BY r.Start_Location
ORDER BY On_Time_Delivery_Percentage DESC;


-- 7.3 Average Traffic Delay per Route.

SELECT 
    Route_ID,
    ROUND(AVG(Traffic_Delay_Min), 2) AS Avg_Traffic_Delay_Min
FROM flipkart_routes
GROUP BY Route_ID
ORDER BY Avg_Traffic_Delay_Min DESC;

-- Combined KPI
SELECT r.start_location as Region,
ROUND(AVG(DATEDIFF(o.Actual_Delivery_Date, o.Expected_Delivery_Date)), 2) AS Avg_Delivery_Delay_Days,
Round(SUM(Case When Actual_Delivery_Date <= Expected_Delivery_Date THEN 1 ELSE 0 END)/Count(*)*100,2)
As On_Time_Delivery_Percentage,
ROUND(AVG(Traffic_Delay_Min), 2) AS Avg_Traffic_Delay_Min
FROM flipkart_orders o
JOIN flipkart_routes r
ON o.Route_ID = r.Route_ID
GROUP BY r.Start_Location;