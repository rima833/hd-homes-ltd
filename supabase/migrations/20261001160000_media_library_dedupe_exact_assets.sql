-- Collapse exact media copies (same bytes and pixel size) onto the newest row
-- and point existing references at that keeper.
DO $$
DECLARE
  fk RECORD;
BEGIN
  CREATE TEMP TABLE media_dupes ON COMMIT DROP AS
  WITH ranked AS (
    SELECT
      id,
      first_value(id) OVER (
        PARTITION BY file_size, width, height, COALESCE(file_type, '')
        ORDER BY created_at DESC, id DESC
      ) AS keep_id
    FROM public.media
    WHERE COALESCE(is_deleted, false) = false
      AND file_size IS NOT NULL
      AND width IS NOT NULL
      AND height IS NOT NULL
  )
  SELECT id AS drop_id, keep_id
  FROM ranked
  WHERE id IS DISTINCT FROM keep_id;

  FOR fk IN
    SELECT c.conrelid AS relid, a.attname AS col
    FROM pg_constraint c
    JOIN pg_attribute a
      ON a.attrelid = c.conrelid
     AND a.attnum = ANY (c.conkey)
     AND NOT a.attisdropped
    WHERE c.confrelid = 'public.media'::regclass
      AND c.contype = 'f'
  LOOP
    EXECUTE format(
      'UPDATE %s t SET %I = d.keep_id FROM media_dupes d WHERE t.%I = d.drop_id',
      fk.relid::regclass,
      fk.col,
      fk.col
    );
  END LOOP;

  UPDATE public.media m
  SET is_deleted = true,
      is_active = false,
      deleted_at = now(),
      updated_at = now()
  FROM media_dupes d
  WHERE m.id = d.drop_id;
END $$;
