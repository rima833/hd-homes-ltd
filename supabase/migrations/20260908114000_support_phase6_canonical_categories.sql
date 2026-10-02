-- Keep one active category for each canonical support concern.
UPDATE public.support_categories
SET slug = 'payment', name = 'Payment',
    description = 'Payments, invoices, receipts and instalments'
WHERE slug = 'billing'
  AND NOT EXISTS (
    SELECT 1 FROM public.support_categories WHERE slug = 'payment'
  );

UPDATE public.support_categories SET name = 'Documents'
WHERE slug = 'documents';
UPDATE public.support_categories SET name = 'Construction'
WHERE slug = 'construction';
UPDATE public.support_categories SET name = 'General'
WHERE slug = 'general';

UPDATE public.tickets
SET category_id = (SELECT id FROM public.support_categories
                   WHERE slug = 'inspection' LIMIT 1)
WHERE category_id = (SELECT id FROM public.support_categories
                     WHERE slug = 'booking' LIMIT 1);
UPDATE public.support_categories SET is_active = false WHERE slug = 'booking';

UPDATE public.tickets
SET category_id = (SELECT id FROM public.support_categories
                   WHERE slug = 'technical' LIMIT 1)
WHERE category_id = (SELECT id FROM public.support_categories
                     WHERE slug = 'portal' LIMIT 1);
UPDATE public.support_categories SET is_active = false WHERE slug = 'portal';
