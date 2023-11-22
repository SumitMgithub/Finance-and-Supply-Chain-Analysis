### Generate a report for TOP MARKETS by net sales for a given financial year

-- a.Creating net_sales VIEW
		
		CREATE VIEW `net_sales` AS	
        
			SELECT 
				*,
				(1-post_invoice_discount_pct)*net_invoice_sales as net_sales
			FROM sales_postinv_discount;
			
-- b. Creating sales_preinv_discount VIEW
		
		CREATE VIEW `sales_preinv_discount` AS
		
			SELECT 
				s.date AS date,
				s.fiscal_year AS fiscal_year,
				s.customer_code AS customer_code,
				c.market AS market,
				s.product_code AS product_code,
				p.product AS product,
				p.variant AS variant,
				s.sold_quantity AS sold_quantity,
				g.gross_price AS gross_price_per_item,
				ROUND((g.gross_price * s.sold_quantity),2) AS gross_price_total,
				pre.pre_invoice_discount_pct AS pre_invoice_discount_pct
		
			FROM fact_sales_monthly s		
			JOIN dim_customer c 
				ON c.customer_code = s.customer_code
			JOIN dim_product p 
				ON s.product_code = p.product_code
			JOIN fact_gross_price g 
				ON g.product_code = s.product_code 
							  AND g.fiscal_year = s.fiscal_year
			JOIN fact_pre_invoice_deductions pre 
				ON pre.customer_code = s.customer_code
				AND pre.fiscal_year = s.fiscal_year
			ORDER BY s.date
		
-- c. Creating sales_postinv_discount VIEW
			
		CREATE VIEW `sales_postinv_discount` AS
		
			SELECT 
				s.date AS date,
				s.fiscal_year AS fiscal_year,
				s.customer_code AS customer_code,
				s.market AS market,
				s.product_code AS product_code,
				s.product AS product,
				s.variant AS variant,
				s.sold_quantity AS sold_quantity,
				s.gross_price_total AS gross_price_total,
				s.pre_invoice_discount_pct AS pre_invoice_discount_pct,
				(s.gross_price_total - (s.pre_invoice_discount_pct * s.gross_price_total)) AS net_invoice_sales,
				(po.discounts_pct + po.other_deductions_pct) AS post_invoice_discount_pct
		 
		   FROM sales_preinv_discount s			
		   JOIN fact_post_invoice_deductions po 
		   ON 
				s.date = po.date
				AND s.product_code = po.product_code
				AND s.customer_code = po.customer_code
                
-- d. Finally generating the required report
		
		SELECT 
			market,
			ROUND(SUM(net_sales)/1000000,2) as net_sales_mn
		FROM net_sales
		WHERE fiscal_year = 2021
		GROUP BY market
		ORDER BY net_sales_mn desc
		LIMIT 5;
	
-- e. Creating Stored Procedure for the same

		CREATE PROCEDURE `get_top_n_markets`(
			in_fiscal_year INT,
			in_top_n INT    
		)
		BEGIN
			SELECT 
				market,
				ROUND(SUM(net_sales)/1000000,2) as net_sales_mn
			FROM net_sales
			WHERE fiscal_year = in_fiscal_year
			GROUP BY market
			ORDER BY net_sales_mn desc
			LIMIT in_top_n; 
		END


### Generate a report for TOP PRODUCTS by net sales for a given financial year

		CREATE PROCEDURE `get_top_n_products` (
		in_fiscal_year int,
	    in_top_n int
		)
		BEGIN
			SELECT 
				product,
				ROUND(SUM(net_sales)/1000000,2) as net_sales_mn
			FROM net_sales 
			WHERE fiscal_year = in_fiscal_year
			GROUP BY product
			ORDER BY net_sales_mn desc
			LIMIT in_top_n;
		END


### Generate a report for TOP CUSTOMERS by net sales for a given financial year

		CREATE PROCEDURE `get_top_n_customers` (
		in_market VARCHAR(40),
	    in_fiscal_year int,
	    in_top_n int    
		)
		BEGIN
			SELECT 
			customer,
			ROUND(SUM(net_sales)/1000000,2) as net_sales_mn
			FROM net_sales s
			JOIN dim_customer c
				ON c.customer_code = s.customer_code 
			WHERE 
				s.fiscal_year = in_fiscal_year AND
				s.market = in_market
			GROUP BY customer
			ORDER BY net_sales_mn desc
			LIMIT in_top_n;
		END
        
### Create a report for FY 2021 for top 10 markets by % net sales
		        
		WITH cte1 AS 
		(
			SELECT 
				customer,
				ROUND(SUM(net_sales)/1000000,2) as net_sales_mn
				FROM net_sales s
				JOIN dim_customer c
					ON c.customer_code = s.customer_code 
				WHERE 
					s.fiscal_year = 2021 
				GROUP BY customer 
		)
		SELECT 
			*,
			net_sales_mn*100/sum(net_sales_mn) over() as pct
		FROM cte1        
		ORDER BY net_sales_mn desc
        
        
### Generate a region wise net sales % breakdown by customers or FY 2021

		WITH cte1 AS 
		(
		SELECT 
			c.customer, 
			c.region,
			ROUND(SUM(net_sales)/1000000,2) as net_sales_mn
			FROM net_sales s
			JOIN dim_customer c
				ON c.customer_code = s.customer_code 
			WHERE 
				s.fiscal_year = 2021 
			GROUP BY c.customer, c.region 	            
		)
		SELECT 
			*,
			net_sales_mn*100/sum(net_sales_mn) over(partition by region) as pct_share_region
		FROM cte1        
		ORDER BY region, net_sales_mn desc

