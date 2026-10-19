'use strict';

// Independent lexical judgments after direct source and complete context reading.
const source = (key, url, level, section, observation) => ({
  source_id: 'foundation01-language-second10-' + key, url,
  consulted_on: '2026-10-16', access: 'fresh_direct_web_open_selected_passages',
  observed_selected_sense_level: level, section, independent_observation: observation,
  assets_acquired: false, asset_license: null
});
const oxford = (word, level, section, observation, suffix = word) => source('oxford-' + word,
  'https://www.oxfordlearnersdictionaries.com/definition/english/' + suffix, level, section, observation);
exports.sources = [
  oxford('contractor', null, 'Contracted provider noun, selected entry and examples', 'The entry covers an individual or company engaged under contract for work or supply. The repair example is within this sense. No selected level was visible; the separate rotating footer is excluded.'),
  oxford('trainee', 'B2', 'Job learner noun; Education and Jobs topic labels', 'The person receives instruction for a job. This supports the revised definition and working-with-a-colleague example. Both selected topic labels show B2.'),
  oxford('receptionist', 'A2', 'Arrivals and telephone inquiries role; Holidays and Jobs topic labels', 'The role handles arriving people and phone callers at workplaces. The front-desk example illustrates the ordinary role without specifying every duty. Both selected labels show A2.'),
  oxford('coordinator', null, 'Organizer noun and British spelling note', 'The role brings activity parts and participants together. British co-ordinator is explicitly listed. No selected CEFR label was visible; a footer label belongs to another word.'),
  oxford('contact', null, 'Sense 4 person; separate communication, touching and point-of-contact passages', 'The countable person sense involves someone known who can assist in work. Communication, physical touch and exposed-person senses are separate. Point of contact permits a place or person. No selected person-level label was visible.', 'contact_1'),
  oxford('supplier', null, 'Goods-provider noun', 'The selected noun covers a person or company supplying goods. It does not require the recipient to be an organization. The selected entry supplies no observed CEFR label; services-only providers are outside this chosen goods sense.'),
  oxford('schedule', 'A2', 'Sense 1 work timing plan; separate timetable and written-list senses', 'The selected plan organizes work by time and has Working life A2. Regional labels attached to school or transport timetable senses are not transferred. Financial written lists remain a separate sense.', 'schedule_1'),
  oxford('shift', 'B1', 'Sense 1 period of work and Business topic label', 'The selected work period is associated with alternating workers and has Business B1. The worker-group noun and change senses are separate. Its examples permit ordinary individual references to a shift.', 'shift_1'),
  oxford('appointment', 'B1', 'Sense 1 arranged meeting or visit; Healthcare and Working life labels', 'The selected arrangement concerns meeting or visiting at a set time. Its two topic labels are B1. Appointment to a job is a separate sense and cannot supply evidence for this entry.'),
  oxford('meeting', 'A1', 'Sense 1 discussion or decision event; Working life and Business labels', 'The selected event involves discussion or decisions and explicitly includes virtual meetings. Both selected labels are A1. Participant-group, encounter and other meanings do not replace this event sense.'),
  source('collins-contact', 'https://www.collinsdictionary.com/dictionary/english/contact', 'B1+', 'COBUILD sense 10 countable helpful person', 'The selected person in an organization or profession can help or provide information and is marked B1+. The A2 communication verb and B1 communication noun are separate. B1+ is retained literally.'),
  source('merriam-shift', 'https://www.merriam-webster.com/dictionary/shift', null, 'Main noun sense 4b(2), with neighboring group and rotation senses distinguished', 'The selected work-or-duty period is scheduled. This independently supports the author wording without requiring the definition to assert a replacement group. No CEFR evidence is supplied.'),
  source('collins-shift', 'https://www.collinsdictionary.com/dictionary/english/shift', 'B2', 'COBUILD sense 6 work periods and worker groups', 'The selected passage describes recurring work periods and the groups working them, marked B2. It differs from the Oxford B1 observation. Neither frequency bands nor unrelated verb uses are used for level selection.')
];

