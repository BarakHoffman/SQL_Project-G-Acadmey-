--SQL Project

--Creating new panel for exploratory data analysis

select h.SalesOrderID,
       h.OrderDate,
	   year(h.OrderDate) as OrderYear,
	   Month(h.OrderDate) as OrderMonth,
	   h.subtotal,
	   d.OrderQty,
	   d.ProductID,
	   d.UnitPrice,
	   d.UnitPriceDiscount,
	   d.LineTotal,
	   p.[Name],
	   p.StandardCost,
	   d.LineTotal/d.OrderQty - p.StandardCost as UnitProfit,
	   d.LineTotal-(p.StandardCost*d.OrderQty) as LineProfit
	   
					into Panel_Business
from Sales.SalesOrderHeader as h
left join Sales.SalesOrderDetail as d
on h.SalesOrderID = d.SalesOrderID
left join Production.Product as p
on p.ProductID=d.ProductID
--All tables were joined in order to explore and analyse only the products that were sold.

select *
from Panel_Business

--Q.1
--Exploring income and profit per months, in order to examine seasonalness. 
--Income and profit should be analysed per month for every year.

--Income and profit for 2011 (important: starts in May) 
select  OrderMonth,
		sum(linetotal) as Income,
		sum(lineprofit) as Profit		

from Panel_Business
where OrderYear = 2011
group by OrderMonth
order by OrderMonth
--Conclusions:
--Income is increasing between months 6-8 and 9-10. Another increse is in month 12, and we can see that the income is bigger in month 1 of 2012.
--Month 10 is the best seller. There is an increase of income at the beginning of the seasons: Summer,Autumn and Winter.
--Profit is stable among all 8 months of 2011, so there is no loss.
--Sub.Q to explore: why there is no increasing profit when the income significantly increased? for example month 10.
--What products were sold in months 6-8, 9-10? the Top 5 or 10. What is their price and unit profit?

--Income and profit for 2012 (full year) 
select  OrderMonth,
		sum(linetotal) as Income,
		sum(lineprofit) as Profit,
		rank()over(order by sum(linetotal)) as RankOfIncome
from Panel_Business
where OrderYear = 2012
group by OrderMonth
order by OrderMonth
--Conclusions:
--TOP 6 income months are: 6>1>9>7>5>3
--Similar to 2011, there is more income in the beginning of the seasons: Summer (around month 6), Autumn (Month 9) and Winter (Month1).
--There is also incresing income in the beggining of the Spring (around month 3).
--Months 4 and 6 are with negative profits. 
--Month 4 makes sense as there is small income, although month 6 is with the biggest income.
--Sub.Q to explore: what are the products that were sold on these months (4,6)? look at their prices.

--Income and profit for 2013 (full year) 
select  OrderMonth,
		sum(linetotal) as Income,
		sum(lineprofit) as Profit
from Panel_Business
where OrderYear = 2013
group by OrderMonth
order by OrderMonth
--Conclusions:
--No loss.
--TOP 6 income months are: 6>7>10>9>12>3
--Similar to 2012, which is also a full year, there is clear incresing in income in the beginning of every season.
--The second half of the year is more profitable than the first half.
--Sub.Q: is there difference between the top sellers products in the first half of the year and the second half?

--Income and profit for 2014 (important: ends in June) 
select  OrderMonth,
		sum(linetotal) as Income,
		sum(lineprofit) as Profit
from Panel_Business
where OrderYear = 2014
group by OrderMonth
order by OrderMonth
--Conclusions
--No loss, stable profits along the 6 months of work.
--TOP 6 income months are: 3>5>1>4>2>6 (there are only 6 months of work in 2014)
--Similar to 2012 and 2013, there is clear incresing in income in the beginning of the seasons: Spring and Summer.
--Month 6 is the last working month of the company.


--Q.2
--Exploring income and profit per years, in order to examine increasing and decreasing patterns. 

-- Comparing the income and profit for the end of the years 2011-2013 (as 2011 starts in May)
select OrderYear,
		sum(LineTotal) as Income,
		sum(lineprofit) as Profit
	from Panel_Business
	where OrderYear between 2011 and 2013
	and OrderMonth between 7 and 12
	group by OrderYear
	order by Income
--Conclusions
--2013 has the most income and the most profit.

-- Comparing the income and profit for the beginning of the years 2012-2014 (as 2014 ends in June)
select OrderYear,
		sum(LineTotal) as Income,
		sum(lineprofit) as Profit
	from Panel_Business
	where OrderYear between 2012 and 2014
	and OrderMonth between 1 and 6
	group by OrderYear
	order by Profit
