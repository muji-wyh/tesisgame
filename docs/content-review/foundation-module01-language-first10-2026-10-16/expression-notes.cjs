'use strict';
// Individually authored context observations. No expression is rewritten or accepted.
const rows=String.raw`
retail.equipment.07|Customer occurs inside customer service desk, a separate place term; the equipment location does not assess the Foundation buyer noun.
software_data.equipment.04|Package manager denotes a software tool; exclude this occurrence from the human work-manager sense.
foundation.module01.01|Team modifies schedule and denotes the people cooperating at work; a coordinator updates this particular schedule.
foundation.module01.02|Manager denotes a person with a work role; the appointment context does not specify a universal reporting hierarchy.
foundation.module01.03|Visitor is a physical arrival welcomed by reception; no claim is made about digital visitors or access rights.
foundation.module01.04|Employer and employee name the ordinary workplace relationship in one invitation; including contractors does not classify employment status or contractual rights.
foundation.module01.05|Supervisor denotes a work overseer; permission to change this task belongs to the fictional local arrangement and is not a universal legal power.
foundation.module01.06|Client is the possessive professional-service noun in an invitation context; the sentence does not approve a privacy or data-sharing policy.
foundation.module01.07|Colleague is a workmate and department an organizational section; other role and responsibility focuses retain their existing review requirements.
foundation.module01.09|Customer is an attributive buyer noun in customer feedback; the meeting context neither limits customers to goods nor determines commercial rights.
foundation.module02.06|Team is a work group expressly described as authorized; word meaning does not authorize a repair procedure.
foundation.module02.10|Team is the group assigned to review an incident; hazard reporting and responsibility remain under the existing domain boundary.
retail.module04.09|Customer is a buyer/service recipient asking for information; lexical fit does not approve allergen advice.
retail.module05.04|Team is the group asked to move cartons after method confirmation; no lifting or loading procedure is approved here.
retail.module05.05|Supervisor is the person performing specified local transaction actions; those powers are contextual, not essential features of every supervisor.
retail.module05.08|Supervisor denotes a work overseer consulted about records; refund and exchange decisions remain context-dependent.
retail.module05.10|Team is the people jointly promoting an event; no general authority to discount is inferred.
retail.module06.04|Customer is the buyer in a completed sale; payment mechanics are outside this selected-noun review.
retail.module06.07|Supervisor is the work role consulted about policies; the dictionary does not establish warranty or return rights.
retail.module07.06|Supervisor is the local work contact for stock-date questions; food dating and rotation meanings retain their domain review.
retail.module07.07|Customer is the buyer reporting a product issue; requesting replacement does not establish entitlement.
retail.module08.01|Supervisor is the local reporting recipient; incident-handling procedure is not approved by this lexical observation.
retail.module08.03|Colleague denotes a workmate reporting events; safety and loss-prevention processes stay separate and pending.
retail.module08.09|Supervisor is a workplace contact; age checks and counterfeit reporting require their own applicable procedures.
retail.module08.10|Customer names the service participant asking questions; no consent, privacy or accessibility rule is established.
retail.module09.09|Supervisor is the person comparing reports; no financial authority or audit certification is implied.
retail.module10.06|Customer is attributive in customer enquiries; pending enquiries do not define legal customer status.
retail.module10.08|Customer satisfaction is a complete related term; the customer constituent does not create a new Foundation assessment route.
software_data.module10.07|The possessive team denotes the project work group; its velocity and estimation method remain local specialist concepts.
nursing.module06.01|Team denotes the care workers acting together; the sentence remains subject to clinical communication review.
nursing.module07.09|Team denotes a care work group seeking appropriate advice; consent and capacity rules are not approved here.
nursing.module08.07|Team denotes the care group reviewing separately named events; event classification remains outside this noun check.
nursing.module10.04|Multidisciplinary team is a related complete term whose human-group constituent fits; participation and care planning are not approved.
nursing.module10.07|Team is the group discussing care options with the person; lexical fit does not recommend an option.
nursing.module10.10|Team denotes the work group reviewing resources and accountability; staffing or supervision standards are not set here.
caregiving.module10.10|Team denotes a specifically qualified group; the lexical observation does not explain or approve a care plan.
food_service.module03.10|Supervisor denotes the authorized work overseer; equipment checks still require the applicable local process.
food_service.module06.09|Manager denotes the person responsible for the complaint referral; no particular complaint outcome is implied.
food_service.module08.07|Supervisor is the local work contact for requirements; recall and age-verification rules remain outside this language slice.
food_service.module10.10|Customer satisfaction is a related service-evaluation compound; the whole term retains its own review.
customer_support.module03.05|Customer portal is a separate digital service-area term containing the buyer/service-user constituent.
customer_support.module03.07|Customer service desk is a separate service-place term; a chatbot is not being called a customer.
customer_support.module04.02|The possessive customer identifies the person or organization with the subscription; current contractual terms are not verified here.
customer_support.module05.04|Supervisor is the person organizing request work; the listed actions illustrate a local role rather than universal authority.
customer_support.module06.01|Customer is the service participant whose meaning is checked; communication-quality claims remain outside this noun observation.
customer_support.module06.09|Customer is the service participant discussing access needs; interpreter availability and accommodations remain contextual.
customer_support.module08.10|Team is the group assigned to review quality matters; no product recall or risk-assessment procedure is approved.
customer_support.module09.01|Customer profile is a separate information-record term; the constituent retains buyer/service-user meaning without approving data collection.
customer_support.module09.02|Customer is the service participant who might repeat information; no record-access permission follows from the word.
customer_support.module09.06|Customer occurs in relationship-management and data compounds; the dashboard is software, while customer still identifies the business relationship.
customer_support.module10.01|Team leader is a related complete role term; its team constituent names a working group and does not merge the role with team.
customer_support.module10.07|Customer effort score and customer satisfaction are complete survey terms; the selected noun does not validate their measures.
customer_support.module10.08|Customer needs refers to buyer/service-user needs; capacity and service metrics retain their own meanings and review.
office_admin.module03.10|Facilities team denotes a work group with a specific function; electrical or workspace changes are not authorized here.
office_admin.module04.10|Records manager is a complete specialized human role; the required form of a certified copy is not determined by this review.
office_admin.module05.04|Records manager remains a specialized human role; the text does not grant the reviewer authority to redact or archive records.
office_admin.module05.10|Manager is the person coordinating the described work; delegation and escalation responsibilities remain local.
office_admin.module08.01|Visitor badge is a separate identification object whose visitor constituent is physical; possession does not imply access authorization.
office_admin.module08.06|Records manager denotes the human records role; retention periods and holds remain subject to separate requirements.
office_admin.module10.02|Office manager denotes a specialized human role; the question leaves approval authority to the actual arrangements.
office_admin.module10.03|Records manager is the human role reviewing storage; the sentence allocates local questions without defining universal duties.
warehouse_logistics.module03.02|Supervisor is the work contact for assignment and authorization; equipment operation is not authorized by the noun.
warehouse_logistics.module05.03|Team is a work group explicitly described as authorized; storage and loading details remain context-specific.
warehouse_logistics.module05.04|Team denotes the group handling shipments; no consolidation or sorting procedure is certified.
warehouse_logistics.module05.05|Team denotes a trained work group comparing instructions; palletization procedures retain separate review.
warehouse_logistics.module05.07|Team denotes an authorized work group deciding under an approved instruction; packaging safety is outside this lexical check.
warehouse_logistics.module05.08|Quality team is the working group assigned to stock decisions; segregation and quarantine authority is contextual.
warehouse_logistics.module05.09|Team denotes people who may dispatch items once arrangements are confirmed; the word does not release held stock.
warehouse_logistics.module05.10|Supervisor and team are human work roles in a local instruction; authorization, recounting and reconciliation remain distinct issues.
warehouse_logistics.module06.01|Customer order is a separate goods-request term with the buyer constituent; the review does not confirm the order or pick list.
warehouse_logistics.module08.05|Supervisor is the local contact for authorization; ergonomic concerns and equipment competence are not assessed here.
warehouse_logistics.module08.07|Visitor badge uses the physical-visitor constituent and explicitly limits access; retain the independent badge and authorization meanings.
warehouse_logistics.module10.04|Warehouse supervisor is a specialized human work role; the complete role remains distinct from the Foundation noun.
warehouse_logistics.module10.05|Supervisor is the person asked about assigned qualified operation; the dictionary establishes no operating permission.
warehouse_logistics.module10.10|Team denotes the work group agreeing to a milestone; staffing capacity and dependencies remain local facts.
hospitality_tourism.module03.10|Team is the group receiving equipment questions; no room-safe or lock operation is approved.
hospitality_tourism.module05.03|Team denotes the people responsible for the update; escalation and response arrangements remain local.
hospitality_tourism.module06.06|Manager denotes the human work role reviewing a booking issue; no overbooking remedy is established.
hospitality_tourism.module07.06|Visitor capacity is a complete operational quantity term containing physical visitor; no numerical or safety capacity is accepted.
hospitality_tourism.module07.07|Visitor information center is a complete service-place term for physical visitors; the center is not itself a visitor.
hospitality_tourism.module08.01|Team is the responsible working group for queries; property and incident-record processes remain unapproved.
hospitality_tourism.module08.07|Team is a qualified working group; lexical fit does not validate allergen, chemical or PPE guidance.
hospitality_tourism.module09.02|Channel manager is room-distribution software in the captured lexeme, not a human manager; exclude it from the Foundation person sense.
hospitality_tourism.module10.03|Housekeeping supervisor is a specialized human work role; referral illustrates one local arrangement.
hospitality_tourism.module10.04|Duty manager is a specialized human role during an assigned period; service-recovery powers remain context-dependent.
hospitality_tourism.module10.07|Revenue manager is a specialized human role; rate decisions and planning authority are not accepted here.
transport_delivery.module03.03|Maintenance team is a working group receiving a damage report; no repair or vehicle-use judgment is made.
transport_delivery.module05.02|Team denotes the assigned loading group; the instruction retains its existing operational review.
transport_delivery.module05.04|Team denotes people working together under a plan; load-security methods are not approved by this word review.
transport_delivery.module05.05|Team is an authorized group handling dispatch; allocation and sealing procedures remain contextual.
transport_delivery.module05.10|Recovery team denotes the work group assessing a tow; the word does not establish towing safety or permission.
transport_delivery.module08.06|Customer is the service participant with an accessibility request; applicable adjustment duties are not determined here.
transport_delivery.module10.04|Customer and its possessive form identify the service recipient; customer satisfaction remains a separate complete term.
transport_delivery.module10.07|Fleet manager is a specialized human work role; fleet availability is an illustrative local fact.
transport_delivery.module10.10|Team leader is a complete human role referring to a working group; assignment of follow-up work remains local.
it_support.module04.06|Network team's possessive denotes the human work group; protocols and DNS review are independent technical topics.
it_support.module05.04|Team denotes people cooperating on testing; no test adequacy or technical diagnosis is approved.
it_support.module05.09|Security team is a human working group; its permission to scan the device depends on actual arrangements.
it_support.module08.02|Team denotes the group assigned to review certificate details; certificate validity is not assessed here.
it_support.module08.07|Security team is a human work group; quarantine and security response retain separate technical review.
it_support.module09.08|Task manager is a software view/tool in the captured lexeme, not a human work-manager; exclude this literal match from the selected sense.
it_support.module10.03|Customer satisfaction is a complete service-evaluation term; the customer constituent is not newly scored.
education_childcare.module07.09|Team denotes the work group discussing a child's needs with family; no dietary or allergy advice is accepted.
education_childcare.module08.01|Team is a working group reviewing risks under actual arrangements; safety judgments remain outside this noun review.
education_childcare.module08.07|Team denotes the people discussing support needs; legal or educational categories remain context-bound.
education_childcare.module10.07|Team briefing is a separate meeting/communication term whose team constituent names workers acting together.
hr_recruitment.module04.04|Hiring manager is a specialized human role; involvement in a vacancy does not grant universal hiring authority.
hr_recruitment.module04.05|Department denotes each organizational section counted in the report; the figures themselves are not verified.
hr_recruitment.module04.09|Employee representative is a separate role term; employee meaning alone cannot settle representative status or powers.
hr_recruitment.module05.05|Colleagues is the regular plural of workmate; the sentence does not require every colleague to have the same employer or legal status.
hr_recruitment.module07.03|Employee assistance program is a complete service term; its scope, confidentiality and entitlements require their own review.
hr_recruitment.module07.04|Employee handbook is a separate guide term containing the worker noun; no policy's validity follows from this lexical fit.
hr_recruitment.module08.08|Employee is the ordinary paid-worker noun in a support request; medical and legal classifications are not made.
hr_recruitment.module09.03|Employee record and employee number are separate information terms; their presence does not approve data access or employment classification.
hr_recruitment.module09.05|Employee self-service is a separate system-function term; the employee constituent does not grant permissions.
hr_recruitment.module10.01|Line manager is a specialized human reporting role; the planning example does not define legal employer status.
hr_recruitment.module10.09|Employee forum and employee voice are separate participation terms; the selected noun does not establish consultation rights.
construction_trades.module03.06|Lifting-equipment team denotes a responsible working group; no equipment inspection or lifting authorization is accepted.
construction_trades.module03.09|Finishing team's possessive refers to the work group requesting materials; no operational specification is approved.
construction_trades.module04.07|Trade teams is the regular plural of work group; the sentence delegates questions without certifying trade work.
construction_trades.module05.03|Team denotes an as-yet-identified work group; the question does not authorize cutting, drilling or finishing operations.
construction_trades.module05.10|Team denotes people asked to organize returned items; the phrase remains an existing operational draft.
construction_trades.module07.06|Team denotes the responsible work group receiving a utility concern; underground or overhead service safety is not settled.
construction_trades.module10.01|Site supervisor is a specialized human work role; drawing revision confirmation remains an assigned local duty.
construction_trades.module10.04|Supervisor denotes a work overseer distinct from the assigned mentor; no universal authority or training qualification is inferred.
construction_trades.module10.10|Client acceptance is a complete contractual/project term; client retains a service-customer constituent without approving legal acceptance or occupancy requirements.
cleaning_facilities.module03.06|Team denotes the cleaning work group needing another time window; access and service rules remain local.
cleaning_facilities.module04.02|Client denotes the recipient of a cleaning service asking a product question; neither an ongoing relationship nor a legal classification is required.
cleaning_facilities.module07.08|Responsible team's possessive denotes a work group for the water-system question; no repair procedure is accepted.
cleaning_facilities.module10.01|Housekeeping supervisor is a specialized human role; the reporting arrangement is local and distinct from caretaker responsibilities.
cleaning_facilities.module10.02|Facilities manager and building manager are specialized human roles, expressly bounded by assigned responsibilities.
cleaning_facilities.module10.04|Team leader is a separate coordinating role for a work group; staffing and allocation judgments are outside this check.
cleaning_facilities.module10.09|Customer satisfaction is a complete evaluation term; customer includes service buyers and is not restricted to purchasers of goods.
cleaning_facilities.module10.10|Team briefing is a separate communication event; the group constituent fits without approving induction or competence requirements.
manufacturing_maintenance.module03.06|Electrical team denotes a human work group; possession or reservation of equipment does not confer competence.
manufacturing_maintenance.module03.08|Team denotes the group whose responsibility is being asked about; inspection ownership and robot safety remain unresolved local matters.
manufacturing_maintenance.module03.10|Team denotes an authorized work group receiving questions; the function or use of an emergency stop is not approved here.
manufacturing_maintenance.module05.04|Team denotes the work group to be identified for installation tasks; no dismantling or installation method is certified.
manufacturing_maintenance.module05.07|Finishing team denotes workers performing a specific function; the question does not approve lubrication, calibration or surface processes.
manufacturing_maintenance.module10.07|Cross-functional team is a complete group term whose team constituent has the workplace meaning; process-improvement claims remain separate.
manufacturing_maintenance.module10.10|Customer requirement is a complete specification term containing the buyer noun; contract requirements and escalation evidence are not verified.
sales_marketing.module03.08|Visitors physically inspect packaging in a cabinet; this concrete place context supports the physical-visit reading without adding a focus.
sales_marketing.module03.10|Customer identifies the participant in a business video conference; remote communication does not turn the noun into a computing-client sense.
sales_marketing.module05.02|Customer's possessive identifies the buyer/service relationship; a recommendation need not prove a completed sale and no advice quality is accepted.
sales_marketing.module05.04|Team denotes the planning work group; cost and campaign evaluation remain outside the selected-noun review.
sales_marketing.module05.06|Customers is the buyer noun in a survey group; campaign targeting and data handling are not accepted by this lexical observation.
sales_marketing.module05.09|The demonstration context permits physical visitors but does not explicitly fix its channel; interested customers may still be prospects. Retain without binding either background match to a new scored sense.
sales_marketing.module05.10|Customers may refuse an additional offer; the wording does not prove a completed transaction for every person. Retain the existing hypothetical buying context without widening the selected definition.
sales_marketing.module06.03|Customer denotes the service participant considering terms; subscription and guarantee rights require independent review.
sales_marketing.module06.04|Customer's possessive identifies the commercial participant; the sentence does not decide the objection or contractual delivery obligation.
sales_marketing.module06.06|Customer denotes the buyer/service participant in a discovery conversation; a product demonstration is not a completed sale.
sales_marketing.module06.09|Customer denotes the participant choosing whether to continue a service; cancellation rights are not assessed here.
sales_marketing.module07.02|Creative team is a specialized work-group term; editorial or publicity approval is outside the noun check.
sales_marketing.module07.06|Visitor group occurs in conversion-rate reporting; physical versus website visitors is not fixed. Exclude automatic binding to the Foundation physical-visitor sense.
sales_marketing.module10.03|Customer satisfaction and customer retention are distinct complete relationship terms; neither becomes a new Foundation route.
sales_marketing.module10.04|Account manager is a specialized human relationship role, not a software tool; the next step remains a local plan.
sales_marketing.module10.05|Marketing manager is a human organizational role; campaign-system changes still need actual approval.
sales_marketing.module10.07|Customer insight and creative team are separate complete terms whose buyer and working-group constituents fit; their whole meanings remain independently pending.
clinical_medicine.module07.08|Team denotes the clinical work group; diagnostic conclusions remain explicitly provisional and outside this lexical review.
clinical_medicine.module08.10|Team denotes the work group reviewing an error report; no clinical reporting framework is approved here.
accounting_finance.module05.07|Customer is the buyer/service recipient to be invoiced; payment terms and entitlement to funds are not established.
accounting_finance.module09.10|Customers are the commercial parties owing amounts in the example; receivable recognition and accounting treatment require separate review.
legal_paralegal.module04.06|Supervisor is the local human work overseer confirming archive timing; no universal legal authority or retention rule is inferred.
legal_paralegal.module07.07|Team denotes the legal work group, which explicitly has not verified the property matters; lexical fit does not validate title or covenant.
legal_paralegal.module08.03|Client conflict is a complete professional-duty term; the client constituent fits but conflict rules and representation status remain unapproved.
legal_paralegal.module08.04|Attorney-client privilege is a specialized legal compound; client is a service-relationship constituent, not approval of privilege scope or cross-jurisdiction equivalence.
legal_paralegal.module10.10|Team briefing is a separate work communication term; progress and handover procedure remain within existing review gates.
`.trim().split('\n').map(line=>{const i=line.indexOf('|');return ['expr.'+line.slice(0,i),line.slice(i+1)];});
if(new Set(rows.map(([id])=>id)).size!==rows.length)throw new Error('Duplicate individual expression note');
module.exports=Object.fromEntries(rows);
