/*
 * * * * * * * * * * * * * * * *
 * Automatic schema inference  *
 * * * * * * * * * * * * * * * *

Since data is stored in the Parquet file format, automatic schema inference is available. You can easily query the data without listing the data types of all columns in the files. You also can use the virtual column mechanism and the filepath function to filter out a certain subset of files.

Let's first get familiar with the NYC Taxi data by running the following query. */

SELECT TOP 100 * FROM
    OPENROWSET(
        BULK 'https://<azrawStorageAccount>.dfs.core.windows.net/raw/yellow/puYear=*/puMonth=*/*.parquet',
        FORMAT='PARQUET'
    )
    AS [nyc];

    /*
 * * * * * * * * * * * * * * * * * * * * * * * * * *
 * Time series, seasonality, and outlier analysis  *
 * * * * * * * * * * * * * * * * * * * * * * * * * *
You can easily summarize the yearly number of taxi rides by using the following query. */

SELECT
    YEAR(tpepPickupDateTime) AS current_year,
    COUNT(*) AS rides_per_year
FROM
    OPENROWSET(
        BULK 'https://<azrawStorageAccount>.dfs.core.windows.net/raw/yellow/puYear=*/puMonth=*/*.parquet',
        FORMAT='PARQUET'
    ) AS [nyc]
--WHERE nyc.filepath(1) >= '2009' AND nyc.filepath(1) <= '2022'
GROUP BY YEAR(tpepPickupDateTime)
ORDER BY 1 ASC;

/* The data can be visualized in Synapse Studio by switching from the Table to the Chart view.
You can choose among different chart types, such as Area, Bar, Column, Line, Pie, and Scatter.
In this case, plot the Column chart with the Category column set to current_year.

From this visualization, a trend of a decreasing number of rides over years can be clearly seen.
Presumably, this decrease is due to the recent increased popularity of ride-sharing companies.
*/

/* Next, let's focus the analysis on a single year, for example, 2016.
The following query returns the daily number of rides during that year. */

SELECT
    CAST([tpepPickupDateTime] AS DATE) AS [current_day],
    COUNT(*) as rides_per_day
FROM
    OPENROWSET(
        BULK 'https://<azrawStorageAccount>.dfs.core.windows.net/raw/yellow/puYear=*/puMonth=*/*.parquet',
        FORMAT='PARQUET'
    ) AS [nyc]
WHERE nyc.filepath(1) = '2022'
GROUP BY CAST([tpepPickupDateTime] AS DATE)
ORDER BY 1 ASC;

