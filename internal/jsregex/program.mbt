///|
/// One instruction of a compiled pattern. The matcher runs them with an
/// explicit backtracking stack, so no subject is too long for it: nothing
/// is matched by recursion.
priv enum Inst {
  /// A node that consumes one code unit: `Char`, `Any` or `Class`.
  Unit(Node)
  /// `^`, `$`, `\b` and `\B`, back references.
  Start
  End
  WordBoundary(negated~ : Bool)
  Backref(Int32)
  /// Where capture group `n` starts, kept aside until the group ends, so
  /// that inside it the group still holds what it held before.
  GroupStart(Int32)
  GroupEnd(Int32)
  /// The capture groups `first` to `last`, which a quantified atom holds,
  /// forgotten at the start of each of its iterations.
  Clear(Int32, Int32)
  /// Go on at `first`; when that fails, at `second`.
  Split(Int32, Int32)
  Jump(Int32)
  /// A repetition: `LoopInit` sets its counter to zero, `LoopBranch` at
  /// its head decides whether to iterate or to leave, `LoopStart` notes
  /// where an iteration starts and `LoopNext` ends it.
  LoopInit(Int32)
  LoopBranch(
    counter~ : Int32,
    min~ : Int32,
    max~ : Int32?,
    greedy~ : Bool,
    body~ : Int32,
    exit~ : Int32
  )
  LoopStart(Int32)
  LoopNext(counter~ : Int32, start~ : Int32, min~ : Int32, head~ : Int32)
  /// A repetition of something that consumes one code unit.
  RepeatUnits(Node, min~ : Int32, max~ : Int32?, greedy~ : Bool)
  /// A lookahead's body runs between them; `after` is where matching goes
  /// on.
  LookStart(negated~ : Bool, after~ : Int32)
  LookEnd
  Accept
}

///|
/// A compiled pattern and the registers it needs: the captures (two per
/// group, group 0 included), the start of each group, and a counter and
/// an iteration start per repetition.
priv struct Program {
  code : Array[Inst]
  groups : Int32
  registers : Int32
}

///|
/// The register holding where group `n` started.
fn group_start_register(groups : Int32, n : Int32) -> Int32 {
  2 * (groups + 1) + n
}

///|
fn is_single(node : Node) -> Bool {
  match node {
    Char(_) | Any | Class(_, ..) => true
    Group(inner, capture=None) => is_single(inner)
    _ => false
  }
}

///|
/// The node consuming one code unit inside non-capturing groups.
fn single_node(node : Node) -> Node {
  match node {
    Group(inner, capture=None) => single_node(inner)
    _ => node
  }
}

///|
/// The lowest and highest capture group in `node`.
fn group_range(node : Node) -> (Int32, Int32)? {
  let join = (a : (Int32, Int32)?, b : (Int32, Int32)?) => {
    match (a, b) {
      (Some((x1, y1)), Some((x2, y2))) =>
        Some((if x1 < x2 { x1 } else { x2 }, if y1 > y2 { y1 } else { y2 }))
      (Some(_), None) => a
      _ => b
    }
  }
  match node {
    Group(inner, capture=Some(n)) => join(Some((n, n)), group_range(inner))
    Group(inner, capture=None) | Repeat(inner, ..) | Look(inner, ..) =>
      group_range(inner)
    Seq(items) | Alt(items) => {
      let mut range = None
      for item in items {
        range = join(range, group_range(item))
      }
      range
    }
    _ => None
  }
}

///|
priv struct Compiler {
  code : Array[Inst]
  mut registers : Int32
}

///|
fn compile_program(node : Node, groups : Int32) -> Program {
  let compiler : Compiler = { code: [], registers: 3 * (groups + 1), }
  compiler.emit(node)
  compiler.code.push(Accept)
  { code: compiler.code, groups, registers: compiler.registers, }
}

///|
fn Compiler::here(self : Compiler) -> Int32 {
  self.code.length()
}

///|
fn Compiler::emit(self : Compiler, node : Node) -> Unit {
  match node {
    Empty => ()
    Char(_) | Any | Class(_, ..) => self.code.push(Unit(node))
    Start => self.code.push(Start)
    End => self.code.push(End)
    WordBoundary(negated~) => self.code.push(WordBoundary(negated~))
    Backref(n) => self.code.push(Backref(n))
    Group(inner, capture=None) => self.emit(inner)
    Group(inner, capture=Some(n)) => {
      self.code.push(GroupStart(n))
      self.emit(inner)
      self.code.push(GroupEnd(n))
    }
    Seq(items) =>
      for item in items {
        self.emit(item)
      }
    Alt(alternatives) => {
      let jumps = []
      for i, alternative in alternatives {
        if i == alternatives.length() - 1 {
          self.emit(alternative)
        } else {
          let split = self.here()
          self.code.push(Jump(-1))
          self.emit(alternative)
          jumps.push(self.here())
          self.code.push(Jump(-1))
          self.code[split] = Split(split + 1, self.here())
        }
      }
      for jump in jumps {
        self.code[jump] = Jump(self.here())
      }
    }
    Look(inner, negated~) => {
      let start = self.here()
      self.code.push(Accept)
      self.emit(inner)
      self.code.push(LookEnd)
      self.code[start] = LookStart(negated~, after=self.here())
    }
    // Never iterated: nothing to match, nothing cleared.
    Repeat(_, max=Some(0), ..) => ()
    Repeat(inner, min~, max~, greedy~) if is_single(inner) =>
      self.code.push(RepeatUnits(single_node(inner), min~, max~, greedy~))
    Repeat(inner, min~, max~, greedy~) => {
      let counter = self.registers
      let start = self.registers + 1
      self.registers += 2
      self.code.push(LoopInit(counter))
      let head = self.here()
      self.code.push(Accept)
      self.code.push(LoopStart(start))
      if group_range(inner) is Some((first, last)) {
        self.code.push(Clear(first, last))
      }
      self.emit(inner)
      self.code.push(LoopNext(counter~, start~, min~, head~))
      self.code[head] = LoopBranch(
        counter~,
        min~,
        max~,
        greedy~,
        body=head + 1,
        exit=self.here(),
      )
    }
  }
}
