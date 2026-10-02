-- Phase 10 — People/RBAC platform connections.
-- Centralizes staff identity lifecycle notifications and restores module access
-- when an employee is reactivated. Existing CRM/Finance/Construction/portal
-- business services remain authoritative.

CREATE OR REPLACE FUNCTION public.notify_people_access_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_role_id uuid;
  v_role_name text;
  v_title text;
  v_body text;
  v_type text;
BEGIN
  IF TG_TABLE_NAME = 'user_roles' THEN
    v_user_id := coalesce(NEW.user_id, OLD.user_id);
    v_role_id := coalesce(NEW.role_id, OLD.role_id);
    SELECT name INTO v_role_name FROM public.roles WHERE id = v_role_id;

    IF TG_OP = 'INSERT'
       OR (TG_OP = 'UPDATE'
           AND coalesce(OLD.is_deleted, false)
           AND NOT coalesce(NEW.is_deleted, false)) THEN
      v_title := 'Platform access updated';
      v_body := 'The ' || coalesce(v_role_name, 'assigned') ||
        ' role was added to your HD Homes account.';
      v_type := 'role_assigned';
    ELSIF TG_OP = 'DELETE'
       OR (TG_OP = 'UPDATE'
           AND NOT coalesce(OLD.is_deleted, false)
           AND coalesce(NEW.is_deleted, false)) THEN
      v_title := 'Platform access updated';
      v_body := 'The ' || coalesce(v_role_name, 'assigned') ||
        ' role was removed from your HD Homes account.';
      v_type := 'role_revoked';
    ELSE
      RETURN coalesce(NEW, OLD);
    END IF;

    INSERT INTO public.notifications (
      user_id, title, body, channel, category, type, priority, action_url,
      metadata, status, delivery_status, created_by
    )
    VALUES (
      v_user_id, v_title, v_body, 'in_app', 'security', v_type, 'high',
      '/dashboard/profile',
      jsonb_build_object('role_id', v_role_id, 'actor_id', auth.uid()),
      'active', 'delivered', auth.uid()
    );

  ELSIF TG_TABLE_NAME = 'profiles' THEN
    IF NEW.account_status IS NOT DISTINCT FROM OLD.account_status THEN
      RETURN NEW;
    END IF;

    INSERT INTO public.notifications (
      user_id, title, body, channel, category, type, priority, action_url,
      metadata, status, delivery_status, created_by
    )
    VALUES (
      NEW.id, 'Account status updated',
      'Your HD Homes account status is now ' ||
        replace(NEW.account_status::text, '_', ' ') || '.',
      'in_app', 'security', 'account_status_changed', 'high',
      '/dashboard/profile',
      jsonb_build_object(
        'old_status', OLD.account_status,
        'new_status', NEW.account_status,
        'actor_id', auth.uid()
      ),
      'active', 'delivered', auth.uid()
    );

  ELSIF TG_TABLE_NAME = 'role_permissions' THEN
    v_role_id := coalesce(NEW.role_id, OLD.role_id);
    INSERT INTO public.notifications (
      user_id, title, body, channel, category, type, priority, action_url,
      metadata, status, delivery_status, created_by
    )
    SELECT DISTINCT
      ur.user_id, 'Permissions updated',
      'Your HD Homes platform permissions were updated.',
      'in_app', 'security', 'permissions_changed', 'normal',
      '/dashboard/profile',
      jsonb_build_object('role_id', v_role_id, 'actor_id', auth.uid()),
      'active', 'delivered', auth.uid()
    FROM public.user_roles ur
    WHERE ur.role_id = v_role_id
      AND NOT coalesce(ur.is_deleted, false)
      AND coalesce(ur.status, 'active') = 'active';
  END IF;

  RETURN coalesce(NEW, OLD);
END;
$$;

DROP TRIGGER IF EXISTS people_access_user_roles_notify ON public.user_roles;
CREATE TRIGGER people_access_user_roles_notify
AFTER INSERT OR UPDATE OR DELETE ON public.user_roles
FOR EACH ROW EXECUTE FUNCTION public.notify_people_access_change();

DROP TRIGGER IF EXISTS people_access_profiles_notify ON public.profiles;
CREATE TRIGGER people_access_profiles_notify
AFTER UPDATE OF account_status ON public.profiles
FOR EACH ROW EXECUTE FUNCTION public.notify_people_access_change();

DROP TRIGGER IF EXISTS people_access_role_permissions_notify ON public.role_permissions;
CREATE TRIGGER people_access_role_permissions_notify
AFTER INSERT OR UPDATE OR DELETE ON public.role_permissions
FOR EACH ROW EXECUTE FUNCTION public.notify_people_access_change();

CREATE OR REPLACE FUNCTION public.reactivate_employee(p_employee_id uuid)
RETURNS public.employees
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_row public.employees;
  v_actor uuid := auth.uid();
BEGIN
  IF v_actor IS NULL OR NOT public.can_manage_people() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  UPDATE public.employees e
  SET
    employment_status = 'active',
    status = 'active',
    deactivated_at = NULL,
    deactivated_by = NULL,
    deactivation_reason = NULL,
    left_at = NULL,
    updated_at = now(),
    updated_by = v_actor
  WHERE e.id = p_employee_id
    AND coalesce(e.is_deleted, false) = false
  RETURNING * INTO v_row;

  IF v_row.id IS NULL THEN
    RAISE EXCEPTION 'employee_not_found';
  END IF;

  IF v_row.user_id IS NOT NULL THEN
    IF v_row.role_slug IS NOT NULL THEN
      PERFORM public._apply_staff_role_to_user(
        v_row.user_id,
        v_row.role_slug,
        v_actor
      );
    END IF;

    UPDATE public.profiles
    SET
      account_status = 'active'::public.account_status,
      updated_at = now(),
      updated_by = v_actor
    WHERE id = v_row.user_id;
  END IF;

  INSERT INTO public.audit_logs (
    user_id, action, module, entity_type, entity_id, metadata
  )
  VALUES (
    v_actor, 'employee.reactivate', 'people', 'employee', v_row.id::text,
    jsonb_build_object(
      'user_id', v_row.user_id,
      'email', v_row.email,
      'role_slug', v_row.role_slug
    )
  );

  RETURN v_row;
END;
$$;

REVOKE ALL ON FUNCTION public.notify_people_access_change() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.reactivate_employee(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.reactivate_employee(uuid) TO authenticated;
