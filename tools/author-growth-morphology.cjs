// These are explicit editorial decisions, not a word-splitting algorithm.
// Adding a vocabulary item never grants review or an automatic atomic analysis.
const fs = require('node:fs');
const path = require('node:path');
const { createHash } = require('node:crypto');
const ROOT = path.resolve(__dirname, '..');
const REVISION = 'growth-morphology-v1';
const DATE = '2026-10-16';
const REVIEWER = 'Codex (AI editorial review; not human approval)';
const FRAMEWORK = 'anderson-morphology';
const atoms = `
cat|A single animal stem; neither letter group carries a smaller cat meaning.
dog|A single animal stem with no affix or compound boundary.
sun|The celestial-body noun is one lexical base.
ball|The round play-object noun is one lexical base.
car|The vehicle noun is one lexical base.
apple|The fruit name is one stem; syllables are not meaningful components.
fish|The animal noun has no added plural ending in this spelling.
duck|The bird sense is one stem, distinct from the verb meaning bend down.
cow|The animal noun is a single base.
pig|The farm-animal noun is a single base.
banana|The borrowed fruit name is not split into syllables; Anderson explicitly treats banana as simple.
egg|The food and animal-development noun is a single stem.
bread|The food noun is one base, not bre plus ad.
milk|The liquid noun is a single stem.
water|The liquid noun is not wat plus an agent suffix.
eye|The body-part noun is one base despite its irregular sound-to-letter mapping.
ear|The hearing-organ noun is one base.
nose|The body-part noun has no productive suffix in its final letters.
mouth|The body-part noun is a single stem.
hand|The body-part noun is a single stem.
foot|The body-part noun is its whole singular form.
hat|The clothing noun is a single base.
shirt|The clothing noun is a single base.
shoe|The footwear noun is a single base; final e is spelling, not an affix.
tree|The plant noun is one lexical base.
bus|The shortened vehicle name is a whole modern word; s is not plural here.
book|The reading-object noun is one base.
doll|The toy noun is one base.
bed|The furniture noun is one base.
chair|The furniture noun is one base.
cup|The drinking-container noun is one base.
spoon|The utensil noun is one base.
bird|The animal-class noun is one base.
clap|The hand-striking action is an uninflected verb stem.
close|The shutting action is an uninflected verb, not clos plus a suffix.
dance|The movement-to-music action is an uninflected verb stem.
drink|The liquid-taking action is an uninflected verb stem.
eat|The consuming action is an uninflected verb stem.
go|The motion verb is a whole base, with no detachable ending.
help|The assisting action is an uninflected verb stem.
hug|The embracing action is an uninflected verb stem.
jump|The upward-motion action is an uninflected verb stem.
open|The opening action is one modern verb stem, not op plus en.
play|The activity verb is an uninflected base.
run|The movement verb is an uninflected base.
sing|The vocal-music verb is a whole stem, not s plus ing.
sit|The sitting action is an uninflected verb stem.
sleep|The resting action is an uninflected verb stem.
walk|The stepping action is an uninflected verb stem.
happy|The modern emotion adjective is kept whole; an obsolete hap analysis is not taught here.
sad|The emotion adjective is a single base.
big|The size adjective is a single base, without comparison marking.
small|The size adjective is a single base, without comparison marking.
good|The evaluative adjective is a single base.
red|The color adjective is a single base; ed is not a tense suffix here.
blue|The color adjective is a single base.
yellow|The color adjective is not a compound or a productive suffix formation.
in|The location preposition is one functional form.
on|The surface-location preposition is one functional form.
up|The direction adverb is one functional form.
down|The direction adverb is one functional form.
one|The cardinal numeral is a whole lexical form.
two|The cardinal numeral is a whole lexical form.
three|The cardinal numeral is a whole lexical form.
toy|The play-object noun is a single base; y is not a suffix here.
baby|The child noun is a whole modern stem; there is no productive bab base.
mother|The kinship noun is not an agent formed from moth.
father|The kinship noun has no productive agent suffix.
i|The existing stored first-person pronoun remains exact; no capitalization migration is performed.
you|The second-person pronoun is an unsegmented functional form.
my|The possessive determiner is a whole inflected form, with no separate spelled suffix.
a|The indefinite article is one functional form.
is|The suppletive be form is retained whole; no invented b plus s decomposition.
can|The ability modal is one stem, distinct from the container noun.
yes|The response word is a single form; its s is not plural.
no|The refusal word is a single functional form.
please|The politeness interjection is a whole form in this sense.
hello|The greeting is not decomposed into phonetic syllables.
me|The object pronoun is a whole case form; no separate spelled case suffix.
friend|The person noun is one base; end is not an affix here.
hen|The adult female-bird noun is a single base.
horse|The animal noun is one stem, without a detachable ending.
goat|The animal noun is a single base.
mouse|The animal noun is its whole singular form.
bear|The animal sense is a single base, not the carrying verb.
lion|The animal name is a single modern stem.
frog|The animal noun is a single base.
bee|The insect noun is a single base.
ant|The insect noun is a single base, not a noun suffix in this word.
orange|The fruit sense is an unsegmented borrowed base.
pear|The fruit noun is a single base.
carrot|The vegetable noun is one stem; car is not a component meaning vehicle.
corn|The food-plant noun is a single base.
cake|The food noun is one base, with no detachable final e.
juice|The liquid-food noun is one base.
rice|The food-grain noun is one base.
arm|The body-part noun is one base.
leg|The body-part noun is one base.
head|The body-part noun is one base.
tooth|The body-part noun is a whole singular form.
coat|The outerwear noun is one base.
sock|The clothing noun is a singular base.
glove|The hand-clothing noun is one base.
moon|The celestial-body noun is one base.
star|The celestial-body noun is one base.
rain|The weather noun is one base.
snow|The frozen-weather noun is one base.
leaf|The plant-part noun is a whole singular form.
flower|The plant noun is not the agent of the verb flow.
train|The vehicle noun is one base.
truck|The vehicle noun is one base.
plane|The shortened aircraft noun is a whole modern stem.
boat|The water-vehicle noun is one base.
bike|The clipped bicycle noun remains a whole form, not bi plus ke.
kite|The flying-toy noun is one base.
block|The play-piece noun is one base.
table|The furniture noun is not tab plus an adjective suffix.
door|The building-part noun is one base.
lamp|The lighting-object noun is one base.
bowl|The food-container noun is one base.
plate|The food-serving noun is one base.
soap|The washing-substance noun is one base.
bag|The container noun is one base.
pen|The writing-tool noun is one base.
come|The motion verb is an uninflected stem.
give|The transfer verb is an uninflected stem.
hear|The hearing verb is an uninflected stem.
laugh|The amusement action is a whole verb stem.
look|The seeing action is a whole verb stem.
smile|The facial-expression action is an uninflected verb stem.
wash|The cleaning action is an uninflected verb stem.
hungry|The present-day adjective is kept whole; Anderson explicitly classifies hungry as monomorphemic.
hot|The temperature adjective is a single base.
cold|The temperature adjective is a single base.
soft|The texture adjective is a single base.
clean|The cleanliness adjective is a single base.
green|The color adjective is a single base.
pink|The color adjective is a single base.
white|The color adjective is a single base.
black|The color adjective is a single base.
four|The cardinal numeral is a whole lexical form.
five|The cardinal numeral is a whole lexical form.
house|The dwelling noun is a single base.
bath|The washing-container noun is a single base.
toilet|The borrowed bathroom noun has no productive English toi base.
teddy|The toy noun is a lexicalized name-based form, not a general ted plus y construction.
family|The relationship noun has no productive famil base in this curriculum.
brother|The kinship noun is not an agent or comparative construction.
sister|The kinship noun is not sist plus an agent suffix.
face|The body-part noun is a single base.
we|The first-person plural pronoun is a whole grammatical form.
he|The third-person pronoun is a whole grammatical form.
she|The third-person pronoun is a whole grammatical form.
it|The reference pronoun is a whole grammatical form.
your|The possessive determiner has no separately spelled suffix to join.
an|The article allomorph stays whole; n is not an independent meaning component.
the|The definite article is one functional form.
and|The conjunction is one functional form.
this|The demonstrative is a whole singular form.
that|The demonstrative is a whole singular form.
what|The interrogative pronoun is one functional form.
am|The suppletive be form stays whole, without invented segments.
have|The possession verb is its whole uninflected base.
here|The place adverb is one modern form.
goodbye|The conventional farewell is retained whole; its historical contraction is not a productive compound exercise.
thanks|The fixed gratitude interjection is retained whole, rather than teaching an active plural reading in this sense.
sorry|The apology interjection is retained whole; its historical sorrow relation is not a transparent spelling join.
want|The desire verb is an uninflected base.
like|The enjoyment verb is an uninflected base.
see|The perception verb is an uninflected base.
listen|The attention-to-sound verb is not list plus a productive en suffix.
say|The speech verb is an uninflected base.
make|The creation verb is an uninflected base.
put|The placement verb is an uninflected base.
kind|The caring adjective is a single base.
little|The size adjective is a whole modern form.
chicken|The food sense is retained whole; chick plus a productive en suffix does not describe this meat sense.
sheep|The animal form has no separate written plural marker.
rabbit|The animal name is a single modern base.
tiger|The animal noun is not tig plus an agent suffix.
monkey|The animal name is not monk plus a suffix.
panda|The animal name is one borrowed base.
zebra|The animal name is one borrowed base.
fox|The animal noun is one base.
owl|The bird noun is one base.
turtle|The animal name has no productive turt base.
grape|The fruit noun is one base.
cherry|The fruit noun is one modern stem, not cherr plus an adjective suffix.
melon|The fruit noun is one base.
tomato|The borrowed fruit name is not divided at syllables.
cookie|The food noun is a borrowed whole form, not the cooking verb plus a productive English suffix.
cheese|The food noun is one base.
dress|The clothing noun is one base; final ss is not a plural suffix.
scarf|The clothing noun is a whole singular form.
cloud|The weather noun is one base.
phone|The clipped telephone noun is retained as a whole modern form.
fork|The utensil noun is one base.
brush|The tool noun is one base.
towel|The cloth noun is one modern stem.
seed|The plant-reproduction noun is one base.
grass|The plant noun is one base; final ss does not mark plural.
skirt|The clothing noun is one base.
pants|This garment is a lexical plural; no misleading pant verb plus plural-s join is taught.
elephant|The animal name is an unsegmented borrowed stem, not eleph plus ant.
giraffe|The animal name is an unsegmented borrowed stem.
kangaroo|The borrowed animal name is not split into syllables.
penguin|The animal name is a whole modern stem.
squirrel|The animal name is a whole modern stem.
mountain|The landscape noun is not mount plus a productive ain suffix.
balloon|The object name is not ball plus a productive oon suffix.
window|The modern building noun is opaque; a historical wind-eye derivation is not this spelling's composition.
mirror|The object noun is one stem; or is not an agent suffix here.
pillow|The bedding noun is one stem.
blanket|The bedding noun is lexicalized, not a current blank plus diminutive-et exercise.
finger|The body-part noun is not fing plus an agent suffix.
thumb|The body-part noun is one stem.
elbow|The body-part noun is opaque in modern English; no el root is taught.
knee|The body-part noun is one stem.
pencil|The writing-tool noun is one borrowed stem, not pen plus a cil suffix.
bake|The cooking verb is an uninflected stem.
carry|The transporting verb is one stem; y is not an adjective suffix here.
catch|The catching action is an uninflected stem.
climb|The climbing action is an uninflected stem.
cook|The food-preparation action is an uninflected stem.
count|The counting action is an uninflected stem.
dig|The digging action is an uninflected stem.
draw|The picture-making action is an uninflected stem.
feed|The supplying-food verb is a whole stem; its vowel relation to food creates no joinable affix.
find|The discovering action is an uninflected stem.
kick|The foot-striking action is an uninflected stem.
paint|The picture-making verb is an uninflected stem.
point|The indicating action is an uninflected stem.
pull|The moving-closer action is an uninflected stem.
push|The moving-away action is an uninflected stem.
read|The reading verb is an uninflected stem in this sense.
ride|The riding action is an uninflected stem.
swim|The water-motion verb is an uninflected stem; Anderson uses it as a simple-word example.
turn|The changing-direction action is an uninflected stem.
wait|The waiting action is an uninflected stem.
wake|The ending-sleep action is an uninflected stem.
write|The writing action is an uninflected stem.
quiet|The low-noise adjective is one base, not qui plus et.
loud|The high-volume adjective is one base.
fast|The speed adjective is one base, distinct from the fasting noun used in breakfast.
long|The length adjective is one base.
short|The height adjective is one base.
tall|The height adjective is one base.
warm|The temperature adjective is one base.
dry|The moisture adjective is one base; y is not an affix on dr.
wet|The moisture adjective is one base.
full|The capacity adjective is a free base, not the bound suffix ful alone.
empty|The capacity adjective is one modern stem; empt is not a free base here.
bad|The evaluative adjective is one base.
young|The age adjective is one base.
old|The age adjective is one base.
sweet|The taste adjective is one base.
beside|The location preposition is lexicalized; its be is not the verb be.
under|The location preposition is one functional form, not und plus er.
over|The location preposition is one functional form, not ov plus er.
near|The location preposition is one functional form.
away|The distance adverb is lexicalized; its a is not the indefinite article.
six|The cardinal numeral is a whole lexical form.
seven|The cardinal numeral is a whole lexical form.
eight|The cardinal numeral is a whole lexical form.
nine|The cardinal numeral is a whole lexical form.
ten|The cardinal numeral is a whole lexical form.
floor|The building-surface noun is one base.
wall|The building-part noun is one base.
shower|The washing noun is not an agent derived from show.
sink|The washing-basin noun is a whole base.
fridge|The shortened refrigerator noun remains whole; clipping is not a morpheme join.
bottle|The container noun is one modern stem.
mug|The drinking-container noun is one base.
glass|The drinking-container noun is one base, not a plural spelled ss.
dish|The food-container noun is one base.
school|The institution noun is one base.
desk|The furniture noun is one base.
paper|The material noun is not pap plus an agent suffix.
glue|The joining-substance noun is one base.
scissors|The tool name is a lexical plural retained whole, without inventing an independent cutting-tool scissor.
puppet|The borrowed toy noun is one modern stem, without a productive pupp base.
present|The gift noun is one base, not pre plus the sending verb sent.
music|The art noun is one modern base, not mus plus an adjective suffix.
circle|The shape noun is one modern stem.
square|The shape noun is one base.
heart|The symbolic-shape noun is a whole stem.
skin|The body-covering noun is one base.
wing|The bird body-part noun is one base; ing is not a suffix here.
stick|The wood-piece noun is one base.
fruit|The food-category noun is one base.
food|The nourishment noun is one base.
lunch|The meal noun is one base.
dinner|The meal noun is not a modern agent derived from dine.
day|The time noun is one base.
night|The time noun is one base.
morning|The lexical day-part noun is retained whole; it is not an ongoing action of a verb morn.
park|The vehicle-placement verb is a whole uninflected base, not the recreational-place sense.
they|The plural reference pronoun is a whole grammatical form.
us|The object pronoun is a whole case form; s is not a separate plural suffix.
him|The object pronoun is a whole case form.
her|The object pronoun is a whole case form, not he plus an agent suffix.
his|The possessive determiner is a whole grammatical form.
our|The possessive determiner is a whole grammatical form.
or|The alternative conjunction is one functional form.
these|The plural demonstrative is a whole inflected form without a separate detachable suffix.
those|The plural demonstrative is a whole inflected form without a separate detachable suffix.
who|The person interrogative is one functional form.
where|The place interrogative is one functional form.
how|The manner interrogative is one functional form.
are|The suppletive be form stays whole, without invented segments.
do|The action verb is an uninflected base.
not|The negator is one functional form.
very|The intensifier is one modern form, not ver plus y.
to|The directional or infinitival functional form is retained whole.
with|The accompaniment preposition is one functional form.
at|The place-or-time preposition is one functional form.
again|The repetition adverb is lexicalized, not the article a plus the gain verb.
there|The place adverb is one functional form.
welcome|The greeting is lexicalized; an altered well plus come analysis is not imposed on this interjection.
love|The affection verb is an uninflected base.
need|The requirement verb is an uninflected base.
feel|The sensation verb is an uninflected base.
learn|The knowledge-gaining verb is an uninflected base.
tell|The information-giving verb is an uninflected base.
try|The effort verb is an uninflected base; y is not an adjective suffix.
new|The recency adjective is one base.
nice|The evaluative adjective is one base.
story|The narrative noun is one modern stem, not stor plus an adjective suffix.
word|The language-unit noun is one base.
name|The naming noun is one base.
child|The person noun is a whole singular form.
evening|The lexical day-part noun is retained whole; it is not the action of making a surface even.
eleven|The numeral is a whole modern form; no historical left-over components are taught.
twelve|The numeral is a whole modern form; no historical two-left components are taught.
more|The irregular quantity form stays whole, without inventing a detachable comparative ending.
some|The indefinite quantity determiner is one functional form.
now|The present-time adverb is one functional form.
off|The separation preposition is one functional form.
out|The direction adverb is one functional form.
back|The rear-part noun is one base.
top|The upper-part noun is one base.
bottom|The lower-part noun is one modern stem.
meat|The food noun is one base.
lollipop|The sweet name is lexicalized; neither lolli nor the sound pop gives a transparent modern ingredient analysis.
card|The paper-object noun is one base.
picture|The image noun is one borrowed stem, without a productive pict base in this cohort.
finish|The ending-action verb is one base; ish is not an approximating suffix here.
number|The counting noun is not a comparative formed from numb.
`;

