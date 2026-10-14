// The numbers upstream gives the kinds of entries in a sequence diagram
// (`LINETYPE` in sequenceDb.ts). The grammar hands them around as plain
// numbers, so they stay numbers here.

///|
const SOLID : Int32 = 0

///|
const DOTTED : Int32 = 1

///|
const NOTE : Int32 = 2

///|
const SOLID_CROSS : Int32 = 3

///|
const DOTTED_CROSS : Int32 = 4

///|
const SOLID_OPEN : Int32 = 5

///|
const DOTTED_OPEN : Int32 = 6

///|
const LOOP_START : Int32 = 10

///|
const LOOP_END : Int32 = 11

///|
const ALT_START : Int32 = 12

///|
const ALT_ELSE : Int32 = 13

///|
const ALT_END : Int32 = 14

///|
const OPT_START : Int32 = 15

///|
const OPT_END : Int32 = 16

///|
const ACTIVE_START : Int32 = 17

///|
const ACTIVE_END : Int32 = 18

///|
const PAR_START : Int32 = 19

///|
const PAR_AND : Int32 = 20

///|
const PAR_END : Int32 = 21

///|
const RECT_START : Int32 = 22

///|
const RECT_END : Int32 = 23

///|
const SOLID_POINT : Int32 = 24

///|
const DOTTED_POINT : Int32 = 25

///|
const AUTONUMBER : Int32 = 26

///|
const CRITICAL_START : Int32 = 27

///|
const CRITICAL_OPTION : Int32 = 28

///|
const CRITICAL_END : Int32 = 29

///|
const BREAK_START : Int32 = 30

///|
const BREAK_END : Int32 = 31

///|
const PAR_OVER_START : Int32 = 32

///|
const BIDIRECTIONAL_SOLID : Int32 = 33

///|
const BIDIRECTIONAL_DOTTED : Int32 = 34

///|
const SOLID_TOP : Int32 = 41

///|
const SOLID_BOTTOM : Int32 = 42

///|
const STICK_TOP : Int32 = 43

///|
const STICK_BOTTOM : Int32 = 44

///|
const SOLID_ARROW_TOP_REVERSE : Int32 = 45

///|
const SOLID_ARROW_BOTTOM_REVERSE : Int32 = 46

///|
const STICK_ARROW_TOP_REVERSE : Int32 = 47

///|
const STICK_ARROW_BOTTOM_REVERSE : Int32 = 48

///|
const SOLID_TOP_DOTTED : Int32 = 51

///|
const SOLID_BOTTOM_DOTTED : Int32 = 52

///|
const STICK_TOP_DOTTED : Int32 = 53

///|
const STICK_BOTTOM_DOTTED : Int32 = 54

///|
const SOLID_ARROW_TOP_REVERSE_DOTTED : Int32 = 55

///|
const SOLID_ARROW_BOTTOM_REVERSE_DOTTED : Int32 = 56

///|
const STICK_ARROW_TOP_REVERSE_DOTTED : Int32 = 57

///|
const STICK_ARROW_BOTTOM_REVERSE_DOTTED : Int32 = 58

///|
const CENTRAL_CONNECTION : Int32 = 59

///|
const CENTRAL_CONNECTION_REVERSE : Int32 = 60

///|
const CENTRAL_CONNECTION_DUAL : Int32 = 61

///|
/// Where a note sits relative to its participant (`PLACEMENT`).
const LEFT_OF : Int32 = 0

///|
const RIGHT_OF : Int32 = 1

///|
const OVER : Int32 = 2

///|
/// The entries that draw a message line between two participants.
fn is_message_line(kind : Int32) -> Bool {
  kind
  is (SOLID_OPEN
  | DOTTED_OPEN
  | SOLID
  | SOLID_TOP
  | SOLID_BOTTOM
  | STICK_TOP
  | STICK_BOTTOM
  | SOLID_TOP_DOTTED
  | SOLID_BOTTOM_DOTTED
  | STICK_TOP_DOTTED
  | STICK_BOTTOM_DOTTED
  | SOLID_ARROW_TOP_REVERSE
  | SOLID_ARROW_BOTTOM_REVERSE
  | STICK_ARROW_TOP_REVERSE
  | STICK_ARROW_BOTTOM_REVERSE
  | SOLID_ARROW_TOP_REVERSE_DOTTED
  | SOLID_ARROW_BOTTOM_REVERSE_DOTTED
  | STICK_ARROW_TOP_REVERSE_DOTTED
  | STICK_ARROW_BOTTOM_REVERSE_DOTTED
  | DOTTED
  | SOLID_CROSS
  | DOTTED_CROSS
  | SOLID_POINT
  | DOTTED_POINT
  | BIDIRECTIONAL_SOLID
  | BIDIRECTIONAL_DOTTED)
}

///|
/// Half-arrows whose head is at the sending end.
fn is_reverse_arrow(kind : Int32) -> Bool {
  kind
  is (SOLID_ARROW_TOP_REVERSE
  | SOLID_ARROW_TOP_REVERSE_DOTTED
  | SOLID_ARROW_BOTTOM_REVERSE
  | SOLID_ARROW_BOTTOM_REVERSE_DOTTED
  | STICK_ARROW_TOP_REVERSE
  | STICK_ARROW_TOP_REVERSE_DOTTED
  | STICK_ARROW_BOTTOM_REVERSE
  | STICK_ARROW_BOTTOM_REVERSE_DOTTED)
}

///|
fn is_bidirectional(kind : Int32) -> Bool {
  kind is (BIDIRECTIONAL_SOLID | BIDIRECTIONAL_DOTTED)
}

///|
fn has_central_connection(connection : Int32) -> Bool {
  connection
  is (CENTRAL_CONNECTION | CENTRAL_CONNECTION_REVERSE | CENTRAL_CONNECTION_DUAL)
}
