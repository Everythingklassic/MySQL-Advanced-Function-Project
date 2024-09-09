-- EXPLORATORY DATA ANALYSIS WITH WINDOW FUNCTIONS
-- CREATING VIEWS,PROCEDURE AND FUNCTIONS USING CHINOOK DATA
-- 1. Create a view help your colleagues see which countries have the most invoices
-- 2. Create a view help your colleagues see which cities have the most valuable customer base
-- 3. Create a view to identify the top spending customer in each country. Order the results from highest spent to lowest.
-- 4. Create a view to show the top 5 selling artists of the top selling genre
-- If there are multiple genres that all sell well, give the top 5 of all top selling genres collectively
-- 5. Create a stored procedure that, when provided with an InvoiceId, 
-- retrieves all orders and corresponding order items acquired by the customer who placed the specified order
-- 6. Create a stored procedure to retrieve sales data from a given date range
-- 7. Create a stored function to calculate the average invoice amount for a given country
-- 8. Create a stored function that returns the best-selling artist in a specified genre
-- 9. Create a stored function to calculate the total amount that customer spent with the company
-- 10. Create a stored function to find the average song length for an album
-- 11. Create a stored function to return the most popular genre for a given country

-- Country with most invoice
CREATE VIEW total_invoice_by_country AS 
SELECT BillingCountry,
COUNT(InvoiceId) Total_invoice
FROM invoice
GROUP BY BillingCountry
ORDER BY Total_invoice DESC;

SELECT *
FROM total_invoice_by_country;

-- Cities with the most valuable customer base
CREATE VIEW Customer_base_by_city AS
-- creating with a window function
SELECT DISTINCT 
    BillingCity,
    BillingCountry,
    COUNT(CustomerId) OVER (PARTITION BY BillingCity, BillingCountry) AS Total_customers,
    SUM(Total) OVER (PARTITION BY BillingCity, BillingCountry) AS Total_purchase
FROM invoice
ORDER BY Total_purchase DESC;
    
-- creating the same view without window function
SELECT BillingCity,
BillingCountry,
COUNT(CustomerId) Total_Customer,
SUM(Total) Total_Purchase
FROM invoice
GROUP BY 1,2
ORDER BY 4 ;

SELECT*
FROM customer_base_by_city;

-- Top spending customers by each country
CREATE VIEW Total_purchase_by_customer AS
SELECT 
    inv.BillingCountry,
    inv.CustomerId,
    cus.FirstName,
    cus.LastName,
    SUM(inv.Total) AS Total_purchase,
    RANK() OVER (PARTITION BY inv.BillingCountry ORDER BY SUM(inv.Total) DESC) AS rank_within_country
FROM invoice AS inv
JOIN customer AS cus
    ON inv.CustomerId = cus.CustomerId
GROUP BY inv.BillingCountry, inv.CustomerId, cus.FirstName, cus.LastName
ORDER BY Total_purchase DESC;

SELECT *
FROM total_purchase_by_customer;

-- 5 Top selling artist of thE 5 top selling genre
SELECT *
FROM track;

SELECT DISTINCT GenreId
FROM track;

CREATE VIEW TopArtistsInTop5GenresWithRank AS
WITH RankedGenres AS (
    -- Subquery to rank genres based on total sales
    SELECT 
        trk.GenreId,
        gen.Name AS Genre_Name,
        SUM(trk.UnitPrice) AS Total_Genre_Sales,
        RANK() OVER (ORDER BY SUM(trk.UnitPrice) DESC) AS genre_rank
    FROM track trk
    JOIN genre gen 
        ON trk.GenreId = gen.GenreId
    GROUP BY trk.GenreId, gen.Name
),
Top5Genres AS (
    -- Select only the top 5 genres based on rank
    SELECT GenreId, Genre_Name, Total_Genre_Sales
    FROM RankedGenres
    WHERE genre_rank <= 5
),
RankedArtists AS (
    -- Rank artists within the top 5 genres
    SELECT 
        art.ArtistId,
        art.Name AS Artist_Name,
        gen.GenreId,
        gen.Name AS Genre_Name,
        SUM(trk.UnitPrice) AS Total_Artist_Sales,
        RANK() OVER (PARTITION BY gen.GenreId ORDER BY SUM(trk.UnitPrice) DESC) AS artist_rank
    FROM album alb
    JOIN artist art
        ON alb.ArtistId = art.ArtistId
    JOIN track trk
        ON alb.AlbumId = trk.AlbumId
    JOIN genre gen
        ON trk.GenreId = gen.GenreId
    WHERE trk.GenreId IN (SELECT GenreId FROM Top5Genres) -- Only include top 5 genres
    GROUP BY art.ArtistId, art.Name, gen.GenreId, gen.Name
)
SELECT *
FROM RankedArtists
WHERE artist_rank <= 5 -- Select only the top 5 artists in each genre
ORDER BY Total_Artist_Sales DESC;


