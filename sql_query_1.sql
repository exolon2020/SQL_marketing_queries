-- Создать таблицы и сгенерировать данные (PostgreSQL): Users (содержит userId и возраст клиента), Items (содержит itemId и цену товара),
-- Purchases (содержит idpurchase, userId, itemId)

DROP TABLE IF EXISTS Users;

CREATE TABLE Users (
  userId SERIAL PRIMARY KEY,
  age INTEGER NULL
);

INSERT INTO Users (userId, age) 
       VALUES (generate_series(1, 1000), trunc(random() * 62 + 18));

DROP TABLE IF EXISTS Items;

CREATE TABLE Items (
  itemId SERIAL PRIMARY KEY,
  price FLOAT default NULL
);

INSERT INTO Items (itemId, price) 
       VALUES (generate_series(1, 1000), trunc(random() * 900 + 100));

DROP TABLE IF EXISTS Purchases;

CREATE TABLE Purchases (
    purchaseId SERIAL PRIMARY KEY,
    userId INTEGER REFERENCES Users(userId),
    itemId INTEGER REFERENCES Items(itemId),
    date DATE
    );

INSERT INTO Purchases (purchaseId, userId, itemId, date) 
       VALUES (generate_series(1, 1000), 
               trunc(random()*999 + 1),
               trunc(random()*999 + 1),
               to_timestamp(trunc(RANDOM() * 31536000)
               + extract(epoch from (now())) - 63072000));

-- какую сумму в среднем в месяц тратит:
-- пользователи в возрастном диапазоне от 18 до 25 лет включительно
-- пользователи в возрастном диапазоне от 26 до 35 лет включительно

-- Вариант 1: ARPPU (Average Revenue Per Paying User)

WITH main AS (SELECT * 
              FROM purchases INNER JOIN 
                   items USING(itemId) INNER JOIN 
                   users USING(userId)
              )

SELECT 
(SELECT SUM(price) / ((DATE_PART('year', MAX(date)) - DATE_PART('year', MIN(date))) * 12 
                         + (DATE_PART('month', MAX(date)) - DATE_PART('month', MIN(date)))) 
                         / COUNT(DISTINCT(userId))
FROM main
WHERE age >= 18 AND age <= 25) as group18to25, 

(SELECT SUM(price) / ((DATE_PART('year', MAX(date)) - DATE_PART('year', MIN(date))) * 12 
                         + (DATE_PART('month', MAX(date)) - DATE_PART('month', MIN(date)))) 
                         / COUNT(DISTINCT(userId))
FROM main
WHERE age >= 26 AND age <= 35) as group26to35

-- Вариант 2: ARPU (Average Revenue Per User)

WITH main AS (SELECT * 
              FROM purchases INNER JOIN 
                   items USING(itemId) INNER JOIN 
                   users USING(userId)
              )

SELECT 
(SELECT SUM(price) / ((DATE_PART('year', MAX(date)) - DATE_PART('year', MIN(date))) * 12 
                        + (DATE_PART('month', MAX(date)) - DATE_PART('month', MIN(date)))) 
                         / (SELECT COUNT(userId) FROM Users WHERE age >= 18 AND age <= 25)
FROM main
WHERE age >= 18 AND age <= 25) as group18to25, 
(SELECT SUM(price) / ((DATE_PART('year', MAX(date)) - DATE_PART('year', MIN(date))) * 12 
                        + (DATE_PART('month', MAX(date)) - DATE_PART('month', MIN(date))))  
                        / (SELECT COUNT(userId) FROM Users WHERE age >= 26 AND age <= 35)
FROM main
WHERE age >= 26 AND age <= 35) as group26to35

-- Вариант 3: средний чек для данных возрастных групп

WITH main AS (
  SELECT * From purchases
  INNER JOIN users USING(userid)
  INNER JOIN items USING(itemid)
)
 
 SELECT
 
 (SELECT AVG(avg_sum_by_month) as monthly_avg_by_18_25_users FROM
   (SELECT 
      date_trunc('month', date) AS date,
      SUM(price)/(COUNT(DISTINCT(userid))) as avg_sum_by_month
    From main
    WHERE age >= 18 AND age <= 25
    GROUP BY date_trunc('month', date)
    ORDER BY date) as t1) AS monthly_avg_by_18_25_users,
 
 (SELECT AVG(avg_sum_by_month) as monthly_avg_by_26_35_users FROM
   (SELECT 
      date_trunc('month', date) AS date,
      SUM(price)/(COUNT(DISTINCT(userid))) as avg_sum_by_month
    From main
    WHERE age >= 26 AND age <= 35
    GROUP BY date_trunc('month', date)
    ORDER BY date) AS t2) AS monthly_avg_by_26_35_users
    
  -- в каком месяце года выручка от пользователей в возрастном диапазоне 35+ самая большая

WITH main AS (
  SELECT * From purchases
  INNER JOIN users USING(userid)
  INNER JOIN items USING(itemid)
)

SELECT 
	date_trunc('month', date) as date, 
    SUM(price) as monthly_sum 
FROM main
wHERE age >=35 AND (DATE_PART('YEAR', date)=2021)
GROUP BY date_trunc('month', date)
ORDER BY monthly_sum DESC
LIMIT 1

-- какой товар обеспечивает дает наибольший вклад в выручку за последний год

WITH main AS (
  SELECT * From purchases
  INNER JOIN items USING(itemid)
)

SELECT 
	itemid,
    SUM(price) as revenue
FROM main
wHERE (DATE_PART('YEAR', date)=2021)
GROUP BY itemid
ORDER BY revenue DESC
LIMIT 1

-- топ-3 товаров по выручке и их доля в общей выручке за любой год

WITH main AS (
  SELECT * From purchases
  INNER JOIN items USING(itemid)
)

SELECT 
	itemid,
	SUM(price) as revenue,
	SUM(price)/(SELECT SUM(price) FROM main wHERE (DATE_PART('YEAR', date)=2021))*100 AS percent_of_revenue
FROM main
wHERE (DATE_PART('YEAR', date)=2021)
GROUP BY itemid
ORDER BY revenue DESC
LIMIT 3
