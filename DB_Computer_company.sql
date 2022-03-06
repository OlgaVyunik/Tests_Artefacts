---База данных "Компьютерная фирма":
---Схема БД состоит из четырех таблиц:
---Product(maker, model, type)
---PC(code, model, speed, ram, hd, cd, price)
---Laptop(code, model, speed, ram, hd, price, screen)
---Printer(code, model, color, type, price)
---Таблица Product представляет производителя (maker), номер модели (model) и тип ('PC' - ПК, 'Laptop' - ПК-блокнот или 'Printer' - принтер). 
---Предполагается, что номера моделей в таблице Product уникальны для всех производителей и типов продуктов. 
---В таблице PC для каждого ПК, однозначно определяемого уникальным кодом – code, указаны модель – model (внешний ключ к таблице Product), 
---скорость - speed (процессора в мегагерцах), объем памяти - ram (в мегабайтах), размер диска - hd (в гигабайтах), скорость считывающего устройства - cd (например, '4x') и цена - price. 
---Таблица Laptop аналогична таблице РС за исключением того, что вместо скорости CD содержит размер экрана -screen (в дюймах). 
---В таблице Printer для каждой модели принтера указывается, является ли он цветным - color ('y', если цветной), 
---тип принтера - type (лазерный – 'Laser', струйный – 'Jet' или матричный – 'Matrix') и цена - price.

---1) Найдите номер модели, скорость и размер жесткого диска для всех ПК стоимостью менее 500 дол. Вывести: model, speed и hd
SELECT model,speed, hd
FROM pc
WHERE price<500

---2) Найдите производителей принтеров. Вывести: maker
SELECT DISTINCT maker
FROM product
WHERE type='printer'

---3) Найдите номер модели, объем памяти и размеры экранов ПК-блокнотов, цена которых превышает 1000 дол.
SELECT model, ram, screen
FROM laptop
WHERE price>1000

---4) Найдите все записи таблицы Printer для цветных принтеров.
SELECT *
FROM printer
WHERE color='y'

---5) Найдите номер модели, скорость и размер жесткого диска ПК, имеющих 12x или 24x CD и цену менее 600 дол.
SELECT model, speed, hd
FROM pc
WHERE cd='12x'AND price<600
 OR cd='24x'AND price<600
 
---6) Для каждого производителя, выпускающего ПК-блокноты c объёмом жесткого диска не менее 10 Гбайт, найти скорости таких ПК-блокнотов. Вывод: производитель, скорость.
SELECT DISTINCT product.maker, laptop.speed
FROM laptop
INNER JOIN product ON product.model = laptop.model
WHERE laptop.hd >= 10

--- 7) Найдите номера моделей и цены всех имеющихся в продаже продуктов (любого типа) производителя B (латинская буква).
SELECT product.model, pc.price
FROM Product 
INNER JOIN pc ON product.model = pc.model 
WHERE maker = 'B'
UNION
SELECT product.model, laptop.price
FROM product 
INNER JOIN laptop ON product.model=laptop.model 
WHERE maker='B'
UNION
SELECT product.model, printer.price
FROM product 
INNER JOIN printer ON product.model=printer.model WHERE maker='B'

---8) Найдите производителя, выпускающего ПК, но не ПК-блокноты.
SELECT maker
FROM product
WHERE type='pc'
EXCEPT
SELECT product.maker
FROM product
WHERE type='laptop'

---9) Найдите производителей ПК с процессором не менее 450 Мгц. Вывести: Maker
SELECT DISTINCT product.maker
FROM pc
INNER JOIN product ON pc.model = product.model
WHERE pc.speed >= 450

---10) Найдите модели принтеров, имеющих самую высокую цену. Вывести: model, price
SELECT model, price
FROM printer
WHERE price = (SELECT MAX(price) FROM printer)

---11) Найдите среднюю скорость ПК.
SELECT AVG(speed)
FROM pc

---12) Найдите среднюю скорость ПК-блокнотов, цена которых превышает 1000 дол.
SELECT AVG(speed)
FROM laptop
WHERE price>1000

---13) Найдите среднюю скорость ПК, выпущенных производителем A.
SELECT AVG(speed)
FROM pc
WHERE model IN(SELECT model
 FROM Product
 WHERE maker = 'A'
 )
 
---15) Найдите размеры жестких дисков, совпадающих у двух и более PC. Вывести: HD
SELECT hd
FROM pc
GROUP BY hd
HAVING COUNT(model) >= 2

---16) Найдите пары моделей PC, имеющих одинаковые скорость и RAM. В результате каждая пара указывается только один раз, т.е. (i,j), но не (j,i), Порядок вывода: модель с большим номером, модель с меньшим номером, скорость и RAM.
SELECT DISTINCT A.model AS model_1, B.model AS model_2, A.speed, A.ram
FROM PC AS A, PC B
WHERE A.speed = B.speed AND A.ram = B.ram AND
 A.model > B.model
 
