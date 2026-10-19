// These decisions concern the exact age-twelve senses, not spelling patterns.
module.exports = ({stem, affix, DATE}) => {
  const c = (id, text = id) => stem(id, text, 'compound');
  const prefix = (id, canonical, surface) => ({canonical_id: `english.affix.${id}`, canonical, surface, type: 'prefix'});
  const combining = (id, canonical, surface) => ({canonical_id: `english.combining.${id}`, canonical, surface, type: 'combining_form'});
  const root = (id, canonical, surface) => ({canonical_id: `english.root.${id}`, canonical, surface, type: 'root'});
  const plural = () => affix('s.plural', '-s', 's');
  const atoms = `
meteor|The celestial-object name is a whole modern borrowing; its historical Greek elevated-in-the-air construction is not taught as an English meter or meteo compound.|mw-meteor
galaxy|The astronomical noun is a lexical whole. Its historical Greek milk metaphor does not turn the current collection of stars into an English gal plus axy formation.|mw-galaxy
satellite|The orbiting-object noun is one current base; its Latin attendant history does not create detachable English sat or lite components.|mw-satellite
cymbal|The percussion-instrument name is one borrowed base; bal is not a current musical suffix.
glacier|The moving-ice noun is a whole borrowing; its final er does not make it the agent of an English glaci verb.
peninsula|The landform name is borrowed whole from Latin. Its historical almost-island description does not create modern English pen and insula bases.|mw-peninsula
canyon|The steep-sided valley name is a whole borrowed stem with no detachable English ending.
geyser|The hot-water-spring name is a whole borrowing; it is not an agent noun formed from a gey action.
avalanche|The falling-snow mass is named by one borrowed base; dividing its syllables would not supply meaningful current components.
stalactite|The cave-deposit name is a whole scientific borrowing. Its historical dripping root is not a free English stalact base plus a general mineral suffix in this learner analysis.|mw-stalactite
fossil|The preserved-organism noun is one current base; its final il is not an English suffix.
nebula|The astronomical cloud noun keeps its complete borrowed singular form; final a is not an English plural marker.
eclipse|The astronomical obscuring event is one lexical base; clip does not describe its internal morphology.
universe|The whole-cosmos noun is lexicalized; modern verse in the poetry sense would give a false compound meaning.
capsule|The enclosed-compartment noun is one current base; the modern headwear noun cap is not its constituent sense.
accordion|The instrument name is borrowed from German. Its naming relation to musical accord does not make final ion the ordinary English action-noun suffix here.|mw-accordion
clarinet|The wind-instrument name is one borrowed stem; its historical diminutive is not recast as an English clarin plus et operation.
trombone|The brass-instrument name is a whole borrowing; bone is not the anatomical noun within this musical term.
harmonica|The reed-instrument noun is borrowed from an Italian harmonious adjective; its final a is not an English instrument suffix.|mw-harmonica
compass|The direction-finding instrument is one current base; pass as an English movement verb does not explain this lexicalized noun.
abacus|The counting-frame noun is a complete borrowed singular form; us is not a plural ending to remove.
refrigerate|The food-cooling verb is one current base. Its historical intensive re- and Latin cooling verb do not mean repeating a modern English frigerate action.|mw-refrigerate
opaque|The light-blocking adjective is one borrowed stem, with no detachable English aque ending.
transparent|The see-through adjective is kept whole in this learner analysis. Its historical appear-root is not the English family noun parent after trans-.|mw-transparent
diagonal|The slanting-direction adjective is a whole current base. Its Greek angle history does not supply an English diagon word to which ordinary -al is attached.|mw-diagonal
parallel|The equal-distance adjective is lexicalized from Greek beside-one-another elements; allel is not presented as a free English geometric base.|mw-parallel
vertical|The up-and-down adjective is kept whole. Its historical summit-related vertex base is not substituted with the current corner sense of geometric vertex.|mw-vertical
acute|The small-angle adjective is one current base, distinct in sense from the medical and perceptual uses.
obtuse|The greater-than-right-angle adjective is a whole borrowed base; ob and tuse are not current free English shape words.
scalene|The unequal-sided triangle adjective is a whole borrowed base; it does not contain the weighing scale noun or a productive ene suffix.|mw-scalene
atom|The matter-unit noun is one modern base. The historical uncut meaning must not falsely teach that a physical atom is indivisible.|mw-atom
friction|The resistance-between-surfaces noun is one current scientific base; a free frict action is not invented from its ion spelling.
gravity|The Earth-attraction noun is lexicalized; joining the modern serious adjective grave with -ity would teach a different sense.
circuit|The electrical-path noun is one current base; its Latin going-around history does not establish separate English cir and cuit words.
flask|The laboratory-container noun is one stem with no affix.
algebra|The mathematics-domain name is a whole Arabic borrowing; its historical article is not a productive English al prefix.
rhombus|The equal-sided quadrilateral name preserves its complete borrowed singular form; us is not an English ending to strip.
trapezoid|The selected quadrilateral noun is lexicalized. A contemporary circus trapeze is not its semantic base, despite the historical table-related family.|mw-trapezoid
pyramid|The solid-shape noun is one borrowed base; mid is not the current middle component within it.
prism|The geometric-solid noun is one borrowed stem with no detachable English suffix.
fraction|The part-of-a-whole number noun is a lexicalized scientific base; it is not formed from a current free English fract verb in this learner analysis.
boccia|The target-ball sport name is borrowed whole from Italian; its ending is not an English plural operation.
bridle|The horse-guiding equipment noun is one base, distinct from the wedding-related bridal adjective.
celeriac|The root-vegetable name is a lexicalized formation. Its relation to celery does not supply a productive English ac suffix for constructing vegetable names.
macadamia|The nut name is a lexicalized botanical eponym; the personal-name origin does not make mac and adamia current food components.
margarine|The vegetable-oil spread noun is one established coined food name; ine alone does not justify inventing a free margar base.
meringue|The egg-white confection name is one borrowed base; its final sound is not the English progressive -ing ending.
muesli|The oat-mixture noun is borrowed whole; its Swiss German diminutive history is not an English li suffix.
quiche|The savory-pastry noun is one borrowed base with no meaningful English internal join.
swede|The root-vegetable noun is a lexicalized shortened name; no current compound is reconstructed inside its remaining letters.
petticoat|The underskirt name is lexicalized. Its historical small-coat formation does not use the current disparaging sense of petty or denote a modern outer coat.|mw-petticoat
evaluate|The evidence-based judgment verb is retained whole. Its attested back-formation from evaluation does not justify inventing a productive e prefix plus valuate for this learner sense.|mw-evaluate
analyze|The parts-examining verb is a whole lexical base. Its documented back-formation from analysis is not a concatenative ana plus lyze exercise or a productive spelling rule.|mw-analyze
strategy|The goal-directed plan noun is one borrowed base; its historical military roots do not supply current strate and gy English components.
`;
  const compounds = [
    ['spacesuit', [c('part.space.outer-space', 'space'), c('part.suit.clothing', 'suit')], 'The protective outfit is a suit for outer space; both free bases retain those particular meanings.'],
    ['hourglass', [c('hour'), c('part.glass.material', 'glass')], 'The traditional sand timer combines the hour duration with its glass material; the second base is not a drinking container.'],
    ['northeast', [c('north'), c('east')], 'The intermediate direction combines the north and east compass directions.'],
    ['northwest', [c('north'), c('west')], 'The intermediate direction combines the north and west compass directions.'],
    ['southeast', [c('south'), c('east')], 'The intermediate direction combines the south and east compass directions.'],
    ['southwest', [c('south'), c('west')], 'The intermediate direction combines the south and west compass directions.']
  ];
  const derivatives = [
    ['telescope', [combining('tele.distant', 'tele-', 'tele'), combining('scope.examine', '-scope', 'scope')], 'The viewing instrument contains the documented distant and observing-instrument combining forms.', 'tele-distant-plus-scope', ['mw-telescope']],
    ['asteroid', [root('aster.star', 'aster', 'aster'), affix('oid.resembling', '-oid', 'oid')], 'The name records the historically starlike appearance through the star root and resemblance suffix. The stored object remains a small celestial body, not a star.', 'aster-star-plus-oid', ['mw-asteroid', 'mw--oid']],
    ['xylophone', [combining('xylo.wood', 'xylo-', 'xylo'), combining('phone.sound', '-phone', 'phone')], 'The instrument name contains the documented wood and sound-producing instrument elements, referring to its struck wooden bars.', 'xylo-wood-plus-phone', ['mw-xylophone']],
    ['saxophone', [{...stem('part.sax.person', 'Sax'), surface: 'sax'}, combining('phone.sound', '-phone', 'phone')], 'The instrument name uses its inventor Sax and the sound-instrument form. The surname has an explicitly lowercase sax realization; it is distinct from the later instrument-name clipping sax.', 'sax-person-plus-phone-with-lowercase-name', ['mw-saxophone']],
    ['supernova', [prefix('super.greater', 'super-', 'super'), stem('part.nova.stellar-outburst', 'nova')], 'The astronomical name joins super- to nova to distinguish an enormously more energetic stellar event; the current supernova meaning remains intact.', 'super-greater-plus-nova', ['mw-supernova']],
    ['metronome', [combining('metro.measure', 'metro-', 'metro'), root('nom.regulate', 'nom', 'nome')], 'The tempo-regulating device contains the documented measure and regulating elements. The final nome realization is explicitly authored, and metro is not a city railway here.', 'metro-measure-plus-nom-authored-nome', ['mw-metronome']],
    ['microscope', [prefix('micro.small', 'micro-', 'micro'), combining('scope.examine', '-scope', 'scope')], 'The instrument makes tiny objects observable; the documented small prefix combines with the observing-instrument form.', 'micro-small-plus-scope', ['mw-microscope']],
    ['binoculars', [prefix('bi.two', 'bi-', 'bi'), stem('part.ocular.eye-related', 'ocular'), plural()], 'The paired viewing instrument contains two-related bi- and eye-related ocular. The established noun uses plural -s after the complete binocular stem.', 'bi-ocular-plus-instrument-plural', ['mw-binocular', 'mw-ocular'], [
      {id: 'binocular', left: 'part1', right: 'part2', surface: 'binocular', rule: 'bi-two-plus-ocular', break_offsets: []},
      {id: 'whole', left: 'binocular', right: 'part3', surface: 'binoculars', rule: 'binocular-plus-plural-s', break_offsets: []}
    ]],
    ['permeable', [stem('part.permeate.pass-through', 'permeate'), affix('able.capable', '-able', 'able')], 'The material permits water to permeate it. The permeate family and capability suffix are retained with the explicitly authored perme- realization before -able.', 'permeate-plus-able-authored-perme', ['mw-permeable', 'mw-permeate']],
    ['horizontal', [stem('part.horizon.level-line', 'horizon'), affix('al.relating', '-al', 'al')], 'The level direction is parallel to the horizon. The exact horizontal result records the horizont- stem realization before -al, without inferring an inserted letter at runtime.', 'horizon-plus-al-authored-horizont', ['mw-horizontal']],
    ['isosceles', [combining('iso.equal', 'iso-', 'iso'), root('skel.leg', 'skel', 'sceles')], 'The attested equal-leg formation refers to equal sides of the triangle. The borrowed sceles realization of the leg root is authored explicitly rather than presented as a free English word.', 'iso-equal-plus-skel-authored-sceles', ['mw-isosceles']],
    ['atmosphere', [combining('atmo.vapor', 'atmo-', 'atmo'), stem('part.sphere.envelope', 'sphere')], 'The documented vapor and sphere formation names the gaseous envelope surrounding Earth; its modern meaning includes the full gas mixture, not only water vapor.', 'atmo-vapor-plus-sphere', ['mw-atmosphere']],
    ['pipette', [stem('part.pipe.tube', 'pipe'), affix('ette.diminutive', '-ette', 'ette')], 'The liquid-transfer instrument has the documented small-pipe formation. The exact pipette spelling shares the final e of pipe with the diminutive ending.', 'pipe-plus-ette-e-sharing', ['mw-pipette', 'mw--ette']],
    ['tripod', [prefix('tri.three', 'tri-', 'tri'), combining('pod.foot', '-pod', 'pod')], 'The three-legged support contains the documented three prefix and foot combining form, not pod in the seed-container sense.', 'tri-three-plus-pod-foot', ['mw-tripod']],
    ['scales', [stem('part.scale.weighing-device', 'scale'), plural()], 'The weighing instrument uses the attested scale noun and plural -s; its base is distinct from the skin covering of a fish.', 'weighing-scale-plus-plural-s', ['mw-scales']],
    ['hexagon', [combining('hexa.six', 'hexa-', 'hexa'), combining('gon.angle-figure', '-gon', 'gon')], 'The six-sided figure contains the documented six and angle-figure elements; hexa keeps its combining vowel.', 'hexa-six-plus-gon', ['mw-hexagon', 'mw--gon']],
    ['heptagon', [combining('hepta.seven', 'hepta-', 'hepta'), combining('gon.angle-figure', '-gon', 'gon')], 'The seven-sided figure contains the documented seven and angle-figure elements, with the full hepta combining form.', 'hepta-seven-plus-gon', ['mw-heptagon', 'mw--gon']],
    ['octagon', [combining('octa.eight', 'octa-', 'octa'), combining('gon.angle-figure', '-gon', 'gon')], 'The eight-sided figure contains the documented eight and angle-figure forms; no octopus base is substituted.', 'octa-eight-plus-gon', ['mw-octagon', 'mw--gon']],
    ['pentagon', [combining('penta.five', 'penta-', 'penta'), combining('gon.angle-figure', '-gon', 'gon')], 'The five-sided figure joins the documented five and angle-figure elements, retaining its shape sense rather than a building name.', 'penta-five-plus-gon', ['mw-pentagon', 'mw--gon']],
    ['quadrilateral', [prefix('quadri.four', 'quadri-', 'quadri'), stem('part.lateral.side-related', 'lateral')], 'The four-sided shape contains four-related quadri- and side-related lateral, preserving the geometric noun sense.', 'quadri-four-plus-lateral', ['mw-quadrilateral', 'mw-lateral']],
    ['parallelogram', [stem('parallel', 'parallel'), combining('gram.line', '-gram', 'gram')], 'The shape has parallel opposite sides. The documented line element is distinct from the weight unit gram, and the connecting o is included in the authored whole output.', 'parallel-plus-gram-line-with-connecting-o', ['mw-parallelogram']],
    ['percent', [stem('part.per.for-each', 'per'), root('cent.hundred', 'cent', 'cent')], 'The quantity is measured for each hundred. The attested per-cent formation uses the hundred root, not a coin worth one hundredth of a dollar.', 'per-each-plus-cent-hundred', ['mw-percent']],
    ['photocopier', [combining('photo.light', 'photo-', 'photo'), stem('copy', 'copy'), affix('er.agent-instrument', '-er', 'er')], 'The machine makes a photocopy. Photo- supplies the light-related process, copy supplies the duplication action, and instrument -er forms copier with y changed to i.', 'photo-plus-derived-copier', ['mw-photocopier', 'mw-photocopy'], [
      {id: 'copier', left: 'part2', right: 'part3', surface: 'copier', rule: 'copy-plus-er-y-to-i', break_offsets: []},
      {id: 'whole', left: 'part1', right: 'copier', surface: 'photocopier', rule: 'photo-plus-copier', break_offsets: []}
    ]],
    ['athletics', [stem('part.athlete.sports-person', 'athlete'), affix('ics.activities', '-ics', 'ics')], 'The sports domain is associated with athletes. The documented activity-domain suffix -ics takes the athlet- realization; this is not the ordinary plural of athlete.', 'athlete-plus-ics-e-loss', ['mw-athletics', 'mw-athletic', 'mw--ics']],
    ['rosette', [stem('rose', 'rose'), affix('ette.diminutive', '-ette', 'ette')], 'The ribbon award has a rose-like decorative shape. The attested rose and diminutive formation uses one shared e in the exact rosette output.', 'rose-plus-ette-e-sharing', ['mw-rosette', 'mw--ette']],
    ['stirrups', [stem('part.stirrup.saddle-foot-support', 'stirrup'), plural()], 'The saddle foot supports use the attested complete singular stirrup plus plural -s; the opaque historical stair-and-rope formation is not reconstructed.', 'stirrup-plus-plural-s', ['mw-stirrup']],
    ['justify', [stem('part.just.reasonable', 'just'), affix('ify.make-show', '-ify', 'ify')], 'The answer-supporting verb means to show an answer just or reasonable through reasons; the just base is not the time adverb meaning recently.', 'just-reasonable-plus-ify', ['mw-justify']],
    ['sustainable', [stem('part.sustain.maintain', 'sustain'), affix('able.capable', '-able', 'able')], 'The practice can be sustained without depleting resources; sustain and capability -able retain the stored environmental-continuity sense.', 'sustain-plus-able', ['mw-sustainable']],
    ['conclusion', [stem('part.conclude.infer', 'conclude'), affix('ion.result', '-ion', 'ion')], 'The judgment is the result of concluding from evidence. The attested verb family has an explicitly authored conclus- realization before -ion, retaining the inference sense rather than merely an ending.', 'conclude-plus-ion-authored-conclus', ['mw-conclusion', 'mw-conclude']]
  ];
  const evidence = {
    meteor: 'The modern astronomical sense and historical Greek elevated-in-the-air formation were checked.',
    galaxy: 'The stellar-system sense and historical Greek milk-related source were checked.',
    satellite: 'The orbiting-object sense and Latin attendant origin were checked.',
    telescope: 'The distant-viewing instrument and tele plus observing-root history were checked.',
    asteroid: 'The small celestial body and historical star-resemblance formation were checked.',
    saxophone: 'The instrument name is traced to the inventor Sax and the sound element; modern sax is not its original independent base.',
    xylophone: 'The wooden-bar instrument and the explicitly described wood plus sound-instrument formation were checked.',
    peninsula: 'The landform sense and Latin almost-island history were checked.',
    stalactite: 'The cave-deposit sense and historical dripping-root source were checked.',
    supernova: 'The stellar explosion is distinguished from a nova by its much greater energy.',
    accordion: 'The bellows instrument and German formation from musical accord plus a naming ending were checked.',
    metronome: 'The tempo device is traced to measure and regulating elements.',
    harmonica: 'The free-reed instrument and Italian harmonious-adjective origin were checked.',
    microscope: 'The magnifying instrument and small plus observing-instrument history were checked.',
    binocular: 'The two-eye adjective and normally plural viewing-instrument noun were checked.',
    ocular: 'The eye-related adjective and eye-root history were checked.',
    refrigerate: 'The cooling verb is traced to a Latin cooling formation with re-.',
    permeable: 'The definition relates the adjective to being permeated, including passage through pores.',
    permeate: 'The current verb includes passage through pores or openings.',
    transparent: 'The light-transmitting sense and historical appear-root were checked, excluding the family-parent noun.',
    diagonal: 'The slanting geometric sense and Greek angle-related history were checked.',
    horizontal: 'The level adjective is related to the horizon; the recorded spelling includes the extended horizont stem.',
    parallel: 'The equal-distance sense and historical beside-one-another formation were checked.',
    vertical: 'The up-and-down sense and historical summit-related vertex source were checked.',
    isosceles: 'The equal-sided triangle adjective is traced to equal and leg elements.',
    scalene: 'The triangle with unequal side lengths and the Greek uneven source were checked.',
    atom: 'The chemical-unit sense and historical uncut formation were checked without asserting modern indivisibility.',
    atmosphere: 'The gaseous envelope and vapor plus sphere formation were checked.',
    pipette: 'The narrow liquid-transfer instrument is traced to French pipe with a diminutive ending.',
    tripod: 'The three-legged stand is traced to three and foot elements.',
    scales: 'The weighing-instrument scale noun and its plural usage were checked.',
    hexagon: 'The six-angle figure and its six plus angle formation were checked.',
    heptagon: 'The seven-angle figure and its seven plus angle formation were checked.',
    octagon: 'The eight-angle figure and its eight plus angle formation were checked.',
    pentagon: 'The five-angle figure and its five plus angle formation were checked.',
    quadrilateral: 'The four-sided sense and four plus side-related formation were checked.',
    lateral: 'The side-related adjective and Latin side-root source were checked.',
    parallelogram: 'The opposite-parallel-side shape and historical parallel plus line formation were checked.',
    trapezoid: 'The selected quadrilateral sense and the historical table-related source were checked.',
    percent: 'The out-of-one-hundred sense is traced to per plus the Latin hundred word.',
    photocopier: 'The copying machine is explicitly related to photocopy plus the agent or instrument ending.',
    photocopy: 'The document-copy sense is associated with a light-based copying process.',
    athletics: 'The noun covers sports and the practice or principles of athletic activities.',
    athletic: 'The adjective relates to athletes and their activities.',
    rosette: 'The rose-shaped ribbon badge and French rose plus diminutive history were checked.',
    stirrup: 'The saddle foot support and its lexicalized historical formation were checked.',
    petticoat: 'The modern underskirt and historical small-coat naming relation were checked.',
    evaluate: 'The judgment verb is described as a back-formation from evaluation.',
    justify: 'The verb includes showing something to be just, right or reasonable.',
    analyze: 'The parts-examining verb has a documented probable back-formation from analysis, not a simple current suffix join.',
    sustainable: 'The adjective means capable of being sustained and includes resource-preserving practice.',
    conclusion: 'The reasoned judgment noun is related to conclude, with the Latin conclus stem recorded in its history.',
    conclude: 'The current verb includes reaching a judgment by reasoning from evidence.',
    '-oid': 'The suffix denotes resemblance or the appearance of a specified object.',
    '-ette': 'The suffix has a diminutive sense and a documented French origin.',
    '-gon': 'The angle-figure combining form is distinguished from the separate generative-root homograph.',
    '-ics': 'The noun suffix denotes a field of practice or characteristic activities, with -ic plus -s in its history.'
  };
  const sources = Object.fromEntries(Object.entries(evidence).map(([word, checked]) => [`mw-${word}`, {
    title: `Merriam-Webster: ${word}`, author: 'Merriam-Webster editors',
    url: `https://www.merriam-webster.com/dictionary/${word}`, consulted: DATE, evidence: checked
  }]));
  return {atoms, compounds, derivatives, sources};
};