const rows = [
  ['contractor','contractor.contracted-worker.n','4f6ec0efd0ca9b8f2ca9f1970ac6b567492a4809a28986b4d236d1437cd58653','A2',
    'A person or business engaged to carry out work under a contract.', 'The contractor will repair the office lighting.',
    'Retain the contracted-work role. The repair sentence gives one comprehensible work task; it says nothing about employment classification or permission to undertake electrical work.',
    'Independent A2 placement for this narrowly illustrated practical role: a concrete repair task and simple future sentence introduce who will do agreed work. No selected source CEFR was observed, and contract law is not part of this learning item.'],
  ['trainee','trainee.learner-worker.n','90604b7f38911cb12f5608e9713d52333cd3d299cfa4bf4e3d0296bbfcf6cbad','B2',
    'A person who is being trained for a particular job.', 'The trainee is working alongside an experienced colleague.',
    'Accept the refinement from someone learning generally to a person receiving job training. Working alongside a colleague is a natural example, not a definition of employment or training status.',
    'Accept B2 for the role-specific learning item, supported by the selected Oxford Education and Jobs B2 observations. This is editorial placement rather than certification of every example word.'],
  ['receptionist','receptionist.front-desk-worker.n','1eb80dd9c38f3e64f69562011adef87b1718dfff52371b7084332ec1deff3cb8','A2',
    'A person who welcomes visitors and handles inquiries at a front desk.', 'The receptionist called the meeting organizer.',
    'Accept the concise front-desk role and its natural completed call. The definition need not enumerate phone duties or all reception settings.',
    'Accept A2 for the familiar reception role, supported by the selected Oxford Holidays and Jobs A2 labels and a short concrete example.'],
  ['coordinator','coordinator.organizer.n','ce3e79bd65b8ee12bb0c8a11e2b5878af4776431a6177951c6a178a513e32c40','B1',
    'A person who organizes activities so that people and tasks work together.', 'The coordinator confirmed the training times.',
    'The definition and example correctly identify an organizing person without inventing a management hierarchy. The British co-ordinator spelling is valid source evidence, but the exact candidate omits it from protected accepted_forms.',
    'Resolve the level question at B1 by independent editorial judgment: coordinating several people or tasks is a less concrete relationship than a front-desk role, but the training-times example makes it accessible. No Oxford CEFR certification is claimed.'],
  ['contact','contact.helpful-person.n','3c45d8dccf6135cb6d0cc500650209b494acaac704e0d3879c0d50ea9c68d7a6','B2',
    'A person who can provide information, help, or a connection to an organization.', 'Our main contact is the project coordinator.',
    'Accept the helpful-person definition. The explicit project coordinator fixes the example to a person, unlike a channel or contact-details phrase.',
    'Choose editorial B2 for this professional-relationship sense: learners must distinguish a useful person from the very common communication verb, information and physical-contact meanings. The explicit-person example supports this bounded upper course placement. Collins remains B1+ literally; B2 is a curriculum decision, not a claimed conversion of B1+ or a new source label.'],
  ['supplier','supplier.goods-provider.n','ae508d67fa10c89e4f2ea38ecb809e6e950353dc0e52ffe2dc44933cb32f9977','A2',
    'A person or organization that provides goods or materials.', 'The supplier confirmed that the order had been sent.',
    'Accept removal of the organizational-recipient restriction. Goods and materials remain the intended scope, with a dispatched order as the example; the term does not identify the courier.',
    'Independent A2 placement for the concrete goods-provider role in routine ordering. No selected source CEFR was observed. The example uses a richer reported past-passive construction, but the editorial field places the selected noun, not a formal CEFR rating of the entire sentence.'],
  ['schedule','schedule.time-plan.n','fb97ddd2f62349a22376bc6e48cb437e8fe6da6d2c395645843435d479a59f9b','A2',
    'A plan showing when activities are expected to happen.', 'The schedule includes a short team meeting.',
    'Accept the activity-time plan and concrete meeting example. The meaning includes routine work plans, with no financial-table or verb-sense transfer.',
    'Accept A2, supported by Oxford selected Working life A2 and the ordinary activity-and-time meaning. Preserve general region because the selected sense has no North-American-only restriction.'],
  ['shift','shift.work-period.n','b06035853573d72e8cf21ed7cfe27b1c90146ca380720a8712754e11fece3c47','B1',
    'A period of time when a person or group is scheduled to work.', 'My shift starts at seven tomorrow morning.',
    'Accept the individual-or-group scheduled work period. The clear start-time example is natural; a break can occur within a shift. Neither uninterrupted work nor an immediately replacing group is required by this wording.',
    'Choose editorial B1 for the bounded work-period noun with a simple start-time example. Oxford directly attaches B1 to this period, while Collins B2 covers the period and worker group together; retain that disagreement. The selected teaching task omits the group metonym and figurative changes, which makes B1 defensible. This is not averaging source labels.'],
  ['appointment','appointment.arranged-meeting.n','0bfd474d1d6a522c988e86e9b24fd96bd3fa657f4e9a47c46a2a57016b0c4295','B1',
    'An arrangement to meet someone or receive a service at a particular time.', 'The appointment is booked for Thursday afternoon.',
    'Accept the arranged visit or meeting sense and the natural booked-time example. Receiving a service fits the workplace setting; appointment to a job is excluded.',
    'Accept B1, supported by Oxford selected Healthcare and Working life B1. Clinical service outcomes and the separate job-appointment sense remain outside the selected language decision.'],
  ['meeting','meeting.work-discussion.n','c32fc272ee904d2399be0b27fdfd41b94d07182804682134ad41d80c50d44684','A2',
    'An arranged gathering where people discuss matters or make decisions.', 'The meeting will last twenty minutes.',
    'Accept the discussion-or-decision event and its duration example. A gathering may be virtual or hybrid, consistent with the source; neither a meeting point nor platform access alone supplies the event meaning.',
    'Accept the A2 course floor for this foundational event word. The observed Oxford label stays A1, and an A1 word can be included in an A2 curriculum. This does not relabel the source or claim the noun intrinsically requires A2.']
];
exports.decisions = rows.map(([word,id,author_hash,editorial_level,definition,example,wording,level_basis]) => ({
  word,id,author_hash,editorial_level,definition,example,wording,level_basis,
  full_language_gate:word==='coordinator'?'hold_pending_spelling':'accept_scoped_ai_language',
  independent_refinement:['contact','shift'].includes(word),
  spelling:word==='coordinator'?{
    decision:'British co-ordinator is independently verified as a spelling alternative. Do not accept the complete coordinator-only candidate under the specification instruction to accept reviewed British variants.',
    observed_alternative:'co-ordinator', observed_region:'British English',
    candidate_forms_preserved:['coordinator'], recommended_future_forms:['coordinator','co-ordinator'],
    required_next_step:'A separately scoped and guarded accepted_forms amendment must be independently bound by root; this review neither adds the variant nor certifies normalization or exercise behavior.'
  }:{decision:'Retain the exact standard headword spelling and general region label. No synonym, inflection or abbreviation is introduced as an answer.'},
  scope_limit:'Ordinary language evidence only. No employment status, legal duties, clinical procedure, safety competence, specialist compound, morphology, media, entire expression, module or release acceptance.'
}));