SELECT * 
FROM TopArtistsInTop5GenresWithRank;

-- Creating a store procedure retrieve orders,order item by customer with invoiceid

SELECT *
FROM invoice;

SELECT *
FROM invoiceline;

SELECT *
FROM customer;

DELIMITER $$

CREATE PROCEDURE GetInvoiceDetailsByInvoiceId(
    IN input_invoiceid INT
)
BEGIN
    -- Select detailed information based on the invoice ID
    SELECT 
        il.TrackId,
        il.Quantity,
        inv.CustomerId,
        cus.FirstName,
        cus.LastName
    FROM InvoiceLine il
    JOIN Invoice inv
        ON il.InvoiceId = inv.InvoiceId
    JOIN Customer cus
        ON inv.CustomerId = cus.CustomerId
    WHERE inv.InvoiceId = input_invoiceid;
END$$

DELIMITER ;

-- Call the stored procedure with a specific invoice ID
CALL GetInvoiceDetailsByInvoiceId(20);

-- Sales Data from 2025-01-01 to 2025-12-31

SELECT DISTINCT 
    InvoiceDate,
    CAST(InvoiceDate AS DATE) AS Date
FROM invoice
WHERE YEAR(InvoiceDate) = 2025;

DELIMITER $$

CREATE PROCEDURE Future_Sales()
BEGIN
    SELECT 
        cus.FirstName,
        cus.LastName,
        ivn.InvoiceId,
        CAST(ivn.InvoiceDate AS DATE) AS Date
    FROM invoice ivn
    JOIN customer cus
        ON ivn.CustomerId = cus.CustomerId
    WHERE YEAR(ivn.InvoiceDate) = 2025;
END$$

DELIMITER ;

CALL Future_Sales();

-- Average invoice amount for each country

DELIMITER $$

CREATE FUNCTION GetAverageInvoiceByCountry(country VARCHAR(100))
RETURNS DECIMAL(10, 2) 
DETERMINISTIC
BEGIN
    DECLARE avg_invoice DECIMAL(10, 2);
    
    -- Calculate the average invoice total for the specified country
    SELECT AVG(Total) 
    INTO avg_invoice
    FROM invoice
    WHERE BillingCountry = country;
    
    -- Return the average invoice amount
    RETURN avg_invoice;
END$$

DELIMITER ;

-- Get the average invoice for the USA
SELECT GetAverageInvoiceByCountry('USA');

-- Get the average invoice for Canada
SELECT GetAverageInvoiceByCountry('Canada');

-- Best selling artist by genres

DELIMITER $$

CREATE FUNCTION GetBestSellingArtistByGenre(genre_name VARCHAR(100))
RETURNS VARCHAR(100)
DETERMINISTIC
BEGIN
    DECLARE best_artist VARCHAR(100);
    
    -- Calculate the best-selling artist in the specified genre
    SELECT art.Name
    INTO best_artist
    FROM artist art
    JOIN album alb
        ON art.ArtistId = alb.ArtistId
    JOIN track trk
        ON alb.AlbumId = trk.AlbumId
    JOIN genre gen
        ON trk.GenreId = gen.GenreId
    JOIN invoiceline il
        ON trk.TrackId = il.TrackId
    WHERE gen.Name = genre_name
    GROUP BY art.ArtistId, art.Name
    ORDER BY SUM(il.UnitPrice * il.Quantity) DESC
    LIMIT 1;
    
    -- Return the best-selling artist
    RETURN best_artist;
END$$

DELIMITER ;

-- Find the best-selling artist in the "Rock" genre
SELECT GetBestSellingArtistByGenre('Rock');

-- Find the best-selling artist in the "Jazz" genre
SELECT GetBestSellingArtistByGenre('Jazz');


-- Total amount customer spend with company

DELIMITER $$

