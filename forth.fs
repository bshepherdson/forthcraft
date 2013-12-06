\ ForthCraft - A Forth implementation in Lua intended as an alternative operating system
\ and programming environment for the Minecraft mod ComputerCraft.
\ Copyright 2013 Braden Shepherdson
\ Version 1


\ Dummy double-cell numbers, since 64-bit doubles are plenty big.
: s>d 0 ;
: d>s drop ;

: /mod >r s>d r> sm/rem ;
: / /mod swap drop ;
: mod /mod drop ;

: 2+ 2 + ;
: 2- 2 - ;
: 2* 2 * ;
: 2/ 2 / ;

: C@ @ ;
: C! ! ;
: C, , ;

\ No-op, cells are address units.
: cells ;
: cell+ 1+ ;

\ No-op, chars are address units.
: chars ;
: char+ 1+ ;

\ No-ops, no alignment here.
: align ;
: aligned ;

\ Given an xt, returns the body address. This is no-op, since there's no header.
: >BODY ;

\ Basic logical ops. THESE WORK ON FLAGS ONLY, THEY ARE NOT BITWISE.
\ XXX Breaks from the spec.
: and 0<> swap 0<> + -2 = ;
: or  0<> swap 0<> + 0<> ;
: xor 0<> swap 0<> <> ;


: nl 10 ;
: bl 32 ;
: cr nl emit ;
: space bl emit ;

: negate 0 swap - ;

\ Standard words for booleans
: true -1 ;
: false 0 ;


\ LITERAL compiles LIT <foo>
: literal
    ' lit , \ compile LIT
    ,       \ compile literal
  ; immediate


\ Compiles IMMEDIATE words.
: postpone
    parse-name  \ get the next word
    find  \ find it in the dict
    ,     \ and compile it.
  ; immediate


: recurse
    latest @  \ This word
    ,         \ compile it
  ; immediate

\ Control structures - ONLY SAFE IN COMPILED CODE!
\ cond IF true-case THEN rest
\ ---> cond 0BRANCH OFFSET true-cast rest
\ cond IF true-case ELSE false-case THEN rest
\ ---> cond 0BRANCH OFFSET true-case BRANCH OFFSET2 false-case rest
: if
    ' 0branch ,
    here @      \ save location
    0 ,         \ dummy offset
  ; immediate


: then
    dup
    here @ swap - \ calc offset
    swap !        \ store it
  ; immediate

: else
    ' branch , \ branch to end
    here @     \ save location
    0 ,        \ dummy offset
    swap       \ orig IF offset
    dup        \ like THEN
    here @ swap -
    swap !
  ; immediate


\ BEGIN loop condition UNTIL ->
\ loop cond 0BRANCH OFFSET
: begin
    here @
; immediate

: until
    ' 0branch ,
    here @ -
    ,
; immediate


\ BEGIN loop AGAIN, infinitely.
: again
    ' branch ,
    here @ -
    ,
  ; immediate

\ UNLESS is IF reversed
: unless
    ' 0= ,
    postpone if
  ; immediate



\ BEGIN cond WHILE loop REPEAT
: while
    ' 0branch ,
    here @
    0 , \ dummy offset
  ; immediate

: repeat
    ' branch ,
    swap
    here @ - ,
    dup
    here @ swap -
    swap !
  ; immediate


