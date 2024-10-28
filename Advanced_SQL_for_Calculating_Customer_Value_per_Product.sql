USE AdventureWorks2016

-- Calculating the list of customers that had discounts and putting it into a temp table
SELECT DISTINCT CustomerID
INTO #temp_list_of_Customer_with_discounts
FROM panel
WHERE UnitPriceDiscount > 0

-- CALCULATING THE AVERAGE LIFESPAN OF CUSTOMERS THAT GOT DISCOUNTS
WITH CTE_LIST_OF_CUSTOMERS_LIFESPAN_WITH_DISCOUNTS AS (
    SELECT CustomerID,
           DATEDIFF(DAY, MIN(OrderDate), MAX(OrderDate)) AS 'Life time of a client'
    FROM Sales.SalesOrderHeader H
    WHERE CustomerID IN (SELECT CustomerID FROM #temp_list_of_Customer_with_discounts)
    GROUP BY CustomerID
)
SELECT AVG([Life time of a client])
FROM CTE_LIST_OF_CUSTOMERS_LIFESPAN_WITH_DISCOUNTS

-- Calculating the average lifespan of clients that did not get any discount 
WITH CTE_LIST_OF_CUSTOMERS_LIFESPAN_WITHOUT_DISCOUNTS AS (
    SELECT CustomerID,
           DATEDIFF(DAY, MIN(OrderDate), MAX(OrderDate)) AS 'Life time of a client'
    FROM Sales.SalesOrderHeader
    WHERE CustomerID NOT IN (SELECT CustomerID FROM #temp_list_of_Customer_with_discounts)
    GROUP BY CustomerID
)
SELECT AVG([Life time of a client])
FROM CTE_LIST_OF_CUSTOMERS_LIFESPAN_WITHOUT_DISCOUNTS

-- A function to calculate the purchase value
CREATE FUNCTION dbo.Client_Purchase_Value(@CustomerID INT)
RETURNS FLOAT AS
BEGIN
    DECLARE @apv FLOAT
    SET @apv = (SELECT SUM(SubTotal) FROM Sales.SalesOrderHeader WHERE CustomerID = @CustomerID) -- will be faster than using the panel
    RETURN @apv
END

-- A function to calculate the Purchase Frequency
ALTER FUNCTION dbo.Average_Purchase_Frequency(@CustomerID INT)
RETURNS FLOAT
AS
BEGIN
    DECLARE @LIST_OF_DATES TABLE (OrderDate DATE);
    
    INSERT INTO @LIST_OF_DATES (OrderDate)
    SELECT DISTINCT OrderDate
    FROM Sales.SalesOrderHeader
    WHERE SalesOrderID IN (
        SELECT SalesOrderID 
        FROM Sales.SalesOrderDetail
        WHERE CustomerID = @CustomerID
    )

    DECLARE @RESULT FLOAT;

    WITH DateDiffs AS (
        SELECT COALESCE(DATEDIFF(DAY, LAG(OrderDate) OVER (ORDER BY OrderDate), OrderDate), 1) AS DaysBetweenOrders
        FROM @LIST_OF_DATES
    )
    SELECT @RESULT = AVG(CAST(DaysBetweenOrders AS FLOAT))
    FROM DateDiffs;

    RETURN @RESULT;
END 

-- A function to calculate a customer's Life Span
CREATE FUNCTION dbo.Customer_Life_Span(@CustomerID INT)
RETURNS INT
AS
BEGIN
    DECLARE @ls INT
    SET @ls = (SELECT DATEDIFF(DAY, MIN(OrderDate), MAX(OrderDate)) FROM Sales.SalesOrderHeader WHERE CustomerID = @CustomerID)  -- will be faster than using the panel
    RETURN @ls
END

-- A function to calculate the Number of discounts a customer got
CREATE FUNCTION dbo.Num_of_discounts(@CustomerID INT)
RETURNS INT
AS
BEGIN
    DECLARE @co INT
    SET @co = (SELECT COUNT(SalesOrderDetailID)
               FROM panel
               WHERE CustomerID = @CustomerID AND UnitPriceDiscount > 0)
    RETURN @co
END

-- Sum of percentage of discounts per client
CREATE FUNCTION dbo.sum_of_pres_discounts(@CustomerID INT)
RETURNS FLOAT
AS
BEGIN
   DECLARE @sum_dis FLOAT
   SET @sum_dis = (SELECT SUM(UnitPriceDiscount) 
                   FROM Sales.SalesOrderHeader H 
                   JOIN Sales.SalesOrderDetail D ON D.SalesOrderID = H.SalesOrderID
                   WHERE CustomerID = @CustomerID)
    RETURN @sum_dis
END

-- Average of gaps in time (days) per client
CREATE FUNCTION dbo.avg_gap_discount(@CustomerID INT)
RETURNS FLOAT
AS
BEGIN
    DECLARE @LIST_OF_DATES TABLE (OrderDate DATE);
    
    INSERT INTO @LIST_OF_DATES (OrderDate)
    SELECT DISTINCT OrderDate
    FROM Sales.SalesOrderHeader
    WHERE SalesOrderID IN (
        SELECT SalesOrderID 
        FROM Sales.SalesOrderDetail
        WHERE UnitPriceDiscount > 0 AND CustomerID = @CustomerID
    )

    DECLARE @RESULT FLOAT;

    WITH DateDiffs AS (
        SELECT COALESCE(DATEDIFF(DAY, LAG(OrderDate) OVER (ORDER BY OrderDate), OrderDate), 1) AS DaysBetweenOrders
        FROM @LIST_OF_DATES
    )
    SELECT @RESULT = AVG(CAST(DaysBetweenOrders AS FLOAT))
    FROM DateDiffs;

    RETURN @RESULT;
END                                

-- Sum of money saved from discounts
ALTER FUNCTION dbo.sum_money_saved_from_discount(@CustomerID INT)
RETURNS FLOAT
AS
BEGIN
    DECLARE @SUM FLOAT

    SET @SUM = (SELECT SUM((UnitPrice - (UnitPrice * UnitPriceDiscount)) * OrderQty)
    FROM Sales.SalesOrderDetail D 
    JOIN Sales.SalesOrderHeader H ON H.SalesOrderID = D.SalesOrderID
    WHERE CustomerID = @CustomerID AND UnitPriceDiscount > 0)

    RETURN ISNULL(@SUM, 0)
END

-- Average of money saved from every discount
ALTER FUNCTION dbo.avg_money_saved_from_discount(@CustomerID INT)
RETURNS FLOAT
AS
BEGIN
    DECLARE @SUM FLOAT

    SET @SUM = (SELECT AVG((UnitPrice - (UnitPrice * UnitPriceDiscount)) * OrderQty)
    FROM Sales.SalesOrderDetail D 
    JOIN Sales.SalesOrderHeader H ON H.SalesOrderID = D.SalesOrderID
    WHERE CustomerID = @CustomerID AND UnitPriceDiscount > 0)

    RETURN ISNULL(@SUM, 0)
END

-- Number of purchases
CREATE FUNCTION dbo.Num_of_purchase(@CustomerID INT)
RETURNS INT
AS
BEGIN
    DECLARE @co INT
    SET @co = (SELECT COUNT(SalesOrderID)
               FROM Sales.SalesOrderHeader
               WHERE CustomerID = @CustomerID)
    RETURN @co
END

-- Calculating a table for all the clients
SELECT CustomerID,
       dbo.Client_Purchase_Value(CustomerID) AS 'Client Purchase Value',
       dbo.Average_Purchase_Frequency(CustomerID) AS 'Average Purchase Frequency',
       dbo.Customer_Life_Span(CustomerID) AS 'Life Span',
       dbo.Average_Purchase_Value(CustomerID) * dbo.Average_Purchase_Frequency(CustomerID) * dbo.Customer_Life_Span(CustomerID) AS 'LV',
       dbo.Num_of_discounts(CustomerID) AS 'Num of Discounts',
       dbo.avg_gap_discount(CustomerID) AS 'avg_of_gaps_discounts',
       dbo.sum_of_pres_discounts(CustomerID) AS 'sum of discounts percentage',
       dbo.avg_money_saved_from_discount(CustomerID) AS 'avg of money per discounts',
       dbo.sum_money_saved_from_discount(CustomerID) AS 'sum of discounts total'
INTO #panel_of_all_the_customers
FROM Sales.Customer
WHERE CustomerID IN (SELECT CustomerID FROM Sales.SalesOrderHeader)
GROUP BY CustomerID

SELECT *
FROM #panel_of_all_the_customers

-- Calculating for all customers with discounts
SELECT CustomerID,
       dbo.Client_Purchase_Value(CustomerID) AS 'Client Purchase Value',
       dbo.Average_Purchase_Frequency(CustomerID) AS 'Average Purchase Frequency',
       dbo.Customer_Life_Span(CustomerID) AS 'Life Span',
       dbo.Average_Purchase_Value(CustomerID) * dbo.Average_Purchase_Frequency(CustomerID) * dbo.Customer_Life_Span(CustomerID) AS 'LV',
       dbo.Num_of_discounts(CustomerID) AS 'Num of Discounts',
       dbo.avg_gap_discount(CustomerID) AS 'avg_of_gaps_discounts',
       dbo.sum_of_pres_discounts(CustomerID) AS 'sum of discounts percentage',
       dbo.avg_money_saved_from_discount(CustomerID) AS 'avg of money per discounts',
       dbo.sum_money_saved_from_discount(CustomerID) AS 'sum of discounts total'
INTO #panel_of_customers_with_discounts
FROM Sales.Customer
WHERE CustomerID IN (SELECT CustomerID FROM #temp_list_of_Customer_with_discounts)
GROUP BY CustomerID

-- Calculating for all customers without discounts
SELECT CustomerID,
       dbo.Client_Purchase_Value(CustomerID) AS 'Client Purchase Value',
       dbo.Average_Purchase_Frequency(CustomerID) AS 'Average Purchase Frequency',
       dbo.Customer_Life_Span(CustomerID) AS 'Life Span',
       dbo.Average_Purchase_Value(CustomerID) * dbo.Average_Purchase_Frequency(CustomerID) * dbo.Customer_Life_Span(CustomerID) AS 'LV',
       dbo.Num_of_discounts(CustomerID) AS 'Num of Discounts',
       dbo.avg_gap_discount(CustomerID) AS 'avg_of_gaps_discounts',
       dbo.sum_of_pres_discounts(CustomerID) AS 'sum of discounts percentage',
       dbo.avg_money_saved_from_discount(CustomerID) AS 'avg of money per discounts',
       dbo.sum_money_saved_from_discount(CustomerID) AS 'sum of discounts total'
INTO #panel_of_customers_without_discounts
FROM Sales.Customer
WHERE CustomerID NOT IN (SELECT CustomerID FROM #temp_list_of_Customer_with_discounts) 
  AND CustomerID IN (SELECT CustomerID FROM Sales.SalesOrderHeader)
GROUP BY CustomerID

SELECT *
FROM #panel_of_all_the_customers

-- Calculating avg of purchase value of customers with discount vs customers without
SELECT AVG(p.[Client Purchase Value]) AS 'avg with discounts'
FROM #panel_of_customers_with_discounts p

SELECT AVG(p.[Client Purchase Value]) AS 'avg without discounts'
FROM #panel_of_customers_without_discounts p

-- Making a table of customers and subcategory
SELECT CustomerID,
       S.[Name]
INTO #temp_list_categories_and_clients 
FROM Sales.SalesOrderHeader H
JOIN Sales.SalesOrderDetail D ON D.SalesOrderID = H.SalesOrderID
JOIN Production.Product P ON P.ProductID = D.ProductID
JOIN Production.ProductSubcategory S ON S.ProductSubcategoryID = P.ProductSubcategoryID

-- Calculating for each subcategory values of clients (with discount)
SELECT Name,
       AVG([Client Purchase Value]) AS 'avg Client Purchase Value',
       AVG([Life Span]) AS 'avg Life Span',
       AVG([LV]) AS 'avg LV',
       AVG(p.[Num of Discounts]) AS 'avg num of discounts',
       AVG(p.[avg of money per discounts]) AS 'avg money per discount',
       AVG(p.avg_of_gaps_discounts) AS 'avg gap of discounts',
       AVG(p.[Average Purchase Frequency]) AS 'avg of purchase Frequency',
       AVG(p.[sum of discounts percentage]) AS 'avg sum of money saved'
FROM #temp_list_categories_and_clients l
JOIN #panel_of_all_the_customers p ON l.CustomerID = p.CustomerID
WHERE p.CustomerID IN (SELECT CustomerID FROM #temp_list_of_Customer_with_discounts)
GROUP BY Name

-- Calculating for each subcategory values of clients (without discount)
SELECT Name,
       AVG([Client Purchase Value]) AS 'avg Client Purchase Value',
       AVG([Life Span]) AS 'avg Life Span',
       AVG([LV]) AS 'avg LV',
       AVG(p.[Num of Discounts]) AS 'avg num of discounts',
       AVG(p.[avg of money per discounts]) AS 'avg money per discount',
       AVG(p.avg_of_gaps_discounts) AS 'avg gap of discounts',
       AVG(p.[Average Purchase Frequency]) AS 'avg of purchase Frequency',
       AVG(p.[sum of discounts percentage]) AS 'avg sum of money saved'
FROM #temp_list_categories_and_clients l
JOIN #panel_of_all_the_customers p ON l.CustomerID = p.CustomerID
WHERE p.CustomerID NOT IN (SELECT CustomerID FROM #temp_list_of_Customer_with_discounts)
GROUP BY Name