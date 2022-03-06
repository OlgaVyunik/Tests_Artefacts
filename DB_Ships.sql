---База данных "Корабли":
---Рассматривается БД кораблей, участвовавших во второй мировой войне. Имеются следующие отношения:
---Classes (class, type, country, numGuns, bore, displacement)
---Ships (name, class, launched)
---Battles (name, date)
---Outcomes (ship, battle, result)
---Корабли в «классах» построены по одному и тому же проекту, и классу присваивается либо имя первого корабля, построенного по данному проекту, либо названию класса дается имя проекта, которое не совпадает ни с одним из кораблей в БД. 
---Корабль, давший название классу, называется головным.
---Отношение Classes содержит имя класса, тип (bb для боевого (линейного) корабля или bc для боевого крейсера), страну, в которой построен корабль, число главных орудий, калибр орудий (диаметр ствола орудия в дюймах) и водоизмещение ( вес в тоннах). 
---В отношении Ships записаны название корабля, имя его класса и год спуска на воду. 
---В отношение Battles включены название и дата битвы, в которой участвовали корабли, 
---а в отношении Outcomes – результат участия данного корабля в битве (потоплен-sunk, поврежден - damaged или невредим - OK).
---Замечания. 1) В отношение Outcomes могут входить корабли, отсутствующие в отношении Ships. 
---2) Потопленный корабль в последующих битвах участия не принимает.

---14) Найдите класс, имя и страну для кораблей из таблицы Ships, имеющих не менее 10 орудий.
SELECT DISTINCT classes.class, ships.name, classes.country
FROM ships JOIN classes ON classes.class=ships.class
WHERE classes.numGuns>=10

---31) Для классов кораблей, калибр орудий которых не менее 16 дюймов, укажите класс и страну.
SELECT class, country
FROM classes
WHERE bore >=16

---32) Одной из характеристик корабля является половина куба калибра его главных орудий (mw). С точностью до 2 десятичных знаков определите среднее значение mw для кораблей каждой страны, у которой есть корабли в базе данных.
SELECT country, cast(avg((power(bore,3)/2)) as numeric(6,2)) as mw 
FROM (SELECT country, classes.class, bore, name 
	FROM classes LEFT JOIN ships ON classes.class=ships.class
	UNION ALL
	SELECT DISTINCT country, class, bore, ship 
	FROM classes t1 LEFT JOIN outcomes t2 on t1.class=t2.ship
	WHERE ship=class and ship NOT IN (SELECT name FROM ships) ) a
WHERE name IS NOT NULL 
GROUP BY country

---33) Укажите корабли, потопленные в сражениях в Северной Атлантике (North Atlantic). Вывод: ship.
SELECT ship
FROM outcomes
WHERE result='sunk' AND battle='North Atlantic'

---34) По Вашингтонскому международному договору от начала 1922 г. запрещалось строить линейные корабли водоизмещением более 35 тыс.тонн. Укажите корабли, нарушившие этот договор (учитывать только корабли c известным годом спуска на воду). Вывести названия кораблей.
SELECT DISTINCT ships.name 
FROM ships, classes
WHERE ships.launched >= 1922 
AND classes.displacement > 35000 
AND classes.type='bb' 
AND ships.class=classes.class
AND ships.launched IS NOT NULL



---База данных "Фирма вторсырья":
---Фирма имеет несколько пунктов приема вторсырья. Каждый пункт получает деньги для их выдачи сдатчикам вторсырья. 
---Сведения о получении денег на пунктах приема записываются в таблицу:
---Income_o(point, date, inc)
---Первичным ключом является (point, date). При этом в столбец date записывается только дата (без времени), т.е. прием денег (inc) на каждом пункте производится не чаще одного раза в день. 
---Сведения о выдаче денег сдатчикам вторсырья записываются в таблицу:
---Outcome_o(point, date, out)
---В этой таблице также первичный ключ (point, date) гарантирует отчетность каждого пункта о выданных деньгах (out) не чаще одного раза в день.
---В случае, когда приход и расход денег может фиксироваться несколько раз в день, используется другая схема с таблицами, имеющими первичный ключ code:
---Income(code, point, date, inc)
---Outcome(code, point, date, out)
---Здесь также значения столбца date не содержат времени.

---29) В предположении, что приход и расход денег на каждом пункте приема фиксируется не чаще одного раза в день [т.е. первичный ключ (пункт, дата)], написать запрос с выходными данными (пункт, дата, приход, расход). Использовать таблицы Income_o и Outcome_o.
SELECT income_o.point, income_o.date, inc, out
FROM income_o LEFT JOIN outcome_o ON income_o.point = outcome_o.point
AND income_o.date = outcome_o.date
UNION
SELECT outcome_o.point, outcome_o.date, inc, out
FROM income_o  RIGHT JOIN outcome_o ON income_o.point = outcome_o.point
AND income_o.date = outcome_o.date

---30) В предположении, что приход и расход денег на каждом пункте приема фиксируется произвольное число раз (первичным ключом в таблицах является столбец code), требуется получить таблицу, в которой каждому пункту за каждую дату выполнения операций будет соответствовать одна строка.
---Вывод: point, date, суммарный расход пункта за день (out), суммарный приход пункта за день (inc). Отсутствующие значения считать неопределенными (NULL).
SELECT point, date, SUM(sum_out), SUM(sum_inc)
FROM (SELECT point, date, SUM(inc) as sum_inc, null as sum_out 
FROM Income 
GROUP BY point, date
UNION
SELECT point, date, null as sum_inc, SUM(out) as sum_out 
FROM Outcome 
GROUP BY point, date ) as t
GROUP BY point, date 
ORDER BY point


