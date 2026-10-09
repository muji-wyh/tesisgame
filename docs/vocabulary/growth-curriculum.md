# Grow with Pip vocabulary curriculum

The October 9, 2026 curriculum contains **1,550 distinct word entries**, preserving
the existing 1,250 IDs and adding 300. It is designed for children learning English
as an additional language, including children whose first language is Mandarin.
The ten age labels describe an editorial learning path. They are not universal
developmental requirements, a substitute for conversation and reading, or CEFR
certification. A child's exposure and interests matter more than a birthday.

## Research and editorial choices

- [British Council: teaching English at home](https://learnenglishkids.britishcouncil.org/parents/helping-your-child/how-start-teaching-kids-english-home)
  recommends short, repeated, enjoyable practice connected to everyday situations.
  Its introductory themes inform the earlier tiers. We added social language and
  useful sentence words alongside familiar objects and actions.
- [Development Matters](https://www.gov.uk/government/publications/development-matters--2/development-matters)
  connects early vocabulary with conversation, stories, pretend play and spatial
  concepts. Its guidance also values the child's home language. These ideas inform
  the 3–5 path; its developmental examples are not treated as English learner quotas.
- [Cambridge English's 2025 young learner wordlists](https://www.cambridgeenglish.org/images/506166-starters-movers-flyers-word-list-2025.pdf)
  provide reference themes and a broad range of parts of speech for Pre A1, A1 and
  A2. The publication describes qualifications for learners aged 6–12, organized by
  proficiency rather than one required list for each age. We did not equate Lv6
  with a Cambridge qualification or reproduce the lists wholesale.
- [England's English curriculum](https://www.gov.uk/government/publications/national-curriculum-in-england-english-programmes-of-study/national-curriculum-in-england-english-programmes-of-study)
  and the Common Core's [Kindergarten](https://www.thecorestandards.org/ELA-Literacy/L/K/)
  and [Grade 5](https://www.thecorestandards.org/ELA-Literacy/L/5/) language guidance
  informed the progression from concept relationships toward explanation,
  comparison and academic language. They are first-language curricula, so their
  grade labels were not used as direct ESL age equivalents.

The resulting word selection, tier assignments, short meanings and practice
phrases are original editorial work. No source's illustrations, recordings,
assessment items or explanatory prose were copied into this curriculum.

## Ten tiers

| Tier | Words | Context-only | Main focus |
| --- | ---: | ---: | --- |
| 3 | 80 | 11 | Familiar people, pets, food, body, colors, actions and first social phrases |
| 4 | 99 | 26 | Home routines, movement, feelings, requests and simple descriptions |
| 5 | 188 | 49 | Home and school, counting, stories, questions and sentence building |
| 6 | 272 | 41 | Time, directions, weather, routines and short connected ideas |
| 7 | 284 | 27 | Community, interests, practical tasks, plans and simple reasons |
| 8 | 184 | 46 | Describing, comparing, observing, solving and exploring |
| 9 | 177 | 27 | Preferences, imagination, results, materials and habitats |
| 10 | 101 | 18 | Culture, climate, responsibility, experiments and broader nature knowledge |
| 11 | 76 | 14 | Sources, reliability, life science and reflection |
| 12+ | 89 | 6 | Conclusions, mathematics, physical science, space and specialist interests |

The larger middle tiers contain the broad everyday vocabulary already present
in the game. The upper tiers add precision and specialist interests rather than
padding each year to an equal quota. Familiar words such as *elephant*, *balloon*
and *camera* were moved out of the old blanket “advanced” gate.

`curriculum.json` contains the exact membership and source references. Every word
belongs to one and only one tier through `min_age`; 12 represents the 12+ label.
Its age and count fields are checked against `words.json` rather than inferred
from word length or an alphabetical partition. Legacy `level` values remain as
historical metadata; `min_age` defines the growth curriculum.

## Practice and reachability

The additions fill gaps in the original catalog: personal pronouns, articles,
social language, questions, common verbs, days and months, and words for
explaining and reasoning. All 300 additions have original short English meanings
and part-of-speech metadata. Existing entries keep their stable IDs and assets;
the earlier 350 picture nouns also receive topic and part-of-speech metadata.

There are **330 phrases**, including the original 36 unchanged scripts. Every
context-only word occurs in a phrase that can be played at that word's tier;
none requires a later tier to unlock. Phrase prerequisites are the maximum
`min_age` of their component words. Examples reuse actual catalog words without
inventing untracked inflected tokens. Phrases range from two to six words.

Words with genuine pictures can appear in Match, Memory, Voice Pop and Phrase
Builder. The 265 context-only entries have an empty `image` and
`practice_modes: ["phrase"]`. They are taught through meaningful phrases instead
of misleading object pictures. Every required word therefore has a reachable
practice route. Vocabulary membership and this reachability are validated by
`node tools/import-growth-vocabulary.cjs --check`.

The six-correct streak is the user's game progression rule, not a claim that six
game answers establish comprehensive language mastery. A wrong answer resets
that word's streak; promotion itself is permanent. This catalog does not define
mode-specific scoring or save ownership.

## Assets and reproduction

The new [artwork manifest](../assets/growth-vocabulary.json) records 35 inspected
Mulberry source illustrations. The [artwork notes](../assets/growth-vocabulary.md)
explain the distinction between illustration-backed and contextual vocabulary.
New pronunciation and whole-phrase recordings use the approved Ava profile in
[the speech manifest](../assets/ava-voice.json).

```powershell
node tools/import-growth-vocabulary.cjs --check
node tools/import-vocabulary.cjs --check
node --test tests/growth-vocabulary.test.cjs
node tools/generate-voices.cjs --missing
```

The historical 900-image importer is verification-only once `curriculum.json`
exists, so rerunning an older import cannot silently discard the growth catalog.
