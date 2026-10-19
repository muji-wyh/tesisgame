// Explicit individual judgments; no automatic fallback or suffix classification.
module.exports = ({stem, affix, DATE}) => {
  const c = (id, text = id) => stem(id, text, 'compound');
  const prefix = (id, canonical, surface) => ({canonical_id: `english.affix.${id}`, canonical, surface, type: 'prefix'});
  const atoms = `
pelican|The bird name is one borrowed animal stem, not peli plus can.
artichoke|The vegetable name is a whole loanword; the ending is not the English action choke.
asparagus|The vegetable noun is a whole borrowed stem; final s is not its English plural suffix.
cinnamon|The spice name is one lexical base with no current English affix boundary.
pistachio|The edible seed name is one borrowed base, not pistach plus io.
pretzel|The baked-food name is a whole borrowed noun; no English pretz base is invented.
earwig|The historical second element meant insect, not the modern hairpiece wig. The insect name stays whole to avoid this misleading modern compound and the false ear-invasion story.|mw-earwig
ferret|The mammal name is one lexical base, not ferr plus a diminutive suffix exercise.
gnat|The small insect name is a whole base despite its silent initial consonant.
mole|The stored skin-spot sense is one noun base, distinct from the burrowing animal.
moth|The nocturnal insect noun is one base.
shrew|The pointed-snouted mammal noun is one base, not a past-tense verb.
shrimp|The shellfish noun is one base; its final p is not a meaningful ending.
skunk|The striped mammal name is a whole English loanword.
slug|The shell-less crawling animal is one base, distinct from the blow or metal-piece senses.
stag|The adult male-deer noun is a single base.
stoat|The slender mammal name is one lexical base.
vulture|The carrion-eating bird name is a whole modern stem; no free vult base is invented.
wasp|The stinging insect noun is one base.
wood|The tree-material noun is one base, distinct from the wooded-area plural.
wool|The sheep-fiber noun is one base.
almond|The nut name is one borrowed lexical base.
apricot|The orange fruit name is a whole loanword, not apri plus cot.
bacon|The cured-pork noun is one base, not bac plus on.
bagel|The bread-roll noun is a whole English loanword.
cabbage|The leaf-vegetable name is lexicalized; cab plus an age suffix would assign unrelated meanings.
cashew|The curved-nut name is one borrowed base.
celery|The stalk vegetable name is lexicalized; it is not a craft suffix applied to cel.
chapati|The flatbread noun is a whole borrowed form.
croissant|The crescent-shaped bread name is a whole English loanword; no English croiss verb is invented.
currant|The stored dried-grape sense is one lexical base, distinct from the fresh berry sense used in blackcurrant.
fennel|The feathery-leaved vegetable name is one base.
fig|The fruit noun is one base.
garlic|The bulb-food noun is a whole modern stem; historic spear-and-leek elements are not imposed as current free parts.
kiwi|The stored fruit sense is a lexical base borrowed through its conventional name, distinct from the bird.
leek|The layered-leaf vegetable noun is one base.
lentil|The soup-seed noun is one borrowed base.
lime|The citrus fruit noun is one base, distinct from the mineral and color uses.
olive|The oil-producing fruit name is one base, not o plus the adjective live.
omelet|The egg-dish noun preserves its existing spelling as one borrowed base.
parsnip|The root vegetable name is lexicalized; the modern cutting verb snip is not its word-forming component.
pecan|The ridged-shell nut name is a whole English loanword, not pe plus can.
porridge|The cooked cereal name is one modern base.
raisin|The dried-grape noun is one borrowed base, not a phonetic rendering of raising.
ravioli|The filled-pasta noun is a borrowed food name; its Italian plural ending is not taught as productive English inflection.
rhubarb|The edible-stalk plant noun is lexicalized; the barbed-object noun barb does not explain its English meaning.
salami|The sliced-sausage noun is a borrowed food name; final i is not an English plural suffix.
satsuma|The easy-peeling citrus name is a whole eponymic borrowing.
spinach|The leafy vegetable name is one borrowed base.
turnip|The root vegetable name is lexicalized; turn plus nip would falsely import two unrelated modern actions.
vinegar|The sour-liquid noun is a whole English loanword; its historical wine-and-sour formation is not a vin plus egar English exercise.
walnut|The original first element meant foreign; modern wal is not an independent word. This nut name stays whole instead of inventing a wall or walk component.|mw-walnut
wafer|The crisp-biscuit noun is lexicalized; it is not an agent from an invented waf verb.
hatch|The stored coming-out-of-an-egg action is one uninflected verb stem.
core|The Earth-center noun is one base, distinct from a verb about removing fruit cores.
fat|The stored nutrient noun is one base, distinct from the body-size adjective.
address|The internet-location noun is a whole modern stem; ad plus dress would assign unrelated components.
palette|The paint-mixing board noun is one borrowed base; it is distinct from pallet and palatal word families.
vacuum|The stored cleaning-machine noun is a lexicalized name, with no productive English vacu plus um construction.
bingo|The number-matching game name is one base.
darts|The game name is lexicalized as a plural-form activity; it is kept whole rather than defined as a mere count of projectiles.
judo|The martial-art name is a whole English loanword; its Japanese internal structure is not treated as productive English affixes.
rugby|The team sport name is one eponymic lexical base.
kennel|The dog-shelter noun is one borrowed base.
parade|The procession noun is one lexical base, not par plus ade.
support|The helping or evidential-support verb is a whole modern base; port is not a harbor in this sense.
achieve|The goal-reaching verb is one lexical stem, with no productive a plus chieve split.
reduce|The making-smaller verb is one modern base; re does not mean doing a duce action again.
increase|The making-larger verb is lexicalized; the fold noun crease does not supply its meaning.
evidence|The truth-supporting information noun is a whole base; an independent evid stem is not invented.
culture|The shared-way-of-life noun is one lexical base; cult in its current organization sense does not explain it.
tradition|The inherited-custom noun is lexicalized; a free tradit verb is not invented.
climate|The usual-weather noun is a whole base, not cli plus mate.
method|The procedure noun is one lexical base; meth and od are not current meaning-bearing components here.
challenge|The difficult-task noun is one modern stem with no detachable productive affix.
`;
  const compounds = [
    ['eggplant', [c('egg'), c('part.plant.organism', 'plant')], 'The established vegetable name compares the fruit of some varieties to eggs; the plant component is the organism noun, not the stored planting verb.'],
    ['hazelnut', [c('part.hazel.tree', 'hazel'), c('nut')], 'The edible nut comes from the hazel tree; the plant sense of hazel is selected.'],
    ['raspberry', [c('part.rasp.fruit', 'rasp'), c('berry')], 'The attested first base is the dialect fruit noun rasp, not the modern scraping tool or harsh voice. The conventional fruit name retains that exact sense.', ['mw-raspberry']],
    ['blueberry', [c('blue'), c('berry')], 'The berry name combines its usual blue appearance with the free berry noun.'],
    ['grapefruit', [c('grape'), c('fruit')], 'The conventional citrus name contains grape and fruit as naming components; it is not defined as a cultivar of grape.'],
    ['beetroot', [c('beet'), c('root')], 'The edible vegetable is the root of the beet plant.'],
    ['blackberry', [c('black'), c('berry')], 'The conventional fruit name combines its dark appearance and berry, without making a botanical classification claim.'],
    ['blackcurrant', [c('black'), c('part.currant.fresh-berry', 'currant')], 'The dark fresh berry uses the fresh-currant sense, explicitly distinct from the stored Growth dried-grape currant.'],
    ['gooseberry', [c('goose'), c('berry')], 'The conventional name has the sourced goose-plus-berry form; uncertain earlier folk-etymological history is not presented as an animal-origin claim.', ['wiktionary-gooseberry']],
    ['marshmallow', [c('marsh'), c('part.mallow.plant', 'mallow')], 'The sweet name comes from the marsh-growing mallow plant name. This historical naming relation does not imply that modern sweets contain the plant.', ['wiktionary-marshmallow']],
    ['scarecrow', [c('scare'), c('crow')], 'The field figure is intended to scare crows and other crop-eating birds; the verb-object compound preserves both meanings.'],
    ['beansprout', [c('bean'), c('sprout')], 'The edible growth is a sprout from a bean; the original closed spelling is preserved.']
  ];
  const derivatives = [
    ['submarine', [prefix('sub.under', 'sub-', 'sub'), stem('part.marine.sea', 'marine')], 'The sea-vessel noun derives from the undersea adjective, formed with under-prefix sub- and marine in its sea-related sense.', 'sub-under-plus-marine', ['wiktionary-submarine']],
    ['woodpecker', [stem('wood', 'wood'), stem('peck', 'peck'), affix('er.agent-instrument', '-er', 'er')], 'The bird pecks wood; agent -er first forms pecker, then wood supplies the object of its action.', 'wood-plus-derived-pecker', [], [
      {id: 'pecker', left: 'part2', right: 'part3', surface: 'pecker', rule: 'peck-plus-agent-er', break_offsets: []},
      {id: 'whole', left: 'part1', right: 'pecker', surface: 'woodpecker', rule: 'wood-plus-pecker', break_offsets: []}
    ]],
    ['cauliflower', [{canonical_id: 'english.combining.cauli.cabbage', canonical: 'cauli-', surface: 'cauli', type: 'combining_form'}, stem('flower', 'flower')], 'The sourced formation uses the cabbage or stalk element cauli- with its linking vowel and flower; cauli is not misrepresented as a free English word.', 'cauli-cabbage-plus-flower', ['wiktionary-cauliflower']],
    ['noodles', [stem('noodle', 'noodle'), affix('s.plural', '-s', 's')], 'The food contains multiple noodle strips; the complete noodle base receives regular plural -s.', 'noodle-plus-plural-s'],
    ['pointed', [stem('part.point.tip', 'point'), affix('ed.having', '-ed', 'ed')], 'The shape adjective means having or ending in a point; this tip noun is distinct from the stored finger-pointing verb.', 'point-plus-having-ed'],
    ['blinds', [stem('part.blind.window-cover', 'blind'), affix('s.plural', '-s', 's')], 'The window-cover noun blind takes plural -s; its base is the furnishing noun rather than the vision adjective.', 'blind-window-cover-plus-plural-s'],
    ['classify', [stem('part.class.group', 'class'), affix('ify.make', '-ify', 'ify')], 'The action puts items into classes or groups; the group sense and verb-forming -ify supply the formation.', 'class-group-plus-ify'],
    ['responsible', [stem('part.response.answerability', 'response'), affix('ible.capable', '-ible', 'ible')], 'The source explicitly permits the surface analysis response plus -ible, with final e removed. The stored trusted-with-duties meaning preserves answerability rather than merely responding to a sound.', 'response-plus-ible-e-loss', ['wiktionary-responsible']],
    ['independent', [prefix('in.not', 'in-', 'in'), stem('dependent', 'dependent')], 'The negating prefix applies to the complete dependent adjective: able to act without depending on help.', 'in-not-plus-dependent', ['wiktionary-independent']],
    ['information', [stem('inform', 'inform'), affix('ation.action-result', '-ation', 'ation')], 'The sourced current analysis joins inform and noun-forming -ation while retaining the stored knowledge-and-facts sense.', 'inform-plus-ation', ['wiktionary-information']],
    ['curiosity', [stem('curious', 'curious'), affix('ity.quality', '-ity', 'ity')], 'The sourced word-family analysis uses curious plus quality -ity; the exact curiosity spelling explicitly realizes the curios- base allomorph.', 'curious-plus-ity-authored-curios-allomorph', ['wiktionary-curiosity']],
    ['communication', [stem('communicate', 'communicate'), affix('ion.action-result', '-ion', 'ion')], 'The sourced formation joins communicate and action noun -ion with final e removed, preserving the sharing-information meaning.', 'communicate-plus-ion-e-loss', ['wiktionary-communication']]
  ];
  const sources = {};
  for (const id of ['earwig', 'walnut', 'raspberry']) sources[`mw-${id}`] = {
    title: `Merriam-Webster: ${id}`, author: 'Merriam-Webster editors', url: `https://www.merriam-webster.com/dictionary/${id}`, consulted: DATE,
    evidence: 'The source word history distinguishes the historical constituent from tempting unrelated modern senses.'
  };
  for (const id of ['gooseberry', 'marshmallow', 'submarine', 'cauliflower', 'responsible', 'independent', 'information', 'curiosity', 'communication']) sources[`wiktionary-${id}`] = {
    title: `Wiktionary: ${id}, English formation`, author: 'Wiktionary contributors', url: `https://en.wiktionary.org/wiki/${id}#English`, consulted: DATE,
    evidence: 'The English formation or explicitly labeled surface analysis was consulted; the stored contemporary sense is retained.'
  };
  // These named withdrawals supersede the removed whole-form decisions.
  const pending = {
  "investigate": "Reopened after new term-specific evidence: The in- and vestigium track family is documented. Hold the prior whole-form proposal and do not yet serialize in + vestig + -ate: the exact English stem realization, prefix contribution, and inherited verbal ending require a term-specific graph decision.",
  "estimate": "Reopened after new term-specific evidence: The Latin aestimare/aestimatus family is established. Hold the old whole-form rationale while a reviewer determines whether estim and -ate are appropriate English teaching units; not having a free estim word is not decisive."
};
  Object.assign(sources, {
  "mw-investigate-new": {
    "title": "Merriam-Webster: investigate",
    "author": "Merriam-Webster editors",
    "url": "https://www.merriam-webster.com/dictionary/investigate",
    "consulted": "2026-10-16",
    "consultation_status": "newly_consulted_page_body_in_revision_pass",
    "sections": "Word History and relevant current sense",
    "evidence": "The history derives the word through investigatus/investigare from in- and vestigium, footprint or track. It establishes a real historical family but does not by itself settle the intended English three-part graph."
  },
  "mw-vestige-new": {
    "title": "Merriam-Webster: vestige",
    "author": "Merriam-Webster editors",
    "url": "https://www.merriam-webster.com/dictionary/vestige",
    "consulted": "2026-10-16",
    "consultation_status": "newly_consulted_page_body_in_revision_pass",
    "sections": "Word History and relevant current sense",
    "evidence": "The history independently traces vestige to Latin vestigium, footprint or trace. The relation is real; the precise vestig/vestige realization and English investigate suffix analysis still require a decision."
  },
  "mw-ate-suffix-new": {
    "title": "Merriam-Webster: -ate",
    "author": "Merriam-Webster editors",
    "url": "https://www.merriam-webster.com/dictionary/-ate",
    "consulted": "2026-10-16",
    "consultation_status": "newly_consulted_page_body_in_revision_pass",
    "sections": "Verb suffix and Word History",
    "evidence": "The dictionary distinguishes a verb-forming suffix and traces it to Latin participial morphology. This is background evidence for investigate, separate, and estimate research, not term-level authorization for automatic splitting."
  },
  "mw-estimate-new": {
    "title": "Merriam-Webster: estimate",
    "author": "Merriam-Webster editors",
    "url": "https://www.merriam-webster.com/dictionary/estimate",
    "consulted": "2026-10-16",
    "consultation_status": "newly_consulted_page_body_in_revision_pass",
    "sections": "Word History and relevant current sense",
    "evidence": "The history gives Latin aestimatus/aestimare value or estimate. It confirms a historical verbal formation but does not settle whether the intended English lesson should expose estim plus -ate."
  }
});
// Nine-hold proposal: these decisions supersede the named pending reviews only.
  delete pending["investigate"];
  delete pending["estimate"];
  derivatives.push(...[
  [
    "investigate",
    [
      {
        "canonical_id": "english.affix.in.inside",
        "type": "prefix",
        "canonical": "in-",
        "surface": "in"
      },
      {
        "canonical_id": "english.root.vestig.track",
        "type": "root",
        "canonical": "vestig",
        "surface": "vestig"
      },
      {
        "canonical_id": "english.affix.ate.verb",
        "type": "suffix",
        "canonical": "-ate",
        "surface": "ate"
      }
    ],
    "The individually attested family combines in- into with vestig track/trace and inherited verbal -ate. The teaching source explicitly lists vestig in investigate and vestige. The graph first builds the bound stem investig, then the complete verb; investig is not presented as an independent English word. Both proposed routes into English, borrowing and back-formation from investigation, share this family, so the graph does not assert a unique chronology. The selected careful inquiry sense remains authoritative; there is no clothing vest root or invented free vestigate requirement.",
    "authored-investig-bound-stem-plus-verbal-ate",
    [
      "mw-investigate-new",
      "mw-vestige-new",
      "mw-ate-suffix-new",
      "etym-investigate-hold9",
      "thoughtful-vestig-hold9",
      "etym-ate-hold9",
      "anderson-2e-roots-new"
    ],
    [
      {
        "id": "bound_stem",
        "left": "part1",
        "right": "part2",
        "surface": "investig",
        "rule": "authored-bound-stem-investig",
        "break_offsets": []
      },
      {
        "id": "whole",
        "left": "bound_stem",
        "right": "part3",
        "rule": "authored-investig-bound-stem-plus-verbal-ate",
        "surface": "investigate",
        "break_offsets": []
      }
    ]
  ],
  [
    "estimate",
    [
      {
        "canonical_id": "english.root.estim.value",
        "type": "root",
        "canonical": "estim",
        "surface": "estim"
      },
      {
        "canonical_id": "english.affix.ate.verb",
        "type": "suffix",
        "canonical": "-ate",
        "surface": "ate"
      }
    ],
    "The history gives the aestimare/aestimatus valuing and appraising family, realized as estim in this inherited English form. The University of Michigan resource specifically identifies estimate as a verbal -ate example and contrasts it with the noun pronunciation. This term-level evidence supports estim plus -ate rather than a spelling-only suffix guess. Estim is bound, and no independent estim word is required. The selected informed approximation sense remains the whole meaning; the graph does not substitute the respectful-admiration sense of esteem or invent an es- prefix.",
    "authored-estim-value-plus-verbal-ate",
    [
      "mw-estimate-new",
      "mw-ate-suffix-new",
      "etym-estimate-hold9",
      "etym-ate-hold9",
      "michigan-ate-hold9",
      "anderson-2e-roots-new"
    ],
    [
      {
        "id": "whole",
        "left": "part1",
        "right": "part2",
        "rule": "authored-estim-value-plus-verbal-ate",
        "surface": "estimate",
        "break_offsets": []
      }
    ]
  ]
]);
  Object.assign(sources, {
  "mw-investigate-new": {
    "title": "Merriam-Webster: investigate",
    "author": "Merriam-Webster editors",
    "url": "https://www.merriam-webster.com/dictionary/investigate",
    "consulted": "2026-10-16",
    "consultation_status": "newly_consulted_page_body_in_revision_pass",
    "sections": "Word History and relevant current sense",
    "evidence": "The history derives the word through investigatus/investigare from in- and vestigium, footprint or track. It establishes a real historical family but does not by itself settle the intended English three-part graph."
  },
  "mw-vestige-new": {
    "title": "Merriam-Webster: vestige",
    "author": "Merriam-Webster editors",
    "url": "https://www.merriam-webster.com/dictionary/vestige",
    "consulted": "2026-10-16",
    "consultation_status": "newly_consulted_page_body_in_revision_pass",
    "sections": "Word History and relevant current sense",
    "evidence": "The history independently traces vestige to Latin vestigium, footprint or trace. The relation is real; the precise vestig/vestige realization and English investigate suffix analysis still require a decision."
  },
  "mw-ate-suffix-new": {
    "title": "Merriam-Webster: -ate",
    "author": "Merriam-Webster editors",
    "url": "https://www.merriam-webster.com/dictionary/-ate",
    "consulted": "2026-10-16",
    "consultation_status": "newly_consulted_page_body_in_revision_pass",
    "sections": "Verb suffix and Word History",
    "evidence": "The dictionary distinguishes a verb-forming suffix and traces it to Latin participial morphology. This is background evidence for investigate, separate, and estimate research, not term-level authorization for automatic splitting."
  },
  "etym-investigate-hold9": {
    "title": "Online Etymology Dictionary: investigate",
    "author": "Douglas Harper",
    "url": "https://www.etymonline.com/word/investigate",
    "consulted": "2026-10-16",
    "consultation_status": "newly_consulted_page_body_in_nine_hold_pass",
    "sections": "Entry history and linked family evidence",
    "evidence": "Two routes into English are offered: back-formation from investigation or borrowing of the Latin participial form. Both retain the in- and vestigium track family. The entry distinguishes vestigium from the unrelated clothing root vestis."
  },
  "thoughtful-vestig-hold9": {
    "title": "Prefixes, Roots, and Suffixes",
    "author": "Thoughtful Learning editorial team",
    "url": "https://thoughtfullearning.com/inquirehsbook/pg166",
    "consulted": "2026-10-16",
    "consultation_status": "newly_consulted_page_body_in_nine_hold_pass",
    "sections": "Root list: vestig",
    "evidence": "The educational root list explicitly identifies vestig trace in investigate, vestige, and vestigial. This supports the retained vestig teaching unit while the dictionary establishes the in- and verbal formation."
  },
  "etym-ate-hold9": {
    "title": "Online Etymology Dictionary: -ate",
    "author": "Douglas Harper",
    "url": "https://www.etymonline.com/word/-ate",
    "consulted": "2026-10-16",
    "consultation_status": "newly_consulted_page_body_in_nine_hold_pass",
    "sections": "Entry history and linked family evidence",
    "evidence": "The entry distinguishes the inherited noun/adjective ending from the English verbal -ate formation based on Latin participial stems. Separate is a named related form. This licenses an inherited verbal ending, not automatic stripping of every final ate string."
  },
  "anderson-2e-roots-new": {
    "title": "Essentials of Linguistics, 2nd edition, section 5.2: Roots, bases, and affixes",
    "author": "Catherine Anderson, Bronwyn Bjorkman, Derek Denis, Julianne Doner, Margaret Grant, Nathan Sanders, and Ai Taniguchi",
    "url": "https://socialsci.libretexts.org/Bookshelves/Linguistics/Essentials_of_Linguistics_2e_(Anderson_et_al.)/05:_Morphology/5.02:_Roots_bases_and_affixes",
    "consulted": "2026-10-16",
    "consultation_status": "newly_consulted_page_body_in_revision_pass",
    "sections": "Affixes vs roots; Free and bound morphemes",
    "evidence": "The author text distinguishes roots from bases and affixes and recognizes bound roots. It also separates historical source-language complexity from a contemporary speaker's analysis, using library and nation as examples. Neither free-base absence nor historical complexity alone decides a teaching graph."
  },
  "mw-estimate-new": {
    "title": "Merriam-Webster: estimate",
    "author": "Merriam-Webster editors",
    "url": "https://www.merriam-webster.com/dictionary/estimate",
    "consulted": "2026-10-16",
    "consultation_status": "newly_consulted_page_body_in_revision_pass",
    "sections": "Word History and relevant current sense",
    "evidence": "The history gives Latin aestimatus/aestimare value or estimate. It confirms a historical verbal formation but does not settle whether the intended English lesson should expose estim plus -ate."
  },
  "etym-estimate-hold9": {
    "title": "Online Etymology Dictionary: estimate",
    "author": "Douglas Harper",
    "url": "https://www.etymonline.com/word/estimate",
    "consulted": "2026-10-16",
    "consultation_status": "newly_consulted_page_body_in_nine_hold_pass",
    "sections": "Entry history and linked family evidence",
    "evidence": "The verb is traced to Latin aestimatus/aestimare, valuing or appraising. Its current approximate-judgment meaning developed later. The esteem relation is historical; the target remains approximation rather than respectful admiration."
  },
  "michigan-ate-hold9": {
    "title": "ELI 538: Rules and Practices, Rule 6-3",
    "author": "University of Michigan English Language Institute; page cites Linda Grant, Well Said, 2nd edition",
    "url": "https://www.lrc.lsa.umich.edu/eli-538/pg-014.html",
    "consulted": "2026-10-16",
    "consultation_status": "newly_consulted_page_body_in_nine_hold_pass",
    "sections": "Rule 6-3 and Exercise 2",
    "evidence": "This teaching resource explicitly treats estimate as a verb with -ate and contrasts its noun/verb pronunciations. Its exercise also places separate in the -ate family. This is term-level evidence for an English suffix boundary, not just a Latin derivation."
  }
});
  return {atoms, compounds, derivatives, sources, pending};
};
