## Linux terminal (GitBash) commands

| Команда | Описание |   
|:-:|:--|  
|$ pwd | 1) Посмотреть где я |  
|$ mkdir QA_Course | 2) Создать папку |  
|$ cd QA_Course| 3) Зайти в папку |
|$ mkdir qa_1 qa_2 qa_3| 4) Создать 3 папки |
|$ cd qa_1| 5) Зайти в любоую папку |
|$ touch 1.txt 2.txt 3.txt 4.json 5.json| 6) Создать 5 файлов (3 txt, 2 json) |
|$ mkdir qa_1_1 qa_1_2 qa_1_3| 7) Создать 3 папки |
|$ ls -la| 8. Вывести список содержимого папки |
|$ cat 1.txt| 9) + Открыть любой txt файл |
|$ cat >> 1.txt|10) + написать туда что-нибудь, любой текст.|
|Ctr+C    $ vim 1.txt -->Ins --> редактируем файл --> Ecs --> :wq (:q! не сохранять) --> Enter | 11) + сохранить и выйти |
|$ cd ..| 12) Выйти из папки на уровень выше |









$ vim 1.txt -->Ins --> редактируем файл --> Ecs --> :wq (:q! не сохранять) --> Enter


13) переместить любые 2 файла, которые вы создали, в любую другую папку.
$ mv /c/Users/Olga/Git/QA_Course/qa_1/2.txt /c/Users/Olga/Git/QA_Course/qa_2/2.txt
$ mv /c/Users/Olga/Git/QA_Course/qa_1/3.txt /c/Users/Olga/Git/QA_Course/qa_2/3.txt

14) скопировать любые 2 файла, которые вы создали, в любую другую папку.
$ cp 4.json  /c/Users/Olga/Git/QA_Course/qa_3/4.json
$ cp 5.json  /c/Users/Olga/Git/QA_Course/qa_3/5.json
Удалить папку со всем содержимым
$ rm -r Folder 
Переименовать файл
$ mv 1.txt 11.txt
15) Найти файл по имени
$ find -name 1.txt 
16) просмотреть содержимое в реальном времени (команда grep) изучите как она работает.
$ tail -f readme.txt | grep Data
17) вывести несколько первых строк из текстового файла
$ head -2 1.txt (команда - количество строк - файл)
18) вывести несколько последних строк из текстового файла
$ tail -3 1.txt
19) просмотреть содержимое длинного файла (команда less) изучите как она работает.
$ less 1.txt (для выхода --> q)
20) вывести дату и время
$ date
=========

Задание *
1) Отправить http запрос на сервер.
$ curl http://162.55.220.72:5005/terminal-hw-request

$ curl http://162.55.220.72:5005/get_method?name=Olga&age=33

$ curl -X POST http://162.55.220.72:5005/get_method? --data "name=Olga" --data "age=33"


2) Написать скрипт который выполнит автоматически пункты 3, 4, 5, 6, 7, 8, 13
$ vim script.scr

#!/bin/bash
cd /c/Users/Olga/Git/QA_Course/qa_1/qa_1_1
mkdir folder1 folder2 folder3
cd folder1
 touch file1.txt file2.txt file3.txt file4.json file5.json
mkdir folder11 folder12 folder13
ls l
mv /c/Users/Olga/Git/QA_Course/qa_1/qa_1_1/folder1/file2.txt 
	/c/Users/Olga/Git/QA_Course/qa_1/qa_1_1/folder1/file3.txt 
	/c/Users/Olga/Git/QA_Course/qa_1/qa_1_1/folder2/file3.txt
--> Esc --> :wq

$ ./script.scr


=====================

