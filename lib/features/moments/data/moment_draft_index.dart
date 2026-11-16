/// Browser recovery lists need only identities, lengths and the edit marker.
/// The separate draft record retains all private editable artwork and originals.
/// This also accepts old full index entries so the next atomic write compacts
/// them without changing the corresponding complete draft records.
Map<String, dynamic> momentDraftIndexMetadata(Map<String, dynamic> metadata) =>
    {
      ...metadata,
      'existingPhotos': [
        for (final raw in metadata['existingPhotos'] as List)
          {
            for (final entry in (raw as Map).entries)
              if (entry.key != 'design') entry.key as String: entry.value,
          },
      ],
      'uploads': [
        for (final raw in metadata['uploads'] as List)
          {
            for (final entry in (raw as Map).entries)
              if (entry.key != 'design') entry.key as String: entry.value,
          },
      ],
      if (metadata['originalRecord'] case final Map original)
        'originalRecord': {'id': original['id']},
    };
