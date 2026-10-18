///|
/// What backtracking comes back to, newest last.
priv enum Entry {
  /// Go on at `pc` from `at`.
  Choice(Int32, Int32)
  /// A repetition of single code units: go on at `pc` from `next`; the
  /// positions up to `last` (down to it when `descending`) are left.
  Units(Int32, Int32, Int32, Bool)
  /// Put `value` back in register `register`.
  Undo(Int32, Int32)
  /// A lookahead under way, started at `at`: its body failing means a
  /// positive one fails, and a negative one goes on at `after`.
  Look(Bool, Int32, Int32)
}

///|
/// Run `program` from `at`: the end of the match, with the captures in
/// the registers, or `None`.
///
/// This is ECMAScript's backtracking, alternatives and iterations tried
/// in order, written as a loop over the instructions with the choices and
/// the register writes to undo on an explicit stack. A quantified atom
/// forgets its captures at each iteration, an iteration past the minimum
/// that matches nothing fails, and a lookahead is atomic: once its body
/// matched, the choices inside it are dropped (a positive one keeps its
/// captures, a negative one fails and keeps none).
fn Run::execute(self : Run, program : Program, at : Int32) -> Int32? {
  let code = program.code
  let registers = self.registers
  let n = self.input.length()
  let stack : Array[Entry] = []
  let set = (register : Int32, value : Int32) => {
    stack.push(Undo(register, registers[register]))
    registers[register] = value
  }
  let mut pc = 0
  let mut at = at
  while true {
    let mut failed = false
    match code[pc] {
      Unit(node) =>
        if at < n && self.single(node, at) is Some(true) {
          at += 1
          pc += 1
        } else {
          failed = true
        }
      Start =>
        if at == self.base ||
          (self.multiline && is_line_terminator(self.unit(at - 1))) {
          pc += 1
        } else {
          failed = true
        }
      End =>
        if at == n || (self.multiline && is_line_terminator(self.unit(at))) {
          pc += 1
        } else {
          failed = true
        }
      WordBoundary(negated~) => {
        let before = at > self.base && is_word(self.unit(at - 1))
        let after = at < n && is_word(self.unit(at))
        if (before != after) != negated {
          pc += 1
        } else {
          failed = true
        }
      }
      Backref(index) => {
        let start = if 2 * index + 1 < 2 * (program.groups + 1) {
          registers[2 * index]
        } else {
          -1
        }
        let end = if start >= 0 { registers[2 * index + 1] } else { -1 }
        if start < 0 || end < 0 {
          pc += 1
        } else {
          let length = end - start
          let mut same = at + length <= n
          for i = 0; same && i < length; i = i + 1 {
            let a = self.unit(start + i)
            let b = self.unit(at + i)
            same = a == b || (self.ignore_case && canonical(a) == canonical(b))
          }
          if same {
            at += length
            pc += 1
          } else {
            failed = true
          }
        }
      }
      GroupStart(index) => {
        set(group_start_register(program.groups, index), at)
        pc += 1
      }
      GroupEnd(index) => {
        set(2 * index, registers[group_start_register(program.groups, index)])
        set(2 * index + 1, at)
        pc += 1
      }
      Clear(first, last) => {
        for index in first..<=last {
          if registers[2 * index] != -1 {
            set(2 * index, -1)
          }
          if registers[2 * index + 1] != -1 {
            set(2 * index + 1, -1)
          }
        }
        pc += 1
      }
      Split(first, second) => {
        stack.push(Choice(second, at))
        pc = first
      }
      Jump(target) => pc = target
      LoopInit(counter) => {
        set(counter, 0)
        pc += 1
      }
      LoopBranch(counter~, min~, max~, greedy~, body~, exit~) => {
        let count = registers[counter]
        if count < min {
          pc = body
        } else if max is Some(max) && count >= max {
          pc = exit
        } else if greedy {
          stack.push(Choice(exit, at))
          pc = body
        } else {
          stack.push(Choice(body, at))
          pc = exit
        }
      }
      LoopStart(start) => {
        set(start, at)
        pc += 1
      }
      LoopNext(counter~, start~, min~, head~) => {
        let count = registers[counter]
        // An iteration that matches nothing past the minimum ends the
        // repetition there, as a failure.
        if at == registers[start] && count >= min {
          failed = true
        } else {
          set(counter, count + 1)
          pc = head
        }
      }
      RepeatUnits(node, min~, max~, greedy~) => {
        let limit = match max {
          Some(max) => if at + max < n { at + max } else { n }
          None => n
        }
        let mut reach = at
        while reach < limit && self.single(node, reach) is Some(true) {
          reach += 1
        }
        if reach - at < min {
          failed = true
        } else if greedy {
          if reach > at + min {
            stack.push(Units(pc + 1, reach - 1, at + min, true))
          }
          at = reach
          pc += 1
        } else {
          if reach > at + min {
            stack.push(Units(pc + 1, at + min + 1, reach, false))
          }
          at = at + min
          pc += 1
        }
      }
      LookStart(negated~, after~) => {
        stack.push(Look(negated, after, at))
        pc += 1
      }
      LookEnd => {
        // The innermost lookahead under way is the nearest on the stack.
        let mut marker = stack.length() - 1
        while !(stack[marker] is Look(_, _, _)) {
          marker -= 1
        }
        guard stack[marker] is Look(negated, after, start) else { panic() }
        if negated {
          // Its body matched: undo what it did, and fail.
          for index = stack.length() - 1; index > marker; index = index - 1 {
            if stack[index] is Undo(register, value) {
              registers[register] = value
            }
          }
          stack.truncate(marker)
          failed = true
        } else {
          // Its choices go; the register writes stay, to be undone when
          // backtracking passes this point.
          let mut kept = marker
          for index in (marker + 1)..<stack.length() {
            if stack[index] is Undo(_, _) {
              stack[kept] = stack[index]
              kept += 1
            }
          }
          stack.truncate(kept)
          at = start
          pc = after
        }
      }
      Accept => return Some(at)
    }
    if !failed {
      continue
    }
    // Backtrack to the latest choice.
    let mut resumed = false
    while !resumed && stack.pop() is Some(entry) {
      match entry {
        Undo(register, value) => registers[register] = value
        Choice(target, position) => {
          pc = target
          at = position
          resumed = true
        }
        Units(target, next, last, descending) => {
          pc = target
          at = next
          if descending && next - 1 >= last {
            stack.push(Units(target, next - 1, last, true))
          } else if !descending && next + 1 <= last {
            stack.push(Units(target, next + 1, last, false))
          }
          resumed = true
        }
        // The body of a lookahead failed.
        Look(negated, after, start) =>
          if negated {
            pc = after
            at = start
            resumed = true
          }
      }
    }
    if !resumed {
      return None
    }
  }
  None
}
