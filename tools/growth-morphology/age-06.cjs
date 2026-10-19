// Each entry is an individual editorial decision, never a suffix classifier.
module.exports = ({stem, affix, DATE}) => {
  const c = (id, text = id) => stem(id, text, 'compound');
  const er = () => affix('er.agent-instrument', '-er', 'er');
  const y = () => affix('y.adjective', '-y', 'y');
  const teen = () => affix('teen.add-ten', '-teen', 'teen');
  const prefix = (id, canonical, surface) => ({canonical_id: `english.affix.${id}`, canonical, surface, type: 'prefix'});
  const atoms = `
clock|The timekeeping noun is one stem, not a clipped suffix construction.
key|The lock-opening noun is one lexical base.
whale|The marine-mammal name is a single animal stem.
shark|The fish name has no smaller current meaningful pieces.
crab|The crustacean noun is a single base.
seal|The animal sense is one stem, distinct from the closing action.
shell|The protective-covering noun is one base.
earth|The planet or ground noun is one stem.
rocket|The vehicle name is a borrowed lexical base, not rock plus a modern diminutive.
alien|The extraterrestrial noun is one borrowed base, not ali plus en.
root|The plant-part noun is a single lexical base.
rose|The flower noun is one stem, not the past form of rise in this sense.
berry|The fruit-class noun has no independent berr base.
acorn|The oak seed name is not a compound containing the modern corn crop.
pebble|The small-stone noun is one lexical base.
pond|The small-waterbody noun is a single stem.
bell|The ringing object is one lexical base.
horn|The pictured horn noun is one base, without a detachable ending.
boot|The footwear noun is a single base.
pumpkin|The vegetable name has no modern pump plus kin meaning.
river|The flowing-water noun is not an agent of rive in the selected sense.
lake|The inland-water noun is one base.
helmet|The protective-headgear word is lexicalized; a diminutive of helm is not productive in this sense.
robot|The borrowed machine name is one English base, without an English rob plus ot relation.
puzzle|The activity-object noun is one lexical base.
marble|The small-ball noun is a single base, not mar plus ble.
dolphin|The animal name is one borrowed stem, without a meaningful fin suffix.
mushroom|The fungus name is not mush plus the modern room noun.
bat|The animal noun is one base, distinct from a sporting implement.
deer|The animal noun remains one stem; this spelling does not add a plural ending.
snake|The reptile noun is one base.
snail|The mollusk name is one stem.
worm|The animal noun is one lexical base.
spider|The animal name has no productive spid base or agent ending in current English.
chick|The young-bird noun is a single stem.
lemon|The citrus fruit name is one borrowed base.
peach|The fruit name is one lexical base.
plum|The fruit noun is a single base.
mango|The borrowed fruit name is not man plus go.
nut|The seed or fruit noun is one lexical base.
soup|The liquid-food noun is one base.
jam|The fruit-preserve noun is one base, distinct from the obstruction sense.
honey|The sweet-food noun has no independent hone base in this sense.
pasta|The food name is a whole English loanword; Italian inflection is not an English suffix.
candy|The sweet-food noun is a single English base, not cand plus adjectival y.
rock|The stone noun is one base.
hill|The landform noun is one base.
beach|The shore noun is a single base.
sand|The granular-material noun is one base.
mud|The wet-earth noun is one base.
ice|The frozen-water noun is one base.
wind|The moving-air noun is one base, distinct from the winding verb.
belt|The clothing-accessory noun is one lexical base.
shorts|The garment sense is a lexical plural; an invented singular short garment would misrepresent this item.
mitten|The handwear noun is one borrowed lexical base, not mitt plus a productive en ending.
cape|The outerwear noun is one stem, distinct from a coastal landform.
van|The clipped vehicle word is a whole modern base.
taxi|The clipped vehicle noun is a whole English base, not tax plus i.
wheel|The rotating vehicle-part noun is one stem.
yoyo|The stored spelling names a borrowed toy; its repeated syllables are not two English morphemes.
dice|The irregular game-piece plural stays whole; ce is not a detachable plural suffix.
swing|The play-equipment noun is one base, not sw plus ing.
slide|The playground-equipment noun is one base.
tent|The portable-shelter noun is one lexical base.
box|The container noun is one stem.
pan|The cooking-vessel noun is one base.
pot|The cooking-container noun is one base.
comb|The hair-tool noun is one stem.
fan|The cooling-device noun is one base, distinct from an admirer.
mop|The cleaning-tool noun is one base.
rug|The floor-covering noun is one base.
jug|The liquid-container noun is one base.
toe|The body-part noun is a single stem.
neck|The body-part noun is one base.
broccoli|The vegetable name is a whole English loanword, without an English plural i suffix.
cucumber|The vegetable name is one English base, not cucumb plus an agent suffix.
lettuce|The vegetable noun is one borrowed base.
potato|The vegetable noun is one lexical base, not pot plus ato.
sandwich|The food name is an eponymic lexical base, not sand plus wich.
waffle|The food noun is one base, not waf plus fle.
forest|The woodland noun is one lexical base, not fore plus st.
cave|The natural-cavity noun is one base.
valley|The landform noun is one base, without a productive vall stem.
jacket|The coat noun is lexicalized; it does not name a smaller Jack.
ask|The requesting action is an uninflected verb base.
bend|The curving action is an uninflected verb stem.
bite|The tooth-cutting action is an uninflected verb base.
blink|The eye-closing action is an uninflected verb base.
blow|The air-pushing action is an uninflected verb base.
bounce|The springing-back action is an uninflected verb stem.
bring|The carrying-toward action is a whole verb, not br plus ing.
build|The construction action is an uninflected base.
chew|The tooth-grinding action is an uninflected base.
crawl|The hands-and-knees motion verb is one base.
cut|The dividing action is an uninflected verb base.
dream|The sleeping-imagination verb is one lexical base.
fill|The container-filling verb is one uninflected base.
float|The water-supported motion verb is one base.
fold|The bending-over action is an uninflected base.
grow|The becoming-bigger action is an uninflected verb base.
hold|The keeping-in-hand action is an uninflected verb base.
hop|The single-foot jumping verb is one base.
knock|The door-tapping action is an uninflected stem.
mix|The combining action is an uninflected verb base.
move|The position-changing action is one verb base.
nod|The head-moving action is an uninflected base.
pick|The choosing action is one verb base.
pour|The liquid-tipping action is one verb base.
rest|The relaxing action is a whole verb, without an iterative re prefix.
rub|The surface-stroking action is one base.
share|The joint-use action is an uninflected verb base.
shout|The loud-speaking action is one base, not sh plus out.
skip|The rope-jumping action is one base.
sneeze|The sudden air-expulsion verb is one base.
spell|The letter-naming action is an uninflected verb.
spin|The rotating action is one base.
squeeze|The firm-pressing action is one base.
stand|The upright-position action is an uninflected verb base.
stir|The food-mixing action is an uninflected base.
stretch|The lengthening action is a whole verb.
talk|The speaking action is an uninflected base.
taste|The food-trying action is an uninflected verb base.
think|The considering action is a whole verb base.
tickle|The light-touch action has no current tick plus le derivation in this sense.
touch|The feeling-by-hand action is an uninflected base.
whisper|The soft-speaking verb has no productive whisp agent base.
wipe|The cloth-cleaning action is one uninflected base.
yawn|The sleepy mouth-opening action is one base.
afraid|The emotion adjective is lexicalized; there is no modern fraid base with a productive a prefix.
awake|The state adjective stays whole; initial a is not a separately taught modern prefix in this sense.
high|The height adjective is one base.
hard|The firmness adjective is a single lexical stem.
same|The identity adjective is one base.
sour|The sharp-taste adjective is one base.
heavy|The weight adjective is lexicalized; no current heav stem is presented as a free base.
light|The low-weight adjective is one base, distinct from illumination.
purple|The color adjective is one lexical base.
brown|The color adjective is one base.
gray|The stored color spelling is one base; no spelling normalization is performed.
above|The higher-location preposition is a whole functional form.
below|The lower-location preposition is lexicalized; be is not the verb be here.
behind|The rear-location preposition is a whole modern functional form.
between|The intervening-location preposition has no independent tween base in this sense.
through|The traversing preposition is one functional form.
across|The crossing preposition is lexicalized; its a is not the indefinite article.
around|The surrounding-location preposition is a whole modern form, not an article-noun phrase.
before|The earlier-time preposition is lexicalized; be is not an independent verbal component.
after|The later-time preposition has no comparative aft plus er meaning in this use.
zero|The zero-quantity numeral is one borrowed base.
room|The interior-space noun is one base.
shelf|The storage-board noun is one singular base.
wardrobe|The cabinet name is a borrowed lexical unit. Its historical French guarding-clothes formation is recorded but not treated as a productive modern English join.|mw-wardrobe
stove|The cooking-device noun is one base.
basket|The woven-container noun is one modern base, not bask plus et.
jar|The container noun is one base, distinct from the jolting action.
tray|The carrying-surface noun is one base.
lid|The container-cover noun is one base.
straw|The drinking-tube noun is one stem.
napkin|The wiping-cloth noun is lexicalized; nap is not the sleeping action in this word.
tissue|The soft-paper noun is one borrowed stem.
sponge|The absorbent-tool noun is one base.
button|The clothing-fastener noun is one lexical base, not butt plus on.
pocket|The clothing-pouch noun is lexicalized; a productive pock diminutive is not taught.
chalk|The drawing-material noun is one base.
picnic|The outdoor-meal noun is a whole borrowed base.
trampoline|The bouncing-apparatus noun is one base, not tramp plus oline.
art|The creative-work noun is one base.
oval|The shape noun is lexicalized; ov is not a free base in this cohort.
diamond|The geometric-shape noun is one base, not dia plus mond.
chin|The body-part noun is one stem.
cheek|The facial-part noun is one base.
tongue|The mouth-organ noun is one base.
shoulder|The body-joint noun is not should plus an agent suffix.
wrist|The body-joint noun is one base.
fly|The insect noun is one base; y is not an adjective ending.
toast|The heated-bread noun is one base.
yogurt|The fermented-food noun is a whole loanword.
pizza|The food name is a whole English loanword.
pie|The pastry noun is a single base.
ham|The cooked-meat noun is one stem.
chocolate|The food noun is one borrowed base, not choc plus an English late component.
jelly|The dessert noun is one lexical base, not jell plus an adjective ending in this noun.
sugar|The sweet-substance noun is one base.
salt|The seasoning noun is a single base.
flour|The ground-grain noun is one base, distinct from flower.
bench|The long-seat noun is one base.
spring|The season noun is one base, not spr plus ing.
summer|The season noun is not sum plus an agent ending.
autumn|The season noun is one borrowed base.
winter|The season noun is not wint plus an agent ending.
today|The current-day adverb is lexicalized; to is not a directional instruction in its modern meaning.|mw-today
tomorrow|The next-day adverb is a whole functional form; the historical morrow is not substituted into the beginner sense.
yesterday|The previous-day adverb is lexicalized; no free yester base is fabricated.
camera|The image-making device noun is one borrowed base.
them|The object pronoun is a whole case form.
their|The possessive determiner is a whole grammatical form.
but|The contrast conjunction is one functional form.
when|The time interrogative is one functional form.
why|The reason interrogative is one functional form.
be|The existence or state verb is the whole base form.
too|The excess adverb is one functional form.
of|The relation preposition is one functional form.
for|The purpose preposition is one functional form.
from|The source preposition is one functional form.
then|The subsequent-time adverb is one functional form.
soon|The near-future adverb is one base.
know|The information-having action is an uninflected base.
use|The tool-using action is an uninflected base.
choose|The selecting action is one uninflected verb.
practice|The skill-repetition verb is one modern base; an invented pract plus ice split has no current meaning.
brave|The courage adjective is one base.
safe|The protection adjective is one base.
special|The valued-difference adjective is retained as a modern stem; spec is not a current free base for this sense.
gentle|The mild-manner adjective is one modern base, not gent plus le.
calm|The relaxed-state adjective is one base.
idea|The thought noun is one borrowed base.
question|The inquiry noun is lexicalized; the search noun quest is not automatically substituted as this base.
weather|The outdoor-conditions noun is one lexical base, not weath plus er.
year|The calendar-duration noun is one base.
monday|The weekday name is retained whole with the original lowercase spelling; no historical moon allomorph is imposed on this calendar label.
tuesday|The weekday name stays whole; its obsolete deity name is not a productive modern base.
wednesday|The weekday name stays whole; its Woden history does not license an invented wednes component.
thursday|The weekday name stays whole; historical divine naming is distinct from a productive modern phrase.
friday|The weekday name stays whole; fri is not an independent modern word component.
saturday|The weekday name stays whole; satur is not invented as a modern base.
sunday|The conventional weekday name is stored whole; it is not defined as any day with sunshine.
both|The two-item determiner is one functional form.
every|The distributive determiner is one modern functional form, not ever plus an adjective ending.
left|The direction adjective is a whole form, distinct from the past of leave.
right|The direction adjective is one stem, distinct from correctness in this sense.
front|The forward-part noun is one base.
bone|The body-structure noun is one base.
stomach|The digestive-organ noun is one borrowed stem.
tea|The leaf-drink noun is a single borrowed base.
clay|The shaping-material noun is one base.
letter|The written-message noun is not an agent of let in this sense.
change|The difference-making action is an uninflected verb base.
`;
  const compounds = [
    ['sunglasses', [c('sun'), c('glasses')], 'Sun modifies the lexical plural eyewear noun glasses. Preserve the glasses sense as a whole component; do not confuse it with the Growth drinking glass.', ['mw-sunglasses']],
    ['pancake', [c('pan'), c('cake')], 'The food is a cake cooked in a pan; both free bases contribute to the food sense.'],
    ['backpack', [c('back'), c('part.pack.bag', 'pack')], 'The carried pack is worn on the back; the second component is a bag noun, not the Growth packing action.'],
    ['cupboard', [c('cup'), c('part.board.shelf', 'board')], 'The established storage compound retains cup and board, although its modern cabinet sense is broader than a board for cups.'],
    ['hairbrush', [c('hair'), c('part.brush.tool', 'brush')], 'The tool is a brush used on hair; the brush component is the implement noun.'],
    ['sandbox', [c('sand'), c('box')], 'The play enclosure is a box holding sand; both free bases retain their meanings.']
  ];
  const derivatives = [
    ['tractor', [{canonical_id: 'english.root.tract.pull', canonical: 'tract', surface: 'tract', type: 'root'}, affix('or.agent', '-or', 'or')], 'The sourced formation joins the bound pulling root tract and agent -or, naming a pulling vehicle. This tract shares its true root sense with subtract and is distinct from the land-area noun.', 'tract-pull-plus-agent-or', ['mw-tractor', 'wiktionary-tractor']],
    ['rover', [stem('part.rove.travel', 'rove'), er()], 'The vehicle is named as something that roves; -er forms the moving agent and the final e is shared in the exact output.', 'rove-plus-er-final-e-sharing'],
    ['scooter', [stem('part.scoot.move', 'scoot'), er()], 'The vehicle name uses scoot and the instrument-forming -er, retaining a current movement base.', 'scoot-plus-instrument-er'],
    ['funny', [stem('part.fun.amusement', 'fun'), y()], 'The humorous adjective relates to fun; final n doubles in the individually authored funny spelling.', 'fun-plus-y-double-n'],
    ['forward', [stem('part.fore.front', 'fore'), affix('ward.direction', '-ward', 'ward')], 'The front-directed adverb has fore and directional -ward; its existing spelling drops the base final e.', 'fore-plus-ward-authored-e-loss', ['mw-forward']],
    ['backward', [stem('back', 'back'), affix('ward.direction', '-ward', 'ward')], 'The adverb directs motion toward the back; -ward contributes direction rather than an independent ward noun.', 'back-plus-directional-ward'],
    ['drawer', [stem('part.draw.pull', 'draw'), er()], 'The sliding compartment is drawn out. Its base is the pulling sense of draw, not the Growth picture-making verb.', 'draw-pull-plus-instrument-er', ['mw-drawer']],
    ['freezer', [stem('freeze', 'freeze'), er()], 'The machine freezes food; freeze and instrument -er produce the authored single-e spelling freezer.', 'freeze-plus-er-final-e-sharing'],
    ['microwave', [prefix('micro.small', 'micro-', 'micro'), stem('part.wave.radiation', 'wave')], 'The shortened oven name refers to microwave radiation. Micro- specifies small wavelength and wave is the radiation sense, not a hand greeting.', 'micro-plus-radiation-wave', ['mw-microwave']],
    ['hairdryer', [stem('hair', 'hair'), stem('part.dry.action', 'dry'), er()], 'The tool dries hair. Dry plus instrument -er forms dryer before hair combines with that derived head; the dryer spelling is explicitly retained.', 'hair-plus-derived-dryer', [], [
      {id: 'dryer', left: 'part2', right: 'part3', surface: 'dryer', rule: 'dry-plus-er-retain-y', break_offsets: []},
      {id: 'whole', left: 'part1', right: 'dryer', surface: 'hairdryer', rule: 'hair-plus-dryer-compound', break_offsets: []}
    ]],
    ['hanger', [stem('hang', 'hang'), er()], 'The frame hangs clothes; the instrument-forming -er attaches to the current hang base.', 'hang-plus-instrument-er'],
    ['zipper', [stem('part.zip.fasten', 'zip'), er()], 'The fastener is an instrument associated with zipping; the exact output doubles p.', 'zip-plus-er-double-p'],
    ['sticker', [stem('part.stick.adhere', 'stick'), er()], 'The adhesive picture sticks to a surface. Use the adhering verb sense, not the Growth wooden-stick noun.', 'stick-adhere-plus-instrument-er'],
    ['rectangle', [{canonical_id: 'english.combining.rect.right', canonical: 'rect-', surface: 'rect', type: 'combining_form'}, stem('angle', 'angle')], 'The established geometric formation relates the right-angle combining base rect- to angle; the Latin-derived analysis is explicitly sourced.', 'rect-right-plus-angle', ['mw-rectangle']],
    ['lips', [stem('lip', 'lip'), affix('s.plural', '-s', 's')], 'The paired mouth edges are the current singular lip plus plural -s.', 'lip-plus-plural-s'],
    ['later', [stem('part.late.time', 'late'), affix('er.comparative', '-er', 'er')], 'The subsequent-time adverb uses the comparative of late; the suffix is comparative, not an agent marker, and the final e is shared.', 'late-plus-comparative-er-final-e-sharing'],
    ['enjoy', [prefix('en.put-in-state', 'en-', 'en'), stem('part.joy.pleasure', 'joy')], 'The pleasure-taking verb retains the attested en- and joy relation; joy is the emotional noun and the exact current verb is authored.', 'en-plus-joy', ['mw-enjoy']],
    ['careful', [stem('part.care.attention', 'care'), affix('ful.characterized-by', '-ful', 'ful')], 'The attentive adjective contains the attention sense of care and -ful; the suffix is spelled with one l.', 'care-plus-ful'],
    ['easy', [stem('part.ease.lack-of-difficulty', 'ease'), y()], 'The low-difficulty adjective is related to ease with adjectival -y; the authored result drops the final e.', 'ease-plus-y-e-loss', ['mw-easy']],
    ['different', [stem('differ', 'differ'), affix('ent.adjective', '-ent', 'ent')], 'The adjective describes things that differ; the current differ base supports -ent without an invented diff component.', 'differ-plus-adjective-ent', ['mw-different']],
    ['celebration', [stem('celebrate', 'celebrate'), affix('ion.event', '-ion', 'ion')], 'The event noun is related to celebrate and nominal -ion; the exact output drops the final e of celebrate.', 'celebrate-plus-ion-final-e-loss', ['mw-celebration']],
    ['thirteen', [stem('three', 'three'), teen()], 'The numeral adds ten to three. Its irregular thir stem is encoded by the exact thirteen output, without treating thir as a free word.', 'three-plus-teen-authored-allomorph', ['wiktionary-teen']],
    ['fourteen', [stem('four', 'four'), teen()], 'The numeral adds ten to four with the established -teen suffix.', 'four-plus-teen', ['wiktionary-teen']],
    ['fifteen', [stem('five', 'five'), teen()], 'The numeral adds ten to five; the exact fifteen spelling carries the base allomorph rather than a generic deletion rule.', 'five-plus-teen-authored-allomorph', ['wiktionary-teen']],
    ['sixteen', [stem('six', 'six'), teen()], 'The numeral combines six with the add-ten suffix, preserving both displayed base meanings.', 'six-plus-teen', ['wiktionary-teen']],
    ['seventeen', [stem('seven', 'seven'), teen()], 'The numeral combines seven with the add-ten suffix, with unchanged base spelling.', 'seven-plus-teen', ['wiktionary-teen']],
    ['eighteen', [stem('eight', 'eight'), teen()], 'The numeral adds ten to eight; the shared t appears once in the authored output eighteen.', 'eight-plus-teen-shared-t', ['wiktionary-teen']],
    ['nineteen', [stem('nine', 'nine'), teen()], 'The numeral adds ten to nine and preserves the base final e.', 'nine-plus-teen', ['wiktionary-teen']],
    ['twenty', [stem('two', 'two'), affix('ty.multiple-ten', '-ty', 'ty')], 'The numeral represents two tens. The established numeric -ty is distinct from abstract-noun -ty, and twenty is an authored irregular base realization.', 'two-plus-numeric-ty-authored-allomorph', ['wiktionary-numeric-ty']]
  ];
  const sources = Object.fromEntries(['tractor', 'wardrobe', 'today', 'sunglasses', 'forward', 'drawer', 'microwave', 'rectangle', 'enjoy', 'easy', 'different', 'celebration'].map(id => [`mw-${id}`, {
    title: `Merriam-Webster: ${id}`, author: 'Merriam-Webster editors', url: `https://www.merriam-webster.com/dictionary/${id}`, consulted: DATE,
    evidence: 'The selected dictionary sense or word history was consulted for this individual decision; review wording is original.'
  }]));
  sources['wiktionary-teen'] = {title: 'Wiktionary: -teen, English suffix', author: 'Wiktionary contributors', url: 'https://en.wiktionary.org/wiki/-teen#English', consulted: DATE, evidence: 'English numeric suffix and explicit thirteen-through-nineteen family checked; irregular spellings are individually authored.'};
  sources['wiktionary-numeric-ty'] = {title: 'Wiktionary: -ty, English numeric suffix', author: 'Wiktionary contributors', url: 'https://en.wiktionary.org/wiki/-ty#English', consulted: DATE, evidence: 'The numeric multiples-of-ten suffix was distinguished from the unrelated abstract-noun suffix.'};
  sources['wiktionary-tractor'] = {title: 'Wiktionary: tractor, English formation', author: 'Wiktionary contributors', url: 'https://en.wiktionary.org/wiki/tractor#English', consulted: DATE, evidence: 'The explicit pulling-root and agent -or formation is recorded, distinct from the unrelated land-area tract noun.'};
  return {atoms, compounds, derivatives, sources};
};
