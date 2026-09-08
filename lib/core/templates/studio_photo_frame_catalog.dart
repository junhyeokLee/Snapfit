/// Stable document keys shared by layout-preserving editing and rendering.
const newStudioPhotoFrames = {
  'studioCapsule',
  'studioDiagonal',
  'studioWave',
  'studioTicket',
  'studioGallery',
  'studioDeckle',
  'studioInstant',
  'studioFilm',
};

const atelierPhotoFrames = {
  'studioDoubleMat',
  'studioPhotoCorners',
  'studioOvalMat',
  'studioLinen',
  'studioPostcard',
  'studioPostage',
};

// Historical keys retained when the prose collection became free.
const studyPhotoFrames = {
  'studyArchWindow',
  'studyFloatMount',
  'studyNotchedMat',
};

// Materials are available in the editor independently of candidate templates.
const editionPhotoFrames = {
  'zineContact',
  'zineDeckle',
  'zineTab',
  'editionLace',
  'editionHeart',
  'editionPostage',
  'editionScallop',
  'editionCameo',
  'editionTriptych',
};

const studioPhotoFrames = {
  ...editionPhotoFrames,
  ...studyPhotoFrames,
  ...atelierPhotoFrames,
  ...newStudioPhotoFrames,
  'studioOval',
  'studioRounded',
  'studioArch',
  'studioTorn',
  'studioSticker',
  'studioScallop',
};
