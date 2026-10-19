'use strict';

// Authoring counterpart of learning_content_resolver.gd. A sense needs its own
// distinct-spelling, compatible witness, not merely a valid pool elsewhere.
function spelling(word) {
  return (word.display_text ?? word.text ?? '').toLowerCase().split(' ').filter(Boolean).join(' ');
}

function compatibilityGraph(words) {
  const labels = words.map(spelling);
  const exclusions = words.map(word => new Set(word.media.image.confusable_with || []));
  const bits = words.map((_, index) => 1n << BigInt(index));
  const adjacent = words.map(() => 0n);
  for (let first = 0; first < words.length; first++) {
    for (let second = first + 1; second < words.length; second++) {
      if (labels[first] && labels[first] === labels[second] ||
        exclusions[first].has(words[second].id) || exclusions[second].has(words[first].id)) continue;
      adjacent[first] |= bits[second];
      adjacent[second] |= bits[first];
    }
  }
  return {bits, adjacent};
}

function canComplete(graph, candidates, needed) {
  if (candidates.length < needed) return false;
  if (needed <= 1) return true;
  // Each color contains mutually incompatible senses. A compatible witness
  // needs a different color for every member, so fewer colors proves failure.
  // Reaching the requested count only stops pruning; it never proves a witness.
  const colors = [];
  for (const candidate of candidates) {
    const color = colors.findIndex(mask => (graph.adjacent[candidate] & mask) === 0n);
    if (color >= 0) colors[color] |= graph.bits[candidate];
    else {
      colors.push(graph.bits[candidate]);
      if (colors.length >= needed) return true;
    }
  }
  return false;
}

function minimumPool(graph, candidates, needed) {
  if (!canComplete(graph, candidates, needed)) return [];
  for (let index = 0; index <= candidates.length - needed; index++) {
    const anchor = candidates[index];
    if (needed === 1) return [anchor];
    const remaining = candidates.slice(index + 1).filter(candidate =>
      (graph.adjacent[anchor] & graph.bits[candidate]) !== 0n);
    const tail = minimumPool(graph, remaining, needed - 1);
    if (tail.length === needed - 1) return [anchor, ...tail];
  }
  return [];
}

function pictureReachableIds(words, minimum) {
  const reachable = new Set();
  if (minimum <= 1) return new Set(words.map(word => word.id));
  if (words.length < minimum) return reachable;
  const graph = compatibilityGraph(words);
  const candidates = words.map((_, index) => index);
  if (!canComplete(graph, candidates, minimum)) return reachable;
  for (const anchor of candidates) {
    if (reachable.has(words[anchor].id)) continue;
    const remaining = candidates.filter(candidate => words[candidate].id !== words[anchor].id &&
      (graph.adjacent[anchor] & graph.bits[candidate]) !== 0n);
    const witness = minimumPool(graph, remaining, minimum - 1);
    if (witness.length === minimum - 1) {
      reachable.add(words[anchor].id);
      for (const candidate of witness) reachable.add(words[candidate].id);
    }
  }
  return reachable;
}

function modulePictureRoutes(module, lexemes) {
  const words = module.lexeme_ids.map(id => lexemes.get(id)).filter(Boolean);
  return new Map(['match', 'memory', 'jelly', 'pop'].map(mode => [mode,
    pictureReachableIds(words.filter(word => word.practice_modes.includes(mode) &&
      word.media.image.picture_suitable), ['match', 'memory'].includes(mode) ? 5 : 1)]));
}

module.exports = {pictureReachableIds, modulePictureRoutes};
