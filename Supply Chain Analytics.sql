### Creating a new table

-- a. Creating fact_act_est table

		CREATE TABLE fact_act_est
		(
        SELECT 
			s.date as date,
			s.fiscal_year as fiscal_year,
			s.product_code as product_code,
			s.customer_code as customer_code,
			s.sold_quantity as sold_quantity,
			f.forecast_quantity as forecast_quantity
        	FROM fact_sales_monthly s
        	LEFT JOIN fact_forecast_monthly f 
        	USING (date, customer_code, product_code)
		)
		UNION
		(
		SELECT 
			f.date as date,
			f.fiscal_year as fiscal_year,
			f.product_code as product_code,
			f.customer_code as customer_code,
			s.sold_quantity as sold_quantity,
			f.forecast_quantity as forecast_quantity
        	FROM fact_forecast_monthly  f
        	LEFT JOIN fact_sales_monthly s 
        	USING (date, customer_code, product_code)
		);


-- b. Setting Null Sold quantity and Null Forecast quantity = 0  

		UPDATE fact_act_est
		SET sold_quantity = 0
		WHERE sold_quantity IS NULL;

		UPDATE fact_act_est
		SET forecast_quantity = 0
		WHERE forecast_quantity IS NULL;

### Generate an aggregated forecast accuracy report for all the customers for FY 2021

		WITH cte1 AS 
		(
		SELECT 
			a.customer_code,
			SUM(a.sold_quantity) as total_sold_qty,
			SUM(a.forecast_quantity) as total_forecast_qty,
			SUM((forecast_quantity - sold_quantity)) as Net_Error,
			SUM((forecast_quantity - sold_quantity))*100/SUM(forecast_quantity) as Net_Error_pct,
			SUM(abs(forecast_quantity - sold_quantity)) as Abs_Net_Error,
			SUM(abs(forecast_quantity - sold_quantity))*100/SUM(forecast_quantity) as Abs_Net_Error_pct
	    FROM fact_act_est a
	    WHERE a.fiscal_year = 2021
	    GROUP BY customer_code	
		)
		SELECT 
			e.*,
			c.customer,
			c.market,
			if(Abs_Net_Error_pct > 100, 0, 100-Abs_Net_Error_pct) as Forecast_Accuracy
		FROM cte1 e
		JOIN dim_customer c
		ON e.customer_code=c.customer_code
		ORDER BY Forecast_Accuracy desc
        

### Generate a report to see which customers' forecast accuracy has dropped  from 2020 to 2021

-- a. Creating Temporary Table of Forecast Accuracy 2021 

		CREATE TEMPORARY TABLE fa_2021
		WITH cte1 AS 
		( 
		SELECT 
			s.customer_code,
	        c.customer as customer_name,
	        c.market,
	        SUM(sold_quantity) as total_sold_qty,
	        SUM(forecast_quantity) as total_forecast_qty,
	        SUM((forecast_quantity - sold_quantity)) as Net_Error,
			SUM((forecast_quantity - sold_quantity))*100/SUM(forecast_quantity) as Net_Error_pct,
			SUM(abs(forecast_quantity - sold_quantity)) as Abs_Net_Error,
			SUM(abs(forecast_quantity - sold_quantity))*100/SUM(forecast_quantity) as Abs_Net_Error_pct
		FROM fact_act_est s
	    JOIN dim_customer c
	    ON s.customer_code = c.customer_code
	    WHERE s.fiscal_year = 2021
		GROUP BY customer_code
		)    
		SELECT 
			*,
			if(Abs_Net_Error_pct > 100, 0, 100-Abs_Net_Error_pct) as Forecast_Accuracy_2021
		FROM cte1 
		ORDER BY Forecast_Accuracy_2021 desc;
	
-- b. Creating Temporary Table of Forecast Accuracy 2020
	
	CREATE TEMPORARY TABLE fa_2020
	WITH cte2 AS 
	( 
		SELECT 
			s.customer_code,
	        c.customer as customer_name,
	        c.market,
	        SUM(sold_quantity) as total_sold_qty,
	        SUM(forecast_quantity) as total_forecast_qty,
	        SUM((forecast_quantity - sold_quantity)) as Net_Error,
			SUM((forecast_quantity - sold_quantity))*100/SUM(forecast_quantity) as Net_Error_pct,
			SUM(abs(forecast_quantity - sold_quantity)) as Abs_Net_Error,
			SUM(abs(forecast_quantity - sold_quantity))*100/SUM(forecast_quantity) as Abs_Net_Error_pct
		FROM fact_act_est s
	    JOIN dim_customer c
	    ON s.customer_code = c.customer_code
	    WHERE s.fiscal_year = 2020
		GROUP BY customer_code
	)    
	SELECT 
		*,
	    if(Abs_Net_Error_pct > 100, 0, 100-Abs_Net_Error_pct) as Forecast_Accuracy_2020
	FROM cte2
	ORDER BY Forecast_Accuracy_2020 desc;
	
-- c. Joining both Temporary tables to get the desired report

	SELECT 
		fa_2021.customer_code,
	    fa_2021.customer_name,
	    fa_2021.market,
	    Forecast_Accuracy_2020,
	    Forecast_Accuracy_2021
	FROM fa_2021 
	JOIN fa_2020 
	ON fa_2021.customer_code=fa_2020.customer_code
	WHERE Forecast_Accuracy_2021 < Forecast_Accuracy_2020
	ORDER BY Forecast_Accuracy_2020 desc


