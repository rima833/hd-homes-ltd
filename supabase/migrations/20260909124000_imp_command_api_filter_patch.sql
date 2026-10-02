-- Remote compatibility cleanup after adding investor_type to the directory API.
DROP FUNCTION IF EXISTS public.admin_list_investors(
  text, text, text, uuid, integer, integer
);
