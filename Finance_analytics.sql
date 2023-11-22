-- Finance Analytics

-- a. Get customer code for Croma india
	SELECT * FROM dim_customer 
    WHERE customer like "%croma%" AND market="india";

-- b. Get all the sales transaction data from fact_sales_monthly table for that customer(croma: 90002002) in the fiscal_year 2021
	SELECT * FROM fact_sales_monthly 
	WHERE 
            customer_code=90002002 AND
            YEAR(DATE_ADD(date, INTERVAL 4 MONTH))=2021 
	ORDER BY date asc
	LIMIT 100000;

-- c. create a function 'get_fiscal_year' to get fiscal year by passing the date
	CREATE FUNCTION `get_fiscal_year`(calendar_date DATE) 
	RETURNS int
    	DETERMINISTIC
	BEGIN
        	DECLARE fiscal_year INT;
        	SET fiscal_year = YEAR(DATE_ADD(calendar_date, INTERVAL 4 MONTH));
        	RETURN fiscal_year;
	END


### Create a report of individual product sales (aggregated on a monthly basis at the product code level) for Chroma India customer for FY = 2021

	SELECT 
    	    s.date, s.product_code, 
            p.product, p.variant, 
            s.sold_quantity, 
            g.gross_price,
            ROUND(s.sold_quantity*g.gross_price,2) as gross_price_total
	FROM fact_sales_monthly s
	JOIN dim_product p
            ON s.product_code=p.product_code
	JOIN fact_gross_price g
            ON g.fiscal_year=get_fiscal_year(s.date)
			AND g.product_code=s.product_code
	WHERE 
    	    customer_code=90002002 AND 
            get_fiscal_year(s.date)=2021     
	ORDER BY date asc;


### Generate monthly gross sales report for Croma India for all the years

	SELECT 
            s.date, 
    	    SUM(ROUND(s.sold_quantity*g.gross_price,2)) as monthly_sales
	FROM fact_sales_monthly s
	JOIN fact_gross_price g
        ON g.fiscal_year=get_fiscal_year(s.date) AND g.product_code=s.product_code
	WHERE 
             customer_code=90002002
	GROUP BY date;


### Generate monthly gross sales report for any customer using stored procedure

	CREATE PROCEDURE `get_monthly_gross_sales_for_customer`(
        	c_code INT
	)
	BEGIN
		SELECT 
			s.date, 
			SUM(ROUND(s.sold_quantity*g.gross_price,2)) as gross_price_total
		FROM fact_sales_monthly s
		JOIN fact_gross_price g
			ON g.fiscal_year=get_fiscal_year(s.date)
			AND g.product_code=s.product_code
		WHERE s.customer_code = c_code 
		GROUP BY s.date
		ORDER BY s.date;
	END


### Stored Procedure: To determine Market Badge

--  Write a stored procedure that can determine market badge. i.e. if total sold quantity > 5 million that market is considered "Gold" else "Silver"
	CREATE PROCEDURE `get_market_badge`(
        	IN in_market VARCHAR(20),
        	IN in_fiscal_year YEAR,
        	OUT out_badge VARCHAR(10)
	)
	BEGIN
             DECLARE qty INT DEFAULT 0;
    
    	     # Set Default market = India
    	     IF in_market = "" THEN
                  SET in_market="India";
             END IF;
    
    	     # Retrieve total sold quantity for a given market in a given FY
             SELECT 
                  SUM(sold_quantity) INTO qty
             FROM fact_sales_monthly s
             JOIN dim_customer c
             ON s.customer_code=c.customer_code
             WHERE 
                  get_fiscal_year(s.date)=in_fiscal_year AND
                  c.market=in_market
			 GROUP BY c.market;
        
             # Determine Market Badge
             IF qty > 5000000 THEN
                  SET out_badge = 'Gold';
             ELSE
                  SET out_badge = 'Silver';
             END IF;
	END
    
    
### Write a stored procedure for getting top n products in each division by their quantities sold in a given FY

		CREATE PROCEDURE `get_top_n_products_per_division_by_qty_sold` (
		in_fiscal_year INT,
		in_top_n INT
		)
		BEGIN
			WITH 
			cte1 AS 
				(
					SELECT 
						p.division,
						p.product,
						sum(sold_quantity) as total_qty
					FROM dim_product p
					JOIN fact_sales_monthly s
					ON p.product_code = s.product_code
					WHERE fiscal_year=in_fiscal_year
					GROUP BY p.product, p.division
				),
			cte2 AS
				(
					SELECT 
						*,
						dense_rank() over(partition by division order by total_qty desc) as d_rnk
					FROM cte1
				)
			SELECT 
				* 
			FROM cte2
			WHERE d_rnk <=in_top_n;
		END
	

### Retrieve top 2 markets in every region by their gross sales amount in financial year 2021
		
		WITH
		cte1 AS
	    (
			SELECT 
				c.market,
				c.region,
				ROUND(SUM(gross_price_total/1000000),2) as gross_price_mn
			FROM dim_customer c
			JOIN gross_sales s
			ON c.customer_code = s.customer_code
			GROUP BY c.region,c.market
		),
		cte2 AS
	    (
			SELECT
				*,
				dense_rank() over(partition by region order by gross_price_mn desc) AS rnk
			FROM cte1
		)
		SELECT * FROM cte2 WHERE rnk<=2;