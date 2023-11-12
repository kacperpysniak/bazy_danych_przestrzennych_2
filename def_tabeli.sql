/* oracle  */
desc FactInternetSales;

/* PostgreSQL  */
\d+ FactInternetSales -- przy pomocy psql command-line tool

select column_name, data_type, character_maximum_length, column_default, is_nullable
from INFORMATION_SCHEMA.COLUMNS where table_name = 'FactInternetSales';

/* MySQL  */
DESCRIBE FactInternetSales;