: (
    1 \ tracking depth
    begin
        key \ read next char
        dup 40 = if \ open (
            drop \ drop it
            1+ \ bump the depth
        else
            41 = if \ close )
               1- \ dec depth
            then
        then
    dup 0= until \ depth == 0
    drop \ drop the depth
  ; immediate

: nip ( x y -- y ) swap drop ;
: tuck ( x y -- y x y )
    swap over ;
: pick ( x_u ... x_1 x_0 u -- x_u ... x_1 x_0 x_u )
    1+     \ skip over u
    dsp@ + \ add to DSP
    @      \ fetch
  ;


\ writes n spaces to stdout
: spaces ( n -- )
    begin
        dup 0> \ while n > 0
    while
        space 1-
    repeat
    drop
;

\ Standard base changers.
: decimal ( -- ) 10 base ! ;
: hex ( -- ) 16 base ! ;


\ Strings and numbers
: u.  ( u -- )
    base @ /mod \ ( r q )
    ?dup if \ if q <> 0 then
        recurse \ print quot
    then
    \ print the remainder
    dup 10 < if
        48 \ dec digits 0..9
    else
        10 -
        65 \ hex and other A..Z
    then
    + emit
;

\ Debugging utility.
: .s ( -- )
    dsp@ \ get stack pointer
    begin
        dup s0 <
    while
        dup @ u. \ print
        space
        1+       \ move up
    repeat
    drop
;


: uwidth ( u -- width )
    base @ / \ rem quot
    ?dup if   \ if quot <> 0
        recurse 1+
    else
        1 \ return 1
    then
;



: u.r ( u width -- )
    swap   \ ( width u )
    dup    \ ( width u u )
    uwidth \ ( width u uwidth )
    rot    \ ( u uwidth width )
    swap - \ ( u width-uwdith )
    spaces \ no-op on negative
    u.
;


\ Print padded, signed number
: .r ( n width -- )
    swap dup 0< if
        negate \ width u
        1 swap \ width 1 u
        rot 1- \ 1 u width-1
    else
        0 swap rot \ 0 u width
    then
    swap dup \ flag width u u
    uwidth \ flag width u uw
    rot swap - \ ? u w-uw
    spaces swap \ u ?
    if 45 emit then \ print -
    u. ;

: . 0 .r space ;
\ Replace U.
: u. u. space ;
\ ? fetches an addr and prints
: ? ( addr -- ) @ . ;



\ c a b WITHIN ->
\   a <= c & c < b
: within ( c a b -- ? )
    -rot    ( b c a )
    over    ( b c a c )
    <= if
        > if   ( b c -- )
            true
        else
            false
        then
    else
        2drop
        false
    then
;

: depth ( -- n )
    s0 dsp@ -
    1- \ adjust for S0 on stack
;


: .s_comp
    ' litstring ,
    here @ \ address
    0 ,    \ dummy length
    begin
        key        \ next char
        dup 34 <>  \ ASCII "
    while
        c, \ copy character
    repeat
    drop \ drop the "
    dup here @ swap - \ length
    1-
    swap ! \ set length
  ;

: .s_interp
    (strbuf) \ temp location
    begin
        key
        dup 34 <>  \ ASCII "
    while
        over c! \ save character
        char+     \ bump address
    repeat
    drop     \ drop the "
    (strbuf) swap - \ calculate length
    (strbuf) swap   \ addr len
  ;

: s" ( -- addr len )
    state @ if \ compiling?
        .s_comp
    else \ immediate mode
        .s_interp
    then
  ; immediate



: ." ( -- )
    state @ if \ compiling?
        postpone s"
        ' type ,
    else
        \ Just read and print
        begin
            key
            dup 34 = if \ "
                drop exit
            then
            emit
        again
    then
  ; immediate


: constant
    parse-name create
    ' lit , \ append LIT
    ,       \ input value
    ' exit , \ and append EXIT
  ;
: value ( n -- )
    parse-name create
    ' lit ,
    ,
    ' exit ,
  ;

\ Allocates n bytes of memory
: allot ( n -- addr )
    here @ swap \ here n
    here +!     \ add n to HERE
  ;


\ Finally VARIABLE itself.
: variable
    1 cells allot \ allocate 1 cell
    parse-name create
    ' lit ,
    , \ pointer from ALLOT
    ' exit ,
  ;



: case 0 ; immediate
: of
    ' over ,
    ' = ,
    postpone if
    ' drop ,
; immediate
: endof
    postpone else ; immediate
: endcase
    ' drop ,
    begin ?dup while
    postpone then repeat
; immediate

: :noname
    0 0 create \ nameless entry
    here @     \ current HERE
    \ value is the address of
    \ the codeword, ie. the xt
    ] \ compile the definition.
  ;

