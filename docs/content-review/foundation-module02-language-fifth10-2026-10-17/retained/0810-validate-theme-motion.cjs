'use strict';

function themeMotionErrors(theme, requireReady = false) {
  const motion = theme.ambient_motion;
  if (motion?.status !== 'ready') return requireReady ? ['Motion is waiting for review.'] : [];
  const errors = [];
  if (motion.review?.status !== 'reviewed') errors.push('Motion timing and static presentation need review.');
  if (!Array.isArray(motion.clips) || motion.clips.length < 1 || motion.clips.length > 4) {
    return [...errors, 'Motion requires one to four authored clips.'];
  }
  const ids = new Set();
  for (const clip of motion.clips) {
    if (!clip || typeof clip !== 'object' || Array.isArray(clip)) {
      errors.push('A motion clip must be an object.');
      continue;
    }
    if (typeof clip.id !== 'string' || !clip.id || ids.has(clip.id)) errors.push('Clip identities must be unique nonempty strings.');
    ids.add(clip.id);
    if (clip.image?.status !== 'integrated' || clip.image.review?.status !== 'reviewed') errors.push('A motion sheet requires reviewed integrated artwork.');
    if (['path', 'sha256', 'source', 'creator', 'license'].some(key => typeof clip.image?.[key] !== 'string' || !clip.image[key].trim()) ||
      !/^[a-f0-9]{64}$/.test(clip.image?.sha256 || '')) errors.push('A motion sheet requires its hash and complete provenance.');
    for (const key of ['columns', 'rows', 'frame_count', 'rest_frame']) {
      if (!Number.isInteger(clip[key])) errors.push('Invalid integer ' + key + '.');
    }
    if (!(clip.columns >= 1 && clip.columns <= 8 && clip.rows >= 1 && clip.rows <= 8 &&
      clip.frame_count >= 2 && clip.frame_count <= clip.columns * clip.rows && clip.rest_frame >= 0 && clip.rest_frame < clip.frame_count)) {
      errors.push('Frame indices exceed the bounded sheet.');
    }
    if (!Number.isFinite(clip.frames_per_second) || clip.frames_per_second < 0.5 || clip.frames_per_second > 24) errors.push('Invalid frame rate.');
    const rect = clip.rect;
    if (!Array.isArray(rect) || rect.length !== 4 || rect.some(value => !Number.isFinite(value) || value < 0 || value > 1) ||
      !(rect[2] > 0 && rect[3] > 0 && rect[0] + rect[2] <= 1.000001 && rect[1] + rect[3] <= 1.000001)) errors.push('Clip placement is outside its composition.');
  }
  return errors;
}

module.exports = {themeMotionErrors};
