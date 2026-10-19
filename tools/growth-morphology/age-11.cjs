// Each decision records a particular stored sense, not a spelling heuristic.
module.exports = ({stem, affix, DATE}) => {
  const c = (id, text = id) => stem(id, text, 'compound');
  const prefix = (id, canonical, surface) => ({canonical_id: `english.affix.${id}`, canonical, surface, type: 'prefix'});
  const combining = (id, canonical, surface) => ({canonical_id: `english.combining.${id}`, canonical, surface, type: 'combining_form'});
  const plural = (surface = 's') => affix('s.plural', '-s', surface);
  const er = () => affix('er.agent-instrument', '-er', 'er');
  const atoms = `
chameleon|The animal name is a whole modern loanword; its ancient ground-and-lion metaphor is not imposed as a current English animal compound.
armadillo|The animal name is borrowed whole; its Spanish diminutive history is not treated as a productive English illo suffix.
porcupine|The animal name is lexicalized from a borrowing; pork and the modern pine tree would give a misleading present-day decomposition.
anemone|The marine-animal name is a whole borrowed stem in this sense, distinct from the flower naming history.
nautilus|The marine-animal noun is a whole borrowed singular form; us is not an English plural suffix.
plankton|The collective organism noun is one borrowed base, not plank plus ton.
crust|The stored outer-Earth-layer noun is one base, extended from the ordinary hard-covering sense.
mantle|The geological-layer noun is one lexical base, not mant plus le.
ozone|The gas name is one scientific borrowing; zone is not the geographic-region component here.
protein|The nutrient name is a lexicalized scientific term; its final in spelling alone does not establish an English derivation from a free prote base.
grain|The food-seed noun is one stem.
poultry|The farm-bird collective noun is lexicalized; a current free poult base is not required to explain its entire meaning.
bladder|The urinary-organ noun is one stem; it is not an agent formed from a bladd verb.
kidney|The filtering-organ name is one lexical base; kid plus ney would invent the wrong internal structure.
muscle|The movement-tissue noun is one borrowed stem; its historical mouse metaphor is not a productive contemporary compound.
spine|The supporting-backbone noun is one base.
trachea|The breathing-tube noun is a whole scientific borrowing, with no detachable English ending.
intestine|The digestive-organ noun is one borrowed base; tine is not a tool prong in this word.
nostril|The nose-opening noun is lexicalized; the historical second element is not the modern drill tool or a free tril word.
shin|The front-of-lower-leg noun is one base.
thigh|The upper-leg noun is one base despite its multiple silent letters.
antelope|The hoofed-animal name is one borrowed stem; ant is not its insect component.
budgie|The clipped bird name is a whole current form; its informal ending does not make bud the plant-base meaning.
mussel|The shellfish noun is one base, distinct from the similarly pronounced muscle.
oyster|The shellfish name is one borrowed base; er does not mark an agent of an oyst action.
mistletoe|The plant name is lexicalized; modern foot toe is not its botanical component sense.
harvest|The crop-gathering noun is one base; vest is not clothing in this word.
weed|The unwanted-plant noun is one base, defined by its growing context rather than a suffix.
secretary|The modern office-worker noun is lexicalized; a person keeping a secret does not fully express the stored administrative role.
mechanic|The vehicle-repair worker noun is one modern base; a free mechan word is not fabricated.
principal|The school-leader noun is a lexicalized rank name; it is not prince plus an adjective suffix in this sense.
syringe|The liquid-delivery tool name is one borrowed stem, not syr plus inge.
sling|The injured-arm support noun is one base, distinct from the throwing action.
rash|The irritated-skin noun is one base, distinct from the hasty adjective.
scar|The healed-wound mark noun is one base.
accurate|The correct-result adjective is one current base; there is no free accur verb to which ate is attached.
source|The origin noun is one base; its e is part of the spelling rather than a meaningful suffix.
knowledge|The understanding noun is lexicalized; ledge in its modern shelf sense is not a constituent alongside know.
resource|The useful-supply noun is one current base; it does not mean a source repeated by re-.
process|The action-sequence noun is one base; a free cess word is not invented.
data|The collected-information noun is a lexicalized English form; its Latin plural history is not converted into a detachable English a suffix.
`;
  const compounds = [
    ['stingray', [c('sting'), c('part.ray.fish', 'ray')], 'The fish name combines its sting with ray in the marine-animal sense, not a beam of light.'],
    ['swordfish', [c('sword'), c('fish')], 'The fish name compares its long bill to a sword; it retains the conventional animal compound.'],
    ['bedrock', [c('part.bed.layer', 'bed'), c('rock')], 'The underlying rock layer uses bed in its geological layer sense, not the sleeping furniture.'],
    ['topsoil', [c('top'), c('soil')], 'The soil occupies the top layer; both bases retain their ordinary spatial and material senses.'],
    ['fingernail', [c('finger'), c('part.nail.body', 'nail')], 'The hard covering is a nail on a finger; the body-part nail sense excludes a metal fastener.'],
    ['eyebrow', [c('eye'), c('part.brow.hair-ridge', 'brow')], 'The hair-bearing brow above the eye forms a transparent body-part compound.'],
    ['eyelash', [c('eye'), c('part.lash.hair', 'lash')], 'The eye-edge hair uses the hair sense of lash, not a whip stroke.'],
    ['rattlesnake', [c('part.rattle.tail-sound', 'rattle'), c('snake')], 'The snake name combines its rattling tail feature with the animal head noun.'],
    ['greengrocer', [c('part.green.fresh-produce', 'green'), c('grocer')], 'The produce-selling occupation combines green in the fresh-produce sense and grocer; it does not require all sold fruit to be green.'],
    ['wheelchair', [c('wheel'), c('chair')], 'The mobility chair has wheels; the two free noun bases remain distinct.']
  ];
  const derivatives = [
    ['rhinoceros', [combining('rhino.nose', 'rhino-', 'rhino'), {canonical_id: 'english.root.cerat.horn', canonical: 'cerat', surface: 'ceros', type: 'root'}], 'The source identifies nose and horn constituents. The horn root has an explicitly recorded ceros realization in this borrowed animal name; neither piece is presented as an independent English word.', 'rhino-plus-horn-root-authored-ceros', ['mw-rhinoceros', 'mw-cerat-']],
    ['centipede', [combining('centi.hundred', 'centi-', 'centi'), combining('pede.foot', '-pede', 'pede')], 'The sourced animal name contains the hundred and foot elements. Its conventional name does not guarantee an exact count of one hundred legs.', 'centi-hundred-plus-pede', ['mw-centipede']],
    ['crutches', [stem('crutch', 'crutch'), plural('es')], 'The walking supports are multiple crutches; plural -s has its es spelling after the crutch base.', 'crutch-plus-plural-es'],
    ['subsoil', [prefix('sub.under', 'sub-', 'sub'), stem('soil', 'soil')], 'The earth layer is under the topsoil; under-prefix sub- modifies soil.', 'sub-under-plus-soil'],
    ['carbohydrate', [combining('carbo.carbon', 'carbo-', 'carbo'), stem('part.hydrate.chemical', 'hydrate')], 'The source formation combines carbon-related carbo- and chemical hydrate. Its historical naming theory is distinguished from the stored modern nutrient sense.', 'carbo-plus-chemical-hydrate', ['wiktionary-carbohydrate']],
    ['lungs', [stem('lung', 'lung'), plural()], 'The breathing organs use the current singular lung plus regular plural -s.', 'lung-plus-plural-s'],
    ['forearm', [prefix('fore.front', 'fore-', 'fore'), stem('arm', 'arm')], 'The front or distal portion of the arm uses fore- and arm, distinct from the numeral four.', 'fore-front-plus-arm'],
    ['freckles', [stem('freckle', 'freckle'), plural()], 'The small skin spots use the complete singular freckle and plural -s.', 'freckle-plus-plural-s'],
    ['anteater', [stem('ant', 'ant'), stem('eat', 'eat'), er()], 'The mammal eats ants. Agent -er first forms eater, and ant supplies the food-object modifier.', 'ant-plus-derived-eater', [], [
      {id: 'eater', left: 'part2', right: 'part3', surface: 'eater', rule: 'eat-plus-agent-er', break_offsets: []},
      {id: 'whole', left: 'part1', right: 'eater', surface: 'anteater', rule: 'ant-plus-eater', break_offsets: []}
    ]],
    ['flipper', [stem('part.flip.move', 'flip'), er()], 'The broad moving limb is an established flip-related instrument noun; the exact output doubles final p before -er.', 'flip-plus-instrument-er-double-p'],
    ['horns', [stem('horn', 'horn'), plural()], 'The head growths are plural horns; the current singular animal-body sense is retained.', 'horn-plus-plural-s'],
    ['paramedic', [prefix('para.associated', 'para-', 'para'), stem('medic', 'medic')], 'The sourced occupation joins para- in its associated medical-role sense and medic; it does not promise that the worker is a physician.', 'para-associated-plus-medic', ['mw-paramedic']],
    ['therapist', [stem('therapy', 'therapy'), affix('ist.specialist', '-ist', 'ist')], 'The specialist provides therapy; -ist replaces the base final y in the exact output, preserving the stored communication-support role.', 'therapy-plus-ist-y-loss', ['wiktionary-therapist']],
    ['caretaker', [stem('care', 'care'), stem('take', 'take'), er()], 'The worker takes care of a building. Taker is formed from take and agent -er, then care supplies the object.', 'care-plus-derived-taker', [], [
      {id: 'taker', left: 'part2', right: 'part3', surface: 'taker', rule: 'take-plus-er-e-sharing', break_offsets: []},
      {id: 'whole', left: 'part1', right: 'taker', surface: 'caretaker', rule: 'care-plus-taker', break_offsets: []}
    ]],
    ['porter', [{canonical_id: 'english.root.port.carry', canonical: 'port', surface: 'port', type: 'root'}, er()], 'The hospital equipment-moving worker follows the attested carry-root history and agent ending. This is distinct from the homonymous gatekeeper and beer senses.', 'carry-port-plus-agent-er', ['mw-porter']],
    ['inhaler', [stem('inhale', 'inhale'), er()], 'The device enables inhaling medicine; instrument -er attaches to inhale with shared final e.', 'inhale-plus-instrument-er-e-sharing'],
    ['stethoscope', [combining('stetho.chest', 'stetho-', 'stetho'), combining('scope.examine', '-scope', 'scope')], 'The sourced instrument contains the chest element stetho- and examining-instrument -scope; the selected listening function is preserved rather than replaced by sight alone.', 'stetho-plus-scope', ['mw-stethoscope']],
    ['summarize', [stem('summary', 'summary'), affix('ize.make', '-ize', 'ize')], 'The action makes a summary; the exact summarize spelling removes base y before verb-forming -ize.', 'summary-plus-ize-y-loss'],
    ['reliable', [stem('rely', 'rely'), affix('able.capable', '-able', 'able')], 'The trustworthy adjective means able to be relied on; the authored spelling changes y to i before -able.', 'rely-plus-able-y-to-i'],
    ['global', [stem('part.globe.earth', 'globe'), affix('al.relating', '-al', 'al')], 'The world-related adjective joins globe in its Earth sense and -al with final e removed; the component is distinct from the stored physical model.', 'globe-plus-al-e-loss'],
    ['research', [prefix('re.intensive', 're-', 're'), stem('search', 'search')], 'The documented surface analysis is re- plus search. The close-examination sense motivates the intensive reading here, while the historical source marks that force as tentative; this is not the productive again prefix.', 'intensive-re-plus-search', ['wiktionary-research', 'etymonline-research']],
    ['empathy', [prefix('en.in', 'en-', 'em'), combining('pathy.feeling', '-pathy', 'pathy')], 'The sourced formation contains the in-prefix with its em allomorph and the feeling element; the stored understanding-another-person sense remains the whole meaning.', 'en-in-em-allomorph-plus-pathy', ['mw-empathy']],
    ['responsibility', [stem('responsible', 'responsible'), affix('ity.quality', '-ity', 'ity')], 'The sourced responsible-plus-ity relation uses the authored responsibil- base realization, preserving the duty noun rather than inventing a new word boundary.', 'responsible-plus-ity-authored-responsibil', ['wiktionary-responsibility']]
  ];
  const sources = {};
  for (const id of ['rhinoceros', 'cerat-', 'centipede', 'paramedic', 'porter', 'stethoscope', 'empathy']) sources[`mw-${id}`] = {
    title: `Merriam-Webster: ${id}`, author: 'Merriam-Webster editors', url: `https://www.merriam-webster.com/dictionary/${id}`, consulted: DATE,
    evidence: 'The specific source roots and modern sense were checked; historical literal meanings do not replace the original Growth definition.'
  };
  for (const id of ['carbohydrate', 'therapist', 'research', 'responsibility']) sources[`wiktionary-${id}`] = {
    title: `Wiktionary: ${id}, English formation`, author: 'Wiktionary contributors', url: `https://en.wiktionary.org/wiki/${id}#English`, consulted: DATE,
    evidence: 'The source English formation was consulted and the particular sense or allomorph is explicitly recorded in the authored decision.'
  };
  sources['etymonline-research'] = {title: 'Online Etymology Dictionary: research', author: 'Online Etymology Dictionary', url: 'https://www.etymonline.com/word/research', consulted: DATE, evidence: 'The close-search history is documented; the source explicitly presents the historical intensive interpretation of re- as tentative.'};
  // These named withdrawals supersede the removed whole-form decisions.
  const pending = {};
  derivatives.push(...[
  [
    "reflect",
    [
      {
        "id": "p1",
        "canonical_id": "english.affix.re.back",
        "type": "prefix",
        "canonical": "re-",
        "surface": "re",
        "break_offsets": []
      },
      {
        "id": "p2",
        "canonical_id": "english.root.flect.bend",
        "type": "root",
        "canonical": "flect",
        "surface": "flect",
        "break_offsets": []
      }
    ],
    "The current thinking-carefully sense belongs to the inherited re- back plus flect bend family corroborated by reflect/deflect. The mental meaning remains the whole target, not a literal physical bending task. Flect is a bound family root. Current gameplay presents the authored surfaces without replacing the mental sense; any future component-meaning display must distinguish the historical family aid from that current meaning.",
    "authored-re-back-plus-bound-flect",
    [
      "mw-reflect-new",
      "mw-deflect-new",
      "mw-re-prefix-new",
      "anderson-2e-roots-new"
    ],
    [
      {
        "id": "whole",
        "left": "p1",
        "right": "p2",
        "surface": "reflect",
        "rule": "authored-re-back-plus-bound-flect",
        "break_offsets": []
      }
    ]
  ],
  [
    "adapt",
    [
      {
        "id": "p1",
        "canonical_id": "english.affix.ad.toward",
        "type": "prefix",
        "canonical": "ad-",
        "surface": "ad",
        "break_offsets": []
      },
      {
        "id": "p2",
        "canonical_id": "english.root.apt.fit",
        "type": "root",
        "canonical": "apt",
        "surface": "apt",
        "break_offsets": []
      }
    ],
    "The current changing-to-suit-conditions sense belongs to the inherited ad- plus apt fit/suitable family. Newly consulted adapt history and the current suitable sense of apt support the graph. Apt is not the likely or quick-learning sense here, and ad- is not an advertisement word. This is a particular inherited formation rather than a productive rule for every adjective.",
    "authored-ad-plus-apt-fit",
    [
      "mw-adapt-new",
      "mw-apt-new",
      "mw-ad-prefix-new",
      "anderson-2e-roots-new"
    ],
    [
      {
        "id": "whole",
        "left": "p1",
        "right": "p2",
        "surface": "adapt",
        "rule": "authored-ad-plus-apt-fit",
        "break_offsets": []
      }
    ]
  ]
]);
  Object.assign(sources, {
  "mw-reflect-new": {
    "title": "Merriam-Webster: reflect",
    "author": "Merriam-Webster editors",
    "url": "https://www.merriam-webster.com/dictionary/reflect",
    "consulted": "2026-10-16",
    "consultation_status": "newly_consulted_page_body_in_revision_pass",
    "sections": "Word History and relevant current sense",
    "evidence": "The dictionary includes careful thought as well as physical reflection. Its history identifies re- plus flectere, bend; the mental sense remains the whole target meaning."
  },
  "mw-deflect-new": {
    "title": "Merriam-Webster: deflect",
    "author": "Merriam-Webster editors",
    "url": "https://www.merriam-webster.com/dictionary/deflect",
    "consulted": "2026-10-16",
    "consultation_status": "newly_consulted_page_body_in_revision_pass",
    "sections": "Word History and relevant current sense",
    "evidence": "The companion history identifies de- plus flectere, bend. It supplies a second current English member of the flect family."
  },
  "mw-re-prefix-new": {
    "title": "Merriam-Webster: re-",
    "author": "Merriam-Webster editors",
    "url": "https://www.merriam-webster.com/dictionary/re-",
    "consulted": "2026-10-16",
    "consultation_status": "newly_consulted_page_body_in_revision_pass",
    "sections": "Prefix entry, senses 1 and 2",
    "evidence": "The prefix distinguishes again from back/backward. The revised receive and reflect candidates select the historical back identity, not a productive repetition claim."
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
  "mw-adapt-new": {
    "title": "Merriam-Webster: adapt",
    "author": "Merriam-Webster editors",
    "url": "https://www.merriam-webster.com/dictionary/adapt",
    "consulted": "2026-10-16",
    "consultation_status": "newly_consulted_page_body_in_revision_pass",
    "sections": "Word History and relevant current sense",
    "evidence": "The history identifies ad- plus aptare, related to aptus suitable or prepared. This supports the fitting root family rather than the unrelated advertisement noun ad."
  },
  "mw-apt-new": {
    "title": "Merriam-Webster: apt",
    "author": "Merriam-Webster editors",
    "url": "https://www.merriam-webster.com/dictionary/apt",
    "consulted": "2026-10-16",
    "consultation_status": "newly_consulted_page_body_in_revision_pass",
    "sections": "Adjective senses, especially suitability",
    "evidence": "The current adjective includes suitability for a purpose, confirming the fit/suitable identity selected for apt rather than its likely or quick-learning senses."
  },
  "mw-ad-prefix-new": {
    "title": "Merriam-Webster: ad-",
    "author": "Merriam-Webster editors",
    "url": "https://www.merriam-webster.com/dictionary/ad-",
    "consulted": "2026-10-16",
    "consultation_status": "newly_consulted_page_body_in_revision_pass",
    "sections": "Prefix entry and listed variants",
    "evidence": "The prefix means to/toward and explicitly has an at- variant before t. This supports ad-/at in attract and ad- in adapt."
  }
});
  return {atoms, compounds, derivatives, sources, pending};
};
