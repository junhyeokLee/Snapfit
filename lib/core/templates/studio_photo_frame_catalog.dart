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

const keepsakePhotoFrames = {
  'materialLaceMount',
  'materialTwinWindow',
  'materialLinenOval',
  'materialNotebookMount',
  'materialScallopMount',
  'materialSlideMount',
};

const atelierEditionPhotoFrames = {
  'atelierDeepMat',
  'atelierFolio',
  'atelierKeyhole',
  'atelierCrossRibbon',
  'atelierNegative',
  'atelierEnvelope',
  'atelierOxford',
  'atelierCoastline',
  'atelierWeave',
  'atelierDeco',
  'atelierAccordion',
  'atelierCornerFold',
};

const keepsakeFrameAssets = {
  'materialLaceMount': 'assets/sticker/studio/material_lace.png',
  'materialLinenOval': 'assets/sticker/studio/material_linen.png',
};

// Explicit transitive materials for a future server-side included-item grant.
// This is an inventory, not a client-side ownership or price override.
const keepsakeFrameIncludedMaterials = {
  'materialLaceMount': 'sticker:materialLace',
  'materialLinenOval': 'sticker:materialLinen',
};

const studioPhotoFrames = {
  ...keepsakePhotoFrames,
  ...atelierEditionPhotoFrames,
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
