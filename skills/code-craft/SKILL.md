---
name: code-craft
description: >
  Design, refactor and review code for structure — where each piece of
  knowledge lives, what each module hides, and whether the types can
  represent a wrong state. Load BEFORE proposing any design: a design-gate
  ticket, choosing between candidate directions, a contract or API, a type or
  state model, a lifecycle or init/boot ordering, a new module or subsystem.
  Load before any refactor — extracting, splitting, moving or decomposing a
  large file or class, a god object or integration shell. Load for every code
  review, PR review or diff review. Load when a bug is the second or third of
  the same shape (a recurring class wants a mechanism, not another fix), and
  when tempted to add a design pattern, interface, factory, strategy, wrapper,
  or indirection. Distils Clean Code, Design Patterns (GoF), Refactoring
  (Fowler), A Philosophy of Software Design (Ousterhout) and Working
  Effectively with Legacy Code (Feathers) into gates that change what gets
  written; skips their dogma.
---

# Code craft

The always-on subset is the code-standards rules' § Code structure, installed
in the project's or user's agent instructions. This skill is the full pass.
Project rules win where they are more specific.

Pick the section for the job, then run it before writing any code or
proposal:

- Designing anything, or a design-gate ticket → § Design pass
- Refactoring → § Design pass, then § Refactoring
- Reviewing → § Review lens
- Fixing a bug whose shape has been seen before → § Bug classes, first
- Writing new code in a seam named in `references/write-time-patterns.md` →
  that section, at write time

## Design pass

Answer each in writing, in the proposal. An unanswered question is the
design's weak point, so name it rather than skip it.

1. **Where is each piece of knowledge decided?** List every place the same
   fact is written: a path, a column roster, a kind list, a formula, the
   order of steps. More than one → one owner, the rest derived from it. Two
   lists kept in step by a test are defended, not designed; say so and
   prefer deriving one from the other.
2. **Can the type hold a wrong state?** For each value, enumerate its real
   states (absent, pending, ready, failed, stale). If a legal-looking value
   — `0`, `false`, `-1`, `(0,0,0)`, empty, infinity, a null coalesced to a
   default — stands in for "not yet", the design is wrong: make the state a
   variant the caller must match on (a sum type: sealed class, tagged union,
   enum with payload), or make the call impossible before the data exists.
   Parse at the boundary into types that cannot be invalid; don't
   re-validate inside.
3. **When is it true?** Order of construction, attach, first use, dispose.
   For each reader: can it run before its data arrives, and if it samples
   early and holds the value, what re-reconciles it? A rule stated in prose
   and broken more than once is not a mechanism; the answer is a type or a
   test.
4. **What does each module hide?** Its interface must be much simpler than
   its implementation. A module whose callers must know its internals, or a
   pass-through that only forwards, is cost without depth.
5. **Why would each module change?** One reason each. A file that changes
   for several unrelated reasons (rendering, input, loading, persistence) is
   several modules sharing a name.
6. **What varies today?** Name two concrete cases in this codebase before
   adding any pattern or seam (`references/patterns-by-force.md`). A seam
   for a hypothetical case is speculative generality.
7. **Where are the copies?** Search for every other place doing the same
   operation (the same state transition, the same fallback, the same parse).
   They are one function or they drift apart.

Present candidate directions by **what each enforces**: the compiler, a
test, or a convention. Rank convention last. When a ticket lists options,
treat the list as a starting set, not the full space.

## Refactoring

- **Two hats** — always-on rules § Code structure. When a fix is hard, the
  restructuring commit lands first.
- **Pin behaviour before moving it** (Feathers). Code without tests gets
  characterisation tests that record what it does now, wrong parts
  included, before extraction.
- **Find the seams from the data.** In a large class, fields used together
  plus the methods that use them are a class waiting to be extracted. Map
  field → method usage before choosing what to move.
- **One responsibility per extraction commit**, each landing where the
  project's folder conventions say, with its tests.
- **Move callers, don't leave forwarders.** A pass-through kept "for
  compatibility" inside one codebase is a shallow module by choice.
- **Re-run Design pass Q1 and Q7 after each extraction.** Moving code
  exposes copies that a large file hid: two methods doing the same
  translation, three sites assembling the same inputs. Fix or file each
  one; don't carry it silently into the new module.

## Review lens

Order: correctness → where knowledge lives → module depth → smells →
naming. Naming last, because it is the cheapest fix.

- Run Design pass Q1, Q2, Q4, Q5 and Q7 against the diff **and the files it
  touches**, not only the changed lines.
- Walk `references/smells.md` against every file in the diff.
- Walk `references/write-time-patterns.md` against every seam the diff
  opens: a new resource, a sibling pair, a cache, a rename.
- For each finding, say which it is: a rule already on the books that was
  missed, or a structural issue no rule names. The first means enforcement
  failed; the second is the finding worth the most.

## Bug classes

Second instance of the same shape → stop and name the shape. Third → the
fix is a mechanism (a type, a test, a single owner), not a fourth patch.
Enumerate the known instances and every other place the shape can occur,
then run Design pass Q2 and Q3 on the class as a whole.

## What to skip from the books

- **Length is not the test.** Clean Code's four-line functions produce
  shallow modules that only make sense read together. The test is one
  level of detail per function.
- **No pattern without its force**, no interface with one implementation
  that nothing substitutes.
- **Clean Code's comment advice** is superseded by the always-on rules'
  § Code comments.