// Canonical identities represent the particular sense, not merely matching text.
const stem = (id, canonical, type = 'stem') => ({ canonical_id: `growth.${id}`, canonical, surface: canonical, type });
const affix = (id, canonical, surface) => ({ canonical_id: `english.affix.${id}`, canonical, surface, type: 'suffix' });
const y = () => affix('y.adjective', '-y', 'y');
const plural = () => affix('s.plural', '-s', 's');
const compounds = [
  ['rainbow', [stem('rain', 'rain', 'compound'), stem('part.bow.arc', 'bow', 'compound')], 'A visible colored arc associated with rain; rain and the arc sense of bow both contribute. This is not the ribbon sense of bow.', ['mw-rainbow']],
  ['classroom', [stem('class', 'class', 'compound'), stem('room', 'room', 'compound')], 'A room used by a class. Both unchanged free bases contribute to the school-room sense.', ['mw-classroom']],
  ['notebook', [stem('note', 'note', 'compound'), stem('book', 'book', 'compound')], 'The writing-book sense joins note and book, excluding the later laptop sense.', ['wiktionary-notebook']],
  ['playground', [stem('play', 'play', 'compound'), stem('ground', 'ground', 'compound')], 'Ground used for play; both bases retain the intended activity and place meanings.', ['mw-playground']],
  ['afternoon', [stem('after', 'after', 'compound'), stem('noon', 'noon', 'compound')], 'The time after noon; the two modern bases are semantically transparent and keep their full spelling.', ['mw-afternoon']],
  ['inside', [stem('in', 'in', 'compound'), stem('side', 'side', 'compound')], 'The interior-location adverb combines in and side; preserve the selected location sense rather than inventing a phrase.', ['mw-inside']],
  ['outside', [stem('out', 'out', 'compound'), stem('side', 'side', 'compound')], 'The exterior-location adverb combines out and side, preserving the selected spatial sense.', ['mw-outside']],
  ['breakfast', [{canonical_id: 'english.stem.break.end-fast', canonical: 'break', surface: 'break', type: 'compound'}, stem('part.fast.abstention', 'fast', 'compound')], 'The first meal ends an overnight fast. The second base is abstention from food, not the Growth speed adjective fast.', ['mw-breakfast']]
];
const derivatives = [
  ['angry', [stem('anger', 'anger'), y()], 'The anger adjective uses the attested anger plus -y relation; the authored result explicitly omits the unstressed e.', 'anger-plus-y-with-authored-e-loss', ['mw-angry']],
  ['thirsty', [stem('thirst', 'thirst'), y()], 'The adjective links the thirst noun with adjectival -y; the base spelling stays unchanged.', 'thirst-plus-adjective-y', ['mw-thirsty']],
  ['dirty', [stem('dirt', 'dirt'), y()], 'The adjective describes the presence of dirt; dirt and adjectival -y are both meaningful here.', 'dirt-plus-adjective-y', ['mw-dirty']],
  ['cloudy', [stem('cloud', 'cloud'), y()], 'The weather adjective joins cloud with adjectival -y; the Cambridge discussion explicitly uses this example.', 'cloud-plus-adjective-y', ['cambridge-adjective-y']],
  ['friendly', [stem('friend', 'friend'), affix('ly.adjective', '-ly', 'ly')], 'This is the adjective built on friend, not an adverb; the -ly identity is specifically adjectival.', 'friend-plus-adjective-ly', [FRAMEWORK]],
  ['closed', [stem('close', 'close'), affix('ed.participle', '-ed', 'ed')], 'The selected adjective denotes the result of closing. The participial ending is -ed; the authored spelling uses one e at the join.', 'close-plus-ed-with-authored-e-sharing', ['mw-closed']],
  ['peas', [stem('pea', 'pea'), plural()], 'The pictured food is the regular plural of pea; final -s contributes plurality.', 'pea-plus-plural-s', [FRAMEWORK]],
  ['stairs', [stem('stair', 'stair'), plural()], 'The selected noun denotes multiple steps; stair plus plural -s retains a current singular base.', 'stair-plus-plural-s', [FRAMEWORK]],
  ['has', [stem('have', 'have'), affix('s.third-person-singular', '-s', 's')], 'This is the third-person singular of have. Its irregular spelling is authored as has, never inferred by removing letters.', 'have-plus-third-person-s-with-authored-allomorph', [FRAMEWORK]],
  ['triangle', [{canonical_id: 'english.affix.tri.three', canonical: 'tri-', surface: 'tri', type: 'prefix'}, stem('angle', 'angle')], 'The shape has three angles; tri- is a numeral prefix and angle supplies the geometric base.', 'tri-plus-angle', ['mw-triangle']],
  ['dinosaur', [{canonical_id: 'english.combining.dino.awe', canonical: 'dino-', surface: 'dino', type: 'combining_form'}, {canonical_id: 'english.combining.saur.lizard', canonical: '-saur', surface: 'saur', type: 'combining_form'}], 'The established scientific formation contains dino- and -saur. The linking o stays with dino-; no claim that dinosaur taxonomy is defined by the literal historical components.', 'attested-dino-saur-combining-forms', ['mw-dinosaur']]
];

