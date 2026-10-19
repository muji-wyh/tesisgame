// Individually authored decisions; absent IDs never become automatic atoms.
module.exports = ({stem, affix, DATE}) => {
  const c = (id, text = id) => stem(id, text, 'compound');
  const er = () => affix('er.agent-instrument', '-er', 'er');
  const y = () => affix('y.adjective', '-y', 'y');
  const ed = () => affix('ed.participle', '-ed', 'ed');
  const plural = () => affix('s.plural', '-s', 's');
  const prefix = (id, canonical, surface) => ({canonical_id: `english.affix.${id}`, canonical, surface, type: 'prefix'});
  const combining = (id, canonical, surface) => ({canonical_id: `english.combining.${id}`, canonical, surface, type: 'combining_form'});
  const atoms = `
vest|The garment noun is one lexical base.
tie|The neckwear noun is one base, distinct from the tying verb used in untie.
bracelet|The wrist-ornament noun is a whole borrowed base; the current support noun brace is not its historical arm base.
ambulance|The emergency-vehicle noun is lexicalized; no independent ambul word is invented for this cohort.
sofa|The seating noun is a whole English loanword.
cactus|The plant noun is a whole borrowed singular form; us is not an English plural ending.
bamboo|The plant-material noun is one borrowed base.
donkey|The animal name has no modern donk plus ey derivation.
camel|The animal name is one borrowed base.
koala|The animal name is a whole English loanword.
otter|The mammal name is one base, not ott plus an agent ending.
parrot|The bird name is one lexical base.
peacock|The bird name stays whole because its first part is not the modern vegetable pea; a misleading pea-plus-rooster exercise is excluded.
flamingo|The bird name is a whole English loanword, not an English flaming plus o action.
onion|The vegetable noun is not on plus the nominal ending -ion.
island|The landform noun is a whole modern base; isle plus land would require a false spelling and does not represent this formation.
volcano|The landform noun is one borrowed base, not a productive volcan plus o join.
apron|The garment noun is one lexical base; initial a is not an article component.
tambourine|The instrument noun is a borrowed lexical base; no current tambour plus ine suffix exercise is imposed.
insert|The putting-inside verb is lexicalized; sert is not fabricated as a contemporary free verb.
knit|The fabric-making action is an uninflected verb base.
mash|The food-crushing action is one uninflected stem.
sew|The thread-joining action is one base.
sieve|The mesh-filtering action is one verb base; conversion adds no spelling suffix.
staple|The paper-fastening action is one base, not stap plus le.
zoom|The image-magnifying action is one uninflected base.
jealous|The envious-state adjective is lexicalized; no current jeal base is invented.
absent|The away-state adjective is one modern base; sent is not the past sending verb here.
delicious|The pleasant-taste adjective is a whole modern stem, not deli plus cious.
flat|The level-surface adjective is one base.
hollow|The empty-inside adjective is one base, without a free holl component.
buffalo|The animal noun is a whole English loanword.
butter|The food-spread noun is one base; it is not an agent of butt.
blouse|The garment noun is one borrowed base.
brooch|The clothing-ornament noun is one base.
buckle|The fastening-device noun is one lexical base, not buck plus le.
cushion|The padded-seat noun is one modern base, not cush plus nominal -ion.
fabric|The cloth noun is one borrowed base; final ic is not an adjective suffix in this noun.
furniture|The collective room-object noun is lexicalized; it is not split into an invented free furnit base.
wallet|The money-holder noun is one lexical base; it is not a little wall.
purse|The money-bag noun is one base.
stool|The seat noun is one base, not s plus tool.
bolt|The metal-fastener noun is one stem, distinct from the running action.
screw|The threaded-fastener noun is one base.
wrench|The nut-turning tool noun is one base.
pliers|The gripping-tool name is a lexical plural; it is not presented as a regular pair of singular pictured pliers parts.
hammer|The striking-tool noun is one modern base; ham is not its verb base.
drama|The performed-story noun is a whole English loanword.
saddle|The horse-seat noun is one base, not sad plus dle.
caravan|The towed-home noun is a whole borrowed base; car and van are not its two inherited components.
escalator|The moving-stairway name is lexicalized from a trademark; it is not automatically assigned the later escalate verb as its original base.|mw-escalator
hangar|The aircraft-building noun is borrowed and distinct from hanger; hanging plus an agent suffix would misteach its spelling.
carpenter|The craft-worker noun is one borrowed stem, not carp plus enter.
print|The paper-output action is an uninflected base.
half|The fraction noun is one base.
quarter|The fourth-part noun is lexicalized; er is not an agent or comparative suffix here.
ahead|The in-front adverb is a lexicalized functional form; a is not an article component.
against|The contact preposition is one modern functional form; final st is not a comparison marker.
opposite|The facing-location preposition is one modern base, not opp plus osite.
middle|The center-position noun is lexicalized; mid plus dle is not a current meaningful join.
bank|The financial-place noun is one base, distinct from the riverbank sense.
cafe|The food-and-drink place noun preserves its stored unaccented loanword spelling as one base.
funnel|The pouring-tool noun is a single stem.
communicate|The information-sharing verb is one modern lexical base; no free communic word is invented.
favorite|The preferred-item adjective is lexicalized from a borrowed form; a generic person-forming -ite would misrepresent this adjective sense.
magnet|The metal-attracting object noun is one lexical base, not mag plus net.
battery|The energy-storage noun is a lexicalized modern sense; the batter hitting verb is not taught as its direct meaning.
lens|The optical-element noun is a singular base despite its final s.
science|The natural-world study noun is one modern base, not sci plus an automatically inferred suffix.
history|The past-events subject noun is one base; it is not his plus story.
graph|The comparison-diagram noun is one base.
joystick|The controller noun is retained as a lexicalized device name; its use does not guarantee the emotional joy component.
curry|The spiced-dish noun is one whole English loanword.
dessert|The after-meal food noun is one borrowed base, not a de reversal of a sert action.
pastry|The dough noun is lexicalized; an invented past plus ry join would confuse it with the time noun.
until|The time-limit preposition is one functional form; un is not a negating prefix here.
during|The time-span preposition is lexicalized; it does not name a present participle of a contemporary dur verb.
while|The simultaneous-time conjunction is one functional form.
still|The continuation adverb is one base.
almost|The near-completion adverb is lexicalized; there is no contemporary free al base.
believe|The accepting-as-true verb is one modern base; initial be is not the state verb.
agree|The shared-opinion verb is lexicalized; it is not a plus a free gree word.
decide|The choosing verb is one modern base; de does not reverse a cide action.
explain|The clarifying verb is lexicalized; ex is not a former-status prefix attached to the plain adjective.
observe|The watching verb is lexicalized; ob is not a free current base.
create|The making-new action is one modern base, not cre plus the eating verb ate.
solve|The problem-answering action is one base.
measure|The quantity-finding action is one modern base.
prefer|The liking-more verb is a whole modern base; pre is not a productive before-prefix attached to fer.
important|The valued-state adjective is lexicalized; its sense is not an agent or adjective of importing goods.
honest|The truthful adjective is one base; est is not a superlative ending here.
patient|The calmly-waiting adjective is one modern base, distinct from the medical-recipient noun.
similar|The likeness adjective is one lexical base, not sim plus ilar.
equal|The same-amount adjective is one modern base.
common|The frequent-occurrence adjective is one base.
reason|The explanatory noun is one modern base, not re plus ason.
result|The outcome noun is lexicalized; it is not repetition of a sult action.
fact|The true-information noun is one base.
community|The connected-people noun is lexicalized; commun is not presented as an independent contemporary word.
choice|The option noun is one modern form; its relationship to choose does not provide a detachable spelled noun suffix.
example|The illustrative-instance noun is one base; ex is not the former-status prefix in this sense.
material|The substance noun is one modern stem; no free materi base is invented.
effort|The exertion noun is one base; fort is not the defensive-building noun here.
january|The first-month name stays whole and preserves original lowercase; a historical divine name is not imposed as a current word part.
february|The second-month name stays whole; febr is not a current free word in this calendar sense.
march|The third-month name is one calendar label, distinct from the walking action.
april|The fourth-month name is one calendar label with no current meaningful join.
may|The fifth-month name is a whole calendar label, distinct from the possibility modal.
june|The sixth-month name is one calendar label with no productive English suffix.
july|The seventh-month name is a whole eponymic calendar label; no Jul base is invented.
august|The eighth-month name is a whole calendar label, distinct from the dignity adjective.
september|The ninth-month name stays whole; the historical seven element would misrepresent its current month number.
october|The tenth-month name stays whole; its historical eight element is not taught as the present calendar position.
november|The eleventh-month name stays whole; its historical nine element is not treated as a current number definition.
december|The twelfth-month name stays whole; the historical ten element would misteach the modern calendar position.
plastic|The manufactured-material noun is one modern base; it is not automatically split by the adjective suffix spelling ic.
`;
  const compounds = [
    ['coconut', [c('part.coco.palm', 'coco'), c('nut')], 'The attested fruit name combines the coco-palm name and nut in its everyday food sense; it makes no botanical claim that this is a true nut.', ['wiktionary-coconut']],
    ['pineapple', [c('pine'), c('part.apple.general-fruit', 'apple')], 'The conventional fruit name compares its form to a pine cone; apple retains the historical general-fruit naming sense, not the claim that it is a modern apple cultivar.', ['mw-pineapple']],
    ['watermelon', [c('water'), c('melon')], 'The melon name uses water to describe its high water content, keeping the two free noun bases.'],
    ['strawberry', [c('part.straw.plant-material', 'straw'), c('berry')], 'The established compound is straw plus berry. The straw component is plant material, not the Growth drinking tube; no disputed naming story is asserted.', ['mw-strawberry']],
    ['waterfall', [c('water'), c('part.fall.drop', 'fall')], 'The land feature consists of falling water; fall is the downward motion, not the season.'],
    ['necklace', [c('neck'), c('part.lace.cord', 'lace')], 'The ornament is a cord or chain at the neck; lace is the cord sense, not decorative openwork fabric.'],
    ['skateboard', [c('part.skate.wheeled-device', 'skate'), c('part.board.riding', 'board')], 'The wheeled riding board uses the skate device and riding-board senses.'],
    ['jellyfish', [c('jelly'), c('fish')], 'The conventional creature name combines jelly-like appearance with the traditional broad fish naming element; it does not assert that jellyfish are vertebrate fish.'],
    ['seahorse', [c('sea'), c('horse')], 'The marine animal name uses sea habitat and horse resemblance; it is an established compound, not a horse species claim.'],
    ['starfish', [c('star'), c('fish')], 'The conventional sea-creature compound names its star shape; the broad fish naming element is not a modern taxonomy claim.'],
    ['pinecone', [c('pine'), c('part.cone.seed-structure', 'cone')], 'The object is the seed-bearing cone of a pine; the plant structure sense of cone is selected.'],
    ['sunflower', [c('sun'), c('flower')], 'The established flower name retains sun and flower as meaningful naming components.'],
    ['ladybug', [c('part.lady.honorific', 'lady'), c('part.bug.insect', 'bug')], 'The conventional insect compound uses the honorific lady and insect bug; it does not claim only female insects bear the name.'],
    ['butterfly', [c('butter'), c('fly')], 'The attested conventional insect compound contains butter and fly. The historical reason for butter is uncertain, so no ingredient, diet, or origin story is taught.', ['wiktionary-butterfly']],
    ['dragonfly', [c('dragon'), c('fly')], 'The conventional insect name combines dragon comparison and fly; it does not claim a mythical animal lineage.'],
    ['waterproof', [c('water'), c('part.proof.resistant', 'proof')], 'The adjective means resistant to water; proof is the established resisting component, not evidence for an argument.'],
    ['suitcase', [c('part.suit.clothes', 'suit'), c('part.case.container', 'case')], 'The luggage name is a case for clothing or suits; both components keep the intended container relation.'],
    ['sandpaper', [c('sand'), c('paper')], 'The abrasive material combines grit or sand with a paper backing.'],
    ['cardboard', [c('card'), c('part.board.sheet', 'board')], 'The stiff material is card in board-like sheet form, with no unrelated computer-board meaning.'],
    ['shuttlecock', [c('part.shuttle.back-and-forth', 'shuttle'), c('part.cock.bird', 'cock')], 'The established sporting-object compound associates shuttle motion with the bird-feather element; the bird sense is explicit.', ['wiktionary-shuttlecock']],
    ['signpost', [c('part.sign.notice', 'sign'), c('part.post.upright', 'post')], 'The direction marker is a sign on a post; neither component uses the unrelated signing verb or mail sense.'],
    ['whiteboard', [c('white'), c('part.board.writing', 'board')], 'The classroom writing board is white; the head is the writing-surface sense.'],
    ['blackboard', [c('black'), c('part.board.writing', 'board')], 'The conventional dark writing-board name preserves black and the writing-surface board sense.'],
    ['playdough', [c('play'), c('dough')], 'The molding material is dough used for play; the stored spelling is retained.'],
    ['peanut', [c('pea'), c('nut')], 'The conventional food name combines pea resemblance and everyday nut use; it does not claim the seed is botanically a true nut.'],
    ['newspaper', [c('news'), c('paper')], 'The publication presents news on paper; news remains a lexical whole rather than new plus an invented plural adjective.']
  ];
  const derivatives = [
    ['helicopter', [combining('helico.spiral', 'helico-', 'helico'), combining('pter.wing', '-pter', 'pter')], 'The sourced aircraft formation contains helico- and -pter. The boundary is after helico, not the tempting but historically false heli plus copter split.', 'attested-helico-pter', ['mw-helicopter']],
    ['octopus', [combining('octo.eight', 'octo-', 'octo'), combining('pus.foot', '-pus', 'pus')], 'The established animal name contains the eight and foot combining forms; the etymology is distinguished from the modern anatomical description of its arms.', 'attested-octo-pus', ['mw-octopus']],
    ['microphone', [prefix('micro.small', 'micro-', 'micro'), combining('phone.sound', '-phone', 'phone')], 'The sourced instrument name combines micro- with the sound element -phone. Its conventional device sense is retained rather than defined by the literal small-sound reading.', 'micro-plus-sound-phone', ['mw-microphone']],
    ['slippers', [stem('part.slip.put-on', 'slip'), er(), plural()], 'The footwear slips on; instrument -er forms slipper with doubled p, followed by regular plural -s. This is distinct from the obsolete adjective behind slippery.', 'slip-plus-er-plus-plural', [], [
      {id: 'slipper', left: 'part1', right: 'part2', surface: 'slipper', rule: 'slip-plus-er-double-p', break_offsets: []},
      {id: 'whole', left: 'slipper', right: 'part3', surface: 'slippers', rule: 'slipper-plus-plural-s', break_offsets: []}
    ]],
    ['earmuffs', [stem('ear', 'ear'), stem('part.muff.warm-cover', 'muff'), plural()], 'The paired warm covers combine ear and muff before plural -s applies to the complete earmuff.', 'ear-muff-compound-plus-plural', [], [
      {id: 'earmuff', left: 'part1', right: 'part2', surface: 'earmuff', rule: 'ear-plus-muff-compound', break_offsets: []},
      {id: 'whole', left: 'earmuff', right: 'part3', surface: 'earmuffs', rule: 'earmuff-plus-plural-s', break_offsets: []}
    ]],
    ['fasten', [stem('part.fast.secure', 'fast'), affix('en.make', '-en', 'en')], 'The securing action makes something fast in the firmly-fixed sense; it does not mean making the Growth speed adjective faster.', 'fast-secure-plus-causative-en'],
    ['tighten', [stem('tight', 'tight'), affix('en.make', '-en', 'en')], 'The action makes something tight; verbal -en contributes the change of state.', 'tight-plus-causative-en'],
    ['unbuckle', [prefix('un.reverse', 'un-', 'un'), stem('part.buckle.action', 'buckle')], 'The action reverses buckling; the component buckle is the fastening action rather than only the hardware noun.', 'un-reverse-plus-buckle'],
    ['unbutton', [prefix('un.reverse', 'un-', 'un'), stem('part.button.action', 'button')], 'The action reverses buttoning clothes; the reversative un- sense is selected.', 'un-reverse-plus-button'],
    ['confused', [stem('confuse', 'confuse'), ed()], 'The uncertain-state adjective is the participial form of confuse; the exact output shares final e.', 'confuse-plus-ed-e-sharing'],
    ['bumpy', [stem('bump', 'bump'), y()], 'The uneven-surface adjective combines bump with adjectival -y.', 'bump-plus-adjective-y'],
    ['crooked', [stem('part.crook.bend', 'crook'), affix('ed.having', '-ed', 'ed')], 'The bent-shape adjective has the bend sense of crook and the having-property ending -ed, not the dishonest-person sense.', 'crook-bend-plus-having-ed'],
    ['crunchy', [stem('crunch', 'crunch'), y()], 'The texture adjective relates to the crunch sound or action plus adjectival -y.', 'crunch-plus-adjective-y'],
    ['curly', [stem('curl', 'curl'), y()], 'The looping-shape adjective combines curl and adjectival -y.', 'curl-plus-adjective-y'],
    ['fuzzy', [stem('fuzz', 'fuzz'), y()], 'The unclear-outline adjective extends the appearance of fuzz with adjectival -y.', 'fuzz-plus-adjective-y'],
    ['lost', [stem('lose', 'lose'), ed()], 'The disoriented adjective is the irregular participial form of lose; -ed is the grammatical ending identity and the entire lost allomorph is authored.', 'lose-plus-participle-authored-lost-allomorph'],
    ['magnetic', [stem('magnet', 'magnet'), affix('ic.relating', '-ic', 'ic')], 'The attraction adjective relates to magnet through adjective-forming -ic.', 'magnet-plus-adjective-ic'],
    ['spotty', [stem('spot', 'spot'), y()], 'The marked-surface adjective joins spot and -y with final t doubled in the exact output.', 'spot-plus-y-double-t'],
    ['wavy', [stem('part.wave.curve', 'wave'), y()], 'The curved-shape adjective uses wave in its undulating-form sense and drops the final e before -y.', 'wave-curve-plus-y-e-loss'],
    ['wrinkled', [stem('wrinkle', 'wrinkle'), ed()], 'The folded-surface adjective is the participial form of wrinkle; the output shares its final e.', 'wrinkle-plus-ed-e-sharing'],
    ['screwdriver', [stem('screw', 'screw'), stem('part.drive.turn-fastener', 'drive'), er()], 'The tool drives screws. Drive in the fastening sense first forms driver with -er, then screw supplies the object of the tool.', 'screw-plus-derived-driver', [], [
      {id: 'driver', left: 'part2', right: 'part3', surface: 'driver', rule: 'drive-fastener-plus-er-e-sharing', break_offsets: []},
      {id: 'whole', left: 'part1', right: 'driver', surface: 'screwdriver', rule: 'screw-plus-driver-compound', break_offsets: []}
    ]],
    ['calculator', [stem('calculate', 'calculate'), affix('or.agent', '-or', 'or')], 'The device calculates; the established -or instrument formation drops the base final e in calculator.', 'calculate-plus-or-e-loss'],
    ['archery', [stem('part.archer.bow-user', 'archer'), affix('ery.craft', '-ery', 'ery')], 'The sourced analysis relates the bow sport to archer plus -ery, with the repeated er shared in the exact output. The complete practitioner noun avoids the unrelated architectural arch sense.', 'archer-plus-ery-er-sharing', ['wiktionary-archery']],
    ['pottery', [stem('pot', 'pot'), affix('ery.craft', '-ery', 'ery')], 'The clay craft has the attested pot plus -ery analysis; the exact output doubles final t.', 'pot-plus-craft-ery-double-t', ['wiktionary-pottery']],
    ['florist', [{canonical_id: 'english.root.flor.flower', canonical: 'flor', surface: 'flor', type: 'root'}, affix('ist.specialist', '-ist', 'ist')], 'The flower seller uses the sourced flor flower root and specialist -ist; flor is not a misspelled floor noun.', 'flor-plus-specialist-ist', ['mw-florist']],
    ['assembly', [stem('assemble', 'assemble'), affix('y.activity', '-y', 'y')], 'The pupil gathering is related to assembling; the documented surface analysis uses assemble and nominal -y with final e removed.', 'assemble-plus-nominal-y-e-loss', ['wiktionary-assembly']],
    ['lawnmower', [stem('lawn', 'lawn'), stem('mow', 'mow'), er()], 'The machine mows a lawn. The instrument mower forms first, followed by the lawn modifier.', 'lawn-plus-derived-mower', [], [
      {id: 'mower', left: 'part2', right: 'part3', surface: 'mower', rule: 'mow-plus-instrument-er', break_offsets: []},
      {id: 'whole', left: 'part1', right: 'mower', surface: 'lawnmower', rule: 'lawn-plus-mower-compound', break_offsets: []}
    ]],
    ['transport', [prefix('trans.across', 'trans-', 'trans'), {canonical_id: 'english.root.port.carry', canonical: 'port', surface: 'port', type: 'root'}], 'The carrying-across action contains the attested trans- and carry-root port; port is distinct from a harbor or computer connector.', 'trans-plus-bound-port', ['mw-transport']],
    ['frozen', [stem('freeze', 'freeze'), affix('en.participle', '-en', 'en')], 'The cold-state adjective is the irregular participle of freeze; frozen is an explicit authored stem realization plus the participial ending.', 'freeze-plus-en-authored-vowel-change'],
    ['thermometer', [combining('thermo.heat', 'thermo-', 'thermo'), combining('meter.measure', '-meter', 'meter')], 'The instrument name joins the heat combining form thermo- and measuring form -meter; the linking o belongs with thermo-.', 'thermo-plus-meter', ['mw-thermometer']],
    ['geography', [combining('geo.earth', 'geo-', 'geo'), combining('graphy.description', '-graphy', 'graphy')], 'The established subject name combines Earth-related geo- and description-related -graphy; the modern subject scope remains the stored meaning.', 'geo-plus-graphy', ['mw-geography']],
    ['technology', [combining('techno.art-skill', 'techno-', 'techno'), combining('logy.study', '-logy', 'logy')], 'The sourced formation combines art-or-skill techno- and -logy; its modern tools-and-methods sense is retained rather than reduced to the historical literal reading.', 'techno-plus-logy', ['mw-technology']],
    ['binder', [stem('bind', 'bind'), er()], 'The cover binds pages together; instrument -er attaches to the current binding verb.', 'bind-plus-instrument-er'],
    ['folder', [stem('part.fold.paper-holder', 'fold'), er()], 'The computer container sense extends the physical folding paper holder. This fold sense is distinguished from the stored clothing-folding action.', 'fold-plus-instrument-er'],
    ['discover', [prefix('dis.reverse', 'dis-', 'dis'), stem('cover', 'cover')], 'The finding verb retains the attested uncovering relation of dis- and cover; its knowledge-finding sense is recorded without narrowing it to physically removing a cover.', 'dis-reverse-plus-cover', ['mw-discover']],
    ['reuse', [prefix('re.again', 're-', 're'), stem('use', 'use')], 'The action explicitly uses something again; both the prefix and base preserve their ordinary current meanings.', 're-again-plus-use'],
    ['useful', [stem('use', 'use'), affix('ful.characterized-by', '-ful', 'ful')], 'The helpful adjective contains use and adjective-forming -ful with its single-l spelling.', 'use-plus-ful'],
    ['natural', [stem('nature', 'nature'), affix('al.relating', '-al', 'al')], 'The adjective relates to nature; final e is removed in the exact authored natural output.', 'nature-plus-al-e-loss']
  ];
  const sources = Object.fromEntries(['escalator', 'pineapple', 'strawberry', 'helicopter', 'octopus', 'microphone', 'florist', 'transport', 'thermometer', 'geography', 'technology', 'discover'].map(id => [`mw-${id}`, {
    title: `Merriam-Webster: ${id}`, author: 'Merriam-Webster editors', url: `https://www.merriam-webster.com/dictionary/${id}`, consulted: DATE,
    evidence: 'The selected sense and source formation were checked; conventional or historical naming does not override the stored modern meaning.'
  }]));
  for (const id of ['coconut', 'butterfly', 'shuttlecock', 'pottery', 'assembly', 'archery']) sources[`wiktionary-${id}`] = {
    title: `Wiktionary: ${id}, English formation`, author: 'Wiktionary contributors', url: `https://en.wiktionary.org/wiki/${id}#English`, consulted: DATE,
    evidence: 'The explicit English formation was consulted, with ambiguous origin stories excluded from the authored teaching claim.'
  };
  // These named withdrawals supersede the removed whole-form decisions.
  const pending = {
  "compare": "Reopened after new term-specific evidence: The com- plus par equal family is documented, so the prior no-modern-com/pare argument is insufficient. Hold until the exact English par/pare realization and learner-level comparison meaning are authored and independently checked. Do not confuse equal par with pare trim or prepare par in separate.",
  "multiply": "Reopened after new term-specific evidence: The multi-/plex fold family is documented through multiple and multiplicare. Hold while plex/plic/ply and the verb ending are resolved. Neither a missing free arithmetic ply nor the existence of the modern layer verb settles the graph.",
  "divide": "Reopened after new term-specific evidence: The dictionary identifies dis- plus a separate-root -videre. Hold until di/dis and vid/vide are authored and independently checked; do not confuse this root with Latin videre see. Lack of a free English vide cannot justify atomic status."
};
  derivatives.push(...[
  [
    "connect",
    [
      {
        "id": "p1",
        "canonical_id": "english.affix.com.together",
        "type": "prefix",
        "canonical": "com-",
        "surface": "con",
        "break_offsets": []
      },
      {
        "id": "p2",
        "canonical_id": "english.root.nect.bind",
        "type": "root",
        "canonical": "nect",
        "surface": "nect",
        "break_offsets": []
      }
    ],
    "The current joining-things-or-ideas sense belongs to the inherited com-/con- plus nect bind/join family. Newly consulted connect history and the com- variant entry support the exact graph. Nect is a bound root, so absence of a free nect word cannot establish atomicity. The current linking sense remains the whole meaning.",
    "authored-com-con-allomorph-plus-nect",
    [
      "mw-connect-new",
      "mw-com-prefix-new",
      "anderson-2e-roots-new"
    ],
    [
      {
        "id": "whole",
        "left": "p1",
        "right": "p2",
        "surface": "connect",
        "rule": "authored-com-con-allomorph-plus-nect",
        "break_offsets": []
      }
    ]
  ]
]);
  Object.assign(sources, {
  "mw-connect-new": {
    "title": "Merriam-Webster: connect",
    "author": "Merriam-Webster editors",
    "url": "https://www.merriam-webster.com/dictionary/connect",
    "consulted": "2026-10-16",
    "consultation_status": "newly_consulted_page_body_in_revision_pass",
    "sections": "Word History and relevant current sense",
    "evidence": "The dictionary includes both joining physical things and establishing communications. Its history identifies com- plus Latin nectere, bind."
  },
  "mw-com-prefix-new": {
    "title": "Merriam-Webster: com-",
    "author": "Merriam-Webster editors",
    "url": "https://www.merriam-webster.com/dictionary/com-",
    "consulted": "2026-10-16",
    "consultation_status": "newly_consulted_page_body_in_revision_pass",
    "sections": "Prefix entry and listed variants",
    "evidence": "The prefix expresses with/together and explicitly lists con- as a variant. This supports com-/con in connect."
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
  "mw-compare-new": {
    "title": "Merriam-Webster: compare",
    "author": "Merriam-Webster editors",
    "url": "https://www.merriam-webster.com/dictionary/compare",
    "consulted": "2026-10-16",
    "consultation_status": "newly_consulted_page_body_in_revision_pass",
    "sections": "Word History and relevant current sense",
    "evidence": "The current comparison sense matches the target. The history identifies com- plus par equal through comparare; this is distinct from English pare trim and the prepare root in separate."
  },
  "mw-multiply-new": {
    "title": "Merriam-Webster: multiply",
    "author": "Merriam-Webster editors",
    "url": "https://www.merriam-webster.com/dictionary/multiply",
    "consulted": "2026-10-16",
    "consultation_status": "newly_consulted_page_body_in_revision_pass",
    "sections": "Word History and relevant current sense",
    "evidence": "The arithmetic verb is traced through French multiplier and Latin multiplicare to multiplex. This establishes the multiple family but not a direct English multi plus the layer verb ply exercise."
  },
  "mw-multiple-new": {
    "title": "Merriam-Webster: multiple",
    "author": "Merriam-Webster editors",
    "url": "https://www.merriam-webster.com/dictionary/multiple",
    "consulted": "2026-10-16",
    "consultation_status": "newly_consulted_page_body_in_revision_pass",
    "sections": "Word History and relevant current sense",
    "evidence": "The history identifies Latin multi- plus -plex meaning fold. The relationship to multiply is documented, while the exact English plex/plic/ply realization remains to be authored."
  },
  "mw-divide-new": {
    "title": "Merriam-Webster: divide",
    "author": "Merriam-Webster editors",
    "url": "https://www.merriam-webster.com/dictionary/divide",
    "consulted": "2026-10-16",
    "consultation_status": "newly_consulted_page_body_in_revision_pass",
    "sections": "Word History and relevant current sense",
    "evidence": "The arithmetic sense is explicit. The history identifies dis- plus a Latin -videre separate root, distinct from Latin videre see. No free English vide is needed for a possible bound-root analysis."
  }
});
// Nine-hold proposal: these decisions supersede the named pending reviews only.
  delete pending["compare"];
  delete pending["multiply"];
  delete pending["divide"];
  derivatives.push(...[
  [
    "compare",
    [
      {
        "canonical_id": "english.affix.com.together",
        "type": "prefix",
        "canonical": "com-",
        "surface": "com"
      },
      {
        "canonical_id": "english.root.par.equal",
        "type": "root",
        "canonical": "par",
        "surface": "pare"
      }
    ],
    "The selected comparison action uses the inherited com- and par equal family. Its exact English root surface is pare; final e belongs to this authored realization and is not a third morpheme. The par.equal identity is corroborated by par and kept distinct from pare trim and separate par.prepare. Comparing can establish differences as well as similarities; it does not assert equality. The completed current meaning is preserved, and this graph does not claim a productive English com- plus free pare construction.",
    "authored-com-plus-par-equal-pare-realization",
    [
      "mw-compare-new",
      "etym-compare-hold9",
      "mw-par-hold9",
      "mw-com-prefix-new",
      "anderson-2e-roots-new"
    ],
    [
      {
        "id": "whole",
        "left": "part1",
        "right": "part2",
        "rule": "authored-com-plus-par-equal-pare-realization",
        "surface": "compare",
        "break_offsets": []
      }
    ]
  ],
  [
    "multiply",
    [
      {
        "canonical_id": "english.combining.multi.many",
        "type": "combining_form",
        "canonical": "multi-",
        "surface": "multi"
      },
      {
        "canonical_id": "english.root.ply.fold",
        "type": "root",
        "canonical": "ply",
        "surface": "ply"
      }
    ],
    "The publisher-hosted Vocabulary Their Way chapter explicitly teaches the plic/ply fold family in multiply and multiplication. Together with the word history and multi- entry this supports the exact multi plus ply graph. Ply is the inherited fold-family root, not a substituted modern layer noun or a verb about plying a trade. The full ply surface includes the inherited English realization; no detachable y or adverbial -ly is invented. Multiplication retains its arithmetic definition, including cases that do not increase a number, and the historical folding analogy does not replace that definition.",
    "authored-multi-plus-ply-fold-family",
    [
      "mw-multiply-new",
      "mw-multiple-new",
      "etym-multiply-hold9",
      "mw-multi-hold9",
      "pearson-ply-hold9",
      "anderson-2e-roots-new"
    ],
    [
      {
        "id": "whole",
        "left": "part1",
        "right": "part2",
        "rule": "authored-multi-plus-ply-fold-family",
        "surface": "multiply",
        "break_offsets": []
      }
    ]
  ],
  [
    "divide",
    [
      {
        "canonical_id": "english.affix.dis.apart",
        "type": "prefix",
        "canonical": "dis-",
        "surface": "di"
      },
      {
        "canonical_id": "english.root.vide.separate",
        "type": "root",
        "canonical": "vide",
        "surface": "vide"
      }
    ],
    "The word history identifies dis- apart and the separate-root -videre. The prefix history explicitly records the di- realization before v, supporting di plus vide with the final e retained in the authored English root surface. The vide.separate identity is distinct from the vid/vis sight family and di is not the numeral combining form meaning two. The arithmetic sense is a conventional application of division into parts; the graph preserves its current definition without requiring a free English vide word.",
    "authored-dis-di-allomorph-plus-vide-separate",
    [
      "mw-divide-new",
      "etym-divide-hold9",
      "mw-dis-hold9",
      "anderson-2e-roots-new"
    ],
    [
      {
        "id": "whole",
        "left": "part1",
        "right": "part2",
        "rule": "authored-dis-di-allomorph-plus-vide-separate",
        "surface": "divide",
        "break_offsets": []
      }
    ]
  ]
]);
  Object.assign(sources, {
  "mw-compare-new": {
    "title": "Merriam-Webster: compare",
    "author": "Merriam-Webster editors",
    "url": "https://www.merriam-webster.com/dictionary/compare",
    "consulted": "2026-10-16",
    "consultation_status": "newly_consulted_page_body_in_revision_pass",
    "sections": "Word History and relevant current sense",
    "evidence": "The current comparison sense matches the target. The history identifies com- plus par equal through comparare; this is distinct from English pare trim and the prepare root in separate."
  },
  "etym-compare-hold9": {
    "title": "Online Etymology Dictionary: compare",
    "author": "Douglas Harper",
    "url": "https://www.etymonline.com/word/compare",
    "consulted": "2026-10-16",
    "consultation_status": "newly_consulted_page_body_in_nine_hold_pass",
    "sections": "Entry history and linked family evidence",
    "evidence": "The entry identifies com- with par equal through Latin comparare and French comparer. It dates the comparison of similarities and differences as a conventional extension of the earlier equality relation; current comparison does not assert that the compared objects are equal."
  },
  "mw-par-hold9": {
    "title": "Merriam-Webster: par",
    "author": "Merriam-Webster editors",
    "url": "https://www.merriam-webster.com/dictionary/par",
    "consulted": "2026-10-16",
    "consultation_status": "newly_consulted_page_body_in_nine_hold_pass",
    "sections": "Relevant sense and Word History",
    "evidence": "The equality noun is traced to Latin par equal and the child-oriented history explicitly connects it to compare. This supports par.equal, not pare trimming or parare preparation."
  },
  "mw-com-prefix-new": {
    "title": "Merriam-Webster: com-",
    "author": "Merriam-Webster editors",
    "url": "https://www.merriam-webster.com/dictionary/com-",
    "consulted": "2026-10-16",
    "consultation_status": "newly_consulted_page_body_in_revision_pass",
    "sections": "Prefix entry and listed variants",
    "evidence": "The prefix expresses with/together and explicitly lists con- as a variant. This supports com-/con in connect."
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
  "mw-multiply-new": {
    "title": "Merriam-Webster: multiply",
    "author": "Merriam-Webster editors",
    "url": "https://www.merriam-webster.com/dictionary/multiply",
    "consulted": "2026-10-16",
    "consultation_status": "newly_consulted_page_body_in_revision_pass",
    "sections": "Word History and relevant current sense",
    "evidence": "The arithmetic verb is traced through French multiplier and Latin multiplicare to multiplex. This establishes the multiple family but not a direct English multi plus the layer verb ply exercise."
  },
  "mw-multiple-new": {
    "title": "Merriam-Webster: multiple",
    "author": "Merriam-Webster editors",
    "url": "https://www.merriam-webster.com/dictionary/multiple",
    "consulted": "2026-10-16",
    "consultation_status": "newly_consulted_page_body_in_revision_pass",
    "sections": "Word History and relevant current sense",
    "evidence": "The history identifies Latin multi- plus -plex meaning fold. The relationship to multiply is documented, while the exact English plex/plic/ply realization remains to be authored."
  },
  "etym-multiply-hold9": {
    "title": "Online Etymology Dictionary: multiply",
    "author": "Douglas Harper",
    "url": "https://www.etymonline.com/word/multiply",
    "consulted": "2026-10-16",
    "consultation_status": "newly_consulted_page_body_in_nine_hold_pass",
    "sections": "Entry history and linked family evidence",
    "evidence": "The entry traces the verb through French multiplier to Latin multiplicare and multiplex, linking the many element and fold family. The arithmetic sense is explicitly historical; no adverbial -ly analysis is licensed."
  },
  "mw-multi-hold9": {
    "title": "Merriam-Webster: multi-",
    "author": "Merriam-Webster editors",
    "url": "https://www.merriam-webster.com/dictionary/multi-",
    "consulted": "2026-10-16",
    "consultation_status": "newly_consulted_page_body_in_nine_hold_pass",
    "sections": "Relevant sense and Word History",
    "evidence": "The combining form supplies the many/multiple contribution and is traced to Latin multus. This is the numeric element in multiply rather than an arbitrary multi syllable sequence."
  },
  "pearson-ply-hold9": {
    "title": "Vocabulary Their Way, chapter 6: Teaching Content-Specific Academic Vocabulary",
    "author": "Shane Templeton, Donald R. Bear, Francine Johnston, and Marcia Invernizzi",
    "url": "https://ptgmedia.pearsoncmg.com/images/9780131555358/samplechapter/ch06.pdf",
    "consulted": "2026-10-16",
    "consultation_status": "newly_consulted_page_body_in_nine_hold_pass",
    "sections": "Printed pages 110 and 130; mathematics root table and Origin of Multiply",
    "evidence": "The publisher-hosted chapter explicitly associates plic/ply with the fold family in multiply/multiplication and discusses this family as vocabulary instruction. The game retains the actual mathematical definition rather than teaching that every multiplication makes a number larger or requires physical folding."
  },
  "mw-divide-new": {
    "title": "Merriam-Webster: divide",
    "author": "Merriam-Webster editors",
    "url": "https://www.merriam-webster.com/dictionary/divide",
    "consulted": "2026-10-16",
    "consultation_status": "newly_consulted_page_body_in_revision_pass",
    "sections": "Word History and relevant current sense",
    "evidence": "The arithmetic sense is explicit. The history identifies dis- plus a Latin -videre separate root, distinct from Latin videre see. No free English vide is needed for a possible bound-root analysis."
  },
  "etym-divide-hold9": {
    "title": "Online Etymology Dictionary: divide",
    "author": "Douglas Harper",
    "url": "https://www.etymonline.com/word/divide",
    "consulted": "2026-10-16",
    "consultation_status": "newly_consulted_page_body_in_nine_hold_pass",
    "sections": "Entry history and linked family evidence",
    "evidence": "The entry identifies the assimilated dis- prefix plus a separate-root -videre, with an arithmetic extension. The separate root is not the Latin sight root used in video and vision."
  },
  "mw-dis-hold9": {
    "title": "Merriam-Webster: dis-",
    "author": "Merriam-Webster editors",
    "url": "https://www.merriam-webster.com/dictionary/dis-",
    "consulted": "2026-10-16",
    "consultation_status": "newly_consulted_page_body_in_nine_hold_pass",
    "sections": "Relevant sense and Word History",
    "evidence": "The prefix history explicitly gives Latin di- before v among the variants of dis- apart/asunder. This supports the exact di surface in divide and distinguishes it from the numeral di- two."
  }
});
  return {atoms, compounds, derivatives, sources, pending};
};
