
'use strict';

const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const {validateDependencies, bundleInventory} = require('../web/professional-media.js');
const {themeMotionErrors} = require('./validate-theme-motion.cjs');
const {modulePictureRoutes} = require('./professional-picture-pools.cjs');

const COURSE_IDS = [
  'caregiving', 'retail', 'food_service', 'nursing', 'customer_support',
  'office_admin', 'warehouse_logistics', 'hospitality_tourism', 'transport_delivery',
  'construction_trades', 'cleaning_facilities', 'education_childcare',
  'manufacturing_maintenance', 'it_support', 'software_data', 'accounting_finance',
  'sales_marketing', 'hr_recruitment', 'clinical_medicine', 'legal_paralegal'
];
const ROOT = path.resolve(__dirname, '..');
const MEDIA_KEYS = ['path', 'sha256', 'source', 'creator', 'license'];
const PICTURE_MODES = new Set(['match', 'memory', 'pop', 'jelly']);
const DOMAIN_COURSES = new Set(['caregiving', 'food_service', 'customer_support', 'office_admin', 'warehouse_logistics', 'hospitality_tourism', 'transport_delivery', 'it_support', 'education_childcare', 'hr_recruitment', 'construction_trades', 'cleaning_facilities', 'manufacturing_maintenance', 'sales_marketing', 'nursing', 'clinical_medicine', 'accounting_finance', 'legal_paralegal']);

