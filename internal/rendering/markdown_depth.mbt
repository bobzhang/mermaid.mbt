// marked lexes a block quote's content as blocks again, and emphasis
// content as inline tokens again, so each level of nesting is a level of
// recursion, in marked and in the port alike (lists are not lexed inside
// here, and nest nothing). The lexer counts the levels and stops past
// these limits, and `markdown_blocks` refuses the label; they are well
// below the depth the stack of every backend takes: 800 block quotes lex
// on js, wasm-gc and native, 1600 overflow on js and wasm-gc; 2000 levels
// of emphasis lex there, 6000 do not.

///|
/// The deepest nesting of block quotes a label may have.
let max_quote_depth : Int32 = 250

///|
/// The deepest nesting of emphasis a label may have.
let max_emphasis_depth : Int32 = 500

///|
fn nesting_error() -> LayoutError {
  LayoutError(
    "a label nests block quotes or emphasis deeper than the port lexes (more than \{max_quote_depth} quotes or \{max_emphasis_depth} levels of emphasis)",
  )
}
