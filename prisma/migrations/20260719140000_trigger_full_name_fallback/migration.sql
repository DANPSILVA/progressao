-- Google OAuth populates raw_user_meta_data.full_name (not .name), so fall back to it
-- when the email/password flow's 'name' key isn't present.
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  INSERT INTO public."User" (id, email, name, "createdAt", "updatedAt")
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'name', NEW.raw_user_meta_data->>'full_name'),
    now(),
    now()
  );
  RETURN NEW;
END;
$$;
