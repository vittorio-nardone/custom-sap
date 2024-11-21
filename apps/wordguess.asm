#include "../assembly/ruledef.asm"
#include "../kernel/symbols.asm"

#bankdef ram
{
    #addr 0x9000
    #size 0x1000
    #outp 0
}

#bank ram

; Game starts
; Choose a word
; Print placeholders (one for each char)
; Ask for char or try
; If Char, ask it -> show placeholder with matching char -> save char in the list -> increase tentative count
; If try, ask for the word -> check if match -> show result

begin:
    LDD welcome_message[15:8]
    LDE welcome_message[7:0]
    jsr ACIA_SEND_STRING

    ; Configure & Enable interrupt
    lda INT_TIMER  ; set int mask
    JSR INTERRUPT_INIT
    cli




    lda INT_TIMER_COUNTER_LSB



word_index:
    #d 0x00

welcome_message:
    #d 0x0A, 0x0D, 
    #d "Welcome to 'Guess the word' game for Otto", 0x0A, 0x0D,
    #d "Press any key to start the game.", 0x0A, 0x0D, 0x00   

word_list:
    #d "blue", 0x00
    #d "computer", 0x00
    #d "rain", 0x00
    #d "mountain", 0x00
    #d "fish", 0x00
    #d "airplane", 0x00
    #d "book", 0x00
    #d "elephant", 0x00
    #d "desk", 0x00
    #d "sunshine", 0x00
    #d "tree", 0x00
    #d "keyboard", 0x00
    #d "star", 0x00
    #d "umbrella", 0x00
    #d "fire", 0x00
    #d "baseball", 0x00
    #d "moon", 0x00
    #d "sandwich", 0x00
    #d "wind", 0x00
    #d "treasure", 0x00
    #d "cake", 0x00
    #d "distance", 0x00
    #d "ship", 0x00
    #d "painting", 0x00
    #d "seed", 0x00
    #d "hospital", 0x00
    #d "rock", 0x00
    #d "butterfly", 0x00
    #d "song", 0x00
    #d "triangle", 0x00
    #d "bird", 0x00
    #d "magazine", 0x00
    #d "soup", 0x00
    #d "whistle", 0x00
    #d "cloud", 0x00
    #d "birthday", 0x00
    #d "milk", 0x00
    #d "darkness", 0x00
    #d "game", 0x00
    #d "climbing", 0x00
    #d "food", 0x00
    #d "swimming", 0x00
    #d "hair", 0x00
    #d "football", 0x00
    #d "lake", 0x00
    #d "precious", 0x00
    #d "road", 0x00
    #d "building", 0x00
    #d "salt", 0x00
    #d "dinosaur", 0x00
    #d "team", 0x00
    #d "princess", 0x00
    #d "park", 0x00
    #d "floating", 0x00
    #d "ring", 0x00
    #d "baseball", 0x00
    #d "door", 0x00
    #d "medicine", 0x00
    #d "gold", 0x00
    #d "teaching", 0x00
    #d "snow", 0x00
    #d "strength", 0x00
    #d "farm", 0x00
    #d "mountain", 0x00
    #d "king", 0x00
    #d "railroad", 0x00
    #d "leaf", 0x00
    #d "thinking", 0x00
    #d "rope", 0x00
    #d "wedding", 0x00
    #d "lion", 0x00
    #d "surprise", 0x00
    #d "meat", 0x00
    #d "rainbow", 0x00
    #d "frog", 0x00
    #d "monster", 0x00
    #d "wire", 0x00
    #d "dancing", 0x00
    #d "club", 0x00
    #d "fighting", 0x00
    #d "rope", 0x00
    #d "picture", 0x00
    #d "shop", 0x00
    #d "treasure", 0x00
    #d "pill", 0x00
    #d "sailing", 0x00
    #d "rose", 0x00
    #d "cooking", 0x00
    #d "tail", 0x00
    #d "jumping", 0x00
    #d "soap", 0x00
    #d "drinking", 0x00
    #d "pine", 0x00
    #d "running", 0x00
    #d "face", 0x00
    #d "sleeping", 0x00
    #d "wall", 0x00
    #d "working", 0x00
    #d "nest", 0x00
    #d "laughing", 0x00
    #d "bear", 0x00
    #d "training", 0x00
    #d "page", 0x00
    #d "watching", 0x00
    #d "corn", 0x00
    #d "floating", 0x00
    #d "desk", 0x00
    #d "singing", 0x00
    #d "bank", 0x00
    #d "playing", 0x00
    #d "fish", 0x00
    #d "walking", 0x00
    #d "goat", 0x00
    #d "farming", 0x00
    #d "tent", 0x00
    #d "reading", 0x00
    #d "mint", 0x00
    #d "driving", 0x00
    #d "wolf", 0x00
    #d "eating", 0x00
    #d "stone", 0x00
    #d "flowing", 0x00
    #d "lamp", 0x00
    #d "skating", 0x00
    #d "boat", 0x00
    #d "smiling", 0x00
    #d "ring", 0x00
    #d "flying", 0x00
    #d "queen", 0x00
    #d "talking", 0x00
    #d "pine", 0x00
    #d "raining", 0x00
    #d "fort", 0x00
    #d "sleeping", 0x00
    #d "bird", 0x00
    #d "hunting", 0x00
    #d "seat", 0x00
    #d "glowing", 0x00
    #d "bath", 0x00
    #d "climbing", 0x00
    #d "wine", 0x00
    #d "falling", 0x00
    #d "rice", 0x00
    #d "sailing", 0x00
    #d "hope", 0x00
    #d "swimming", 0x00
    #d "rain", 0x00
    #d "dancing", 0x00
    #d "wish", 0x00
    #d "running", 0x00
    #d "zone", 0x00
    #d "jumping", 0x00
    #d "fire", 0x00
    #d "skating", 0x00
    #d "mail", 0x00
    #d "walking", 0x00
    #d "horn", 0x00
    #d "reading", 0x00
    #d "cave", 0x00
    #d "cooking", 0x00
    #d "dust", 0x00
    #d "playing", 0x00
    #d "fort", 0x00
    #d "singing", 0x00
    #d "east", 0x00
    #d "farming", 0x00
    #d "west", 0x00
    #d "hunting", 0x00
    #d "time", 0x00
    #d "flowing", 0x00
    #d "love", 0x00
    #d "eating", 0x00
    #d "soul", 0x00
    #d "flying", 0x00
    #d "drum", 0x00
    #d "riding", 0x00
    #d "life", 0x00
    #d "drawing", 0x00
    #d "mind", 0x00
    #d "skiing", 0x00
    #d "pace", 0x00
    #d "sailing", 0x00
    #d "edge", 0x00
    #d "racing", 0x00
    #d "note", 0x00
    #d "camping", 0x00
    #d "hope", 0x00
    #d "talking", 0x00
    #d "fate", 0x00
    #d "fighting", 0x00
    #d "wave", 0x00
    #d "growing", 0x00
    #d "path", 0x00
    #d "writing", 0x00
    #d "moon", 0x00
    #d "looking", 0x00
    #d "star", 0x00
    #d "moving", 0x00
    #d "song", 0x00
    #d "helping", 0x00
    #d "lake", 0x00
    #d "winning", 0x00
    #d "tree", 0x00
    #d "living", 0x00
    #d "road", 0x00
    #d "making", 0x00
    #d "wind", 0x00
    #d "trying", 0x00
    #d "bell", 0x00
    #d "falling", 0x00
    #d "book", 0x00
    #d "seeking", 0x00
    #d "door", 0x00
    #d "giving", 0x00
    #d "face", 0x00
    #d "taking", 0x00
    #d "hand", 0x00
    #d "feeling", 0x00
    #d "foot", 0x00
    #d "seeing", 0x00
    #d "milk", 0x00
    #d "hearing", 0x00
    #d "salt", 0x00
    #d "waiting", 0x00
    #d "gold", 0x00
    #d "finding", 0x00
    #d "hair", 0x00
    #d "knowing", 0x00
    #d "time", 0x00
    #d "being", 0x00