module Bytes.Encode exposing
  ( encode
  , Encoder
  , signedInt8, signedInt16, signedInt32
  , unsignedInt8, unsignedInt16, unsignedInt32
  , float32, float64
  , bytes
  , string, getStringWidth
  , sequence
  )


{-|

# Encoders
@docs encode, Encoder, sequence

# Integers
@docs signedInt8, signedInt16, signedInt32,
  unsignedInt8, unsignedInt16, unsignedInt32

# Floats
@docs float32, float64

# Bytes
@docs bytes

# Strings
@docs string, getStringWidth

-}


import Bytes exposing (Bytes, Endianness(..))



-- ENCODER


{-| Describes how to generate a sequence of bytes.

These encoders snap together with [`sequence`](#sequence) so you can start with
small building blocks and put them together into a more complex encoding.
-}
type Encoder
  = I8 Int
  | I16 Endianness Int
  | I32 Endianness Int
  | U8 Int
  | U16 Endianness Int
  | U32 Endianness Int
  | F32 Endianness Float
  | F64 Endianness Float
  | Seq Int (List Encoder)
  | Utf8 Int String
  | Bytes Bytes



-- ENCODE


{-| Turn an `Encoder` into `Bytes`.

    encode (unsignedInt8     7) -- <07>
    encode (unsignedInt16 BE 7) -- <0007>
    encode (unsignedInt16 LE 7) -- <0700>

The `encode` function is designed to minimize allocation. It figures out the
exact width necessary to fit everything in `Bytes` and then generate that
value directly. This is valuable when you are encoding more elaborate data:

    import Bytes exposing (Endianness(..))
    import Bytes.Encode as Encode

    type alias Person =
      { age : Int
      , name : String
      }

    toEncoder : Person -> Encode.Encoder
    toEncoder person =
      Encode.sequence
        [ Encode.unsignedInt16 BE person.age
        , Encode.unsignedInt16 BE (Encode.getStringWidth person.name)
        , Encode.string person.name
        ]

    -- encode (toEncoder (Person 33 "Tom")) == <00210003546F6D>

Did you know it was going to be seven bytes? How about when you have a hundred
people to serialize? And when some have Japanese and Norwegian names? Having
this intermediate `Encoder` can help reduce allocation quite a lot!
-}
encode : Encoder -> Bytes
encode =
  Elm.Kernel.Bytes.encode



-- INTEGERS


{-| Encode integers from `-128` to `127` in one byte.
-}
signedInt8 : Int -> Encoder
signedInt8 =
  I8


{-| Encode integers from `-32768` to `32767` in two bytes.
-}
signedInt16 : Endianness -> Int -> Encoder
signedInt16 =
  I16


{-| Encode integers from `-2147483648` to `2147483647` in four bytes.
-}
signedInt32 : Endianness -> Int -> Encoder
signedInt32 =
  I32


{-| Encode integers from `0` to `255` in one byte.
-}
unsignedInt8 : Int -> Encoder
unsignedInt8 =
  U8


{-| Encode integers from `0` to `65535` in two bytes.
-}
unsignedInt16 : Endianness -> Int -> Encoder
unsignedInt16 =
  U16


{-| Encode integers from `0` to `4294967295` in four bytes.
-}
unsignedInt32 : Endianness -> Int -> Encoder
unsignedInt32 =
  U32



-- FLOATS


{-| Encode 32-bit floating point numbers in four bytes.
-}
float32 : Endianness -> Float -> Encoder
float32 =
  F32


{-| Encode 64-bit floating point numbers in eight bytes.
-}
float64 : Endianness -> Float -> Encoder
float64 =
  F64



-- BYTES


{-| Copy bytes directly into the new `Bytes` sequence. This does not record the
width though! You usually want to say something like this:

    import Bytes exposing (Bytes, Endianness(..))
    import Bytes.Encode as Encode

    png : Bytes -> Encode.Encoder
    png imageData =
      Encode.sequence
        [ Encode.unsignedInt32 BE (Bytes.width imageData)
        , Encode.bytes imageData
        ]

This allows you to represent the width however is necessary for your protocol.
For example, you can use [Base 128 Varints][pb] for ProtoBuf,
[Variable-Length Integers][sql] for SQLite, or whatever else they dream up.

[pb]: https://developers.google.com/protocol-buffers/docs/encoding#varints
[sql]: https://www.sqlite.org/src4/doc/trunk/www/varint.wiki
-}
bytes : Bytes -> Encoder
bytes =
  Bytes



-- STRINGS


{-| Encode a `String` as a bunch of UTF-8 bytes.

    encode (string "$20")   -- <24 32 30>
    encode (string "£20")   -- <C2A3 32 30>
    encode (string "€20")   -- <E282AC 32 30>
    encode (string "bread") -- <62 72 65 61 64>
    encode (string "brød")  -- <62 72 C3B8 64>

Some characters take one byte, while others can take up to four. Read more
about [UTF-8](https://en.wikipedia.org/wiki/UTF-8) to learn the details!

But if you just encode UTF-8 directly, how can you know when you get to the end
of the string when you are decoding? So most protocols have an integer saying
how many bytes follow, like this:

    sizedString : String -> Encoder
    sizedString str =
      sequence
        [ unsignedInt32 BE (getStringWidth str)
        , string str
        ]

You can choose whatever representation you want for the width, which is helpful
because many protocols use different integer representations to save space. For
example:

- ProtoBuf uses [Base 128 Varints](https://developers.google.com/protocol-buffers/docs/encoding#varints)
- SQLite uses [Variable-Length Integers](https://www.sqlite.org/src4/doc/trunk/www/varint.wiki)

In both cases, small numbers can fit just one byte, saving some space. (The
SQLite encoding has the benefit that the first byte tells you how long the
number is, making it faster to decode.) In both cases, it is sort of tricky
to make negative numbers small.
-}
string : String -> Encoder
string str =
  Utf8 (Elm.Kernel.Bytes.getStringWidth str) str


{-| Get the width of a `String` in UTF-8 bytes.

    getStringWidth "$20"   == 3
    getStringWidth "£20"   == 4
    getStringWidth "€20"   == 5
    getStringWidth "bread" == 5
    getStringWidth "brød"  == 5

Most protocols need this number to come directly before a chunk of UTF-8 bytes
as a way to know where the string ends!

Read more about how UTF-8 works [here](https://en.wikipedia.org/wiki/UTF-8).
-}
getStringWidth : String -> Int
getStringWidth =
  Elm.Kernel.Bytes.getStringWidth



-- SEQUENCE


{-| Put together a bunch of builders. So if you wanted to encode three `Float`
values for the position of a ball in 3D space, you could say:

    import Bytes exposing (Endianness(..))
    import Bytes.Encode as Encode

    type alias Ball = { x : Float, y : Float, z : Float }

    ball : Ball -> Encode.Encoder
    ball {x,y,z} =
      Encode.sequence
        [ Encode.float32 BE x
        , Encode.float32 BE y
        , Encode.float32 BE z
        ]

-}
sequence : List Encoder -> Encoder
sequence builders =
  Seq (getWidths 0 builders) builders



-- WRITE


write : Encoder -> Bytes -> Int -> Int
write builder mb offset =
  case builder of
    I8    n -> Elm.Kernel.Bytes.write_i8  mb offset n
    I16 e n -> Elm.Kernel.Bytes.write_i16 mb offset n (e == LE)
    I32 e n -> Elm.Kernel.Bytes.write_i32 mb offset n (e == LE)
    U8    n -> Elm.Kernel.Bytes.write_u8  mb offset n
    U16 e n -> Elm.Kernel.Bytes.write_u16 mb offset n (e == LE)
    U32 e n -> Elm.Kernel.Bytes.write_u32 mb offset n (e == LE)
    F32 e n -> Elm.Kernel.Bytes.write_f32 mb offset n (e == LE)
    F64 e n -> Elm.Kernel.Bytes.write_f64 mb offset n (e == LE)
    Seq _ bs -> writeSequence bs mb offset
    Utf8 _ s -> Elm.Kernel.Bytes.write_string mb offset s
    Bytes bs -> Elm.Kernel.Bytes.write_bytes mb offset bs


writeSequence : List Encoder -> Bytes -> Int -> Int
writeSequence builders mb offset =
  case builders of
    [] ->
      offset

    b :: bs ->
      writeSequence bs mb (write b mb offset)



-- WIDTHS


getWidth : Encoder -> Int
getWidth builder =
  case builder of
    I8    _ -> 1
    I16 _ _ -> 2
    I32 _ _ -> 4
    U8    _ -> 1
    U16 _ _ -> 2
    U32 _ _ -> 4
    F32 _ _ -> 4
    F64 _ _ -> 8
    Seq w _ -> w
    Utf8 w _ -> w
    Bytes bs -> Elm.Kernel.Bytes.width bs


getWidths : Int -> List Encoder -> Int
getWidths width builders =
  case builders of
    [] ->
      width

    b :: bs ->
      getWidths (width + getWidth b) bs
