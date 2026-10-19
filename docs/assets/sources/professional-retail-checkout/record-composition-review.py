from pathlib import Path
import hashlib
import json
from PIL import Image

base = Path(__file__).resolve().parent
output = base / 'ranked-composition-review.json'
if output.exists():
    raise RuntimeError('Preserve the existing review')
def sha(file):
    return hashlib.sha256(file.read_bytes()).hexdigest()
def image_record(relative):
    file = base / relative
    image = Image.open(file).convert('RGBA')
    return {'path': relative, 'sha256': sha(file), 'rgba_pixel_sha256': hashlib.sha256(image.tobytes()).hexdigest(), 'dimensions': list(image.size), 'bytes': file.stat().st_size}

report_file = base / 'composition-probe/report.json'
report = json.loads(report_file.read_text())
recommended = report['probes'][0]
review = {
    'date': '2026-10-16',
    'sense_id': 'checkout.payment-area.n',
    'status': 'author_ranked_recommendation_pending_independent_root_image_review',
    'scope': 'Scoped AI picture review of original-source scratch probes only. No human, domain, curriculum, production delivery or module-readiness claim.',
    'aggregate_native_status': {'passed': False, 'checks': 72, 'failed': 2, 'failure_reason': 'Both tiled variants extend their floor to the viewport sides; complete-scene checks failed. The full r01 aggregate remains failed and is preserved.', 'failed_checks': [c for c in report['checks'] if not c['passed']], 'source_and_production_guards_unchanged': True, 'receipt_sha256': sha(base / 'composition-native-receipt.json'), 'report_sha256': sha(report_file)},
    'inspected': {'full_composition_images': 4, 'native_word_card_contacts': 4, 'card_states_per_composition': 4, 'method': 'Viewed every 512px composition and every actual 704x250 native WordCard contact, then compared all four full composition images and contacts together.'},
    'ranking': [
        {'rank': 1, 'name': 'compact-three-quarter', 'decision': 'recommend_as_final_candidate_basis', 'reason': 'Largest and clearest useful checkout group among the technically intact probes. Shopper on the goods side and green-uniformed employee behind the terminal frame a single station. The dark belt, terminal, carton and apple remain visible. No observed body/station penetration or implausible hand contact in this view. The real matched badge remains to the right of the group.', 'limits': 'At Match the fitted image is 67.75x52 within the 102x52 picture area. Grocery details are small; recognition depends on the whole interaction and equipment together. Matched alpha reduces contrast. This is scoped visual judgment, not a measured recognition study.'},
        {'rank': 2, 'name': 'compact-high', 'decision': 'retain_as_alternative_not_selected', 'reason': 'All local technical checks pass, and the lane stays coherent. More top-down projection makes the group taller and reduces its fitted Match width to 61.77px, making the roles and groceries smaller than the first view.'},
        {'rank': 3, 'name': 'tiled-three-quarter', 'decision': 'reject_current_probe', 'reason': 'The complete floor is clipped by the viewport. The floor fills substantial card area and reduces the scale of staff, shopper and station without adding a necessary meaning cue.'},
        {'rank': 4, 'name': 'tiled-high', 'decision': 'reject_current_probe', 'reason': 'The complete floor is clipped by the viewport; the top-down floor competes with the payment station and crowds the useful content further.'}
    ],
    'meaning_check': {'selected_meaning': 'The place in a store where purchases are paid for.', 'place_not_lone_object': 'One whole belt-and-terminal station connects a shopper presenting groceries with an employee on the staff side.', 'counter_distinction': 'The accepted counter image is a broad surface and parcel; this image adds payment equipment, grocery presentation and staff/customer roles.', 'cash_register_distinction': 'The station and interaction are the subject; no claim that the isolated machine has visible physical keys or a drawer base.', 'exclusions': 'No hotel/reception cues, readable words, brand marks, payment credentials, detached device close-up, invented geometry or replacement materials.'},
    'recommended_image': image_record('composition-probe/compact-three-quarter/checkout.png'),
    'recommended_card_crops': [image_record('composition-probe/compact-three-quarter/' + state + '.png') for state in ['match-unmatched', 'match-matched', 'memory-unmatched', 'memory-matched']],
    'contact_artifacts': [image_record('composition-probe/composition-contact.png'), image_record('composition-probe/all-native-word-card-contacts.png')],
    'next_step': 'Root independently reviews the exact compact-three-quarter pixels and phone contacts. If accepted, preserve failed r01 and prepare an isolated final candidate/QA revision using the same source arrangement and camera before production delivery. No further native run without a separate root slot grant.',
    'production_mutations': False,
}
output.write_text(json.dumps(review, indent=2) + '\n')
print(json.dumps({'review_sha256': sha(output), 'recommended_image': review['recommended_image'], 'contact_artifacts': review['contact_artifacts']}, indent=2))
