WITH OrdersCount AS (
    SELECT 
        OrderDate,
        COUNT(*) AS Orders_cnt 
    FROM AdventureWorksDW2019.dbo.FactInternetSales 
    GROUP BY OrderDate 
    HAVING COUNT(*) < 100
)

SELECT 
    RankedProducts.OrderDate,
    RankedProducts.UnitPrice
FROM (
    SELECT 
        OrderDate,
        UnitPrice,
        ROW_NUMBER() OVER (PARTITION BY OrderDate ORDER BY UnitPrice DESC) AS PriceRank
    FROM AdventureWorksDW2019.dbo.FactInternetSales
) AS RankedProducts
JOIN OrdersCount ON RankedProducts.OrderDate = OrdersCount.OrderDate
WHERE RankedProducts.PriceRank <= 3;