--- 17) Найдите модели ПК-блокнотов, скорость которых меньше скорости каждого из ПК. Вывести: type, model, speed
SELECT DISTINCT pr.type, l.model, l.speed
FROM laptop l, product pr
WHERE pr.type = 'laptop' AND
speed < ALL (SELECT speed FROM pc)

---18) Найдите производителей самых дешевых цветных принтеров. Вывести: maker, price
SELECT DISTINCT product.maker, printer.price
FROM product, printer
WHERE product.model = printer.model
AND printer.color = 'y'
AND printer.price = (
SELECT MIN(price) FROM printer
WHERE printer.color = 'y'
)

---19) Для каждого производителя, имеющего модели в таблице Laptop, найдите средний размер экрана выпускаемых им ПК-блокнотов. Вывести: maker, средний размер экрана.
SELECT DISTINCT pr.maker, AVG(l.screen)
FROM product pr, laptop l
WHERE pr.model = l.model
GROUP BY pr.maker

---20) Найдите производителей, выпускающих по меньшей мере три различных модели ПК. Вывести: Maker, число моделей ПК.
SELECT maker, COUNT(model)  
FROM product
WHERE type = 'pc'
GROUP BY maker
HAVING COUNT(model) > 2

---21) Найдите максимальную цену ПК, выпускаемых каждым производителем, у которого есть модели в таблице PC. Вывести: maker, максимальная цена.
SELECT pr.maker, MAX(pc.price)
FROM product pr, pc
WHERE pr.model=pc.model
GROUP BY pr.maker

---22) Для каждого значения скорости ПК, превышающего 600 МГц, определите среднюю цену ПК с такой же скоростью. Вывести: speed, средняя цена.
SELECT speed, AVG(price)
FROM pc
WHERE speed > 600
GROUP BY speed

---23) Найдите производителей, которые производили бы как ПК со скоростью не менее 750 МГц, так и ПК-блокноты со скоростью не менее 750 МГц. Вывести: Maker
SELECT DISTINCT maker
FROM product JOIN pc ON product.model=pc.model
WHERE speed>=750 
AND maker IN
(SELECT maker
FROM product JOIN laptop ON product.model=laptop.model
WHERE speed>=750 )

---24) Перечислите номера моделей любых типов, имеющих самую высокую цену по всей имеющейся в базе данных продукции.
SELECT model
FROM (
 SELECT model, price FROM pc
 UNION
 SELECT model, price FROM Laptop
 UNION
 SELECT model, price FROM Printer
) a 
WHERE price = (SELECT MAX(price)
 FROM (
  SELECT price FROM pc
  UNION
  SELECT price FROM Laptop
  UNION
  SELECT price FROM Printer
  ) b
 )

---25) Найдите производителей принтеров, которые производят ПК с наименьшим объемом RAM и с самым быстрым процессором среди всех ПК, имеющих наименьший объем RAM. Вывести: Maker
SELECT DISTINCT product.maker FROM product WHERE product.type='Printer'  
INTERSECT 
SELECT DISTINCT product.maker FROM product INNER JOIN pc ON pc.model=product.model  
WHERE product.type='PC' AND pc.ram=(SELECT MIN(ram) FROM pc)  
AND pc.speed = (SELECT MAX(speed) FROM (SELECT DISTINCT speed FROM pc 
WHERE pc.ram=(SELECT MIN(ram) FROM pc)) as t)

---26) Найдите среднюю цену ПК и ПК-блокнотов, выпущенных производителем A (латинская буква). Вывести: одна общая средняя цена.
SELECT AVG(price)
FROM 
(SELECT pc.price as price
FROM product, pc
WHERE pc.model=product.model AND product.maker='A'
UNION all
SELECT laptop.price as price FROM laptop,product
 WHERE laptop.model=product.model AND product.maker='A') as a
 
---27) Найдите средний размер диска ПК каждого из тех производителей, которые выпускают и принтеры. Вывести: maker, средний размер HD.
SELECT maker, AVG(hd)
FROM product, pc
WHERE product.model=pc.model 
AND maker IN (SELECT maker 
 FROM product 
 WHERE type='Printer')
GROUP BY maker

---28) Используя таблицу Product, определить количество производителей, выпускающих по одной модели.
SELECT COUNT(maker) as qty
FROM product 
WHERE maker IN (SELECT maker FROM product
GROUP BY maker
HAVING COUNT(model)=1 )

---35) В таблице Product найти модели, которые состоят только из цифр или только из латинских букв (A-Z, без учета регистра). Вывод: номер модели, тип модели.
SELECT model, type
FROM product
WHERE model NOT LIKE '%[^0-9]%' OR model NOT LIKE '%[^a-z]%'



