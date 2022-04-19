/* В файл HTML вставить <script src="\HW_JS_4.js"> </script>*/

let age_2 = 18
let age_3 = 60

let checkAge = function(age_1){
    if(isNaN(age_1)){
    alert('Error! Enter number.')
}
    else{
        if(age_1 < age_2 && age_1 >= 0){
            alert('You don`t have access cause your age is ' + age_1 + '. It`s less then 18')
        }
        else if(age_1>=age_2 && age_1 < age_3){
            alert('Welcome !')
        }
        else if(age_1 > age_3){
            alert('Keep calm and look Culture channel')
        }
        else{
            alert('Technical work')
        }
    }
}

let userAge = prompt('Enter your age')
checkAge(userAge)