exports.extraSupplierHolds = [
  'expr.office_admin.module07.10','expr.office_admin.module10.04',
  'expr.accounting_finance.module05.07','expr.accounting_finance.module09.10'
];
exports.contextNotes = {
  'expr.foundation.module01.01':'The human coordinator adjusts an activity schedule. Existing selected focuses fit the text; coordinator spelling remains a separate entry hold.',
  'expr.foundation.module01.02':'The work period contains a break and precedes a booked manager meeting. Both existing selected senses fit, and the shift definition must permit breaks.',
  'expr.foundation.module01.03':'A receptionist welcomes and introduces a visitor; the role meaning is clear. The expression does not grant access or information-sharing authority.',
  'expr.foundation.module01.04':'The contracted worker or representative is invited to a discussion meeting. The invitation does not classify employment or alter contractor obligations.',
  'expr.foundation.module01.07':'Colleague and the role-questions context identify contact as a helpful person. The author level hold is resolved in separate entry evidence, with no expression acceptance.',
  'expr.foundation.module01.09':'The deliveries context supports a goods supplier update in this selected-focus example. This contextual reading does not narrow every other supplier occurrence to goods.',
  'expr.office_admin.module07.10':'Unit prices, quotes, orders and discounts can concern services as well as goods. The expression does not fix the supplier as the selected goods provider; preserve it without adding that binding.',
  'expr.office_admin.module10.04':'A procurement supplier proposal could concern goods or services. The finance contact is a separate complete role; preserve both without inferring the goods-provider binding or purchase permission.',
  'expr.accounting_finance.module05.07':'Invoicing, paying and receiving funds do not distinguish a goods supplier from a service provider. Keep that sense question open; this review makes no accounting claim.',
  'expr.accounting_finance.module09.10':'Amounts payable can be owed for services as well as goods, and this sentence does not specify the purchase. The selected goods-provider sense must not be asserted merely from suppliers.',
  'expr.office_admin.module10.08':'Alternative contact in an automatic reply may name a person, team, mailbox or route. Preserve the author binding hold and all privacy scope.',
  'expr.sales_marketing.module10.09':'The checklist does not identify the point of contact as a human. Preserve the person-versus-route hold and complete term.',
  'expr.hr_recruitment.module10.02':'Case owner explicitly fixes this point of contact to a person, unlike the campaign checklist. The complete role and limits remain independent.',
  'expr.manufacturing_maintenance.module05.06':'A machining work package may be provided by a goods supplier or a service-only contractor. Retain the author scope hold and avoid a new goods-provider binding.',
  'expr.manufacturing_maintenance.module05.08':'Fabrication and machining do not establish whether the provider sells goods or only performs work. Retain the author hold, with no design or operating approval.',
  'expr.accounting_finance.module09.07':'The complete amortization and loan entries identify supporting financial tables. Their temporal dimension does not make either the selected activity-time plan.',
  'expr.accounting_finance.module10.08':'The existing complete payment schedule is a timetable; the time-plan constituent is compatible. Credit risk and payment terms remain separate financial matters.',
  'expr.hospitality_tourism.module07.05':'A tour meeting point is a rendezvous location. It does not establish the planned discussion or decision event.',
  'expr.legal_paralegal.module09.09':'The meeting link is platform access for a hearing. Preserve the access term and legal event without inferring a work-discussion binding.',
  'expr.office_admin.module06.09':'The hybrid event includes remote people; gathering in the selected definition does not require one physical room.',
  'expr.food_service.module08.02':'Allergen cross-contact concerns physical transfer, not the person who helps with workplace questions.',
  'expr.hospitality_tourism.module08.07':'Allergen cross-contact is a separate physical-transfer meaning. The qualified guidance request and all safety questions remain unchanged.',
  'expr.cleaning_facilities.module06.05':'Contact time describes product-surface interaction. Exclude the helpful-person noun and preserve the product-specific guidance requirements.',
  'expr.customer_support.module03.09':'The first contact is a verb and the second is part of contact center. Neither binds the selected person noun.',
  'expr.education_childcare.module07.06':'Both literal occurrences concern information; one references the independent emergency-contact role. Neither information phrase itself denotes the selected helpful person.'
};
exports.categoryNotes = {
  focus:'The existing selected focus fits this bounded workplace meaning; preserve its exact binding and pending expression gates.',
  background:'An ordinary workplace reading is compatible, but background compatibility alone does not prove a unique referent or add a scored binding.',
  compound:'The selected word is a constituent of an independent complete term. Preserve its whole meaning, role or record and every existing gate.',
  verb:'This literal contact is a communication verb and cannot score the helpful-person noun.',
  communication:'This occurrence concerns communication information, an event, preference or means; exclude the helpful-person noun.',
  verb_and_communication:'Both contact occurrences are outside the selected person sense: a communication verb and an operation compound.',
  physical:'This is physical interaction or transfer, not a helpful person; preserve the complete specialist identity.',
  ambiguous:'The referent could be a person or communication route. Hold exact person-sense binding.',
  mixed_info_role:'Communication details and information about an emergency-contact role remain information phrases, not direct person-noun bindings.',
  rendezvous:'The meeting-point location is not the selected discussion event.',
  financial_schedule:'The complete financial schedules are tables, not the selected activity-time plan.',
  platform_access:'A link names access to a hearing platform; this does not establish a work-discussion event.',
  supplier_scope:'The text leaves goods-provider versus service-only scope unresolved. No new goods-supplier binding.'
};
