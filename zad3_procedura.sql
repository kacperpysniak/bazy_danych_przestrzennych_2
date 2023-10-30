USE AdventureWorksDW2019;
GO

CREATE PROCEDURE GetCurrencyRatesAdventureWorksDW2019
    @YearsAgo INT
AS
BEGIN
    DECLARE @CutoffDate DATE;
    SET @CutoffDate = DATEADD(YEAR, -@YearsAgo, GETDATE());
    
    SELECT cr.*
    FROM dbo.FactCurrencyRate cr
    INNER JOIN dbo.DimCurrency dc ON cr.CurrencyKey = dc.CurrencyKey
    WHERE (dc.CurrencyAlternateKey = 'GBP' OR dc.CurrencyAlternateKey = 'EUR')
    AND cr.Date <= @CutoffDate;
END;
GO