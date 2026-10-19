// Explicit age-nine sense decisions. No inference is performed for missing IDs.
module.exports = ({stem, affix, DATE}) => {
  const c = (id, text = id) => stem(id, text, 'compound');
  const er = () => affix('er.agent-instrument', '-er', 'er');
  const plural = () => affix('s.plural', '-s', 's');
  const y = () => affix('y.adjective', '-y', 'y');
  const ed = () => affix('ed.participle', '-ed', 'ed');
  const pref = (id, canonical, surface) => ({canonical_id: `english.affix.${id}`, canonical, surface, type: 'prefix'});
  const atoms = `
drum|The percussion-instrument noun is one stem.
coral|The marine-organism noun is a borrowed whole base, not cor plus adjectival -al.
squid|The sea-animal name has no detachable meaningful ending.
clam|The shellfish noun is one lexical base.
comet|The astronomical noun is a whole borrowed base, not come plus t.
piano|The established instrument name is a shortening retained as one base.
flute|The wind-instrument noun is a whole base; final e is not an affix.
violin|The borrowed instrument name is retained whole; its Italian diminutive history does not supply a current English lin suffix.
guitar|The stringed-instrument name is one borrowed base.
harp|The stringed-instrument noun is an uninflected base.
tuba|The brass-instrument noun is one borrowed stem.
crystal|The mineral noun is a borrowed base, not cryst plus adjectival -al.
lamb|The young-sheep noun is a single stem; silent b is spelling rather than a morpheme.
beak|The bird-mouth noun is one lexical base.
paw|The animal-foot noun is one uninflected base.
badger|The animal name is kept whole; it does not mean someone who badges.
cheetah|The animal name is one borrowed lexical form.
chimpanzee|The ape name is a borrowed whole form; syllable divisions do not supply English morphemes.
chipmunk|The rodent name is a whole borrowed stem, not chip plus a monk or munk base.
cockatiel|The crested-bird name is a whole borrowed form, not a current cock plus tiel compound.
dove|The bird noun is a single stem, distinct from the past-tense diving verb.
gorilla|The ape noun is a whole lexical base with no current diminutive suffix.
hare|The animal noun is one base; final e is not an ending.
heron|The wading-bird noun has no modern her plus on analysis.
hippopotamus|The borrowed species name retains its Latin whole form. Its Greek horse-and-river history is not converted into invented English potamus or us components.|mw-hippopotamus
leopard|The animal noun is a whole modern base; the historical lion and pard relation is not a current transparent compound in this sense.
ostrich|The bird name is not an English ost plus rich compound.
puffin|The seabird noun is kept whole; the ending is not a current English diminutive morpheme.
quail|The bird noun is a single base, distinct from the fear verb.
reindeer|The animal name remains whole; historical rein refers to the animal and is not the modern harness strap.|mw-reindeer
robin|The bird name is a lexical base; a personal-name origin does not make rob plus in a current animal analysis.
swan|The waterbird noun is one lexical base.
toad|The amphibian noun is one uninflected stem.
walrus|The borrowed mammal name is one modern base; it is not wall plus an English rus.
wolf|The singular animal noun is retained without importing its wolves plural alternation.
clover|The plant name is one base, not clove plus an agent suffix.
daffodil|The flower name is a whole borrowed form; its syllables are not meaningful English parts.
holly|The plant noun is not an adjective made from holl plus y.
ivy|The climbing-plant noun is one base, not iv plus y.
lily|The flower noun is one base with no adverbial -ly ending.
petal|The flower-part noun is one borrowed base, not pet plus -al.
vine|The climbing-plant noun is a single base.
fin|The swimming body-part noun is one stem.
hoof|The singular animal-foot covering is kept in its exact base form.
hedge|The row-of-bushes noun is one base.
casserole|The cooking-dish noun is a whole borrowed form, not a modern casserole component split.
lantern|The portable-light noun is one modern stem.
ladle|The serving-tool noun is one stem; le is not independently meaningful here.
colander|The draining-tool name does not contain a modern coland verb with instrument -er.
spatula|The utensil name is a whole borrowed base; its syllables are not English components.
tongs|The gripping-tool name is a lexical plural; a fabricated singular tong is not taught as an interchangeable utensil.
saucer|The cup-supporting dish is retained whole. Its historical condiment-container sense does not make this picture an agent of saucing.|mw-saucer
vase|The flower-container noun is a whole base.
certificate|The document noun is a whole borrowed base in this sense; no free certifi stem is invented.
crumple|The paper-wrinkling verb is kept whole; it has no current crump base meaning the same action.
crush|The compression verb is an uninflected single stem.
crouch|The low-bending verb is one base.
escape|The getting-away verb is retained whole rather than dividing it at a syllable boundary.
flip|The turning action is one uninflected base.
plow|The soil-turning verb keeps its original US spelling and has no affix.
polish|The coating action is one base, not an adjective with -ish and not the national-language name.
prop|The supporting action is one stem, distinct from a shortened property noun.
smear|The uneven-spreading verb is one lexical base.
squeak|The sound-making verb is a single stem.
squirt|The liquid-jet verb is one base with no meaningful ending to detach.
strain|The separating-food verb is one stem, distinct from the injury noun.
vote|The ballot-choice verb is a single base.
carve|The shaping action is one stem; its e is a spelling letter, not an affix.
chop|The cutting action is one uninflected stem.
dip|The brief-immersion action is one stem.
dribble|The ball-moving verb is retained whole rather than teaching drib as a current football action.
sign|The hand-language verb is one base, without an ending.
skid|The uncontrolled-sliding verb is one stem.
stamp|The firm-footstep verb is one base, distinct from the postal noun.
concentrate|The attention verb is retained whole; concentrate is the meaningful current base, not con plus a fabricated centrate action.
fancy|The decorative adjective is a lexical whole form; a historical shortening does not supply a current fanc root.
extra|The additional-amount word is a whole form in this entry, rather than a prefix awaiting a base.
serene|The calm adjective is one borrowed base without an English ending.
brain|The body-organ noun is a single stem.
tuna|The fish noun is one whole base; a is not an inflection here.
chestnut|The nut name is retained whole because chest is an opaque historical plant element, not the body or storage sense of chest.|mw-chestnut
chili|The pepper name is a borrowed whole form and preserves the stored regional spelling.
cranberry|The fruit name has a historical crane relation, but cran is not a free modern base meaning crane; the entry is kept whole rather than assigning it a false current meaning.|mw-cranberry
cable|The wire-connection noun is one base, not c plus -able.
date|The palm-fruit noun is one stem and is distinct from the calendar sense.
macaroni|The pasta name is a whole borrowed form; its source-language ending is not a current English plural here.
mayonnaise|The sauce name is a whole lexical base rather than a syllable assembly.
kebab|The skewered-food name is one borrowed base.
tart|The pastry noun is one base, distinct from the sharp-tasting adjective.
chandelier|The light-fixture name is borrowed whole, not an English agent derived from chandeli.
chimney|The smoke-passage noun is one base, not chim plus ney.
dresser|The cabinet sense is kept whole; the dictionary separates furniture from a person who dresses, and that agent meaning must not replace this one.|mw-dresser
clamp|The holding-tool noun is a single base.
chisel|The cutting-tool noun is one stem; el is not a meaningful current suffix here.
drill|The hole-making tool noun is one base.
hoe|The gardening-tool noun is one stem.
saw|The cutting-tool noun is a whole base, distinct from the past form of see.
varnish|The protective-coating noun is one base; its final ish is not an adjective suffix.
visor|The face-protection noun is a borrowed base, not a person who vises.
medicine|The treatment-substance noun is kept whole; cine is not a current medicine suffix.
plaster|The wound-covering sense is a whole borrowed base, not an instrument derived from plast.
moped|The established vehicle blend is retained whole; motor and pedal are not inserted as independent surface morphemes.
lift|The elevator noun is one base, with no overt derivational affix.
socket|The electrical connection noun is a whole base; sock plus et would evoke the wrong meaning.
stereo|The audio-system clipping is retained whole, rather than treating the final o as a suffix.
design|The planning verb is one lexical base; de- plus the hand-language sign sense would be misleading.
improve|The making-better verb is one current base; im- is not negation of prove.
identify|The recognizing verb is retained whole; no free ident word is invented for this learner analysis.
expect|The anticipation verb is one current base; pect is not fabricated as an independent learner word.
possible|The ability adjective is kept whole; there is no current English poss base to which a learner can attach -ible.
confident|The self-assured adjective is a lexical stem in this sense; confide meaning tell a secret is not its present compositional base.
rare|The infrequency adjective is one base.
local|The nearby-area adjective is kept whole; loc is not presented as a free current word for a place.
opinion|The belief noun is retained whole; an opin stem and productive ion operation are not invented.
cause|The causal-factor noun is one base.
effect|The resulting-change noun is one current stem, distinct from affect.
topic|The discussion-subject noun is a whole borrowed form; top meaning highest part is not its base.
detail|The individual-feature noun is one base; tail is not a component in this sense.
energy|The scientific noun is a whole current base, not ener plus an adjectival y.
habitat|The living-place noun is a whole borrowed form, not habit plus a modern at suffix.
temperature|The heat-measurement noun is kept whole; a temper mood meaning would misidentify its scientific sense.
experiment|The planned-test noun is one current base; there is no free experi verb that takes -ment.
progress|The goal-directed movement noun is one current stem; gress is not taught as an independent word.
respect|The consideration noun is one current base, not re- plus a spect word.
thousand|The numeral is a lexical whole form, not thou plus sand.
`;
  const compounds = [
    ['spaceship', [c('space'), c('ship')], 'The spacecraft is a ship for space; both constituent nouns retain the intended senses.'],
    ['seagull', [c('sea'), c('part.gull.bird', 'gull')], 'The coastal bird name combines the sea setting and the gull bird noun.'],
    ['beehive', [c('bee'), c('part.hive.bee-home', 'hive')], 'The insect dwelling combines bee with the hive dwelling noun.'],
    ['lampshade', [c('lamp'), c('part.shade.light-screen', 'shade')], 'The cover shades a lamp; shade is the light-screen sense.'],
    ['clipboard', [c('part.clip.fastener', 'clip'), c('part.board.flat-support', 'board')], 'The paper support is a board equipped with a clip.'],
    ['paperclip', [c('paper'), c('part.clip.fastener', 'clip')], 'The wire fastener combines the paper material with the clip implement.'],
    ['worksheet', [c('part.work.exercise', 'work'), c('part.sheet.paper', 'sheet')], 'The learning page is a sheet for work or exercises, preserving both noun meanings.'],
    ['daydream', [c('day'), c('part.dream.imagination', 'dream')], 'The waking-imagination verb transparently combines day and dream.'],
    ['download', [c('down'), c('part.load.data-transfer', 'load')], 'The computer verb combines directional down with the current data-transfer load base; it is not a physical weight sense.'],
    ['headboard', [c('part.head.bed-end', 'head'), c('part.board.flat-support', 'board')], 'The furniture board stands at the head end of a bed; the base sense is specified.'],
    ['briefcase', [c('part.brief.document', 'brief'), c('part.case.container', 'case')], 'The case carries papers or briefs; brief is the document noun, not the short-duration adjective.'],
    ['tracksuit', [c('part.track.running', 'track'), c('part.suit.clothing', 'suit')], 'The exercise outfit combines the athletics-track sense with a suit of clothes.'],
    ['sweatshirt', [c('part.sweat.perspiration', 'sweat'), c('shirt')], 'The clothing compound combines perspiration with shirt and keeps its lexical garment meaning.'],
    ['headache', [c('head'), c('part.ache.pain', 'ache')], 'The pain noun locates an ache in the head.'],
    ['toothache', [c('tooth'), c('part.ache.pain', 'ache')], 'The pain noun locates an ache in a tooth.'],
    ['homepage', [c('part.home.starting-place', 'home'), c('part.page.web-document', 'page')], 'The website starting page uses the established digital senses of home and page.'],
    ['inbox', [c('in'), c('part.box.message-container', 'box')], 'The incoming-message container retains the directional in and metaphorical box components.'],
    ['outbox', [c('out'), c('part.box.message-container', 'box')], 'The outgoing-message container combines out with the same message-container sense of box.'],
    ['webcam', [c('part.web.internet', 'web'), c('part.cam.camera-clipping', 'cam')], 'The network camera combines web with the established cam clipping; no letters are invented.'],
    ['software', [c('part.soft.nonphysical-computing', 'soft'), c('part.ware.products', 'ware')], 'The established computing compound distinguishes nonphysical programs from hardware; ware carries the products sense.'],
    ['network', [c('part.net.connections', 'net'), c('part.work.constructed-system', 'work')], 'The connected-computer noun uses the net of connections and constructed-system work senses.']
  ];
  const derivatives = [
    ['astronaut', [{canonical_id:'english.combining.astro.stars',canonical:'astro-',surface:'astro',type:'combining_form'}, {canonical_id:'english.combining.naut.traveller',canonical:'-naut',surface:'naut',type:'combining_form'}], 'The attested modern formation combines the space-related astro- with -naut, a traveller element; both are typed as combining forms, not free words.', 'astro-plus-naut', ['mw-astronaut']],
    ['seedling', [stem('seed','seed'), affix('ling.young-small','-ling','ling')], 'The young plant is a seed-derived plant with diminutive -ling; ling is not treated as a free plant word.', 'seed-plus-ling', ['mw-seedling']],
    ['whiskers', [stem('part.whisker.animal-hair','whisker'), plural()], 'The sensitive facial hairs use the current singular whisker plus plural -s; whisker is not further reduced to a misleading whisking agent.', 'whisker-plus-plural-s'],
    ['prickles', [stem('part.prickle.sharp-point','prickle'), plural()], 'The sharp points use the current singular prickle plus plural -s.', 'prickle-plus-plural-s'],
    ['curtains', [stem('part.curtain.window-cover','curtain'), plural()], 'The window coverings use curtain plus the regular plural ending.', 'curtain-plus-plural-s'],
    ['dishwasher', [stem('part.dish.tableware','dish'), stem('wash','wash'), er()], 'Wash plus instrument -er forms washer, then dish specifies what the appliance washes.', 'dish-plus-derived-washer', [], [
      {id:'washer',left:'part2',right:'part3',surface:'washer',rule:'wash-plus-instrument-er',break_offsets:[]},
      {id:'whole',left:'part1',right:'washer',surface:'dishwasher',rule:'dish-plus-washer',break_offsets:[]}
    ]],
    ['headphones', [stem('head','head'), stem('part.phone.audio-receiver','phone'), plural()], 'The listening device has head and phone receiver components and an overt plural ending; the exact whole device name remains headphones.', 'head-phone-plural', [], [
      {id:'headphone',left:'part1',right:'part2',surface:'headphone',rule:'head-plus-phone-receiver',break_offsets:[]},
      {id:'whole',left:'headphone',right:'part3',surface:'headphones',rule:'headphone-plus-plural-s',break_offsets:[]}
    ]],
    ['locker', [stem('part.lock.secure','lock'), er()], 'The storage compartment locks; the instrument/place noun is related to the current lock verb.', 'lock-plus-er'],
    ['stapler', [stem('part.staple.fasten','staple'), er()], 'The fastener is an instrument for stapling; the exact output shares one final e.', 'staple-plus-er-final-e-sharing'],
    ['rewind', [pref('re.back','re-','re'), stem('part.wind.recording','wind')], 'The recording action winds back; the base is the winding verb, not moving air.', 're-back-plus-wind'],
    ['flexible', [stem('part.flex.bend','flex'), affix('ible.capable','-ible','ible')], 'The bendable adjective retains the current flex verb and the established -ible capability suffix.', 'flex-plus-ible', ['mw-flexible']],
    ['salty', [stem('salt','salt'), y()], 'The tasting-of-salt adjective combines salt and adjectival -y.', 'salt-plus-y'],
    ['messy', [stem('part.mess.disorder','mess'), y()], 'The untidy adjective contains the disorder noun mess and -y.', 'mess-plus-y'],
    ['disgusted', [stem('part.disgust.revulsion','disgust'), ed()], 'The feeling adjective retains the current disgust base and participial -ed; gust meaning wind is not substituted.', 'disgust-plus-participial-ed'],
    ['stuffing', [stem('part.stuff.fill','stuff'), affix('ing.result-noun','-ing','ing')], 'The food filling is the material used to stuff food; the -ing noun is not described as a progressive tense.', 'stuff-plus-result-ing'],
    ['masher', [stem('part.mash.crush-food','mash'), er()], 'The kitchen tool mashes food, with instrument-forming -er.', 'mash-plus-instrument-er'],
    ['steamer', [stem('part.steam.cook','steam'), er()], 'The appliance steams food; -er forms the cooking instrument.', 'steam-plus-instrument-er'],
    ['shepherd', [stem('sheep','sheep'), stem('part.herd.herdsman','herd')], 'The sheep-tender noun retains the documented sheep and herd keeper relation. Its contracted shep spelling is individually authored, not a general vowel rule.', 'sheep-plus-herd-contracted-ee', ['mw-shepherd']],
    ['visitor', [stem('part.visit.see-someone','visit'), affix('or.agent','-or','or')], 'The person visits; the agent suffix is -or rather than -er.', 'visit-plus-agent-or'],
    ['attachment', [stem('part.attach.connect','attach'), affix('ment.result','-ment','ment')], 'The email file is something attached; -ment gives the result noun while the digital sense stays explicit.', 'attach-plus-result-ment'],
    ['charger', [stem('part.charge.battery','charge'), er()], 'The device charges batteries; its charge base is electrical, not a fee, and the exact output shares final e.', 'charge-plus-er-final-e-sharing'],
    ['predict', [pref('pre.before','pre-','pre'), {canonical_id:'english.root.dict.say',canonical:'dict',surface:'dict',type:'root'}], 'The before-saying formation retains pre- and the bound say root dict; dict is explicitly a bound root rather than a free verb.', 'pre-plus-bound-dict', ['mw-predict']],
    ['disappointed', [stem('part.disappoint.let-down','disappoint'), ed()], 'The disappointed feeling relates to the current disappoint verb and participial -ed; appointing to a job is not its base sense.', 'disappoint-plus-participial-ed'],
    ['creative', [stem('part.create.make','create'), affix('ive.adjective','-ive','ive')], 'The adjective relates to creating, with -ive and the explicitly authored loss of final e.', 'create-plus-ive-final-e-loss'],
    ['solution', [stem('part.solve.problem','solve'), affix('tion.result','-tion','tion')], 'The problem answer belongs to the solve family. The exact solution spelling records the Latinate solu allomorph rather than guessing a regular concatenation.', 'solve-plus-tion-authored-allomorph', ['mw-solution']],
    ['environment', [stem('part.environ.surround','environ'), affix('ment.result','-ment','ment')], 'The surrounding conditions relate to the attested surround verb environ and nominal -ment; the rare base is explicitly documented.', 'environ-plus-ment', ['mw-environ']],
    ['imagination', [stem('part.imagine.form-mental-picture','imagine'), affix('ation.faculty','-ation','ation')], 'The faculty for imagining retains imagine and nominal -ation, with the final e removed in the exact authored output.', 'imagine-plus-ation-final-e-loss', ['mw-imagination']]
  ];
  const sourceNotes = {
    astronaut:'The entry explicitly gives astro- and -naut and the modern space-traveller sense.',
    shepherd:'The sheep-tender sense and historical sheep plus herd keeper components support the exact contracted spelling.',
    cranberry:'The source records a historical crane relation, not a free modern English cran stem.',
    saucer:'The current cup-supporting dish and historical sauce-container meanings are distinct.',
    hippopotamus:'The entry identifies a Latin borrowing of a Greek river-and-horse name; no free potamus base is asserted.',
    seedling:'The source confirms the young plant sense used with the diminutive analysis.',
    dresser:'The separate furniture and one-who-dresses entries prevent selecting the wrong agent sense.',
    flexible:'The definition relates flexible to flexing; the history identifies the -ible suffix.',
    solution:'The solving-result sense and solvere family support an explicitly authored base allomorph.',
    imagination:'The history connects the action noun to imagining; the current mental-picture sense is preserved.',
    chestnut:'The history traces chesten to a plant name; modern body chest is not its component sense.',
    retire:'The source traces a withdrawal verb rather than a repeated-fatigue construction.',
    predict:'The entry explicitly connects pre- with the say root of Latin dicere and dict-.',
    reindeer:'The historical first element is an animal name, not a modern harness rein.',
    environ:'The source confirms the current, less common surround verb underlying environment.'
  };
  const sources = Object.fromEntries(Object.entries(sourceNotes).map(([id,evidence]) => [`mw-${id}`, {title:`Merriam-Webster: ${id}`,author:'Merriam-Webster editors',url:`https://www.merriam-webster.com/dictionary/${id}`,consulted:DATE,evidence}]));
  // These named withdrawals supersede the removed whole-form decisions.
  const pending = {
  "suggest": "Reopened after new term-specific evidence: The sub-/gerere family and suggestus are documented. Hold while the sug-/gest allomorphs and the furnish/propose semantic development are checked as teaching units; the old whole-form justification cannot be based on missing free sug or gest words.",
  "retire": "Reopened after new term-specific evidence: New consultation establishes re- plus French tirer draw. Hold the prior whole-form proposal until historical tir/tire draw and career withdrawal are explicitly assessed. The unrelated English fatigue verb cannot serve as the component, but that does not make the word morphologically indivisible."
};
  derivatives.push(...[
  [
    "attract",
    [
      {
        "id": "p1",
        "canonical_id": "english.affix.ad.toward",
        "type": "prefix",
        "canonical": "ad-",
        "surface": "at",
        "break_offsets": []
      },
      {
        "id": "p2",
        "canonical_id": "english.root.tract.pull",
        "type": "root",
        "canonical": "tract",
        "surface": "tract",
        "break_offsets": []
      }
    ],
    "The current drawing-closer or attention-drawing sense belongs to the inherited ad-/at- plus tract pull family. Newly consulted attract/subtract histories and the ad- allomorph entry support the exact two-part graph. Tract means the pull root here, not a land area. Whole-word meaning remains authoritative; literal historical glosses do not replace it.",
    "authored-ad-at-allomorph-plus-tract",
    [
      "mw-attract-new",
      "mw-subtract-new",
      "mw-ad-prefix-new",
      "anderson-2e-roots-new"
    ],
    [
      {
        "id": "whole",
        "left": "p1",
        "right": "p2",
        "surface": "attract",
        "rule": "authored-ad-at-allomorph-plus-tract",
        "break_offsets": []
      }
    ]
  ],
  [
    "include",
    [
      {
        "id": "p1",
        "canonical_id": "english.affix.in.inside",
        "type": "prefix",
        "canonical": "in-",
        "surface": "in",
        "break_offsets": []
      },
      {
        "id": "p2",
        "canonical_id": "english.root.clude.close",
        "type": "root",
        "canonical": "clude",
        "surface": "clude",
        "break_offsets": []
      }
    ],
    "The current membership sense belongs to the inherited in- plus clude close/enclose family corroborated by include and exclude. This in- means inside, not negative in-. Clude is bound; the whole meaning does not require physically enclosing a person or object. Historical component glosses do not replace the current membership meaning.",
    "authored-in-plus-bound-clude",
    [
      "mw-include-new",
      "mw-exclude-new",
      "anderson-2e-roots-new"
    ],
    [
      {
        "id": "whole",
        "left": "p1",
        "right": "p2",
        "surface": "include",
        "rule": "authored-in-plus-bound-clude",
        "break_offsets": []
      }
    ]
  ]
]);
  Object.assign(sources, {
  "mw-attract-new": {
    "title": "Merriam-Webster: attract",
    "author": "Merriam-Webster editors",
    "url": "https://www.merriam-webster.com/dictionary/attract",
    "consulted": "2026-10-16",
    "consultation_status": "newly_consulted_page_body_in_revision_pass",
    "sections": "Word History and relevant current sense",
    "evidence": "The attention-drawing sense is explicit. The history identifies Latin ad- plus trahere and the participial form attractus, supporting at- plus the tract pull family."
  },
  "mw-subtract-new": {
    "title": "Merriam-Webster: subtract",
    "author": "Merriam-Webster editors",
    "url": "https://www.merriam-webster.com/dictionary/subtract",
    "consulted": "2026-10-16",
    "consultation_status": "newly_consulted_page_body_in_revision_pass",
    "sections": "Word History and relevant current sense",
    "evidence": "The history gives subtractus from subtrahere, with sub- and the same trahere draw base. This confirms the shared historical tract identity with attract."
  },
  "mw-ad-prefix-new": {
    "title": "Merriam-Webster: ad-",
    "author": "Merriam-Webster editors",
    "url": "https://www.merriam-webster.com/dictionary/ad-",
    "consulted": "2026-10-16",
    "consultation_status": "newly_consulted_page_body_in_revision_pass",
    "sections": "Prefix entry and listed variants",
    "evidence": "The prefix means to/toward and explicitly has an at- variant before t. This supports ad-/at in attract and ad- in adapt."
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
  "mw-include-new": {
    "title": "Merriam-Webster: include",
    "author": "Merriam-Webster editors",
    "url": "https://www.merriam-webster.com/dictionary/include",
    "consulted": "2026-10-16",
    "consultation_status": "newly_consulted_page_body_in_revision_pass",
    "sections": "Word History and relevant current sense",
    "evidence": "The history identifies Latin in- plus claudere, close. The current membership sense and include spelling support the inherited clude realization rather than a free English word."
  },
  "mw-exclude-new": {
    "title": "Merriam-Webster: exclude",
    "author": "Merriam-Webster editors",
    "url": "https://www.merriam-webster.com/dictionary/exclude",
    "consulted": "2026-10-16",
    "consultation_status": "newly_consulted_page_body_in_revision_pass",
    "sections": "Word History and relevant current sense",
    "evidence": "The companion history identifies ex- plus the same Latin claudere close base. The include/exclude family supports a shared bound clude realization."
  },
  "mw-suggest-new": {
    "title": "Merriam-Webster: suggest",
    "author": "Merriam-Webster editors",
    "url": "https://www.merriam-webster.com/dictionary/suggest",
    "consulted": "2026-10-16",
    "consultation_status": "newly_consulted_page_body_in_revision_pass",
    "sections": "Word History and relevant current sense",
    "evidence": "The proposing sense is explicit. The history identifies sub- plus gerere carry via the participial form suggestus. The sug-/gest realization is a valid research lead, not evidence for unrelated modern sug or gest words."
  },
  "mw-retire-new": {
    "title": "Merriam-Webster: retire",
    "author": "Merriam-Webster editors",
    "url": "https://www.merriam-webster.com/dictionary/retire",
    "consulted": "2026-10-16",
    "consultation_status": "newly_consulted_page_body_in_revision_pass",
    "sections": "Word History and relevant current sense",
    "evidence": "The history identifies French re- plus tirer draw. The career-ending sense must not be analyzed using modern tire fatigue; a draw-root proposal needs explicit treatment of the historical tire/tir realization."
  }
});
// Nine-hold proposal: these decisions supersede the named pending reviews only.
  delete pending["suggest"];
  delete pending["retire"];
  derivatives.push(...[
  [
    "suggest",
    [
      {
        "canonical_id": "english.affix.sub.under",
        "type": "prefix",
        "canonical": "sub-",
        "surface": "sug"
      },
      {
        "canonical_id": "english.root.gest.carry",
        "type": "root",
        "canonical": "gest",
        "surface": "gest"
      }
    ],
    "Collins explicitly records sug- as the before-g allomorph of sub- in suggest. The suggest/ingest histories corroborate gest as the participial realization of the carry/bear family. Sub.under is a historical identity here, not a claim that proposing an idea literally means carrying something underneath. The dictionary traces the furnishing/bringing-forward development into the selected proposal sense. The graph neither selects the modern sales acronym sug nor treats the unrelated noun gest as its base.",
    "authored-sub-sug-allomorph-plus-gest-carry",
    [
      "mw-suggest-new",
      "etym-suggest-hold9",
      "etym-sub-hold9",
      "collins-sug-hold9",
      "mw-ingest-hold9",
      "anderson-2e-roots-new"
    ],
    [
      {
        "id": "whole",
        "left": "part1",
        "right": "part2",
        "rule": "authored-sub-sug-allomorph-plus-gest-carry",
        "surface": "suggest",
        "break_offsets": []
      }
    ]
  ],
  [
    "retire",
    [
      {
        "canonical_id": "english.affix.re.back",
        "type": "prefix",
        "canonical": "re-",
        "surface": "re"
      },
      {
        "canonical_id": "english.root.tir.draw",
        "type": "root",
        "canonical": "tir",
        "surface": "tire"
      }
    ],
    "The dictionary history explicitly traces retire through French re- back and tirer draw into withdrawal from employment. The graph uses canonical tir.draw with the inherited English tire surface; final e belongs to that realization. This is not the Old English fatigue verb tire, the wheel noun, or a productive instruction to become tired again. The selected retirement sense remains the complete definition. Bound historical tir is legitimate even without a current free drawing verb of that spelling, and its canonical identity remains separate from all fatigue and equipment senses.",
    "authored-re-back-plus-tir-draw-tire-realization",
    [
      "mw-retire-new",
      "mw-re-prefix-new",
      "etym-retire-hold9",
      "etym-tire-hold9",
      "anderson-2e-roots-new"
    ],
    [
      {
        "id": "whole",
        "left": "part1",
        "right": "part2",
        "rule": "authored-re-back-plus-tir-draw-tire-realization",
        "surface": "retire",
        "break_offsets": []
      }
    ]
  ]
]);
  Object.assign(sources, {
  "mw-suggest-new": {
    "title": "Merriam-Webster: suggest",
    "author": "Merriam-Webster editors",
    "url": "https://www.merriam-webster.com/dictionary/suggest",
    "consulted": "2026-10-16",
    "consultation_status": "newly_consulted_page_body_in_revision_pass",
    "sections": "Word History and relevant current sense",
    "evidence": "The proposing sense is explicit. The history identifies sub- plus gerere carry via the participial form suggestus. The sug-/gest realization is a valid research lead, not evidence for unrelated modern sug or gest words."
  },
  "etym-suggest-hold9": {
    "title": "Online Etymology Dictionary: suggest",
    "author": "Douglas Harper",
    "url": "https://www.etymonline.com/word/suggest",
    "consulted": "2026-10-16",
    "consultation_status": "newly_consulted_page_body_in_nine_hold_pass",
    "sections": "Entry history and linked family evidence",
    "evidence": "The history and linked suggestion discussion give sub- with gerere through suggestus. They trace the transition from supplying or bringing forward to proposing an idea; the modern proposal sense is not a literal carrying task."
  },
  "etym-sub-hold9": {
    "title": "Online Etymology Dictionary: sub-",
    "author": "Douglas Harper",
    "url": "https://www.etymonline.com/word/sub-",
    "consulted": "2026-10-16",
    "consultation_status": "newly_consulted_page_body_in_nine_hold_pass",
    "sections": "Entry history and linked family evidence",
    "evidence": "Latin sub- assimilates to following g and other consonants. The entry explicitly includes suggest among borrowed words whose historical prefix contribution is no longer transparent."
  },
  "collins-sug-hold9": {
    "title": "Collins: sug-",
    "author": "Webster's New World College Dictionary editors; HarperCollins",
    "url": "https://www.collinsdictionary.com/us/dictionary/english/sug",
    "consulted": "2026-10-16",
    "consultation_status": "newly_consulted_page_body_in_nine_hold_pass",
    "sections": "American English prefix entry",
    "evidence": "The entry explicitly identifies sug- as the before-g form of sub- and uses suggest as its example. The unrelated sales acronym is not selected."
  },
  "mw-ingest-hold9": {
    "title": "Merriam-Webster: ingest",
    "author": "Merriam-Webster editors",
    "url": "https://www.merriam-webster.com/dictionary/ingest",
    "consulted": "2026-10-16",
    "consultation_status": "newly_consulted_page_body_in_nine_hold_pass",
    "sections": "Relevant sense and Word History",
    "evidence": "The history gives ingestus from in- plus gerere bear/carry, corroborating the recurring gest realization independently of the unrelated modern noun gest."
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
  "mw-retire-new": {
    "title": "Merriam-Webster: retire",
    "author": "Merriam-Webster editors",
    "url": "https://www.merriam-webster.com/dictionary/retire",
    "consulted": "2026-10-16",
    "consultation_status": "newly_consulted_page_body_in_revision_pass",
    "sections": "Word History and relevant current sense",
    "evidence": "The history identifies French re- plus tirer draw. The career-ending sense must not be analyzed using modern tire fatigue; a draw-root proposal needs explicit treatment of the historical tire/tir realization."
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
  "etym-retire-hold9": {
    "title": "Online Etymology Dictionary: retire",
    "author": "Douglas Harper",
    "url": "https://www.etymonline.com/word/retire",
    "consulted": "2026-10-16",
    "consultation_status": "newly_consulted_page_body_in_nine_hold_pass",
    "sections": "Entry history and linked family evidence",
    "evidence": "The entry gives French re- back plus tirer draw and explicitly traces withdrawal from employment as an extension of drawing back. It supports the career sense without substituting English tire weary."
  },
  "etym-tire-hold9": {
    "title": "Online Etymology Dictionary: tire",
    "author": "Douglas Harper",
    "url": "https://www.etymonline.com/word/tire",
    "consulted": "2026-10-16",
    "consultation_status": "newly_consulted_page_body_in_nine_hold_pass",
    "sections": "Entry history and linked family evidence",
    "evidence": "The fatigue verb comes from Old English teorian, a different history from the French drawing element in retire. The wheel noun has a separate equipment/attire history and is also excluded."
  }
});
  return {atoms, compounds, derivatives, sources, pending};
};
