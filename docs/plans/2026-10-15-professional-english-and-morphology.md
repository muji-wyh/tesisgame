# Growth and Professional English — Development Specification

**Status:** Planning document. No code, vocabulary assets, or repository files have been created in this planning pass.

**Intended file:** `Q:/.codex/worktrees/current-age-vocabulary/tesisgame/docs/plans/2026-10-15-professional-english-and-morphology.md`

## 1. Product direction and researched Top 20

Add **Professional English** alongside the existing **Growth** curriculum. Professional English targets teenagers and adults, with approximately A2–B2 learning difficulty and practical workplace vocabulary.

The implementation target is **20 courses, each containing 500 vocabulary entries and 100 useful expressions**. “Complete” means completing this reviewed curriculum; it does not mean exhausting every word used in a profession.

### Selection basis

The list below combines occupational prevalence, practical communication needs, and established professional-English subject areas. Its numbering is the recommended catalog order, **not an official international employment ranking**.

US employment data places care, retail, food service, nursing, logistics, customer service, and administration among the largest occupations. UK, Canadian, and Australian sources provide additional occupational context, but their classifications and reporting periods differ. Sources: [US BLS](https://www.bls.gov/oes/2025/may/largest1.htm), [UK ONS](https://www.ons.gov.uk/employmentandlabourmarket/peopleinwork/employmentandemployeetypes/adhocs/3410employmentbydetailedoccupationandindustrybysexagegroupandcountry2024and2025), [Statistics Canada](https://www150.statcan.gc.ca/t1/tbl1/en/tv.action?pid=1410041601), and [Jobs and Skills Australia](https://www.jobsandskills.gov.au/data/occupation-and-industry-profiles/industries/retail-trade).

Professional-English publishing supports extending that foundation into technical and specialist communication. This informs the inclusion of IT, software, finance, marketing, HR, medicine, and legal work. Sources: [Cambridge professional English](https://www.cambridge.es/en/catalogue/business-english/professional-vocational-titles/cambridge-english-for) and [Career Paths ESP](https://careerpaths-esp.com/esp-catalogue).

| # | Course ID and title | Two principal workplace workflows | Automatic theme |
|---:|---|---|---|
| 1 | `caregiving` — Home & Elder Care | Daily assistance; reporting changes and handing over care | Welcoming Home |
| 2 | `retail` — Retail & Checkout | Helping shoppers and taking payment; stock and returns | Neighborhood Store |
| 3 | `food_service` — Restaurants & Food Service | Taking and serving orders; preparing food | Restaurant & Kitchen |
| 4 | `nursing` — Nursing | Patient observation and care; documentation and handover | Care Ward |
| 5 | `customer_support` — Customer Support | Handling inquiries; resolving and escalating problems | Service Center |
| 6 | `office_admin` — Office Administration | Scheduling and correspondence; documents and coordination | Office Hub |
| 7 | `warehouse_logistics` — Warehousing & Logistics | Receiving and storing goods; picking, packing, and dispatch | Distribution Center |
| 8 | `hospitality_tourism` — Hospitality & Tourism | Reservations and check-in; guest and visitor assistance | Hotel & Travel Desk |
| 9 | `transport_delivery` — Transport & Delivery | Route and vehicle preparation; collection and delivery | Delivery Depot |
| 10 | `construction_trades` — Construction & Trades | Reading site instructions; coordinating installation work | Building Site & Workshop |
| 11 | `cleaning_facilities` — Cleaning & Facilities | Cleaning and maintaining spaces; reporting building issues | Building Care Center |
| 12 | `education_childcare` — Teaching & Childcare | Guiding learning activities; communicating with families | Learning Center |
| 13 | `manufacturing_maintenance` — Manufacturing & Maintenance | Production and quality checks; servicing and fault reporting | Production Workshop |
| 14 | `it_support` — IT Support | Setting up accounts and devices; troubleshooting user problems | Device Support Lab |
| 15 | `software_data` — Software & Data | Building and testing software; working with and explaining data | Digital Studio |
| 16 | `accounting_finance` — Accounting & Finance | Recording and reconciling transactions; explaining budgets and reports | Finance Office |
| 17 | `sales_marketing` — Sales & Marketing | Understanding customer needs; planning and evaluating campaigns | Showroom & Campaign Studio |
| 18 | `hr_recruitment` — HR & Recruitment | Recruitment and interviews; onboarding and workplace communication | People & Interview Office |
| 19 | `clinical_medicine` — Clinical Medicine | Taking histories and discussing examinations; explaining findings and follow-up | Consultation Clinic |
| 20 | `legal_paralegal` — Legal & Paralegal | Client intake and case organization; preparing and reviewing documents | Legal Office |

These are career **tracks**, allowing related roles to share a course. Trade-specific, clinical, financial, and jurisdiction-specific content must carry explicit labels.

## 2. Curriculum, vocabulary, and artwork

### Course structure

Each course has **10 modules × 50 vocabulary entries**, plus **10 expressions per module**:

1. People, schedules, and workplace communication.
2. Requests, instructions, and problem reporting.
3. Workplace spaces and equipment.
4. Materials, information, and specialist concepts.
5. Common actions and descriptions.
6. Principal workflow A from the table.
7. Principal workflow B from the table.
8. Problems, safety, and quality.
9. Records, documents, and digital systems.
10. Coordination, handover, and follow-up.

Modules 1–2 use a shared 100-entry workplace foundation. The remaining 400 entries are selected for each career. Shared terms retain one canonical identity wherever the meaning is the same.

The total is **10,000 course memberships**, not necessarily 10,000 unique words or illustrations. Inflections and regional spelling variants do not inflate the count. A lexicalized term such as `blood pressure` counts as one vocabulary entry; a sentence such as `Could you check this invoice?` belongs to the separate expression inventory.

Every entry requires:

- Stable sense ID, displayed term, part of speech, and original English definition.
- Workplace example, course/module membership, and editorial difficulty.
- Accepted spelling variants and relevant regional labels.
- Whole-term pronunciation.
- Reviewed morphological analysis or explicit atomic classification.
- A meaningful picture and permitted exercise types.
- Research references, review status, and asset provenance.

Existing Growth IDs remain stable. Different meanings receive different IDs: `charge` as a fee, electrical charging, and a legal accusation must not share one learning record or misleading illustration.

### Content production

Produce and review the complete vocabulary inventories before bulk artwork production:

1. Draft terms against the module coverage requirements.
2. Remove duplicates, padding, irrelevant specialist material, and unsupported definitions.
3. Review meanings, regional usage, examples, and morphological analyses.
4. Approve a picture brief for each sense.
5. Produce or acquire images and recordings.
6. Validate exercise reachability and integrate the completed module.

Medical, legal, financial, and safety-related entries require appropriate subject review. Lessons teach language for communication; professional procedures must not be invented to create examples.

US English is the pronunciation default. Retain the approved `ava-sweet` settings: `en-US-AvaNeural`, rate `-15%`, pitch `+8Hz`, volume `+0%`, without postprocessing. Accept reviewed British and other relevant spelling variants.

### Picture requirements

Every professional vocabulary entry receives a reviewed primary still image:

| Meaning type | Required depiction |
|---|---|
| Concrete object/person | Distinctive object or person with sufficient contextual cues |
| Action | A readable workplace action |
| Process or relationship | A short visual sequence or meaningful comparison |
| Abstract concept | A concrete situation demonstrating the intended meaning |

For example, `refund` should depict returning a purchase and receiving money; `confidential` should depict restricted access to information.

Reuse existing licensed artwork only when both meaning and style fit. New artwork must meet the repository’s production-asset requirements. Record source, creator, license, acquisition status, adaptations, and available animation separately. A source preview is not an integrated asset.

Review pictures at actual gameplay size. An illustration may support learning without being suitable for an isolated picture-identification question; exercise eligibility must reflect that distinction.

**Growth’s existing 265 context-only entries remain unchanged.** New artwork coverage applies to professional vocabulary. Animation is selective, rather than mandatory for every entry.

## 3. Home experience and automatic themes

### Home navigation

Place two illustrated choices near the top of Home:

- **Grow with Pip** — “Build everyday English, one step at a time.”
- **Professional English** — “Practice English for your working world.”

Retain a compact **Continue** action showing the active course and module.

Selecting Growth displays the existing age journey and game choices. Selecting Professional English displays the searchable list of 20 careers, with a recognizable workplace illustration, short description, and progress for each.

Selecting a career:

1. Immediately selects its theme and updates the active context.
2. Shows its modules and a recommended continuation action.
3. Presents the existing six games using that course’s eligible content.

Keep the active career and module visible above the game choices. Provide **Change career** and **Change learning path** actions. Returning users can continue directly without repeating onboarding.

On phones, use stacked path cards and a vertical career list. On larger screens, use a responsive card grid. Keep keyboard, controller, and touch navigation equivalent; pointer entry must not create an unsolicited selection outline.

### Theme system

There are **21 active learning themes**:

- Growth → **Pip’s Garden**, derived from the established garden direction.
- Each professional course → its workplace theme from the table.

Each theme profile defines an environment, Home illustration, palette, workplace props, restrained ambient motion, and explicit audio/reward resource mappings. Related courses need visibly different compositions—not just different background colors.

Use one consistent illustration style across careers. Professional presentation remains warm and playful, with course progress replacing baby-age progression.

Theme behavior:

- Selection immediately applies the local theme preview, palette, and identity.
- Larger environment assets load on demand.
- Gameplay starts when required course and theme resources are ready.
- Failed loading presents retry and course-selection actions.
- Rapid changes apply only the latest selection; stale loading callbacks cannot restore an earlier theme.
- Use a short crossfade, approximately 200 ms; reduced-motion mode changes immediately.

Remove the independent theme picker from the main learning flow. Preserve historical theme preferences and reward references for compatibility. Existing collectibles, chest identities, wallet balances, and purchases remain valid.

## 4. Engineering contracts and Jelly behavior

### Separate learning content from age

The current implementation contains 1,550 Growth words and 330 phrases. Vocabulary validation, loading, and progression are tied to ages 3–12. Professional terms must use a separate curriculum layer.

Introduce these contracts:

| Contract | Required responsibility |
|---|---|
| `LearningContext` | Track, course, module, curriculum revision, and exercise mode |
| `Lexeme` | Stable sense identity, text/forms, meaning, media, morphology, and exercise capabilities |
| `CourseManifest` | Versioned module membership, expressions, objectives, and theme reference |
| `MorphologyAnalysis` | Typed parts, canonical forms, surface spellings, and permitted composition graph |
| `CompositionResult` | Invalid, legal partial, completed term, or insufficient placement space |
| `ThemeProfile` | Explicit visual, audio, and existing reward-resource mappings |

Freeze the learning context and content revision for each round. Reusing the same game mode must not resume another career’s round accidentally.

Resolve eligible content before constructing a game. Remove the current dependency that initializes picture Match even when launching another exercise.

Support spaces, hyphens, apostrophes, capitalization, abbreviations, and digits where genuine terms require them. Phrase data must preserve token positions and repeated words.

### Real morphological composition

Replace midpoint splitting and the two-piece assumption with reviewed, authored analyses.

Use modern roots/stems, prefixes, suffixes, transparent compound components, and appropriate classical combining forms. These are distinct part types; do not label every piece a “root.” This follows the distinction between meaningful morphemes and their roles described by the [British Council](https://www.teachingenglish.org.uk/professional-development/teachers/teaching-knowledge-database/d-h/morpheme). Medical combining forms additionally require appropriate linking-vowel rules, as described in [Maricopa’s medical terminology text](https://open.maricopa.edu/medicalterminology/chapter/identifying-medical-word-parts/).

Representative contracts:

| Term | Analysis and behavior |
|---|---|
| `cat`, `nurse` | Atomic: one whole Jelly |
| `unhelpful` | `un-` + `help` + `-ful` |
| `waterproof` | `water` + `proof` |
| `happiness` | `happy` + `-ness`, with authored `y → i` spelling change |
| `running` | `run` + `-ing`, with authored consonant doubling |
| `electrocardiogram` | Reviewed classical combining forms and suffix |
| `blood pressure` | Preserve the lexical word boundary; do not describe the space as a root boundary |
| `MRI` | Atomic abbreviation; never invent letter-based roots |

Apply this policy to both Growth and Professional English. Review existing entries instead of silently treating the old spelling chunks as morphology.

One shared composition resolver must drive manual merging, hints, compatibility highlighting, and Auto merge.

- Legal intermediate compositions remain mergeable.
- Partial forms receive no completed-word reward, mastery event, or whole-word pronunciation.
- Authored spelling transformations determine the resulting text.
- Equivalent parts may combine across supply groups when an approved analysis permits it.
- Sample only one sense of an identical displayed spelling within a round, avoiding invisible sense-based conflicts.
- Auto merge must establish a valid completion path and available placement before charging.

Atomic words settle as complete, collectable Jellies. Their collection provides exposure and pronunciation, **not spelling correctness or mastery evidence**.

### Long words and physical layout

Retain the **6-column × 8-row board**.

Separate semantic part count, occupied area, and reward value. One long root remains one Jelly even when it occupies several cells.

- Allow footprints of **1–6 columns and 1–2 rows**.
- Measure actual font metrics, padding, and badges; minimum label size is **16 displayed pixels**.
- Compute footprints against a 32-display-pixel minimum cell pitch, then freeze them for the round.
- Choose the smallest fitting area; prefer one row when areas tie.
- Wrap only at reviewed constituent boundaries or preserved spaces.
- Never create extra Jellies merely to fit text.
- Exceptional unbreakable text retains its complete spelling and exposes a **Read** action. This pauses play and opens a readable, horizontally scrollable detail view.
- Resizing changes rendering coordinates, not tile identities, grid positions, or footprints. A viewport too small for the minimum layout pauses safely until sufficient space is available.

Before merging, reserve space for the complete result footprint. If no valid space exists, return `needs_room`; retain both inputs and do not count an incorrect answer.

### Wide-piece supply

Keep six **preview lanes**, allowing fewer than six visible pieces when pieces span multiple columns.

- A wide Jelly reserves adjacent lanes.
- Once visible, its identity, position, span, and fragments remain fixed.
- It drops only when its entire rectangle has a clear route through those advertised lanes.
- Blocked pieces remain in place; independently unblocked pieces may drop.
- Fill available spans from the pending queue without rearranging visible pieces.
- Detect blockage using complete footprints, rather than a single empty cell.
- Preserve fragments and pending parts across supply batches.

Retain the existing four-collection speed stages and 20-to-10-second baseline. Normalize scheduled wave intervals by preview area:

`wave interval = baseline interval × max(1, preview occupied area / 6)`

Freeze the interval when scheduled. Count each completed collection once, including atomic collection; partial merges do not advance the stage.

For Word Jelly, retain the existing 1% bonus chance and standard two-piece reward category. Morpheme count and physical area must not multiply rewards. Preserve fragment allocation per supplied target and exactly-once collection receipts.

### Progress and persistence

Keep Growth’s existing save, age cohorts, level curve, and earned progress intact. Professional answers never advance Pip’s age or Growth level.

Professional progress is shared across careers by **canonical sense and assessed skill**:

- Three consecutive unassisted correct answers establish the existing style of game mastery for that skill.
- A mistake resets its current streak; earned mastery remains.
- Atomic collection and assisted completion do not establish mastery.
- A word is shown as learned when at least one eligible skill is mastered; other skills remain explicitly unassessed.
- A module completes when its 50 terms are learned and its 10 expressions have each been completed unassisted.
- Earned module completion is pinned to its requirements revision and is not revoked by later content additions.

Use one new IndexedDB database for professional progress and learning-context preferences, with atomic native-file storage outside the browser. Keep Growth storage unchanged.

Persist professional answer events transactionally, using unique IDs and an outbox for existing wallet operations. Preserve wallet idempotency across crashes and retries. Storage failures must show a retryable state, never an apparently empty profile.

### Delivery and resource budgets

The existing vocabulary export already exceeds 140 MiB compressed across its packs. Do not preload all professional media.

- Load a small course/index catalog first, then the active module’s resources.
- Target at most **10 MiB compressed** for a module’s first-use media.
- Limit new decoded delivery bundles to **32 MiB**.
- Use stable shared resource groups instead of every possible combination of course memberships.
- Keep new professional media releasable through a bounded resource cache; do not permanently mount one large resource pack per career.
- Bound decoded professional-media residency to **128 MiB**, evicting inactive resources.
- Virtualize large vocabulary lists.
- Preserve hashes, immutable URLs, dependency validation, cancellation, and retry behavior.

## 5. Implementation sequence and acceptance

### Delivery sequence

1. **Foundations:** Add the sense-aware lexicon, course manifests, learning context, progress store, and generic content resolver. Preserve existing Growth behavior.
2. **Representative vertical slices:** Complete 50-entry modules for Retail, Nursing, and Software & Data, including pictures, audio, themes, morphology, and all applicable exercises.
3. **Home and Jelly integration:** Implement automatic themes, navigation, multipart merging, atomic words, wide-piece supply, and readable long-word presentation.
4. **Content production:** Complete all 20 courses to 500 reviewed entries and 100 expressions each; audit Growth morphology.
5. **Release validation:** Verify all courses, migration compatibility, storage recovery, resource limits, and rendered layouts.

The representative slices validate the pipeline; they do not reduce the final 20-course scope.

### Required acceptance scenarios

| Area | Acceptance |
|---|---|
| Content coverage | All 20 courses meet their inventories; every professional term has reviewed meaning, pronunciation, morphology, picture, provenance, and a reachable scored exercise |
| Home | Both learning paths are discoverable; all careers are accessible; returning users continue directly |
| Themes | Growth and every career select the correct theme; rapid switching and failed downloads never apply stale assets |
| Morphology | Atomic words, 2/3/4+ parts, spelling changes, compounds, abbreviations, and phrases behave according to authored analyses |
| Composition | Manual merge, hints, highlighting, and Auto merge agree; insufficient room is distinct from an incorrect answer |
| Long text | No tiny-font fallback or invented split; complete spelling remains accessible on phone and desktop |
| Supply | Wide pieces require full-span clearance; blocked preview pieces retain identity and fragments |
| Progress | Professional careers share the same sense’s evidence; Growth remains independent; passive collection grants no mastery |
| Economy | Partial merges and retries cannot duplicate rewards; extra morphemes do not increase payouts |
| Persistence | Reloads, interrupted writes, concurrent tabs, failed storage, and interrupted reward delivery preserve progress |
| Loading | Missing assets, wrong hashes, timeouts, cancellation, and cache pressure recover without corrupting a round |
| Accessibility | Keyboard/controller/touch navigation, readable contrast, reduced motion, and pronunciation access remain usable |

Render and inspect at **320×568, 390×844, 844×390, and 1280×800**, plus a deliberately undersized viewport to verify safe pause behavior. Include long terms, multiword terms, repeated phrase tokens, and visually confusable meanings.

The release is complete only when the full inventories, 21 active themes, media, morphology, progress behavior, and acceptance evidence are delivered. Unreviewed terms and missing artwork remain explicit unfinished work.

## Execution Dependency

On 2026-10-15, the user authorized implementing this plan after the work in `tesis-iter-3` has demonstrably completed. The dependency is local thread `01a13fee-eb29-7d91-a519-c32c6caadbeb`. Verify its completion before beginning implementation and preserve its audio changes.

Recheck the intended implementation workspace, `Q:/.codex/worktrees/current-age-vocabulary/tesisgame`, after the dependency finishes. Do not modify `C:/uworks/tesisgame`. This artifact records the full implementation specification and scheduling dependency; saving it does not begin implementation.
