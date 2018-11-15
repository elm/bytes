module Bytes.Decode exposing
  ( Decoder, decode
  , signedInt8, signedInt16, signedInt32
  , unsignedInt8, unsignedInt16, unsignedInt32
  , float32, float64
  , string
  , bytes
  , map, map2, map3, map4, map5
  , andThen, succeed, fail
  , Step(..), loop
  )


{-|

# Decoders
@docs Decoder, decode

# Integers
@docs signedInt8, signedInt16, signedInt32,
  unsignedInt8, unsignedInt16, unsignedInt32

# Floats
@docs float32, float64

# Bytes
@docs bytes

# Strings
@docs string

# Map
@docs map, map2, map3, map4, map5

# And Then
@docs andThen, succeed, fail

# Loop
@docs Step, loop
-}


import Bytes exposing (Bytes, Endianness(..))



-- PARSER


{-| Describes how to turn a sequence of bytes into a nice Elm value.
-}
type Decoder a =
  Decoder (Bytes -> Int -> (Int, a))


{-| Turn a sequence of bytes into a nice Elm value.

    -- decode (unsignedInt16 BE) <0007> == Just 7
    -- decode (unsignedInt16 LE) <0700> == Just 7
    -- decode (unsignedInt16 BE) <0700> == Just 1792
    -- decode (unsignedInt32 BE) <0700> == Nothing

The `Decoder` specifies exactly how this should happen. This process may fail
if the sequence of bytes is corrupted or unexpected somehow. The examples above
show a case where there are not enough bytes.
-}
decode : Decoder a -> Bytes -> Maybe a
decode (Decoder decoder) bs =
  Elm.Kernel.Bytes.decode decoder bs



-- SIGNED INTEGERS


{-| Decode one byte into an integer from `-128` to `127`.
-}
signedInt8 : Decoder Int
signedInt8 =
  Decoder Elm.Kernel.Bytes.read_i8


{-| Decode two bytes into an integer from `-32768` to `32767`.
-}
signedInt16 : Endianness -> Decoder Int
signedInt16 endianness =
  Decoder (Elm.Kernel.Bytes.read_i16 (endianness == LE))


{-| Decode four bytes into an integer from `-2147483648` to `2147483647`.
-}
signedInt32 : Endianness -> Decoder Int
signedInt32 endianness =
  Decoder (Elm.Kernel.Bytes.read_i32 (endianness == LE))



-- UNSIGNED INTEGERS


{-| Decode one byte into an integer from `0` to `255`.
-}
unsignedInt8 : Decoder Int
unsignedInt8 =
  Decoder Elm.Kernel.Bytes.read_u8


{-| Decode two bytes into an integer from `0` to `65535`.
-}
unsignedInt16 : Endianness -> Decoder Int
unsignedInt16 endianness =
  Decoder (Elm.Kernel.Bytes.read_u16 (endianness == LE))


{-| Decode four bytes into an integer from `0` to `4294967295`.
-}
unsignedInt32 : Endianness -> Decoder Int
unsignedInt32 endianness =
  Decoder (Elm.Kernel.Bytes.read_u32 (endianness == LE))



-- FLOATS


{-| Decode four bytes into a floating point number.
-}
float32 : Endianness -> Decoder Float
float32 endianness =
  Decoder (Elm.Kernel.Bytes.read_f32 (endianness == LE))


{-| Decode eight bytes into a floating point number.
-}
float64 : Endianness -> Decoder Float
float64 endianness =
  Decoder (Elm.Kernel.Bytes.read_f64 (endianness == LE))



-- BYTES


{-| Copy a given number of bytes into a new `Bytes` sequence.
-}
bytes : Int -> Decoder Bytes
bytes n =
  Decoder (Elm.Kernel.Bytes.read_bytes n)



-- STRINGS