const mw = title => ({ title: `Merriam-Webster: ${title}`, author: 'Merriam-Webster editors', url: `https://www.merriam-webster.com/dictionary/${title}`, consulted: DATE, evidence: 'Dictionary sense and word history consulted; no definition text copied.' });
const sources = {
  [FRAMEWORK]: {title: 'Essentials of Linguistics, sections 6.1-6.4 and 7.1-7.3', author: 'Catherine Anderson, McMaster University', url: 'https://openlibrary-repo.ecampusontario.ca/jspui/bitstream/123456789/497/6/Essentials-of-Linguistics-1539375829.html', consulted: DATE, evidence: 'Framework for free bases, bound affixes, allomorphy, compounds and function words. Individual corpus decisions are the named reviewer\'s analysis, not a dictionary-wide endorsement.'},
  'cambridge-adjective-y': {title: "PLEASE DON'T SHOUT!", author: 'Colin McIntosh, Cambridge Dictionary', url: 'https://dictionaryblog.cambridge.org/2016/02/09/please-dont-shout/', consulted: DATE, evidence: 'Published discussion of adjectival -y, with cloudy as an explicit example.'},
  'wiktionary-notebook': {title: 'Wiktionary: notebook, English etymology and noun', author: 'Wiktionary contributors', url: 'https://en.wiktionary.org/wiki/notebook#English', consulted: DATE, evidence: 'Explicit note + book formation; the writing-book sense selected.'},
  ...Object.fromEntries(['angry', 'thirsty', 'dirty', 'closed', 'rainbow', 'classroom', 'playground', 'afternoon', 'inside', 'outside', 'breakfast', 'triangle', 'dinosaur'].map(id => [`mw-${id}`, mw(id)]))
};

