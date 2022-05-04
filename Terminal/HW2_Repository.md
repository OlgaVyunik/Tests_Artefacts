## Work with repository
|Command|Description|
|:--|:--|
|git status|показать состояние репозитория (отслеживаемые, изменённые, новые файлы и пр.)|
|git add . |добавить в индекс все новые, изменённые, удалённые файлы из текущей директории и её поддиректорий|
|git commit -m "-"|зафиксировать в коммите проиндексированные изменения (закоммитить), добавить сообщение|
|git commit -am "-"|проиндексировать отслеживаемые файлы (ТОЛЬКО отслеживаемые, но НЕ новые файлы) и закоммитить, добавить сообщение|
|git checkout -b first_branch|создать новую ветку с указанным именем и перейти в неё|
|git checkout main|переключиться на ветку main|
|git branch|показать список веток|
|git branch new_branch|создать новую ветку с указанным именем на текущем коммите|
|git push|отправляем данные из локального репозитория в удаленный|
|git pull|влить изменения с удалённого репозитория |
|git merge first_branch|влить в ветку, в которой находимся, данные из ветки first_branch|
|git branch -m old_branch_name new_branch_name|переименовать локально ветку old_branch_name в new_branch_name|
|git branch -m new_branch_name|переименовать локально ТЕКУЩУЮ ветку в new_branch_name|
|git push origin :old_branch_name new_branch_name|применить переименование в удаленном репозитории|
|git branch --unset-upstream|завершить процесс переименования|
|git clone https://link |клонировать удаленный репозиторий в одноименную директорию|
|ssh-keygen -t rsa -C "github_user” | получить SSH сертификат, который затем вставляем на сайте github -> Settings -> SSH and GPG keys -> New SSH key -> вставляем ключ из файла |
 

