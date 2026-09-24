# Patterns by force

A pattern is admissible only when its force is present today, with two
concrete cases in the codebase. Name it in the identifier when applied.

| Force (what is actually varying or coupling) | Pattern | Admissible only when |
| --- | --- | --- |
| Behaviour chosen per call or per config | Strategy (a function parameter is usually enough) | Two implementations exist now |
| Construction depends on runtime data | Factory function | Callers would otherwise branch on type to construct |
| Many listeners to one change | Observer / event bus | 2+ independent subscribers; each unsubscribes in dispose |
| Per-kind behaviour across a closed set | Registry / table keyed by kind | The set is enumerated in one place and every consumer iterates it |
| Operations over a stable structure, new operations added often | Visitor | The structure truly is stable; otherwise a kind table is simpler |
| Lifecycle with ordered phases | State machine / sum-typed state | Phases have different valid operations; a phase can be read too early |
| Expensive or remote thing behind a local interface | Proxy / facade | The interface is much simpler than what it hides |
| Incompatible interface to integrate | Adapter | The foreign interface is outside your control |
| Undo, queue or replay of actions | Command | Actions must be stored or replayed, not just called |
| Tree of parts treated uniformly | Composite | Callers genuinely treat leaf and group the same |

Default when unsure: the direct version. Inheritance only for true is-a
where every inherited method stays correct; otherwise hold and delegate.