: ['] parse-name find ' lit , , ; immediate


\ Expects the user to specify the number of bytes, not cells.
: array ( n -- )
  allot >r
  parse-name create \ define the word
  ' cells ,     \ multiply the index into cells
  ' lit ,    \ compile LIT
  r> ,       \ compile address
  ' + ,      \ add index
  ' exit ,   \ compile EXIT
;



: welcome
    ." FORTHCRAFT - Forth OS for ComputerCraft" cr
    ." by Braden Shepherdson" cr
    ." version " version . cr
;

welcome



: do \ lim start --
  here @
  ' 2dup ,
  ' swap , ' >r , ' >r ,
  ' > ,
  ' 0branch ,
  here @ \ location of offset
  0 , \ dummy exit offset
; immediate

: +loop \ inc --
  ' r> , ' r> , \ i s l
  ' swap , \ ils
  ' rot , ' + , \ l s'
  ' branch , \ ( top branch )
  swap here @ \ ( br top here )
  - , \ top ( br )
  here @ over -
  swap ! \ end
  ' r> , ' r> , ' 2drop ,
; immediate

: loop \ --
  ' lit , 1 , postpone +loop ; immediate

: i \  -- i
  r> r> \ ret i
  dup -rot >r >r ;

: j \ -- j
  r> r> r> r> dup \ ( riljj )
  -rot \ ( r i j l j )
  >r >r \ ( r i j )
  -rot >r >r \ ( j )
;

\ Drops the values from RS.
: unloop \ ( -- )
  r> r> r> 2drop >r ;


\ Copies a block of cells.
\ Copies a1 to a2. DOES NOT HANDLE OVERLAPPING REGIONS!
: move ( a1 a2 n -- )
  0 do
    over @ ( a1 a2 x )
    over ! ( a1 a2 )
    cell+ swap cell+ swap ( a1' a2' )
  loop
;


\ : abort ( -- ) s0 dsp! ." Aborted!" cr quit ;

\ TODO: Fix me. I crash out.
\ : abort" ( "msg<quote>" -- )
\  34 parse-delim \ ( buf len )
\  here @ \ buf len here
\  2+ 2dup + \ buf len here' post-here
\  ' branch , \ compile a branch
\  ,          \ compile post-here ( buf len here' )
\  2dup >r >r \ ( buf len here / here len )
\  swap move \ copy the string ( / here len )
\  r> r> \ len here
\  2dup + here ! \ update HERE ( len here )
\  postpone if
\  ' lit , , \ push literal address to definition
\  ' lit , , \ push literal length to definition
\  ' type ,  \ compile type: emit the message
\  ' cr ,    \ compile cr for a newline.
\  ' abort , \ compile abort
\  postpone then \ and compile then
\ ; immediate


\ Turns a counted string into a two-cell string on the stack.
: count ( c-addr1 -- c-addr2 u ) dup @ ( a len ) swap char+ swap ;

\ Fills a block of memory with a given value.
: fill ( c-addr len char -- )
  -rot ( char c-addr len )
  dup 0> if
    over + swap ( char end start )
    do
      dup i !
    1 chars +loop
  else
    drop 2drop
  then
;


\ Do leaves ( top-of-loop address-of-branch-to-end ) on the compiler stack.
\ Leave needs to compile an unconditional branch to that location.
\ Trouble is, it hasn't been written yet, since the closing +LOOP hasn't been compiled yet.
\ So we compile code that will add a 0 to the stack and then jump to the condition branch.
: leave ( C: top-of-loop address-of-branch-to-end -- top-of-loop address-of-branch-to-end )
  ' lit , 0 , \ compile in the literal 0.
  ' branch ,  \ the branch
  here @      \ ( top branch here )
  2dup - 1-   \ ( top branch here delta ) - extra 1- to point it at the branch order.
  ,           \ ( top branch here )
  drop        \ ( top branch )
; immediate
\ Alternative implementation: Have the top branch jump to the leave, which jumps to the end,
\ chaining the branches.

: negate ( n1 -- n2 ) 0 swap - ;

: accept ( c-addr u1 -- u2 )
  dup >r \ set aside the length for later use
  begin
    dup 0>
  while
    key \ addr len key
    dup 10 = over 13 = + 0<> if
      drop \ addr len
      r>   \ addr rem-len len
      swap - \ addr delta
      nip
      exit \ exit early
    else
      2 pick \ addr len key addr
      ! \ addr len
      1-
    then
  repeat
  2drop r> \ if we got down here, we used up the whole buffer
;


: 2! ( x1 x2 a-addr -- ) swap over ! cell+ ! ;
: 2@ ( a-addr -- x1 x2 ) dup cell+ @ swap @ ;

: [char]
  parse-name \ addr len
  drop @     \ char
  ' lit ,
  ,
; immediate

