# Smells — tell, then fix

Fowler's catalogue cut to the ones that recur; each with how to spot it and
the move that fixes it.

| Smell | Tell | Fix |
| --- | --- | --- |
| Divergent change | One file edited for unrelated reasons across recent commits (`git log --format=%s -- <file>`) | Split by reason to change |
| Shotgun surgery | One logical change edits many files (a path, a layout, a kind list) | One owner; derive the rest |
| Parallel lists | Interface + allocator + roster naming the same keys | Derive all of them from one roster (generated, or computed from the enum) |
| Large class | Many fields; methods touching disjoint field subsets | Extract by field cluster |
| Feature envy | Method reads mostly another object's data | Move it to that object |
| Missed polymorphism | `if kind == A … else if kind == B` where a per-kind table or registry exists | Route through the table |
| Data clump | Same group of values assembled at several call sites | A type, built once |
| Plausible default | A default operator turning *missing* into a legal value (`false`, `0`, empty); a pre-filled sentinel; a zero-initialised slot read as data | Pending/ready variant; see SKILL.md Design pass Q2 |
| Drifted copies | Same operation written twice with different side steps | One function; diff the copies first — the difference is often a bug |
| Pass-through | Method whose body is one forwarded call | Callers use the target directly |
| Long positional parameters | 4+ positional args, especially same-typed | A parameter object, or named arguments |
| Flag argument | Boolean parameter selecting behaviour; call site reads `f(x, false)` | Two functions, or a named option |
| Act and answer | Function mutates state and returns a verdict; side effect runs even on refusal | Split, or check before mutating |
| Primitive obsession | Manual offset arithmetic into a flat array; magic sentinels such as `-1` and `null` mixed | A typed accessor or value type |
| Speculative generality | Seam, option or layer with no second case in use | Inline it; or record the product decision to keep it |
| Swallowed failure | Empty catch block; fire-and-forget async call whose failure nobody observes; fallback without a log | Handle at the boundary that can act, or propagate |