--Conclusions
--Income and profits were increased in the beginning of 2014.

--Comparing 2012 and 2013 
select OrderYear,
		sum(LineTotal) as Income,
		sum(lineprofit) as Profit
	from Panel_Business
	where OrderYear between 2012 and 2013
	group by OrderYear
	order by Income
--Conclusions
--2013 has the bigger income and profit.

--Sub.Q to explore: what makes 2013 as the best year in a matter of income and profit?
--What can we learn from the products that were mainly sold in 2013? what about their price?

--Exploring year 2012, months 4 and 6, where there is negative profit

select *
from Panel_Business

--Creating new table for products
select Product.[Name] as ProductName,
	   SC.ProductCategoryID,
	   C.[Name] as CatogoryName,
	   SC.ProductSubcategoryID,
	   SC.[Name] as SubCategoryName
	into Panel_Products
from Production.Product as Product
left join Production.ProductSubcategory as SC
on Product.ProductSubcategoryID = SC.ProductSubcategoryID
left join Production.ProductCategory as C
on C.ProductCategoryID = SC.ProductCategoryID

select*
from Panel_Products

--Looking for nonprofitable products from 2012, months 4 and 6:

select B.[Name],
		P.CatogoryName,
		P.SubCategoryName,
		UnitPrice,
		UnitPriceDiscount,
		LineTotal/OrderQty as 'Unit price after discount',
		StandardCost,
		UnitProfit
from Panel_Business as B
	left join (select Product.[Name] as ProductName,
					   SC.ProductCategoryID,
					   C.[Name] as CatogoryName,
					   SC.ProductSubcategoryID,
					   SC.[Name] as SubCategoryName
				from Production.Product as Product
				left join Production.ProductSubcategory as SC
				on Product.ProductSubcategoryID = SC.ProductSubcategoryID
				left join Production.ProductCategory as C
				on C.ProductCategoryID = SC.ProductCategoryID) as P
	on B.[Name] = P.productname
where OrderYear=2012 and OrderMonth in (4,6)
		and UnitProfit<=0 
order by UnitProfit

--The most nonprofitable products from 04/2012 and 06/2012

with CTE_NoProfit
as (
select  P.CatogoryName,
		P.SubCategoryName,
		B.[Name] as ProductName,
	    B.UnitProfit,
		count(*) as QTY
from Panel_Business as B
		left join (select Product.[Name] as ProductName,
					      SC.ProductCategoryID,
						  C.[Name] as CatogoryName,
						  SC.ProductSubcategoryID,
						  SC.[Name] as SubCategoryName
					from Production.Product as Product
						left join Production.ProductSubcategory as SC
						on Product.ProductSubcategoryID = SC.ProductSubcategoryID
						left join Production.ProductCategory as C
						on C.ProductCategoryID = SC.ProductCategoryID) as P
		 on B.[Name] = P.productname
where OrderYear=2012 and OrderMonth in (4,6)
	and UnitProfit<=0 
group by UnitProfit,B.[Name], SubCategoryName, CatogoryName
)

select top 10 CatogoryName,
		SubCategoryName,
		ProductName,
		UnitProfit*QTY as TotalProfit
from CTE_NoProfit
order by TotalProfit

--Grouping by SubCategory

with CTE_NoProfit
as (
select  P.CatogoryName,
		P.SubCategoryName,
		B.[Name] as ProductName,
	    B.UnitProfit,
		count(*) as QTY
from Panel_Business as B
		left join (select Product.[Name] as ProductName,
					      SC.ProductCategoryID,
						  C.[Name] as CatogoryName,
						  SC.ProductSubcategoryID,
						  SC.[Name] as SubCategoryName
					from Production.Product as Product
						left join Production.ProductSubcategory as SC
						on Product.ProductSubcategoryID = SC.ProductSubcategoryID
						left join Production.ProductCategory as C
						on C.ProductCategoryID = SC.ProductCategoryID) as P
		 on B.[Name] = P.productname
where OrderYear=2012 and OrderMonth in (4,6)
	and UnitProfit<=0 
group by UnitProfit,B.[Name], SubCategoryName, CatogoryName
)

select CatogoryName,
		SubCategoryName,
		sum(UnitProfit*QTY) as TotalProfit
from CTE_NoProfit
group by CatogoryName,
		SubCategoryName
order by TotalProfit
									
--Conclusions:
--Mountain Bikes were the most nonprofitable group  in 04/2012 and 06/2012, they should be priced much higher.