{-| Decode a given number of UTF-8 bytes into a `String`.

Most protocols store the width of the string right before the content, so you
will probably write things like this:

    import Bytes exposing (Endianness(..))
    import Bytes.Decode as Decode

    sizedString : Decode.Decoder String
    sizedString =
      Decode.unsignedInt32 BE
        |> Decode.andThen Decode.string

In this case we read the width as a 32-bit unsigned integer, but you have the
leeway to read the width as a [Base 128 Varint][pb] for ProtoBuf, a
[Variable-Length Integer][sql] for SQLite, or whatever else they dream up.

[pb]: https://developers.google.com/protocol-buffers/docs/encoding#varints
[sql]: https://www.sqlite.org/src4/doc/trunk/www/varint.wiki
-}
string : Int -> Decoder String
string n =
  Decoder (Elm.Kernel.Bytes.read_string n)



-- MAP


{-| Transform the value produced by a decoder. If you encode negative numbers
in a special way, you can say something like this:

    negativeInt8 : Decoder Int
    negativeInt8 =
      map negate unsignedInt8

In practice you may see something like ProtoBuf’s [ZigZag encoding][zz] which
decreases the size of small negative numbers.

[zz]: https://developers.google.com/protocol-buffers/docs/encoding#types
-}
map : (a -> b) -> Decoder a -> Decoder b
map func (Decoder decodeA) =
  Decoder <|
    \bites offset ->
      let
        (aOffset, a) = decodeA bites offset
      in
      (aOffset, func a)


{-| Combine two decoders.

    import Bytes exposing (Endiannness(..))
    import Bytes.Decode as Decode

    type alias Point = { x : Float, y : Float }

    decoder : Decode.Decoder Point
    decoder =
      Decode.map2 Point
        (Decode.float32 BE)
        (Decode.float32 BE)
-}
map2 : (a -> b -> result) -> Decoder a -> Decoder b -> Decoder result
map2 func (Decoder decodeA) (Decoder decodeB) =
  Decoder <|
    \bites offset ->
      let
        (aOffset, a) = decodeA bites offset
        (bOffset, b) = decodeB bites aOffset
      in
      (bOffset, func a b)


{-| Combine three decoders.
-}
map3 : (a -> b -> c -> result) -> Decoder a -> Decoder b -> Decoder c -> Decoder result
map3 func (Decoder decodeA) (Decoder decodeB) (Decoder decodeC) =
  Decoder <|
    \bites offset ->
      let
        (aOffset, a) = decodeA bites offset
        (bOffset, b) = decodeB bites aOffset
        (cOffset, c) = decodeC bites bOffset
      in
      (cOffset, func a b c)


{-| Combine four decoders.
-}
map4 : (a -> b -> c -> d -> result) -> Decoder a -> Decoder b -> Decoder c -> Decoder d -> Decoder result
map4 func (Decoder decodeA) (Decoder decodeB) (Decoder decodeC) (Decoder decodeD) =
  Decoder <|
    \bites offset ->
      let
        (aOffset, a) = decodeA bites offset
        (bOffset, b) = decodeB bites aOffset
        (cOffset, c) = decodeC bites bOffset
        (dOffset, d) = decodeD bites cOffset
      in
      (dOffset, func a b c d)


{-| Combine five decoders. If you need to combine more things, it is possible
to define more of these with `map2` or `andThen`.
-}
map5 : (a -> b -> c -> d -> e -> result) -> Decoder a -> Decoder b -> Decoder c -> Decoder d -> Decoder e -> Decoder result
map5 func (Decoder decodeA) (Decoder decodeB) (Decoder decodeC) (Decoder decodeD) (Decoder decodeE) =
  Decoder <|
    \bites offset ->
      let
        (aOffset, a) = decodeA bites offset
        (bOffset, b) = decodeB bites aOffset
        (cOffset, c) = decodeC bites bOffset
        (dOffset, d) = decodeD bites cOffset
        (eOffset, e) = decodeE bites dOffset
      in
      (eOffset, func a b c d e)



-- AND THEN


