'use strict';
// Pending language proposals only; all examples are original local teaching text.
module.exports={
  colleague:{
    changes:{},
    meaning:'Retain the workmate definition: shared profession allows colleagues at different organizations and does not require the same employer.',
    example:'Retain the natural present-tense workplace example; it describes this colleague\'s deliveries, not a universal job duty.',
    excluded:'Coworker and workmate are contextual synonyms, not accepted spelling variants. A colleague is not necessarily an employee of the same organization.',
    observed_level:'A2',difficulty_status:'retain_A2_provisionally_supported_by_selected_topic_label',
    difficulty_note:'Oxford Working life A2 supports the current choice; this is source evidence, not independent assessment of the complete learning item.',
    sources:['oxford-colleague']
  },
  employee:{
    changes:{example:"The new employee checked next week's work schedule."},
    meaning:'Retain the ordinary paid-worker meaning, including work for an individual or organization. The definition is lexical, not a legal employment-status test.',
    example:'Replace the generic Each employee claim with one fictional action so a work schedule is not presented as an essential or universally supplied employment benefit.',
    excluded:'Worker, contractor and staff are not interchangeable legal categories or accepted spelling variants. The original example was grammatically sound; the proposed change narrows its assertion.',
    observed_level:'A2',difficulty_status:'retain_A2_provisionally_supported_by_selected_topic_label',
    difficulty_note:'Oxford Working life A2 supports the ordinary noun; employment law and source legal examples are outside this proposal.',
    sources:['oxford-employee']
  },
  employer:{
    changes:{definition:'A person or organization that has people working for them in paid jobs.',example:'My employer offered a training session for new staff.'},
    meaning:'Retain both individual and organizational referents and the paid-work relation; neutral them avoids making the pronoun it refer awkwardly to a person.',
    example:'Use a specific past offer of training rather than an apparent standing obligation. The sentence makes no universal training-duty claim.',
    excluded:'Owner, manager, supervisor and employer can refer to different people or entities. Paying for a service alone does not settle jurisdictional employer status.',
    observed_level:'A2',difficulty_status:'retain_A2_provisionally_supported_by_selected_topic_label',
    difficulty_note:'Oxford Business/Working life A2 supports the selected everyday meaning, without deciding any employment-law question.',
    sources:['oxford-employer']
  },
  supervisor:{
    changes:{definition:"A person whose job includes directing and checking other people's work."},
    meaning:'Express oversight with common work verbs, avoiding oversees and the implication that giving guidance is the sole defining action. Retain the human work role.',
    example:'Retain the concrete past-tense check of a team\'s progress; this is an ordinary work-overseeing activity.',
    excluded:'This is not an acceptance of academic-supervisor or special public-office duties. Directing work does not grant universal hiring, safety, legal or clinical authority.',
    observed_level:'C1',difficulty_status:'hold_source_C1_outside_A2_B1_B2_schema_keep_stored_A2_unaccepted',
    difficulty_note:'Oxford supervisor and supervise show selected topic C1. Collins supports meaning but supplies no usable CEFR label. Keep the existing A2 only as an unchanged provisional field; do not relabel C1 as B2 or widen the production schema in this package.',
    sources:['oxford-supervisor','oxford-supervise','collins-supervisor']
  },
  manager:{
    changes:{definition:"A person responsible for running an organization or part of it, or for organizing a group's work.",example:'The manager arranged for another employee to work the evening shift.'},
    meaning:'Include whole organizations as well as sections and work groups. Preserve the workplace person sense and distinguish it from software tools.',
    example:'Replace the less transparent arranged cover collocation with an explicit staffing action, without claiming an unobserved regional restriction on the old wording.',
    excluded:'Sports managers, entertainment representatives and software package/channel/task managers are not automatically the selected workplace sense. Manager and supervisor overlap but are not universal synonyms or a fixed hierarchy.',
    observed_level:'A2',difficulty_status:'retain_A2_provisionally_supported_by_selected_topic_label',
    difficulty_note:'Oxford sense 1 Jobs/Business/Shopping A2 supports the work-role choice. Other numbered senses or footer labels are not used.',
    sources:['oxford-manager']
  },
  team:{
    changes:{},
    meaning:'Retain people working together toward a shared aim; the workplace example and shared course context constrain the selected group sense.',
    example:'Retain Our team meets with singular agreement. Oxford also permits plural agreement; this proposal does not label that alternative an error.',
    excluded:'Sports sides, pulling animals and the informal team-someone expression are outside the selected sense. Team leader and team briefing are separate complete terms.',
    observed_level:null,difficulty_status:'retain_A2_provisionally_no_selected_working_sense_level_observed',
    difficulty_note:'No separate level was observed for Oxford working-group sense 2. Do not transfer sports A1, animal-team C2 or unrelated footer B2; exact difficulty acceptance remains open.',
    sources:['oxford-team']
  },
  department:{
    changes:{},
    meaning:'Retain a section of an organization with a particular function; this supports business as well as other institutional settings.',
    example:'Retain the concrete finance-department invoice example; it illustrates this unit\'s work and does not claim that every invoice is handled there.',
    excluded:'Dept is an abbreviation rather than an automatically accepted full-word spelling. Department head and clinical department names keep their distinct complete senses and domain boundaries.',
    observed_level:'A2',difficulty_status:'retain_A2_provisionally_supported_by_selected_topic_label',
    difficulty_note:'Selected Oxford organizational topic labels support A2; no separate geographical or other department sense is imported.',
    sources:['oxford-department']
  },
  customer:{
    changes:{},
    meaning:'Retain persons or organizations buying either goods or services. A service buyer can be called a customer; customer and client are not a goods-versus-services partition.',
    example:'Retain the delivery-date question, a natural buyer interaction. The question alone does not need to establish the timing of a completed purchase.',
    excluded:'Customer satisfaction, customer service desk and other compounds are separately authored terms. Prospect-oriented expressions do not silently expand the selected buyer definition or add assessment routes.',
    observed_level:'A1',difficulty_status:'retain_course_floor_A2_provisionally_source_label_A1_not_exact_A2_certification',
    difficulty_note:'Oxford selected Shopping/Business A1 is recorded exactly. The schema starts at A2; an easier noun can occur in an A2 course, but this observation does not certify that the headword itself is A2.',
    sources:['oxford-customer']
  },
  client:{
    changes:{definition:'A person or organization that uses professional advice or services from a person or business.',difficulty:'B1'},
    meaning:'Keep the professional-services relationship and remove ongoing as a necessary condition. A single professional consultation can have a client.',
    example:'Retain the project-update request; it is a natural service relationship without requiring a fixed duration or a legal retainer.',
    excluded:'A computing client is a different sense. Legal client conflict, client acceptance and attorney-client privilege need independent domain review; dictionary wording cannot establish representation, contractual acceptance or privilege.',
    observed_level:'B1',difficulty_status:'propose_A2_to_B1_pending_independent_acceptance',
    difficulty_note:'Oxford selected professional-advice/services sense carries Business B1. Propose B1 within the existing enum, while keeping all review gates pending. The computing C2 label is excluded.',
    sources:['oxford-client']
  },
  visitor:{
    changes:{definition:'A person who comes to a place to see someone or something for a limited time.'},
    meaning:'Keep a physical temporary visit and remove the absolute exclusion of people who normally work or live at the place; normal affiliation alone need not prevent a particular visit.',
    example:'Retain the reception sign-in example as a concrete physical visit. It illustrates a local practice and does not prescribe universal sign-in or access rights.',
    excluded:'Website visitors are a separately listed sense. Visitor badge, capacity and information center remain independent complete terms; marketing visitor groups may need a physical-versus-digital distinction.',
    observed_level:'A1',difficulty_status:'retain_course_floor_A2_provisionally_source_label_A1_not_exact_A2_certification',
    difficulty_note:'Oxford physical-visit Holidays A1 is recorded without conversion. The existing A2 is retained as a provisional course-floor choice, not a claim of exact headword-level certification.',
    sources:['oxford-visitor']
  }
};