// Cohort modules contain only authored decisions. The fixed list is not a
// classifier: absent decisions remain pending even when a spelling looks simple.
const cohorts = Array.from({length: 7}, (_, index) => index + 6).map(age => {
  const filename = path.join(__dirname, 'growth-morphology', `age-${String(age).padStart(2, '0')}.cjs`);
  return fs.existsSync(filename) ? require(filename)({stem, affix, FRAMEWORK, DATE}) : {};
});
for (const cohort of cohorts) Object.assign(sources, cohort.sources || {});

function decisions() {
  const result = new Map();
  const add = (id, value) => { if (result.has(id)) throw new Error(`Duplicate editorial decision: ${id}`); result.set(id, value); };
  for (const line of [atoms, ...cohorts.map(cohort => cohort.atoms || '')].join('\n').trim().split('\n').filter(line => line.trim())) {
    const [id, rationale, references = ''] = line.split('|');
    if (!id || !rationale) throw new Error('An atomic decision needs an individual rationale.');
    add(id, {kind: 'atomic', rationale, references: [FRAMEWORK, ...references.split(',').filter(Boolean)]});
  }
  for (const [id, parts, rationale, references = [], nodes] of [...compounds, ...cohorts.flatMap(cohort => cohort.compounds || [])]) add(id, {kind: 'compound', parts, rationale, references: [FRAMEWORK, ...references], rule: 'authored-compound-concatenation', nodes});
  for (const [id, parts, rationale, rule, references = [], nodes] of [...derivatives, ...cohorts.flatMap(cohort => cohort.derivatives || [])]) add(id, {kind: 'morphological', parts, rationale, rule, references: [...new Set([FRAMEWORK, ...references])], nodes});
  return result;
}

