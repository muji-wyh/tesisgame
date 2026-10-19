// Individual decisions for the seven-year-old Growth cohort.
module.exports = ({stem, affix, DATE}) => {
  const c = (id, text = id) => stem(id, text, 'compound');
  const er = () => affix('er.agent-instrument', '-er', 'er');
  const y = () => affix('y.adjective', '-y', 'y');
  const ed = () => affix('ed.participle', '-ed', 'ed');
  const plural = () => affix('s.plural', '-s', 's');
  const prefix = (id, canonical, surface) => ({canonical_id: `english.affix.${id}`, canonical, surface, type: 'prefix'});
  const atoms = `
explore|Keep the current explore stem whole at this teaching depth after examining, rather than denying, its historical complexity. The new history offers back-formation from exploration or borrowing and records competing cry-out and flow explanations of the deeper element. The stable contemporary family is explore/explorer/exploration; neither disputed historical account supplies a uniquely settled ex-plus-root lesson for the selected examining/discovery sense. This deliberate whole-stem exposure does not claim that bound roots must be free words or that explore has no etymological structure. A future explicit historical-family lesson may revisit it with the competing account retained.|mw-explore-new,etym-explore-hold9,anderson-2e-roots-new
planet|The astronomical-body noun is one borrowed English base.
ring|The circular-object noun is one stem, not r plus ing.
watch|The timepiece noun is one base, distinct from its related observation verb.
crown|The headwear noun is one base.
ankle|The leg-joint noun has no smaller contemporary components.
trumpet|The instrument name is lexicalized; a modern diminutive of trump is not taught here.
beetle|The insect noun is one base, not beet plus le.
radish|The vegetable name is not rad plus the approximating suffix -ish.
avocado|The fruit noun is a whole English loanword.
desert|The dry-land noun is one lexical stem; de is not a reversible-action prefix here.
canoe|The watercraft noun is one borrowed base.
ferry|The crossing-vessel noun is one base, not ferr plus adjectival y.
domino|The game-piece noun is one borrowed base.
frisbee|The flying-disc name is lexicalized from a trade name, not fris plus bee.
sled|The snow-vehicle noun is one base.
seesaw|The playground name is lexicalized reduplication; it does not combine the visual verb see with its past saw as two object meanings.
kettle|The boiling-vessel noun is one modern base.
ladder|The climbing-apparatus noun is not ladd plus an agent ending.
bucket|The container noun is lexicalized; buck is not an animal component of this sense.
broom|The cleaning-tool noun is one base, not b plus room.
tulip|The flower name is a whole loanword.
daisy|The flower name stays whole; the historical day-eye contraction is not a current spelled join.
fern|The plant noun is one base.
crocodile|The reptile noun is a whole English loanword, not croco plus dile.
shampoo|The washing-substance noun is one borrowed base.
umbrella|The weather-cover noun is a whole English loanword; a foreign diminutive is not an English operation.
party|The celebration noun is one modern base, not part plus adjective -y.
caterpillar|The larval-insect noun is lexicalized; pillar is not an architectural component of its meaning.
goose|The waterbird noun is its whole singular form.
lizard|The reptile noun is one borrowed base.
nest|The bird-home noun is one stem.
feather|The bird-covering noun is not feath plus an agent ending.
bud|The unopened-flower noun is one base.
bush|The low-plant noun is one stem.
branch|The woody-tree-part noun is one base.
log|The cut-wood noun is one stem.
vegetable|The food-plant noun is lexicalized; it is not veg plus the productive ability suffix -able.
cereal|The grain-food noun is a whole borrowed base in this sense.
sausage|The prepared-meat noun is one borrowed base, not saus plus an English age component.
spaghetti|The pasta noun is a whole English loanword; its Italian ending is not an English plural suffix.
answer|The replying verb is one base, not answ plus an agent ending.
collect|The gathering verb is a lexical base; no free lect or productive col component is posed here.
copy|The reproducing verb is an uninflected base, not cop plus adjectival y.
deliver|The transporting verb is lexicalized; it is not removal of the body organ liver.
dive|The plunging action is an uninflected base.
drip|The drop-falling action is a single verb stem.
fry|The oil-cooking action is an uninflected base.
grab|The quick-taking action is one verb base.
grate|The food-shredding action is an uninflected base.
grill|The heat-cooking action is one verb base.
guess|The uncertain-answer action is one base; ss is not a suffix.
heat|The warming action is an uninflected base.
hike|The trail-walking action is an uninflected base.
jog|The slow-running action is one verb stem.
join|The group-entering action is an uninflected base.
melt|The becoming-liquid action is one verb base.
mend|The repairing action is an uninflected stem.
pack|The luggage-filling action is an uninflected verb base.
peel|The skin-removing action is one verb base.
protect|The guarding verb is lexicalized; a free tect base is not invented for this cohort.
queue|The line-waiting verb is one whole English loanword.
relax|The resting verb is lexicalized; it does not mean making someone lax again.
remove|The taking-away verb is lexicalized; treating it as moving again would teach the wrong selected sense.
rinse|The brief-washing action is one uninflected verb base.
scoop|The curved-tool lifting action is one verb base.
scrub|The vigorous-cleaning action is an uninflected base.
serve|The food-giving action is one uninflected base.
skate|The skate-gliding action is an uninflected verb.
ski|The snow-sliding action is a whole English loanword.
sneak|The unnoticed-moving action is an uninflected base.
sort|The grouping action is an uninflected base.
spill|The accidental-pouring action is one verb base.
spray|The droplet-sending action is one base.
spread|The surface-covering action is an uninflected verb base.
sprinkle|The small-piece scattering verb is lexicalized; no independent sprink base is required.
squash|The flattening verb is one stem, distinct from the vegetable noun.
study|The learning action is an uninflected base, not stud plus adjective -y.
tear|The pulling-apart action is one base, distinct from the eye-liquid noun.
trace|The line-following action is one base.
trim|The slight-cutting action is one verb base.
type|The keyboard-writing action is one uninflected base.
visit|The person-seeing action is one modern base.
weigh|The weight-measuring action is one uninflected stem.
whisk|The food-beating verb is one base.
wiggle|The small-twisting verb is lexicalized; no invented wig plus gle relation is taught.
wrap|The paper-covering action is one uninflected base.
slippery|The surface adjective stays whole. Its attested source is the obsolete adjective slipper plus -y, not the footwear noun slipper or a fictitious -pery ending.|mw-slippery
smooth|The even-surface adjective is one base.
strong|The physical-strength adjective is one stem.
weak|The low-strength adjective is one base.
correct|The accurate adjective is a modern lexical base, not cor plus the rectangle element rect-.
ready|The prepared-state adjective has no productive read plus y relation.
whole|The completeness adjective is one stem.
dictionary|The reference-book noun is lexicalized; it is not assigned a generic -ary split into a mismatched diction speaking-style sense.
envelope|The letter-container noun is one borrowed base, not en plus a free velope word.
glitter|The decorative-pieces noun is one base; it is not an agent noun of glitt.
globe|The Earth-model noun is one base.
medal|The award-object noun is one stem.
ribbon|The narrow-fabric noun is one base.
badminton|The sport name is eponymic, not bad plus mint plus on.
cricket|The sport noun is one base, distinct from the insect sense.
golf|The sport name is one base.
tennis|The sport name is a whole modern loanword, without a plural s ending.
gym|The clipped exercise-place noun remains a whole lexical form.
parachute|The canopy noun is a borrowed lexical unit; the current para- professional prefix would give a misleading analysis.
ramp|The sloping-surface noun is one base.
calendar|The date-chart noun is one base, not calend plus an agent ending.
castle|The historic-building noun is one modern base, not cast plus le.
garage|The vehicle-building noun is one borrowed base.
road|The vehicle-route noun is one stem.
minute|The sixty-second unit is a whole noun, distinct from the small-size adjective.
pilot|The aircraft-operator noun is a whole borrowed base.
pupil|The eye-opening noun is one base, distinct from the student sense.
add|The arithmetic-combining action is one base.
first|The irregular ordinal is a whole grammatical form; no separate modern fir base is invented.
second|The ordinal is a whole modern form, distinct from the time-unit noun.
last|The final-position adjective is one base.
next|The immediately-following adjective is a whole lexical form.
exercise|The fitness-action verb is a modern base, not ex plus an independent ercise word.
enter|The going-inside action is one verb base, not ent plus an agent ending.
exit|The leaving action is one whole English verb.
travel|The journeying action is one uninflected base.
beaker|The laboratory-container noun is not an agent of beak.
carton|The food-box noun is lexicalized; it is not cart plus a contemporary -on suffix.
crane|The lifting-machine noun is one stem, distinct from the bird sense.
engine|The power-producing machine noun is one base.
celebrate|The occasion-marking verb is one modern base; celebr is not posed as an independent current word.
order|The goods-requesting verb is one base, not ord plus an agent ending.
drive|The vehicle-controlling action is an uninflected base.
dust|The dirt-removing verb is one base; noun-to-verb conversion adds no spelled suffix.
iron|The clothing-smoothing verb is one base; conversion adds no spelled suffix.
meet|The coming-together action is one base.
plant|The soil-placing verb is one base; conversion adds no spelled suffix.
raise|The lifting action is one uninflected stem.
reach|The extending-toward action is one base.
stroke|The gentle-touching action is an uninflected base.
text|The phone-messaging verb is one base; conversion is not a two-piece spelling join.
toss|The light-throwing action is one verb stem.
work|The effort-giving verb is one base.
bright|The strong-light adjective is one base.
deep|The depth adjective is one base.
shallow|The low-depth adjective is one base, not shall plus a suffix.
thick|The width adjective is one base.
thin|The low-width adjective is one stem.
straight|The uncurved-shape adjective is one base.
busy|The occupied-state adjective has no bus plus y relation.
throat|The neck-passage noun is one base.
hamster|The rodent name is a whole borrowed noun; it is not ham plus a person-forming suffix.
rat|The rodent noun is one base.
tortoise|The reptile noun is one borrowed base.
turkey|The bird name is lexicalized; the final ey is not a productive suffix.
claw|The pointed-nail noun is one base.
recipe|The cooking-instructions noun is a whole English loanword.
salad|The mixed-vegetable dish noun is one base.
steak|The meat-slice noun is one base.
dairy|The milk-food category is lexicalized; dair is not posed as a contemporary free base.
barbecue|The outdoor-cooker noun is a whole loanword, not bar plus becue.
ceiling|The upper-room-surface noun is lexicalized; the rare historical ceil verb is not turned into an ongoing-action exercise.
rake|The toothed-garden-tool noun is one base.
spade|The digging-tool noun is one base.
trowel|The small-digging-tool noun is one borrowed stem.
string|The thin-cord noun is one stem, not str plus -ing.
nail|The fastening-pin noun is one base, distinct from a body-part sense.
hose|The water-tube noun is one base.
goggles|The protective-eyewear noun is a lexical plural; no singular protective goggle is invented as a pictured object.
chef|The professional-cook noun is one borrowed base.
nurse|The care-worker noun is one base.
aunt|The kinship noun is one base.
future|The coming-time noun is one lexical base, not fut plus ure.
past|The earlier-time noun is a whole lexical form, not an invented pass plus t exercise.
east|The direction noun is one base.
west|The direction noun is one base.
north|The direction noun is one stem.
south|The direction noun is one stem.
hour|The time-unit noun is one base.
month|The calendar-unit noun is one lexical base.
week|The seven-day unit is one stem.
stable|The horse-building noun is one base; it is unrelated to an ability suffix -able.
coach|The bus noun is one base, distinct from the teaching-person sense.
monitor|The screen noun is one lexical base; a modern mon plus itor split is not meaningful.
because|The reason conjunction is lexicalized; it is not the state verb be joined to cause.
if|The conditional conjunction is one functional form.
so|The result conjunction is one functional form.
also|The addition adverb is lexicalized; no contemporary al base is invented.
always|The every-time adverb is lexicalized; it does not present the route noun ways as its current sense.
never|The negative-time adverb is a whole functional form, not a free n plus ever.
understand|The comprehension verb is lexicalized; it does not mean standing underneath something.
remember|The recall verb is lexicalized; it is not making someone a member again.
forget|The failed-recall verb is one modern base; for does not contribute the purpose-preposition meaning here.
hope|The favorable-wishing verb is one stem.
imagine|The mental-picture verb is one modern base; it is not a productive imag plus ine operation.
notice|The awareness verb is a single base, not not plus ice.
describe|The describing verb is lexicalized; de does not reverse the action of a scribe in this sense.
check|The verifying action is one verb stem.
difficult|The effort-demanding adjective is a lexical base; there is no current ficult word for a prefix exercise.
fair|The impartial-treatment adjective is one base.
proud|The achievement-satisfaction adjective is one stem.
curious|The inquisitive adjective is lexicalized; no contemporary curi base is fabricated.
problem|The issue noun is one lexical base.
plan|The intention noun is one base.
team|The cooperating-group noun is one base.
goal|The intended-result noun is one base.
pattern|The arrangement noun is one base.
hundred|The number is a whole modern form; no historical hund plus red exercise is imposed.
enough|The sufficient-quantity determiner is one functional form.
sharp|The cutting-edge adjective is one stem.
menu|The food-list noun is one borrowed base.
money|The currency noun is one lexical base, not mon plus an adjective ending.
world|The Earth-and-people noun is one modern base, not an obsolete wer plus old join.
`;
  const compounds = [
    ['sailboat', [c('part.sail.wind-surface', 'sail'), c('boat')], 'A boat propelled by a sail; the first component is the wind-catching surface.'],
    ['teapot', [c('tea'), c('pot')], 'The pot holds or brews tea; both free nouns preserve their beverage and container senses.'],
    ['hedgehog', [c('hedge'), c('part.hog.animal', 'hog')], 'The conventional animal compound combines hedge habitat with the hog comparison; it does not classify the animal as a pig.'],
    ['toothbrush', [c('tooth'), c('part.brush.tool', 'brush')], 'The brush cleans teeth; the head is the implement noun, not the brushing action.'],
    ['toothpaste', [c('tooth'), c('part.paste.substance', 'paste')], 'The paste is used on teeth; both noun bases retain the intended substance and body-part senses.'],
    ['birthday', [c('birth'), c('part.day.calendar-date', 'day')], 'The yearly calendar date marks a birth; the day component is distinct from the stored daylight-only day sense.'],
    ['milkshake', [c('milk'), c('part.shake.mixing', 'shake')], 'The drink combines milk with the shaking or mixing action; the second sense is not a fear-related shake.'],
    ['laptop', [c('lap'), c('top')], 'The computer name is the conventional lap-top location compound, retaining the body-location sense of lap.'],
    ['baseball', [c('part.base.sport', 'base'), c('ball')], 'The sport uses bases and a ball; base is the playing-field station rather than an unrelated foundation.'],
    ['basketball', [c('part.basket.scoring-target', 'basket'), c('ball')], 'The sport combines the basket scoring target and ball; the basket sense is distinct from the stored woven carrying container.'],
    ['volleyball', [c('part.volley.sport', 'volley'), c('ball')], 'The sport involves volleying a ball; volley is the sporting exchange, not gunfire.'],
    ['weekend', [c('week'), c('end')], 'The selected days occur at the end of a week; both components keep their time meanings.'],
    ['raincoat', [c('rain'), c('coat')], 'A protective coat used in rain; both free bases contribute directly.'],
    ['goldfish', [c('part.gold.color', 'gold'), c('fish')], 'The fish name uses gold as a color modifier; it does not mean a fish made of metal.'],
    ['saucepan', [c('sauce'), c('pan')], 'The deep cooking pan retains the conventional sauce-plus-pan naming relation.'],
    ['tablecloth', [c('table'), c('cloth')], 'A cloth placed over a table; both components match the selected household sense.'],
    ['armchair', [c('part.arm.furniture', 'arm'), c('chair')], 'The chair has side supports called arms; the furniture-support sense is distinguished from the body-part noun.'],
    ['bookcase', [c('book'), c('part.case.container', 'case')], 'The furniture is a case for books; case is the containing structure, not a medical case.'],
    ['fireplace', [c('fire'), c('place')], 'The architectural place holds a fire; the two free bases preserve the selected room feature.'],
    ['wheelbarrow', [c('wheel'), c('part.barrow.cart', 'barrow')], 'The handcart is a wheeled barrow; the cart sense of barrow is distinguished from a burial mound.'],
    ['sunscreen', [c('sun'), c('part.screen.shield', 'screen')], 'The protective substance screens sunlight; screen is the shielding sense, not an electronic display.'],
    ['headband', [c('head'), c('part.band.strip', 'band')], 'The strip is worn around the head; band is a strip, not a music group.'],
    ['passport', [c('part.pass.travel', 'pass'), c('part.port.entry', 'port')], 'The established travel document compound concerns passing through a port; pass is the travel action rather than the permission noun, and the current document meaning is retained.', ['mw-passport']],
    ['motorcycle', [c('motor'), c('part.cycle.vehicle', 'cycle')], 'The vehicle is a motor-powered cycle; cycle has the wheeled-vehicle sense.'],
    ['keyboard', [c('part.key.input', 'key'), c('part.board.panel', 'board')], 'The computer panel bears input keys; those are distinguished from door keys and storage boards.']
  ];
  const derivatives = [
    ['sweater', [stem('sweat', 'sweat'), er()], 'The garment name is derived from sweat with -er, reflecting its original warming purpose; the modern clothing sense is retained.', 'sweat-plus-er-garment', ['mw-sweater']],
    ['glider', [stem('glide', 'glide'), er()], 'The aircraft glides; instrument -er joins glide with one final e in the authored spelling.', 'glide-plus-er-e-sharing'],
    ['unicycle', [prefix('uni.one', 'uni-', 'uni'), {canonical_id: 'english.combining.cycle.wheel', canonical: '-cycle', surface: 'cycle', type: 'combining_form'}], 'The vehicle has one wheel; its attested uni- and -cycle formation is preserved with an explicitly sourced combining form.', 'uni-plus-wheel-cycle', ['mw-unicycle']],
    ['crayons', [stem('crayon', 'crayon'), plural()], 'The drawing items are the regular plural of the existing singular crayon base.', 'crayon-plus-plural-s'],
    ['toaster', [stem('part.toast.action', 'toast'), er()], 'The machine toasts bread; the base is the heating verb rather than the Growth finished-food noun.', 'toast-action-plus-instrument-er'],
    ['grandmother', [prefix('grand.kinship', 'grand-', 'grand'), stem('mother', 'mother')], 'Grand- marks one additional generation in the kinship noun; it is distinct from the impressive-quality adjective grand.', 'grand-kinship-plus-mother'],
    ['grandfather', [prefix('grand.kinship', 'grand-', 'grand'), stem('father', 'father')], 'Grand- adds a generation to father in this specific family relation.', 'grand-kinship-plus-father'],
    ['piglet', [stem('pig', 'pig'), affix('let.small-young', '-let', 'let')], 'The young pig uses the diminutive -let suffix with the current animal base pig.', 'pig-plus-young-let'],
    ['lemonade', [stem('lemon', 'lemon'), affix('ade.drink', '-ade', 'ade')], 'The lemon drink contains the fruit base and beverage-forming -ade, not an unrelated ending inferred from spelling.', 'lemon-plus-drink-ade'],
    ['decorate', [stem('part.decor.adornment', 'decor'), affix('ate.verb', '-ate', 'ate')], 'The verb relates to decor and adornment; -ate makes the action of providing decoration, with the accentless current base decor.', 'decor-plus-verbal-ate', ['mw-decorate']],
    ['recycle', [prefix('re.again', 're-', 're'), stem('part.cycle.process', 'cycle')], 'The materials go through a cycle of use again; re- and the process sense of cycle are meaningful in the selected action.', 're-again-plus-cycle-process'],
    ['return', [prefix('re.back', 're-', 're'), stem('turn', 'turn')], 'The movement-back sense preserves re- meaning back with turn; it does not use the separately identified repetition-only re- sense.', 're-back-plus-turn', ['mw-return']],
    ['sharpen', [stem('sharp', 'sharp'), affix('en.make', '-en', 'en')], 'The action makes something sharp; verbal -en contributes the change of state.', 'sharp-plus-causative-en'],
    ['subtract', [prefix('sub.from-beneath', 'sub-', 'sub'), {canonical_id: 'english.root.tract.pull', canonical: 'tract', surface: 'tract', type: 'root'}], 'The established Latin-derived formation uses sub- and the pulling base tract; the latter is not the land-area noun tract.', 'sub-plus-bound-tract', ['mw-subtract']],
    ['unlock', [prefix('un.reverse', 'un-', 'un'), stem('part.lock.action', 'lock')], 'The action reverses locking; the reversative prefix is distinct from adjectival negation.', 'un-reverse-plus-lock'],
    ['untie', [prefix('un.reverse', 'un-', 'un'), stem('part.tie.action', 'tie')], 'The action reverses tying; the original tie spelling is kept in the current verb.', 'un-reverse-plus-tie'],
    ['worried', [stem('worry', 'worry'), ed()], 'The emotional adjective is the participial form of worry; the exact output changes y to i before -ed.', 'worry-plus-ed-y-to-i'],
    ['surprised', [stem('part.surprise.action', 'surprise'), ed()], 'The adjective is the result-state participle of surprise; the final e is shared in surprised.', 'surprise-plus-ed-e-sharing'],
    ['healthy', [stem('health', 'health'), y()], 'The adjective describes good health; adjectival -y attaches to the complete health stem.', 'health-plus-adjective-y'],
    ['lucky', [stem('luck', 'luck'), y()], 'The good-chance adjective joins luck and adjectival -y.', 'luck-plus-adjective-y'],
    ['noisy', [stem('noise', 'noise'), y()], 'The sound-filled adjective joins noise and -y with final e removed in the exact output.', 'noise-plus-y-e-loss'],
    ['shiny', [stem('shine', 'shine'), y()], 'The light-reflecting adjective relates to shine; the authored output removes its final e.', 'shine-plus-y-e-loss'],
    ['spicy', [stem('spice', 'spice'), y()], 'The hot-flavor adjective joins spice and -y with the final e removed.', 'spice-plus-y-e-loss'],
    ['sticky', [stem('part.stick.adhere', 'stick'), y()], 'The clinging adjective uses the adhering verb stick, not the wooden-stick noun.', 'stick-adhere-plus-y'],
    ['striped', [stem('stripe', 'stripe'), affix('ed.having', '-ed', 'ed')], 'The adjective means having stripes; the possessive -ed ending is distinguished from a tense claim and shares the base final e.', 'stripe-plus-having-ed-e-sharing'],
    ['printer', [stem('print', 'print'), er()], 'The device prints; instrument -er attaches to the current print action.', 'print-plus-instrument-er'],
    ['bowling', [stem('part.bowl.action', 'bowl'), affix('ing.activity', '-ing', 'ing')], 'The sport is the activity of bowling a ball; its verb base is not the food-container noun bowl.', 'bowl-action-plus-activity-ing'],
    ['baker', [stem('bake', 'bake'), er()], 'The person bakes; agent -er joins bake with a shared final e.', 'bake-plus-agent-er-e-sharing'],
    ['dentist', [{canonical_id: 'english.root.dent.tooth', canonical: 'dent', surface: 'dent', type: 'root'}, affix('ist.specialist', '-ist', 'ist')], 'The tooth-care professional uses the attested dental root dent and specialist -ist; the base is not a dent in a surface.', 'dent-tooth-plus-specialist-ist', ['mw-dentist']],
    ['gardener', [stem('part.garden.action', 'garden'), er()], 'The person gardens; the verbal gardening sense receives agent -er.', 'garden-action-plus-agent-er'],
    ['musician', [stem('music', 'music'), affix('ian.practitioner', '-ian', 'ian')], 'The music practitioner combines music and the practitioner suffix -ian.', 'music-plus-practitioner-ian'],
    ['sailor', [stem('part.sail.action', 'sail'), affix('or.agent', '-or', 'or')], 'The ship worker sails; the established agent ending is spelled -or, distinct from -er.', 'sail-action-plus-agent-or'],
    ['singer', [stem('sing', 'sing'), er()], 'The performer sings; agent -er attaches to the current sing base.', 'sing-plus-agent-er'],
    ['broken', [{canonical_id: 'english.stem.break.damage', canonical: 'break', surface: 'break', type: 'stem'}, affix('en.participle', '-en', 'en')], 'The damaged-state adjective is the irregular participle of break; the complete broken output preserves its vowel change.', 'break-plus-participle-en-authored-vowel-change'],
    ['excited', [stem('excite', 'excite'), ed()], 'The emotional adjective is the participial form of excite; the exact output shares final e.', 'excite-plus-ed-e-sharing'],
    ['ingredients', [stem('ingredient', 'ingredient'), plural()], 'The food components are the regular plural of ingredient; the base is not segmented further into a false gradient relation.', 'ingredient-plus-plural-s'],
    ['blender', [stem('blend', 'blend'), er()], 'The kitchen device blends ingredients; instrument -er gives the tool noun.', 'blend-plus-instrument-er'],
    ['grater', [stem('grate', 'grate'), er()], 'The utensil grates food; instrument -er shares the base final e.', 'grate-plus-er-e-sharing'],
    ['peeler', [stem('peel', 'peel'), er()], 'The utensil peels vegetables; the current peel action receives instrument -er.', 'peel-plus-instrument-er'],
    ['sandals', [stem('sandal', 'sandal'), plural()], 'The open shoes are the current singular sandal plus plural -s.', 'sandal-plus-plural-s'],
    ['earrings', [stem('ear', 'ear'), stem('ring', 'ring'), plural()], 'The ornaments combine ear and ring before plural -s applies to the complete compound.', 'ear-ring-compound-plus-plural', [], [
      {id: 'earring', left: 'part1', right: 'part2', surface: 'earring', rule: 'ear-plus-ring-compound', break_offsets: []},
      {id: 'whole', left: 'earring', right: 'part3', surface: 'earrings', rule: 'earring-plus-plural-s', break_offsets: []}
    ]],
    ['aquarium', [{canonical_id: 'english.combining.aqua.water', canonical: 'aqua-', surface: 'aqua', type: 'combining_form'}, affix('arium.place', '-arium', 'arium')], 'The water-life container uses the established aqua- and -arium relation; the joining a is shared in the authored aquarium spelling.', 'aqua-plus-arium-shared-a', ['mw-aquarium', 'wiktionary-aquarium']],
    ['internet', [prefix('inter.between', 'inter-', 'inter'), stem('part.net.network', 'net')], 'The worldwide linked-network noun is shortened from internetwork. The retained inter- and network-net components remain meaningful; net is the shortened network sense, not a catching net.', 'inter-plus-shortened-network-net', ['wiktionary-internet']],
    ['email', [{canonical_id: 'english.abbreviation.e.electronic', canonical: 'e', surface: 'e', type: 'abbreviation'}, stem('part.mail.messages', 'mail')], 'The electronic-message noun combines the abbreviation e for electronic with mail. Keep the stored unhyphenated form exactly.', 'abbreviated-electronic-plus-mail', ['mw-email']],
    ['sometimes', [stem('some', 'some'), stem('part.time.occasion', 'time'), affix('s.adverbial', '-s', 's')], 'The occasional-time adverb contains some and time with the established adverbial -s; it is not counted as an ordinary plural noun.', 'some-time-plus-adverbial-s', ['mw-sometimes', 'wiktionary-sometimes'], [
      {id: 'sometime', left: 'part1', right: 'part2', surface: 'sometime', rule: 'some-plus-time', break_offsets: []},
      {id: 'whole', left: 'sometime', right: 'part3', surface: 'sometimes', rule: 'sometime-plus-adverbial-s', break_offsets: []}
    ]],
    ['lonely', [stem('part.lone.alone', 'lone'), affix('ly.adjective', '-ly', 'ly')], 'The solitary-state adjective is lone plus adjectival -ly; it is not an adverb.', 'lone-plus-adjectival-ly'],
    ['winner', [stem('win', 'win'), er()], 'The successful person or team wins; the exact agent noun doubles final n before -er.', 'win-plus-er-double-n']
  ];
  const sources = Object.fromEntries(['slippery', 'passport', 'sweater', 'unicycle', 'decorate', 'return', 'subtract', 'dentist', 'aquarium', 'email', 'sometimes'].map(id => [`mw-${id}`, {
    title: `Merriam-Webster: ${id}`, author: 'Merriam-Webster editors', url: `https://www.merriam-webster.com/dictionary/${id}`, consulted: DATE,
    evidence: 'Selected sense and relevant formation or lexicalization checked for the individual authored decision; no definition text copied.'
  }]));
  sources['wiktionary-aquarium'] = {title: 'Wiktionary: aquarium, English formation', author: 'Wiktionary contributors', url: 'https://en.wiktionary.org/wiki/aquarium#English', consulted: DATE, evidence: 'Explicit aqua- and -arium formation checked alongside the dictionary account of the aquatic-vivarium contraction.'};
  sources['wiktionary-internet'] = {title: 'Wiktionary: Internet, English formation', author: 'Wiktionary contributors', url: 'https://en.wiktionary.org/wiki/Internet#English', consulted: DATE, evidence: 'The documented shortening of internetwork supports the retained inter- and network-net analysis; original vocabulary case remains unchanged.'};
  sources['wiktionary-sometimes'] = {title: 'Wiktionary: sometimes, English formation', author: 'Wiktionary contributors', url: 'https://en.wiktionary.org/wiki/sometimes#English', consulted: DATE, evidence: 'The sometime plus adverbial -s formation distinguishes the ending from an ordinary noun plural.'};
  // These named withdrawals supersede the removed whole-form decisions.
  const pending = {
  "explore": "Reopened after new term-specific evidence: The ex-/plorare cry-out history is documented but distant from the target examining/learning sense. Hold both a reflexive whole-form declaration and a literal out-plus-cry exercise. A reviewer must decide contemporary learner depth with the explore/exploration family and historical opacity made explicit.",
  "separate": "Reopened after new term-specific evidence: The se- apart plus parare prepare family is documented. Hold until the English se/par/ate realization and nonliteral prepare element are resolved. A future par.prepare identity must stay separate from par.equal in compare."
};
  derivatives.push(...[
  [
    "receive",
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
        "canonical_id": "english.root.ceive.take",
        "type": "root",
        "canonical": "ceive",
        "surface": "ceive",
        "break_offsets": []
      }
    ],
    "The current getting-something-given sense has an inherited re- plus bound ceive family. Newly consulted receive/conceive histories and the linguistic bound-root example support the graph. Re.back is historical here: receive does not mean receiving again or necessarily taking something back. Ceive take is an ancestry gloss, not an independently usable English word. Current gameplay presents the authored surfaces without a false literal gloss; any future component-meaning display must retain this historical distinction.",
    "authored-re-back-plus-bound-ceive",
    [
      "mw-receive-new",
      "mw-conceive-new",
      "mw-re-prefix-new",
      "pbs-bound-ceive-new",
      "anderson-2e-roots-new"
    ],
    [
      {
        "id": "whole",
        "left": "p1",
        "right": "p2",
        "surface": "receive",
        "rule": "authored-re-back-plus-bound-ceive",
        "break_offsets": []
      }
    ]
  ]
]);
  Object.assign(sources, {
  "mw-receive-new": {
    "title": "Merriam-Webster: receive",
    "author": "Merriam-Webster editors",
    "url": "https://www.merriam-webster.com/dictionary/receive",
    "consulted": "2026-10-16",
    "consultation_status": "newly_consulted_page_body_in_revision_pass",
    "sections": "Word History and relevant current sense",
    "evidence": "The current sense includes getting something given or sent. The history traces French receivre to Latin re- plus capere, take; the children's history distinguishes the historical back sense."
  },
  "mw-conceive-new": {
    "title": "Merriam-Webster: conceive",
    "author": "Merriam-Webster editors",
    "url": "https://www.merriam-webster.com/dictionary/conceive",
    "consulted": "2026-10-16",
    "consultation_status": "newly_consulted_page_body_in_revision_pass",
    "sections": "Word History and relevant current sense",
    "evidence": "The companion history traces French conceivre to Latin com- plus capere, take. This supports the ceive family correspondence without making ceive a free English verb."
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
  "pbs-bound-ceive-new": {
    "title": "Crash Course Linguistics, episode 2: Morphology",
    "author": "Crash Course Linguistics, published by PBS",
    "url": "https://www.pbs.org/video/morphology-j8k5re/",
    "consulted": "2026-10-16",
    "consultation_status": "newly_consulted_page_body_in_revision_pass",
    "sections": "Transcript, bound-root discussion",
    "evidence": "The transcript explicitly uses receive, deceive, perceive, and conceive to illustrate the bound root ceive. It distinguishes structural recurrence from an independently usable English meaning. The take gloss in the proposal is historical evidence from the dictionary, not a claim that ceive is a standalone word."
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
  "mw-explore-new": {
    "title": "Merriam-Webster: explore",
    "author": "Merriam-Webster editors",
    "url": "https://www.merriam-webster.com/dictionary/explore",
    "consulted": "2026-10-16",
    "consultation_status": "newly_consulted_page_body_in_revision_pass",
    "sections": "Word History and relevant current sense",
    "evidence": "The history identifies ex- plus plorare cry out. The selected examining/learning sense is semantically distant; historical segmentation alone does not settle an appropriate modern teaching graph."
  },
  "mw-separate-new": {
    "title": "Merriam-Webster: separate",
    "author": "Merriam-Webster editors",
    "url": "https://www.merriam-webster.com/dictionary/separate",
    "consulted": "2026-10-16",
    "consultation_status": "newly_consulted_page_body_in_revision_pass",
    "sections": "Word History and relevant current sense",
    "evidence": "The history identifies se- apart plus parare prepare/procure. That prepare root differs from the equal par root in compare; a spelling-only shared canonical identity would be wrong."
  },
  "mw-ate-suffix-new": {
    "title": "Merriam-Webster: -ate",
    "author": "Merriam-Webster editors",
    "url": "https://www.merriam-webster.com/dictionary/-ate",
    "consulted": "2026-10-16",
    "consultation_status": "newly_consulted_page_body_in_revision_pass",
    "sections": "Verb suffix and Word History",
    "evidence": "The dictionary distinguishes a verb-forming suffix and traces it to Latin participial morphology. This is background evidence for investigate, separate, and estimate research, not term-level authorization for automatic splitting."
  }
});
// Nine-hold proposal: these decisions supersede the named pending reviews only.
  delete pending["explore"];
  delete pending["separate"];
  derivatives.push(...[
  [
    "separate",
    [
      {
        "canonical_id": "english.affix.se.apart",
        "type": "prefix",
        "canonical": "se-",
        "surface": "se"
      },
      {
        "canonical_id": "english.root.par.prepare",
        "type": "root",
        "canonical": "par",
        "surface": "par"
      },
      {
        "canonical_id": "english.affix.ate.verb",
        "type": "suffix",
        "canonical": "-ate",
        "surface": "ate"
      }
    ],
    "The selected verb has the inherited se- apart, par prepare/procure, and verbal -ate structure. Prepare supplies the companion parare family, and the University of Michigan teaching exercise independently includes separate in the -ate family. The exact first join is the bound stem separ, not an invented standalone verb; the second yields separate. Par.prepare is kept distinct from compare par.equal. The whole separating action remains the definition; the historical preparation gloss is not a claim that separation means preparation or equalization. This review concerns the verb rather than automatically reusing its analysis for a noun or adjective sense.",
    "authored-separ-bound-stem-plus-verbal-ate",
    [
      "mw-separate-new",
      "mw-ate-suffix-new",
      "etym-separate-hold9",
      "etym-se-hold9",
      "mw-prepare-hold9",
      "michigan-ate-hold9",
      "anderson-2e-roots-new"
    ],
    [
      {
        "id": "bound_stem",
        "left": "part1",
        "right": "part2",
        "surface": "separ",
        "rule": "authored-bound-stem-separ",
        "break_offsets": []
      },
      {
        "id": "whole",
        "left": "bound_stem",
        "right": "part3",
        "rule": "authored-separ-bound-stem-plus-verbal-ate",
        "surface": "separate",
        "break_offsets": []
      }
    ]
  ]
]);
  Object.assign(sources, {
  "mw-explore-new": {
    "title": "Merriam-Webster: explore",
    "author": "Merriam-Webster editors",
    "url": "https://www.merriam-webster.com/dictionary/explore",
    "consulted": "2026-10-16",
    "consultation_status": "newly_consulted_page_body_in_revision_pass",
    "sections": "Word History and relevant current sense",
    "evidence": "The history identifies ex- plus plorare cry out. The selected examining/learning sense is semantically distant; historical segmentation alone does not settle an appropriate modern teaching graph."
  },
  "etym-explore-hold9": {
    "title": "Online Etymology Dictionary: explore",
    "author": "Douglas Harper",
    "url": "https://www.etymonline.com/word/explore",
    "consulted": "2026-10-16",
    "consultation_status": "newly_consulted_page_body_in_nine_hold_pass",
    "sections": "Entry history and linked family evidence",
    "evidence": "The entry offers back-formation from exploration or borrowing via French. It discusses the historical plorare cry-out account but also a competing pluere flow account. That uncertainty and the established explore/exploration base argue against presenting one deep historical split as the uniquely settled learner graph."
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
  "mw-separate-new": {
    "title": "Merriam-Webster: separate",
    "author": "Merriam-Webster editors",
    "url": "https://www.merriam-webster.com/dictionary/separate",
    "consulted": "2026-10-16",
    "consultation_status": "newly_consulted_page_body_in_revision_pass",
    "sections": "Word History and relevant current sense",
    "evidence": "The history identifies se- apart plus parare prepare/procure. That prepare root differs from the equal par root in compare; a spelling-only shared canonical identity would be wrong."
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
  "etym-separate-hold9": {
    "title": "Online Etymology Dictionary: separate",
    "author": "Douglas Harper",
    "url": "https://www.etymonline.com/word/separate",
    "consulted": "2026-10-16",
    "consultation_status": "newly_consulted_page_body_in_nine_hold_pass",
    "sections": "Entry history and linked family evidence",
    "evidence": "The verb derives from the Latin participial form separatus, with se- apart and parare prepare/procure. The adjective has related borrowing/conversion history. This evidence supports the selected verb graph while keeping par.prepare distinct from compare par.equal."
  },
  "etym-se-hold9": {
    "title": "Online Etymology Dictionary: se-",
    "author": "Douglas Harper",
    "url": "https://www.etymonline.com/word/se-",
    "consulted": "2026-10-16",
    "consultation_status": "newly_consulted_page_body_in_nine_hold_pass",
    "sections": "Entry history and linked family evidence",
    "evidence": "The entry records the apart/away prefix in Latin-derived English words. This is the specific se- identity selected for separate, not an arbitrary opening syllable."
  },
  "mw-prepare-hold9": {
    "title": "Merriam-Webster: prepare",
    "author": "Merriam-Webster editors",
    "url": "https://www.merriam-webster.com/dictionary/prepare",
    "consulted": "2026-10-16",
    "consultation_status": "newly_consulted_page_body_in_nine_hold_pass",
    "sections": "Relevant sense and Word History",
    "evidence": "The history identifies prae- plus parare supply/provide/make ready, providing a companion family for the prepare/procure element of separate. It is unrelated to compare par equal."
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
