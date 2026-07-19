-- AlterTable
ALTER TABLE "Character" ADD COLUMN     "avatarUrl" TEXT;

-- AlterTable
ALTER TABLE "User" DROP COLUMN "passwordHash";

-- Supabase Auth owns auth.users; this trigger keeps public."User" in sync so the
-- app's existing tables (Character, HuntSession, Friendship) can keep referencing
-- a plain public."User".id foreign key exactly as before.
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
    NEW.raw_user_meta_data->>'name',
    now(),
    now()
  );
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();