function resourcePath(rootDir, resource) {
  if (typeof resource !== 'string' || !resource.startsWith('res://') || /[\\?#:]/.test(resource.slice(6))) {
    throw new Error('Expected a local res:// resource path');
  }
  const root = path.resolve(rootDir);
  const resolved = path.resolve(root, resource.slice(6));
  if (!resolved.startsWith(root + path.sep)) throw new Error('Resource escapes the repository');
  if (fs.existsSync(resolved)) {
    const real = fs.realpathSync(resolved);
    const realRoot = fs.realpathSync(root);
    if (!real.startsWith(realRoot + path.sep)) throw new Error('Resource resolves outside the repository');
  }
  return resolved;
}

function loadProfessionalContent(rootDir = ROOT) {
  const read = resource => JSON.parse(fs.readFileSync(resourcePath(rootDir, resource), 'utf8'));
  const catalog = read('res://data/professional/catalog.json');
  const data = {catalog, themes: read(catalog.themes).profiles, sources: read(catalog.sources).sources,
    courses: [], lexemes: [], expressions: [], lexemeOrigins: {}, expressionOrigins: {}};
  for (const item of catalog.courses) data.courses.push(read(item.manifest));
  for (const [key, origins, resources] of [
    ['lexemes', 'lexemeOrigins', catalog.lexeme_files],
    ['expressions', 'expressionOrigins', catalog.expression_files]
  ]) {
    for (const resource of resources) {
      const envelope = read(resource);
      if (envelope.schema_version !== 1 || !Array.isArray(envelope[key])) throw new Error('Invalid envelope: ' + resource);
      for (const entry of envelope[key]) {
        data[key].push(entry);
        data[origins][entry.id] = resource;
      }
    }
  }
  return data;
}

// The contracts use this deliberately small JSON Schema subset. Unknown validation
// keywords fail rather than silently producing a weaker release check.
function schemaErrors(value, schemaName, schemaDir = path.join(ROOT, 'data/professional/schemas'), cache = new Map()) {
  const read = file => {
    if (!cache.has(file)) cache.set(file, JSON.parse(fs.readFileSync(path.join(schemaDir, file), 'utf8')));
    return cache.get(file);
  };
  const supported = new Set(['$schema', '$id', '$defs', '$ref', 'type', 'const', 'enum', 'anyOf',
    'properties', 'required', 'additionalProperties', 'items', 'uniqueItems', 'minItems', 'maxItems',
    'minLength', 'pattern', 'minimum', 'maximum', 'description', 'title']);
  const equal = (a, b) => JSON.stringify(a) === JSON.stringify(b);
  function visit(item, schema, pointer, file) {
    const errors = [];
    const fail = message => errors.push(pointer + ': ' + message);
    for (const key of Object.keys(schema)) if (!supported.has(key)) fail('Unsupported schema keyword ' + key);
    if (schema.$ref) {
      const [target, fragment] = schema.$ref.split('#');
      const nextFile = target || file;
      if (!/^[a-z-]+\.schema\.json$/.test(nextFile)) return [pointer + ': Invalid schema reference'];
      let targetSchema = read(nextFile);
      if (fragment) for (const segment of fragment.slice(1).split('/')) targetSchema = targetSchema?.[segment];
      if (!targetSchema) return [pointer + ': Missing schema reference'];
      return errors.concat(visit(item, targetSchema, pointer, nextFile));
    }
    if (schema.anyOf && !schema.anyOf.some(candidate => visit(item, candidate, pointer, file).length === 0)) {
      fail('Does not match any permitted schema'); return errors;
    }
    if (Object.hasOwn(schema, 'const') && !equal(item, schema.const)) fail('Unexpected constant value');
    if (schema.enum && !schema.enum.some(option => equal(item, option))) fail('Value is outside the permitted enum');
    const actual = item === null ? 'null' : Array.isArray(item) ? 'array' : typeof item;
    const types = schema.type ? [].concat(schema.type) : [];
    if (types.length && !types.some(type => type === actual || type === 'integer' && Number.isInteger(item))) {
      fail('Expected ' + types.join(' or ') + ', received ' + actual); return errors;
    }
    if (typeof item === 'string') {
      if (schema.minLength && [...item].length < schema.minLength) fail('String is empty or too short');
      if (schema.pattern && !new RegExp(schema.pattern, 'u').test(item)) fail('String does not match its pattern');
    }
    if (typeof item === 'number') {
      if (schema.minimum !== undefined && item < schema.minimum) fail('Number is below minimum');
      if (schema.maximum !== undefined && item > schema.maximum) fail('Number is above maximum');
    }
    if (Array.isArray(item)) {
      if (schema.minItems !== undefined && item.length < schema.minItems) fail('Too few items');
      if (schema.maxItems !== undefined && item.length > schema.maxItems) fail('Too many items');
      if (schema.uniqueItems && new Set(item.map(x => JSON.stringify(x))).size !== item.length) fail('Duplicate items');
      if (schema.items) item.forEach((child, index) => errors.push(...visit(child, schema.items, pointer + '/' + index, file)));
    } else if (item && typeof item === 'object') {
      for (const key of schema.required || []) if (!Object.hasOwn(item, key)) fail('Missing required property ' + key);
      for (const [key, child] of Object.entries(item)) {
        if (schema.properties?.[key]) errors.push(...visit(child, schema.properties[key], pointer + '/' + key, file));
        else if (schema.additionalProperties === false) fail('Unexpected property ' + key);
      }
    }
    return errors;
  }
  return visit(value, read(schemaName + '.schema.json'), '$', schemaName + '.schema.json');
}

function morphologyErrors(analysis, entry) {
  const errors = [], parts = analysis?.parts || [], nodes = analysis?.nodes || [];
  const fail = message => errors.push(message);
  if (!analysis) return ['Morphology has not been authored'];
  if (analysis.lexeme_id !== entry.id || analysis.text !== entry.text) fail('Morphology identity or text differs from the lexeme');
  const entries = new Map(), intervals = new Map(), used = new Set();
  parts.forEach((part, index) => {
    if (entries.has(part.id)) fail('Duplicate graph ID ' + part.id);
    entries.set(part.id, part); intervals.set(part.id, [index, index]);
  });
  for (const node of nodes) {
    if (entries.has(node.id)) fail('Duplicate graph ID ' + node.id);
    entries.set(node.id, node);
  }
  for (const item of entries.values()) {
    let previous = 0;
    for (const offset of item.break_offsets || []) {
      if (!Number.isInteger(offset) || offset <= previous || offset >= [...item.surface].length) fail('Invalid break offset in ' + item.id);
      previous = offset;
    }
  }
  const visiting = new Set();
  function walk(id) {
    used.add(id);
    if (!entries.has(id)) { fail('Unknown graph reference ' + id); return null; }
    if (intervals.has(id)) return intervals.get(id);
    if (visiting.has(id)) { fail('Cyclic composition graph at ' + id); return null; }
    visiting.add(id);
    const node = entries.get(id), left = walk(node.left), right = walk(node.right);
    visiting.delete(id);
    if (!left || !right) return null;
    if (left[1] + 1 !== right[0]) { fail('Composition reorders, overlaps, or skips parts at ' + id); return null; }
    const interval = [left[0], right[1]]; intervals.set(id, interval); return interval;
  }
  for (const root of analysis.roots || []) {
    const interval = walk(root);
    if (!interval || interval[0] !== 0 || interval[1] !== parts.length - 1) fail('Root does not cover all parts in order');
    if (entries.get(root)?.surface !== entry.text) fail('Root does not produce the exact displayed term');
  }
  if (!(analysis.roots || []).length) fail('Composition graph has no root');
  for (const id of entries.keys()) if (!used.has(id)) fail('Graph element is unreachable: ' + id);
  if (analysis.kind === 'atomic' && (parts.length !== 1 || nodes.length !== 0)) fail('An atomic analysis must have one part and no merges');
  if (analysis.kind !== 'atomic' && (parts.length < 2 || nodes.length < 1)) fail('A multipart analysis needs parts and a composition');
  if (parts.some(part => part.type === 'combining_form') && analysis.review?.status === 'reviewed' && !analysis.review.references?.length) {
    fail('Reviewed classical combining forms require references');
  }
  return errors;
}

function auditProfessionalContent({rootDir = ROOT, release = false, data} = {}) {
  rootDir = path.resolve(rootDir);
  const errors = [], warnings = [];
  const add = (code, at, message, strict = true) => (strict ? errors : warnings).push({code, path: at, message});
  try { data ||= loadProfessionalContent(rootDir); }
  catch (error) { return {ok: false, errors: [{code: 'load.invalid', path: 'data/professional', message: error.message}], warnings, summary: {release_ready: false}}; }
  const schemaDir = path.join(rootDir, 'data/professional/schemas');
  const schemaCache = new Map();
  const schema = (value, name, at) => {
    try { for (const message of schemaErrors(value, name, schemaDir, schemaCache)) add('schema.invalid', at, message); }
    catch (error) { add('schema.invalid', at, error.message); }
  };
  schema(data.catalog, 'catalog', 'catalog');
  for (const [list, name] of [[data.courses, 'course'], [data.themes, 'theme'], [data.lexemes, 'lexeme'], [data.expressions, 'expression']]) {
    for (const item of list || []) schema(item, name, name + '/' + item.id);
  }
  if (errors.length) return {ok: false, errors, warnings, summary: {release_ready: false}};
  const index = (items, kind) => {
    const result = new Map();
    for (const item of items) {
      if (result.has(item.id)) add('identity.duplicate', kind + '/' + item.id, 'Canonical IDs must be unique across files');
      result.set(item.id, item);
    }
    return result;
  };
  const courses = index(data.courses, 'course'), lexemes = index(data.lexemes, 'lexeme');
  const expressions = index(data.expressions, 'expression'), themes = index(data.themes, 'theme'), sources = index(data.sources, 'source');
  const listedCourses = index(data.catalog.courses, 'catalog/course');
  if (COURSE_IDS.some(id => !listedCourses.has(id)) || listedCourses.size !== 20 || courses.size !== 20) {
    add('catalog.coverage', 'catalog', 'The agreed twenty career tracks are required');
  }
  if (themes.size !== 21 || data.themes.filter(t => t.track === 'growth').length !== 1) add('theme.coverage', 'themes', 'One Growth and twenty career theme profiles are required');
  if (themes.get(data.catalog.growth_theme_id)?.track !== 'growth') add('theme.growth', 'themes', 'The Growth theme reference is invalid');
  const memberships = new Map(), phraseMemberships = new Map(), readyIds = new Set(), readyExpressions = new Set(), readyThemes = new Set();
  let membershipCount = 0, expressionCount = 0, readyModules = 0;
  const foundation = new Map();
  const sharedBundles = new Map();
  for (const info of data.catalog.courses) {
    const course = courses.get(info.id), at = 'course/' + info.id;
    if (!course) { add('course.missing', at, 'Catalog manifest is missing'); continue; }
    if (course.curriculum_revision !== data.catalog.curriculum_revision || course.theme_id !== info.theme_id) add('course.identity', at, 'Course revision or theme does not match the catalog');
    if (themes.get(info.theme_id)?.course_id !== info.id || themes.get(info.theme_id)?.track !== 'professional') add('theme.mapping', at, 'A course must reference its own professional theme');
    const termIds = new Set(), expressionIds = new Set(), moduleIds = new Set();
    for (const module of course.modules) {
      const moduleAt = at + '/' + module.id, strict = release || module.status === 'ready' || info.status === 'ready';
      if (moduleIds.has(module.id)) add('module.duplicate', moduleAt, 'Module IDs must be unique');
      moduleIds.add(module.id);
      if (strict) readyThemes.add(info.theme_id);
      if (module.status === 'ready') readyModules++;
      if (module.status === 'planned' && (module.lexeme_ids.length || module.expression_ids.length)) add('module.status', moduleAt, 'A populated module must be draft or ready');
      if (module.lexeme_ids.length !== 50 || module.expression_ids.length !== 10) add('module.incomplete', moduleAt, 'Requires 50 terms and 10 expressions', strict);
      if (module.status !== 'ready') add('module.not_ready', moduleAt, 'Release requires a ready module', release || info.status === 'ready');
      if (module.requirements_revision !== course.curriculum_revision) add('module.revision', moduleAt, 'New manifests must use the course requirements revision');
      if (!module.media_manifest) add('delivery.pending', moduleAt, 'A verified on-demand media manifest is required', strict);
      else {
        try {
          const file = resourcePath(rootDir, module.media_manifest.path);
          if (!fs.existsSync(file)) add('delivery.missing', moduleAt, 'Media manifest does not exist');
          else {
            const bytes = fs.readFileSync(file);
            if (crypto.createHash('sha256').update(bytes).digest('hex') !== module.media_manifest.sha256) {
              add('delivery.hash', moduleAt, 'Media manifest does not match its SHA256');
            } else {
              if (bytes.length > 256 * 1024) throw new Error('Media manifest exceeds 256 KiB');
              const expectedMedia = module.lexeme_ids.flatMap(id => {
                const entry = lexemes.get(id);
                return entry ? [['image', entry.media.image], ['audio', entry.media.audio]] : [];
              }).concat(module.expression_ids.flatMap(id => expressions.has(id) ? [['audio', expressions.get(id).media.audio]] : []),
                Object.values(themes.get(info.theme_id)?.art || {}).map(asset => ['image', asset]),
                (themes.get(info.theme_id)?.ambient_motion?.clips || []).map(clip => ['image', clip.image]));
              const delivery = validateDependencies(JSON.parse(bytes.toString('utf8')),
                expectedMedia.map(([, asset]) => 'sha256:' + asset.sha256), {
                  track: 'professional', course_id: info.id, module_id: module.id, curriculum_revision: course.curriculum_revision
                });
              for (const [key, members] of bundleInventory(delivery)) {
                const signature = JSON.stringify(members);
                if (sharedBundles.has(key) && sharedBundles.get(key) !== signature) {
                  add('delivery.bundle_identity', moduleAt, 'Shared bundle membership changed without a new bundle revision');
                }
                sharedBundles.set(key, signature);
              }
              const resources = new Map(delivery.resources.map(resource => [resource.sha256, resource]));
              for (const [kind, asset] of expectedMedia) {
                const resource = resources.get(asset.sha256);
                if (resource?.kind !== kind || asset.path !== 'res://' + resource.path) {
                  add('delivery.coverage', moduleAt, 'Required ' + kind + ' has a mismatched resource kind or immutable path');
                }
              }
            }
          }
        } catch (error) { add(error.code === 'missing_dependency' ? 'delivery.coverage' : 'delivery.path', moduleAt, error.message); }
      }
      const shouldBeFoundation = ['module01', 'module02'].includes(module.id);
      if (module.foundation !== shouldBeFoundation) add('module.foundation', moduleAt, 'Only the first two modules are shared foundation modules');
      if (module.foundation) {
        const signature = JSON.stringify({lexemes: [...module.lexeme_ids].sort(), expressions: [...module.expression_ids].sort()});
        if (foundation.has(module.id) && foundation.get(module.id) !== signature) add('foundation.membership', moduleAt, 'Foundation terms and expressions must have the same canonical membership in each course');
        foundation.set(module.id, signature);
      }
      for (const [key, available] of [['lexeme_files', data.catalog.lexeme_files], ['expression_files', data.catalog.expression_files]]) {
        for (const file of module[key]) if (!available.includes(file)) add('module.file', moduleAt, 'Module file is outside the catalog: ' + file);
      }
      for (const id of module.lexeme_ids) {
        membershipCount++;
        if (!lexemes.has(id)) add('membership.missing', moduleAt, 'Unknown lexeme ' + id);
        if (termIds.has(id)) add('membership.duplicate', moduleAt, 'A sense may only count once per course: ' + id);
        termIds.add(id);
        if (!module.lexeme_files.includes(data.lexemeOrigins[id])) add('membership.file', moduleAt, 'On-demand file links do not include lexeme ' + id);
        if (!memberships.has(id)) memberships.set(id, []);
        memberships.get(id).push({course: info.id, module});
        if (strict) readyIds.add(id);
      }
      for (const id of module.expression_ids) {
        expressionCount++;
        if (!expressions.has(id)) add('expression.missing', moduleAt, 'Unknown expression ' + id);
        if (expressionIds.has(id)) add('expression.duplicate', moduleAt, 'An expression may only count once per course');
        expressionIds.add(id);
        if (!module.expression_files.includes(data.expressionOrigins[id])) add('expression.file', moduleAt, 'On-demand file links do not include expression ' + id);
        if (!phraseMemberships.has(id)) phraseMemberships.set(id, []);
        phraseMemberships.get(id).push({course: info.id, module});
        if (strict) readyExpressions.add(id);
      }
    }
    if (termIds.size !== 500 || expressionIds.size !== 100) add('course.incomplete', at, 'Requires 500 distinct senses and 100 expressions', release || info.status === 'ready');
    if (info.status !== 'ready') add('course.not_ready', at, 'Catalog course is not ready', release);
  }
  function review(entry, at, strict, domainRequired) {
    if (entry.review.status !== 'reviewed' || entry.review.language !== 'reviewed' ||
      !['not_required', 'reviewed'].includes(entry.review.domain) || domainRequired && entry.review.domain !== 'reviewed' ||
      !entry.review.reviewer || !entry.review.reviewed_at) {
      add('review.pending', at, 'Documented language review and required subject review are incomplete', strict);
    }
    for (const reference of entry.references) if (!sources.has(reference.source_id)) add('reference.unknown', at, 'Unknown reference source ' + reference.source_id);
    if (!entry.references.some(reference => reference.status === 'verified')) add('reference.pending', at, 'Term-level reference checks are pending', strict);
  }
  function media(asset, at, strict) {
    const claimed = asset.status === 'integrated';
    if (!claimed || asset.acquisition_status !== 'integrated' || asset.review.status !== 'reviewed') add('media.pending', at, 'An acquired, integrated, reviewed production asset is required', strict || claimed);
    if (strict || claimed) {
      for (const key of MEDIA_KEYS) if (!asset[key]) add('media.provenance', at, 'Missing asset ' + key);
      if (!asset.review.reviewer || !asset.review.reviewed_at) add('media.review', at, 'Record the asset reviewer and review date');
    }
    if (asset.path) {
      try {
        const file = resourcePath(rootDir, asset.path);
        const extensions = at.endsWith('/audio') ? /\.(wav|ogg|mp3)$/i : /\.(png|webp|jpe?g|svg)$/i;
        if (!extensions.test(file)) add('media.format', at, 'Asset path has the wrong image or audio format');
        if (!fs.existsSync(file)) add('media.missing', at, 'Referenced asset does not exist');
        else if (asset.sha256 && crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex') !== asset.sha256) add('media.hash', at, 'Asset bytes do not match the declared SHA256');
      } catch (error) { add('media.path', at, error.message); }
    }
  }
  const signatures = new Map(), pictureRoutes = new Map();
  for (const course of data.courses) for (const module of course.modules) {
    pictureRoutes.set(module, modulePictureRoutes(module, lexemes));
  }
  for (const entry of data.lexemes) {
    const at = 'lexeme/' + entry.id, strict = release || readyIds.has(entry.id), locations = memberships.get(entry.id) || [];
    if (!locations.length) add('membership.orphan', at, 'Lexeme is not in any course module');
    const signature = [entry.text.toLowerCase(), entry.pos, entry.definition.toLowerCase()].join('|');
    if (signatures.has(signature)) add('sense.duplicate', at, 'This same-sense definition already has canonical ID ' + signatures.get(signature));
    signatures.set(signature, entry.id);
    if (!entry.accepted_forms.includes(entry.text)) add('forms.canonical', at, 'Accepted forms must include the canonical spelling');
    review(entry, at, strict, locations.some(x => DOMAIN_COURSES.has(x.course) && !x.module.foundation || x.module.id === 'module08'));
    media(entry.media.image, at + '/image', strict); media(entry.media.audio, at + '/audio', strict);
    if (!entry.media.image.brief) add('image.brief', at, 'Every draft image needs a sense-specific picture brief');
    for (const other of entry.media.image.confusable_with || []) {
      if (other === entry.id || !lexemes.has(other)) add('image.confusable', at,
        'Picture exclusions must reference another known canonical sense: ' + other);
    }
    if (entry.morphology) {
      for (const message of morphologyErrors(entry.morphology, entry)) add('morphology.invalid', at, message);
      if (entry.morphology.review.status !== 'reviewed' || !entry.morphology.review.reviewer || !entry.morphology.review.reviewed_at) add('morphology.pending', at, 'Morphological analysis awaits recorded review', strict);
    } else add('morphology.missing', at, 'Morphology has not been authored', strict);
    for (const mode of entry.practice_modes) {
      if (PICTURE_MODES.has(mode)) {
        if (!entry.media.image.picture_suitable) add('exercise.picture', at, mode + ' requires reviewed isolated-picture suitability', strict);
      }
      if (mode === 'phrase') {
        const linked = locations.some(location => location.module.expression_ids.some(id => expressions.get(id)?.focus_lexeme_ids.includes(entry.id)));
        if (!linked) add('exercise.phrase', at, 'Phrase practice requires an expression in the same module that assesses this sense', strict);
      }
    }
    const localRoutes = locations.map(location => ({location, reachable: entry.practice_modes.some(mode =>
      PICTURE_MODES.has(mode) ? pictureRoutes.get(location.module).get(mode).has(entry.id) :
        mode === 'word_jelly' ? entry.morphology?.parts.length > 1 :
          mode === 'phrase' && location.module.expression_ids.some(id => expressions.get(id)?.focus_lexeme_ids.includes(entry.id)))}));
    if (!localRoutes.some(route => route.reachable)) add('exercise.unreachable', at, 'No scored exercise is reachable; atomic collection is exposure only', strict);
    for (const {location, reachable} of localRoutes) {
      const localStrict = release || location.module.status === 'ready' || listedCourses.get(location.course)?.status === 'ready';
      if (!reachable) add('exercise.module_unreachable', 'course/' + location.course + '/' + location.module.id + '/lexeme/' + entry.id,
        'This module requires a feasible scored route for this sense, including a compatible distinct-spelling picture pool or a local phrase focus', localStrict);
    }
  }
  for (const entry of data.expressions) {
    const at = 'expression/' + entry.id, strict = release || readyExpressions.has(entry.id), locations = phraseMemberships.get(entry.id) || [];
    if (!locations.length) add('expression.orphan', at, 'Expression is not in a module');
    review(entry, at, strict, locations.some(x => DOMAIN_COURSES.has(x.course) && !x.module.foundation || x.module.id === 'module08'));
    media(entry.media.audio, at + '/audio', strict);
    const chars = [...entry.text]; let end = 0;
    for (const [index, token] of entry.tokens.entries()) {
      if (token.index !== index || token.start < end || token.end <= token.start ||
        chars.slice(token.start, token.end).join('') !== token.text || chars.slice(end, token.start).join('').trim()) {
        add('expression.tokens', at, 'Tokens must preserve every non-space character, occurrence, and position');
      }
      end = token.end;
    }
    if (chars.slice(end).join('').trim()) add('expression.tokens', at, 'Trailing characters are not represented by tokens');
    for (const location of locations) for (const id of entry.focus_lexeme_ids) {
      if (!location.module.lexeme_ids.includes(id) || !lexemes.has(id)) add('expression.focus', at, 'Focus sense is outside this module: ' + id);
      else if (!lexemes.get(id).practice_modes.includes('phrase')) add('expression.skill', at, 'A focus sense must expose the phrase skill: ' + id, strict);
    }
  }
  for (const theme of data.themes) {
    const at = 'theme/' + theme.id, strict = release || readyThemes.has(theme.id) || theme.status === 'ready';
    if (theme.status !== 'ready') add('theme.pending', at, 'Theme artwork and presentation are not ready', strict);
    if (theme.ambient_motion.status !== 'ready') add('theme.motion_pending', at, 'The motion and reduced-motion presentation await review', strict);
    for (const problem of themeMotionErrors(theme)) add('theme.motion_invalid', at, problem);
    for (const clip of theme.ambient_motion.clips) if (clip && typeof clip === 'object' && clip.image) media(clip.image, at + '/motion/' + clip.id, strict);
    for (const [key, asset] of Object.entries(theme.art)) media(asset, at + '/' + key, strict);
    if (theme.preview) {
      const previewAt = at + '/preview';
      // Local catalog illustrations are separate from complete on-demand themes.
      media(theme.preview, previewAt, false);
      if (theme.preview.path) {
        if (!/^res:\/\/assets\/images\/professional-previews\/[a-z0-9-]+\.png$/.test(theme.preview.path)) {
          add('theme.preview_scope', previewAt, 'Home previews must be PNGs in the dedicated local preview directory');
        }
        try {
          const file = resourcePath(rootDir, theme.preview.path);
          if (fs.existsSync(file)) {
            const bytes = fs.readFileSync(file);
            if (bytes.length > 400 * 1024) add('theme.preview_budget', previewAt, 'Home previews must not exceed 400 KiB');
            if (bytes.length < 33 || !bytes.subarray(0, 8).equals(Buffer.from([137,80,78,71,13,10,26,10])) ||
              bytes.readUInt32BE(8) !== 13 || bytes.toString('ascii', 12, 16) !== 'IHDR') {
              add('theme.preview_format', previewAt, 'Home previews require a PNG image header');
            } else if (bytes.readUInt32BE(16) < 1 || bytes.readUInt32BE(20) < 1 || bytes.readUInt32BE(16) > 512 || bytes.readUInt32BE(20) > 512) {
              add('theme.preview_dimensions', previewAt, 'Home preview dimensions must be between 1 and 512 pixels');
            }
          }
        } catch (error) { add('theme.preview_path', previewAt, error.message); }
      }
    }
    for (const key of ['music', 'interaction_bank']) {
      try { if (!fs.existsSync(resourcePath(rootDir, theme.audio[key]))) add('theme.audio', at, 'Mapped existing audio resource is missing'); }
      catch (error) { add('theme.audio', at, error.message); }
    }
  }
  const summary = {
    courses: courses.size, modules: data.courses.reduce((sum, c) => sum + c.modules.length, 0), themes: themes.size,
    unique_lexemes: lexemes.size, vocabulary_memberships: membershipCount, vocabulary_memberships_target: 10000,
    vocabulary_memberships_remaining: 10000 - membershipCount,
    expressions: expressions.size, expression_memberships: expressionCount, expression_memberships_target: 2000,
    expression_memberships_remaining: 2000 - expressionCount, ready_modules: readyModules,
    reviewed_lexemes: data.lexemes.filter(e => e.review.status === 'reviewed').length,
    morphology_authored: data.lexemes.filter(e => e.morphology).length,
    morphology_reviewed: data.lexemes.filter(e => e.morphology?.review.status === 'reviewed').length,
    integrated_word_images: data.lexemes.filter(e => e.media.image.status === 'integrated').length,
    integrated_word_audio: data.lexemes.filter(e => e.media.audio.status === 'integrated').length,
    release_ready: release ? errors.length === 0 : errors.length === 0 && warnings.length === 0
  };
  return {ok: errors.length === 0, errors, warnings, summary};
}

if (require.main === module) {
  const args = process.argv.slice(2);
  if (args.some(arg => !['--release', '--json'].includes(arg))) {
    console.error('Usage: node tools/validate-professional-content.cjs [--release] [--json]');
    process.exitCode = 2;
  } else {
    const result = auditProfessionalContent({release: args.includes('--release')});
    if (args.includes('--json')) console.log(JSON.stringify(result, null, 2));
    else {
      console.log(JSON.stringify({audit: result.ok ? 'passed' : 'failed', ...result.summary, errors: result.errors.length, warnings: result.warnings.length}, null, 2));
      for (const issue of result.errors.slice(0, 20)) console.error(issue.code + ' ' + issue.path + ': ' + issue.message);
      if (result.errors.length > 20) console.error('Additional errors omitted; use --json for the complete report.');
    }
    process.exitCode = result.ok ? 0 : 1;
  }
}

module.exports = {COURSE_IDS, resourcePath, loadProfessionalContent, schemaErrors, morphologyErrors, auditProfessionalContent};

