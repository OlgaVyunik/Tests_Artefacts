// 1. Написать скрипт, который сосчитает и выведет результат от возведения 2 в степень 10, начиная со степени 1
let a = 2
let b = 1
while(b < 11){
     result = a ** b
     console.log(result)
     b++
}
    // Вариант 2
for (i=1; i < 11; i++){
    ii = a**i
    console.log(ii)
}
// 2*. Преобразовать 1 задачу в функцию, принимающую на вход степень, в которую будет возводиться число 2
function degree(i){
    i = 2**i
    console.log(i)
}
degree(10)
    //Вариант 2 
function degree1(i){
    return 2**i
}
console.log(degree1(10))
    // Вариант 3
function degree3(i){
    return Math.pow(2,i)
}
console.log(degree3(10))

// 3. Написать скрипт, который выведет 5 строк в консоль таким образом, чтобы в первой строчке выводилось :), во второй :):) и так далее
let word = ':)'
let result2 = ''
for (let i=1; i<=5; i++){
    result2 += word
    console.log(result2)
}

// 4*. Преобразовать 2 задачу в функцию, принимающую на вход строку, которая и будет выводиться в консоль (как в условии смайлик), а также количество строк для вывода 
function printSmile(stroka, numberOfRows){
    let result = ''
    for (let i = 1; i<=numberOfRows; i++){
        result += stroka
        console.log(result)
    }
}
printSmile('(-|-)', 5)
    // Вариант 2
function printSmile2(stroka, numberOfRows){
    for (let i = 1; i<=numberOfRows; i++){
        console.log(stroka.repeat(i))
    }
}
printSmile2('Holo', 4)

// 5**.  Написать функцию, которая принимает на вход слово. Задача функции посчитать и вывести в консоль, сколько в слове гласных, и сколько согласных букв.
// В консоли: 
// Слово (word) состоит из  (число) гласных и (число) согласных букв
function getWordStructure(word){
    const vowels = 'eyuioa'.split('') //split делает из слова массив букв
    const consonants = 'qwrtpsdfghjklzxcvbnm'.split('')
    let numberOfVowels = 0
    let numberOfConsonants = 0
    for(char of word.toLowerCase()){ //toLowerCase приводит к нижнему регистру
        if (vowels.includes(char)) numberOfVowels++
        if (consonants.includes(char)) numberOfConsonants++
    }
    console.log(`Слово ${word} состоит из ${numberOfVowels} гласных и ${numberOfConsonants} согласных букв`)
}
getWordStructure('Use-case')
    // Вариант 2
function getWordStructure2(word){
    const vowels = word.match(/[eyuioa]/gi) // match (/[]/) - регулярное выражение, g - по всему тексту, i - не замечая регистр
    const consonants = word.match(/[qwrtpsdfghjklzxcvbnm]/gi)
    console.log("Слово " + word + " состоит из " + vowels.length + " гласных и " + consonants.length + " согласных букв")
}
getWordStructure2('Check-list')

// 6**. Написать функцию, которая проверяет, является ли слово палиндромом
    //Вариант 1
function isPalindrom(word){
    let newStroka = '' // сюда кладем перевернутое слово
    for (i = word.length - 1; i >= 0; i--){
        newStroka = newStroka + word[i]
    }
    if (word.toLowerCase() == newStroka.toLowerCase()){
        console.log(word, '- палиндром',)
    } else{
        console.log(word, '- не палиндром',)
    }
}
isPalindrom('Salas')
isPalindrom('Shalas')
    //Вариант 2 самое быстрое решение
function isPalindrom2(word){
    word = word.toLowerCase()
    const len = word.length
    for(let i = 0; i < len / 2; i++){
        if (word[i] !== word[len -1 -i]){
            return 'It is not a palindrome'
        }
    }
    return 'It is a palindrome'
}
console.log(isPalindrom2('alanala'))
    //Вариант 3
function isPalindrom3(word){
    return word.toLowerCase() == word.toLowerCase().split('').reverse().join('') //join обратно собирает слово в строку (обратно split)
}
console.log(`${isPalindrom3('Abhfba') ? 'Это палиндром' : 'Это не палиндром'}`)