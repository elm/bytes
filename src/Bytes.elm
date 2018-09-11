module Bytes exposing
  ( Bytes
  , width
  , Endianness(..)
  , getHostEndianness
  )


{-|

# Bytes
@docs Bytes, width

# Endianness
@docs Endianness, getHostEndianness

-}


import Elm.Kernel.Bytes
import Task exposing (Task)


-- BYTES


{-| A sequence of bytes.

A byte is a chunk of eight bits. For example, the letter `j` is usually
represented as the byte `01101010`, and the letter `k` is `01101011`.

Seeing each byte as a stream of zeros and ones can be quite confusing though,
so it is common to use hexidecimal numbers instead:

```
| Binary | Hex |
+--------+-----+
|  0000  |  0  |
|  0001  |  1  |
|  0010  |  2  |
|  0011  |  3  |     j = 01101010
|  0100  |  4  |         \__/\__/
|  0101  |  5  |           |   |
|  0110  |  6  |           6   A
|  0111  |  7  |
|  1000  |  8  |     k = 01101011
|  1001  |  9  |         \__/\__/
|  1010  |  A  |           |   |
|  1011  |  B  |           6   B
|  1100  |  C  |
|  1101  |  D  |
|  1110  |  E  |
|  1111  |  F  |
```

So `j` is `6A` and `k` is `6B` in hexidecimal. This more compact representation
is great when you have a sequence of bytes. You can see this even in a short
string like `"jazz"`:

```
binary                                 hexidecimal
01101010 01100001 01111010 01111010 => 6A 61 7A 7A
```

Anyway, the point is that `Bytes` is a sequence of bytes!
-}
type Bytes = Bytes


{-| Get the width of a sequence of bytes.

So if a sequence has four-hundred bytes, then `width bytes` would give back
`400`. That may be 400 unsigned 8-bit integers, 100 signed 32-bit integers, or
even a UTF-8 string. The content does not matter. This is just figuring out
how many bytes there are!
-}
width : Bytes -> Int
width =
  Elm.Kernel.Bytes.width



-- ENDIANNESS


{-| Different computers store integers and floats slightly differently in
memory. Say we have the integer `0x1A2B3C4D` in our program. It needs four
bytes (32 bits) in memory. It may seem reasonable to lay them out in order:

```
   Big-Endian (BE)      (Obvious Order)
+----+----+----+----+
| 1A | 2B | 3C | 4D |
+----+----+----+----+
```

But some people thought it would be better to store the bytes in the opposite
order:

```
  Little-Endian (LE)    (Shuffled Order)
+----+----+----+----+
| 4D | 3C | 2B | 1A |
+----+----+----+----+
```

Notice that **the _bytes_ are shuffled, not the bits.** It is like if you cut a
photo into four strips and shuffled the strips. It is not a mirror image.
The theory seems to be that an 8-bit `0x1A` and a 32-bit `0x0000001A` both have
`1A` as the first byte in this scheme. Maybe this was helpful when processors
handled one byte at a time.

**Most processors use little-endian (LE) layout.** This seems to be because
Intel did it this way, and other chip manufactures followed their convention.
**Most network protocols use big-endian (BE) layout.** I suspect this is
because if you are trying to debug a network protocol, it is nice if your
integers are not all shuffled.

**Note:** Endianness is relevant for integers and floats, but not strings.
UTF-8 specifies the order of bytes explicitly.

**Note:** The terms little-endian and big-endian are a reference to an egg joke
in Gulliver's Travels. They first appeared in 1980 in [this essay][essay], and
you can decide for yourself if they stood the test of time. I personally find
these terms quite unhelpful, so I say “Obvious Order” and “Shuffled Order” in
my head. I remember which is more common by asking myself, “if things were
obvious, would I have to ask this question?”

[essay]: http://www.ietf.org/rfc/ien/ien137.txt
-}
type Endianness = LE | BE


{-| Is this program running on a big-endian or little-endian machine?
-}
getHostEndianness : Task x Endianness
getHostEndianness =
  Elm.Kernel.Bytes.getHostEndianness LE BE