function identity(word) {
  return {id: word.id, text: word.text, min_age: word.min_age, part_of_speech: word.part_of_speech || '', meaning: word.meaning || ''};
}
function fingerprint(words) {
  return createHash('sha256').update(JSON.stringify(words.map(identity).sort((a, b) => a.id.localeCompare(b.id, 'en')))).digest('hex');
}
function build(root = ROOT) {
  const words = JSON.parse(fs.readFileSync(path.join(root, 'words.json'), 'utf8'));
  const reviewed = decisions(), known = new Set(words.map(word => word.id));
  for (const id of reviewed.keys()) if (!known.has(id)) throw new Error(`Unknown reviewed identity: ${id}`);
  const pending = new Map();
  for (const cohort of cohorts) for (const [id, reason] of Object.entries(cohort.pending || {})) {
    if (!known.has(id) || reviewed.has(id) || pending.has(id) || typeof reason !== 'string' || !reason.trim()) throw new Error(`Invalid or conflicting reopened review: ${id}`);
    pending.set(id, reason);
  }
  const ages = {}, target = path.join(root, 'data/vocabulary/morphology');
  fs.mkdirSync(target, {recursive: true});
  for (let age = 3; age <= 12; age++) {
    const entries = words.filter(word => word.min_age === age).map(word => {
      const decision = reviewed.get(word.id), entry = identity(word);
      if (!decision) return {...entry, review: {status: 'pending', reason: pending.get(word.id) || 'Individual sense, component, spelling, and source review has not been completed.'}};
      const parts = decision.kind === 'atomic' ? [{id: 'whole', canonical_id: `growth.${word.id}`, canonical: word.text, surface: word.text, type: 'atomic', break_offsets: []}] : decision.parts.map((part, i) => ({id: `part${i + 1}`, ...part, break_offsets: []}));
      const composed = decision.kind !== 'atomic';
      return {...entry, review: {status: 'reviewed', reviewer: REVIEWER, date: DATE, method: 'Individual contemporary-sense analysis with named framework and lexical evidence; no suffix inference or generated review.', rationale: decision.rationale, references: decision.references},
        analysis: {schema: 1, id: `growth.${word.id}.analysis.v1`, lexeme_id: word.id, text: word.text, kind: decision.kind, parts,
          nodes: composed ? decision.nodes || [{id: 'whole', left: 'part1', right: 'part2', surface: word.text, rule: decision.rule, break_offsets: []}] : [], roots: ['whole']}};
    });
    ages[age] = {total: entries.length, reviewed: entries.filter(entry => entry.review.status === 'reviewed').length, pending: entries.filter(entry => entry.review.status === 'pending').length};
    fs.writeFileSync(path.join(target, `age-${String(age).padStart(2, '0')}.json`), JSON.stringify({schema: 1, revision: REVISION, age, entries}, null, 2) + '\n');
  }
  const index = {schema: 1, revision: REVISION, inventory_sha256: fingerprint(words), total: words.length, context_only: words.filter(word => !word.image).length, ages, sources};
  fs.writeFileSync(path.join(target, 'index.json'), JSON.stringify(index, null, 2) + '\n');
  return index;
}
if (require.main === module) console.log(JSON.stringify(build().ages, null, 2));
module.exports = {build, decisions, identity, fingerprint};