{-| Decode something **and then** use that information to decode something
else. This is most common with strings or sequences where you need to read
how long the value is going to be:

    import Bytes exposing (Endianness(..))
    import Bytes.Decode as Decode

    string : Decoder String
    string =
      Decode.unsignedInt32 BE
        |> Decode.andThen Decode.string

Check out the docs for [`succeed`](#succeed), [`fail`](#fail), and
[`loop`](#loop) to see `andThen` used in more ways!
-}
andThen : (a -> Decoder b) -> Decoder a -> Decoder b
andThen callback (Decoder decodeA) =
  Decoder <|
    \bites offset ->
      let
        (newOffset, a) = decodeA bites offset
        (Decoder decodeB) = callback a
      in
      decodeB bites newOffset


{-| A decoder that always succeeds with a certain value. Maybe we are making
a `Maybe` decoder:

    import Bytes.Decode as Decode exposing (Decoder)

    maybe : Decoder a -> Decoder (Maybe a)
    maybe decoder =
      let
        helper n =
          if n == 0 then
            Decode.succeed Nothing
          else
            Decode.map Just decoder
      in
      Decode.unsignedInt8
        |> Decode.andThen helper

If the first byte is `00000000` then it is `Nothing`, otherwise we start
decoding the value and put it in a `Just`.
-}
succeed : a -> Decoder a
succeed a =
  Decoder (\_ offset -> (offset,a))


{-| A decoder that always fails. This can be useful when using `andThen` to
decode custom types:

    import Bytes exposing (Endianness(..))
    import Bytes.Encode as Encode
    import Bytes.Decode as Decode

    type Distance = Yards Float | Meters Float

    toEncoder : Distance -> Encode.Encoder
    toEncoder distance =
      case distance of
        Yards n -> Encode.sequence [ Encode.unsignedInt8 0, Encode.float32 BE n ]
        Meters n -> Encode.sequence [ Encode.unsignedInt8 1, Encode.float32 BE n ]

    decoder : Decode.Decoder Distance
    decoder =
      Decode.unsignedInt8
        |> Decode.andThen pickDecoder

    pickDecoder : Int -> Decode.Decoder Distance
    pickDecoder tag =
      case tag of
        0 -> Decode.map Yards (Decode.float32 BE)
        1 -> Decode.map Meters (Decode.float32 BE)
        _ -> Decode.fail

The encoding chosen here uses an 8-bit unsigned integer to indicate which
variant we are working with. If we are working with yards do this, if we are
working with meters do that, and otherwise something went wrong!
-}
fail : Decoder a
fail =
  Decoder Elm.Kernel.Bytes.decodeFailure



-- LOOP


{-| Decide what steps to take next in your [`loop`](#loop).

If you are `Done`, you give the result of the whole `loop`. If you decide to
`Loop` around again, you give a new state to work from. Maybe you need to add
an item to a list? Or maybe you need to track some information about what you
just saw?

**Note:** It may be helpful to learn about [finite-state machines][fsm] to get
a broader intuition about using `state`. I.e. You may want to create a `type`
that describes four possible states, and then use `Loop` to transition between
them as you consume characters.

[fsm]: https://en.wikipedia.org/wiki/Finite-state_machine
-}
type Step state a
  = Loop state
  | Done a


{-| A decoder that can loop indefinitely. This can be helpful when parsing
repeated structures, like a list:

    import Bytes exposing (Endianness(..))
    import Bytes.Decode as Decode exposing (..)

    list : Decoder a -> Decoder (List a)
    list decoder =
      unsignedInt32 BE
        |> andThen (\len -> loop (len, []) (listStep decoder))

    listStep : Decoder a -> (Int, List a) -> Decoder (Step (Int, List a) (List a))
    listStep decoder (n, xs) =
      if n <= 0 then
        succeed (Done xs)
      else
        map (\x -> Loop (n - 1, x :: xs)) decoder

The `list` decoder first reads a 32-bit unsigned integer. That determines how
many items will be decoded. From there we use [`loop`](#loop) to track all the
items we have parsed so far and figure out when to stop.
-}
loop : state -> (state -> Decoder (Step state a)) -> Decoder a
loop state callback =
  Decoder (loopHelp state callback)


loopHelp : state -> (state -> Decoder (Step state a)) -> Bytes -> Int -> (Int, a)
loopHelp state callback bites offset =
  let
    (Decoder decoder) = callback state
    (newOffset, step) = decoder bites offset
  in
  case step of
    Loop newState ->
      loopHelp newState callback bites newOffset

    Done result ->
      ( newOffset, result )