CREATE FUNCTION GetCustomerTotalSpendById(
    input_customer_id INT
)
RETURNS VARCHAR(255)
DETERMINISTIC
BEGIN
    DECLARE last_name VARCHAR(100);
    DECLARE first_name VARCHAR(100);
    DECLARE company_name VARCHAR(100);
    DECLARE total_spent DECIMAL(10, 2);
    DECLARE result_message VARCHAR(255);

    -- Initialize total_spent to 0
    SET total_spent = 0;

    -- Retrieve customer details and calculate total money spent
    SELECT 
        cus.LastName,
        cus.FirstName,
        cus.Company,
        IFNULL(SUM(inv.Total), 0) AS total_money_spent
    INTO 
        last_name, 
        first_name, 
        company_name, 
        total_spent
    FROM customer cus
    JOIN invoice inv
        ON cus.CustomerId = inv.CustomerId
    WHERE cus.CustomerId = input_customer_id
      AND cus.Company IS NOT NULL
    GROUP BY cus.Company, cus.CustomerId;

    -- If no customer details are found, return an error message
    IF last_name IS NULL THEN
        SET result_message = 'Customer not found or no company specified.';
        RETURN result_message;
    END IF;

    -- Return the customer name, company, and total money spent
    SET result_message = CONCAT(
        'Customer: ', first_name, ' ', last_name, 
        ', Company: ', company_name, 
        ', Total Money Spent: $', total_spent
    );
    
    RETURN result_message;
END$$

DELIMITER ;

-- Example: Retrieve details for customer with ID 1
SELECT GetCustomerTotalSpendById(1);

-- Average song length for an album

SELECT alb.AlbumId,
alb.Title,
AVG(trk.Milliseconds) avg_song_length
FROM album alb
JOIN track trk
ON alb.AlbumId = trk.AlbumId
GROUP BY 1;

DELIMITER $$

CREATE FUNCTION GetAlbumInfoAndAvgSongLength(
    input_album_id INT
)
RETURNS VARCHAR(255)
DETERMINISTIC
BEGIN
    DECLARE album_title VARCHAR(255);
    DECLARE avg_song_length DECIMAL(10, 2);
    DECLARE result_message VARCHAR(255);

    -- Retrieve album title and average song length
    SELECT 
        alb.Title, 
        IFNULL(AVG(trk.Milliseconds), 0)
    INTO 
        album_title, 
        avg_song_length
    FROM album alb
    JOIN track trk
        ON alb.AlbumId = trk.AlbumId
    WHERE alb.AlbumId = input_album_id
    GROUP BY alb.AlbumId;

    -- If album_title is NULL, return an error message
    IF album_title IS NULL THEN
        RETURN 'Album not found.';
    END IF;

    -- Construct and return the result message
    SET result_message = CONCAT(
        'AlbumId: ', input_album_id, 
        ', Title: ', album_title, 
        ', Average Song Length: ', avg_song_length, ' milliseconds'
    );
    
    RETURN result_message;
END$$

DELIMITER ;

-- Example: Retrieve details for album with ID 1
SELECT GetAlbumInfoAndAvgSongLength(1);

-- Most popular genre for a given country

DELIMITER $$

CREATE FUNCTION GetMostPopularGenreByCountry(
    input_country VARCHAR(100)
)
RETURNS VARCHAR(255)
DETERMINISTIC
BEGIN
    DECLARE popular_genre VARCHAR(255);
    DECLARE total_sales INT;
    DECLARE result_message VARCHAR(255);

    -- Calculate the most popular genre by total sales for a given country
    SELECT 
        gen.Name AS GenreName,
        SUM(il.Quantity) AS TotalSales
    INTO 
        popular_genre, 
        total_sales
    FROM invoice inv
    JOIN invoiceline il
        ON inv.InvoiceId = il.InvoiceId
    JOIN track trk
        ON il.TrackId = trk.TrackId
    JOIN genre gen
        ON trk.GenreId = gen.GenreId
    WHERE inv.BillingCountry = input_country
    GROUP BY gen.GenreId
    ORDER BY TotalSales DESC
    LIMIT 1;

    -- If no popular genre is found, return an error message
    IF popular_genre IS NULL THEN
        RETURN 'No genres found for the specified country.';
    END IF;

    -- Construct and return the result message
    SET result_message = CONCAT(
        'Most Popular Genre in ', input_country, 
        ': ', popular_genre, 
        ' (Total Sales: ', total_sales, ')'
    );
    
    RETURN result_message;
END$$

DELIMITER ;

-- Example: Retrieve the most popular genre in the USA
SELECT GetMostPopularGenreByCountry('USA');






