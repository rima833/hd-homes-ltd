-- Already applied remotely as occ_health_bootstrap_and_cron.
-- Kept for repo parity: idempotent health upserts + optional pg_cron schedule.

SELECT public.upsert_system_health(
  'database', 'Database', 'healthy', NULL, 'Reachable (bootstrap)', '{}'::jsonb
);
SELECT public.upsert_system_health(
  'realtime', 'Realtime', 'healthy', NULL, 'Realtime publication active', '{}'::jsonb
);
SELECT public.upsert_system_health(
  'auth', 'Authentication', 'healthy', NULL, 'Auth service available', '{}'::jsonb
);
SELECT public.upsert_system_health(
  'storage', 'Storage', 'healthy', NULL, 'Storage available', '{}'::jsonb
);
SELECT public.upsert_system_health(
  'email', 'Email provider', 'degraded', NULL, 'Awaiting Edge probe for Resend', '{}'::jsonb
);
SELECT public.upsert_system_health(
  'sms', 'SMS provider', 'degraded', NULL, 'Awaiting Edge probe for Twilio', '{}'::jsonb
);
SELECT public.upsert_system_health(
  'edge_functions', 'Edge Functions', 'unknown', NULL,
  'Deploy observability-health-probe', '{}'::jsonb
);

DO $$
DECLARE
  v_url TEXT;
BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron')
     AND EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_net') THEN
    v_url := current_setting('app.settings.supabase_url', true);
    IF coalesce(v_url, '') = '' THEN
      BEGIN
        SELECT decrypted_secret INTO v_url
        FROM vault.decrypted_secrets
        WHERE name = 'supabase_url'
        LIMIT 1;
      EXCEPTION WHEN OTHERS THEN
        v_url := NULL;
      END;
    END IF;
    IF coalesce(v_url, '') <> '' THEN
      BEGIN
        PERFORM cron.unschedule(jobid)
        FROM cron.job
        WHERE jobname = 'occ-health-probe';
      EXCEPTION WHEN OTHERS THEN
        NULL;
      END;
      PERFORM cron.schedule(
        'occ-health-probe',
        '*/5 * * * *',
        format(
          $cron$
          SELECT net.http_post(
            url := %L || '/functions/v1/observability-health-probe',
            headers := jsonb_build_object(
              'Content-Type', 'application/json',
              'x-occ-health-cron', '1'
            ),
            body := '{}'::jsonb
          );
          $cron$,
          rtrim(v_url, '/')
        )
      );
    END IF;
  END IF;
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'OCC health cron not scheduled: %', SQLERRM;
END $$;
