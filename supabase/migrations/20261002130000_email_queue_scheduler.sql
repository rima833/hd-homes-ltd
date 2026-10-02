-- Minute drain of the transactional email queue.
-- The scheduler inserts a one-time ticket and asks the Edge worker to
-- consume it. No API key is stored in this migration.

CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS pg_net;
CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS public.email_queue_drain_tickets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  nonce text NOT NULL UNIQUE,
  expires_at timestamptz NOT NULL,
  used_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.email_queue_drain_tickets ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.email_queue_drain_tickets FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.issue_email_queue_drain()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, net, extensions
AS $$
DECLARE
  v_nonce text;
BEGIN
  DELETE FROM public.email_queue_drain_tickets
  WHERE expires_at < now() - interval '1 day';

  v_nonce := encode(extensions.gen_random_bytes(32), 'hex');
  INSERT INTO public.email_queue_drain_tickets (nonce, expires_at)
  VALUES (v_nonce, now() + interval '2 minutes');

  PERFORM net.http_post(
    url := 'https://wbonjdqsifwsawhhxygl.supabase.co/functions/v1/process-email-queue',
    headers := jsonb_build_object('Content-Type', 'application/json'),
    body := jsonb_build_object('drain_ticket', v_nonce),
    timeout_milliseconds := 15000
  );
END;
$$;

REVOKE ALL ON FUNCTION public.issue_email_queue_drain() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.issue_email_queue_drain() TO postgres, service_role;

DO $cron$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'hd-homes-email-queue') THEN
      PERFORM cron.unschedule('hd-homes-email-queue');
    END IF;
    PERFORM cron.schedule(
      'hd-homes-email-queue',
      '* * * * *',
      $job$SELECT public.issue_email_queue_drain();$job$
    );
  END IF;
END
$cron$;
