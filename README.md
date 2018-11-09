# Bytes

Work with densely packed sequences of bytes.

The goal of this package is to support **network protocols** such as ProtoBuf. Or to put it another way, the goal is to have packages like `elm/http` send fewer bytes over the wire.


## Motivation = [A vision for data interchange in Elm](https://gist.github.com/evancz/1c5f2cf34939336ecb79b97bb89d9da6)

Please read it!


## Example

This package lets you create encoders and decoders for working with sequences of bytes. Here is an example for converting between `Point` and `Bytes` values:

```elm
import Bytes exposing (Endianness(..))
import Bytes.Encode as Encode exposing (Encoder)
import Bytes.Decode as Decode exposing (Decoder)


-- POINT

type alias Point =
  { x : Float
  , y : Float
  , z : Float
  }

toPointEncoder : Point -> Encoder
toPointEncoder point =
  Encode.sequence
    [ Encode.float32 BE point.x
    , Encode.float32 BE point.y
    , Encode.float32 BE point.z
    ]

pointDecoder : Decoder Point
pointDecoder =
  Decode.map3 Point
    (Decode.float32 BE)
    (Decode.float32 BE)
    (Decode.float32 BE)
```

Rather than writing this by hand in client or server code, the hope is that folks implement things like ProtoBuf compilers for Elm.

Again, the overall plan is described in [**A vision for data interchange in Elm**](https://gist.github.com/evancz/1c5f2cf34939336ecb79b97bb89d9da6)!


## Scope

**This API is not intended to work like `Int8Array` or `Uint16Array` in JavaScript.** If you have a concrete scenario in which you want to interpret bytes as densely packed arrays of integers or floats, please describe it on [https://discourse.elm-lang.org/](https://discourse.elm-lang.org/) in a friendly and high-level way. What is the project about? What do densely packed arrays do for that project? Is it about perf? What kind of algorithms are you using? Etc.

If some scenarios require the mutation of entries in place, special care will be required in designing a nice API. All values in Elm are immutable, so the particular API that works well for us will probably depend a lot on the particulars of what folks are trying to do.
