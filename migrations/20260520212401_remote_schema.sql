

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


CREATE EXTENSION IF NOT EXISTS "pgsodium";






CREATE EXTENSION IF NOT EXISTS "moddatetime" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pg_stat_statements" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pgjwt" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "supabase_vault" WITH SCHEMA "vault";






CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA "extensions";






CREATE OR REPLACE FUNCTION "public"."add_user_default_role"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  INSERT INTO public.user_roles (user_id, role_id)
  VALUES (NEW.id, 'e6b0c2c1-547d-4a3c-9695-86d5df716081');
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."add_user_default_role"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_user_announcements"("announcement_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  u RECORD;
BEGIN
  FOR u IN SELECT id FROM auth.users LOOP
    INSERT INTO public.user_announcements (user_id, announcement_id, is_read)
    VALUES (u.id, announcement_id, false);
  END LOOP;
END;
$$;


ALTER FUNCTION "public"."create_user_announcements"("announcement_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."is_super_admin"("_user_id" "uuid", "_role" "text") RETURNS boolean
    LANGUAGE "sql" SECURITY DEFINER
    AS $$
SELECT EXISTS (
  SELECT 1 FROM user_roles, roles
  WHERE user_roles.user_id = _user_id
  AND roles.id = user_roles.role_id
  AND roles.role = _role
);
$$;


ALTER FUNCTION "public"."is_super_admin"("_user_id" "uuid", "_role" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."trigger_send_announcement"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  -- Call the actual function with the announcement ID
  PERFORM create_user_announcements(NEW.id);
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."trigger_send_announcement"() OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "public"."announcements" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "title" "text" NOT NULL,
    "body" "text" NOT NULL,
    "image_url" "text",
    "image_public_id" "text",
    "state" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."announcements" OWNER TO "postgres";


COMMENT ON TABLE "public"."announcements" IS 'Stores all the announcements in the system';



CREATE TABLE IF NOT EXISTS "public"."events" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "title" "text" NOT NULL,
    "description" "text" NOT NULL,
    "time" time with time zone NOT NULL,
    "type" "text" NOT NULL,
    "start_date" timestamp with time zone NOT NULL,
    "end_date" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "day" "text",
    "category" "text" DEFAULT 'general'::"text" NOT NULL,
    "banner_url" "text",
    "banner_public_id" "text"
);


ALTER TABLE "public"."events" OWNER TO "postgres";


COMMENT ON TABLE "public"."events" IS 'All events will be managed in this table';



CREATE TABLE IF NOT EXISTS "public"."groups" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "title" "text" NOT NULL,
    "description" "text" NOT NULL,
    "type" "text" NOT NULL,
    "whatsappLink" "text",
    "location" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "banner_url" "text",
    "banner_public_id" "text"
);


ALTER TABLE "public"."groups" OWNER TO "postgres";


COMMENT ON TABLE "public"."groups" IS 'All groups will be managed and stored in this table';



CREATE TABLE IF NOT EXISTS "public"."meta_data" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "key" "text",
    "title" "text",
    "content" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp without time zone DEFAULT "now"()
);


ALTER TABLE "public"."meta_data" OWNER TO "postgres";


COMMENT ON TABLE "public"."meta_data" IS 'All other meta data shown in app, only to be managed by super admins';



CREATE TABLE IF NOT EXISTS "public"."notes" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "title" "text" NOT NULL,
    "content" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp without time zone DEFAULT "now"()
);


ALTER TABLE "public"."notes" OWNER TO "postgres";


COMMENT ON TABLE "public"."notes" IS 'User notes';



CREATE TABLE IF NOT EXISTS "public"."roleplayers" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "fullname" "text" NOT NULL,
    "title" "text" NOT NULL,
    "bio" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "profile_public_id" "text",
    "profile_url" "text"
);


ALTER TABLE "public"."roleplayers" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."roles" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "role" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."roles" OWNER TO "postgres";


COMMENT ON TABLE "public"."roles" IS 'all roles that can be assigned in the system';



CREATE TABLE IF NOT EXISTS "public"."sermons" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "title" "text" NOT NULL,
    "description" "text",
    "link" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "pastor" "text" NOT NULL
);


ALTER TABLE "public"."sermons" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."social_media" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "title" "text" NOT NULL,
    "link" "text" NOT NULL,
    "type" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "banner_url" "text",
    "banner_public_id" "text"
);


ALTER TABLE "public"."social_media" OWNER TO "postgres";


COMMENT ON TABLE "public"."social_media" IS 'All social media links will be stored and managed in this table';



CREATE TABLE IF NOT EXISTS "public"."user_announcements" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "is_read" boolean NOT NULL,
    "user_id" "uuid" NOT NULL,
    "announcement_id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."user_announcements" OWNER TO "postgres";


COMMENT ON TABLE "public"."user_announcements" IS 'Stores an announcement specific to a user';



CREATE TABLE IF NOT EXISTS "public"."user_profile" (
    "id" "uuid" NOT NULL,
    "first_name" character varying,
    "last_name" character varying,
    "updated_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "is_baptized" boolean,
    "address" character varying,
    "is_member" boolean,
    "profile_public_id" "text",
    "profile_url" "text"
);


ALTER TABLE "public"."user_profile" OWNER TO "postgres";


COMMENT ON TABLE "public"."user_profile" IS 'All user profiles within the system. Contains additional data for a user that is related to a user''s auth profile';



CREATE TABLE IF NOT EXISTS "public"."user_roles" (
    "user_id" "uuid" NOT NULL,
    "role_id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."user_roles" OWNER TO "postgres";


COMMENT ON TABLE "public"."user_roles" IS 'mapping table to map all roles assigned to a specific user';



CREATE OR REPLACE VIEW "public"."user_profile_view" AS
 SELECT "user_profile"."id",
    "user_profile"."first_name",
    "user_profile"."last_name",
    "user_profile"."updated_at",
    "user_profile"."created_at",
    "roles"."role",
    "user_profile"."is_baptized",
    "user_profile"."is_member",
    "user_profile"."address",
    "users"."email",
    "user_profile"."profile_public_id",
    "user_profile"."profile_url"
   FROM ((("public"."user_profile"
     JOIN "auth"."users" ON (("user_profile"."id" = "users"."id")))
     JOIN "public"."user_roles" ON (("user_profile"."id" = "user_roles"."user_id")))
     JOIN "public"."roles" ON (("user_roles"."role_id" = "roles"."id")));


ALTER TABLE "public"."user_profile_view" OWNER TO "postgres";


ALTER TABLE ONLY "public"."announcements"
    ADD CONSTRAINT "announcements_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."events"
    ADD CONSTRAINT "events_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."groups"
    ADD CONSTRAINT "groups_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."meta_data"
    ADD CONSTRAINT "meta_data_key_key" UNIQUE ("key");



ALTER TABLE ONLY "public"."meta_data"
    ADD CONSTRAINT "meta_data_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."notes"
    ADD CONSTRAINT "notes_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."roleplayers"
    ADD CONSTRAINT "roleplayers_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."roles"
    ADD CONSTRAINT "roles_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."sermons"
    ADD CONSTRAINT "sermons_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."social_media"
    ADD CONSTRAINT "social_media_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."user_announcements"
    ADD CONSTRAINT "user_announcements_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."user_profile"
    ADD CONSTRAINT "user_profile_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."user_roles"
    ADD CONSTRAINT "user_roles_pkey" PRIMARY KEY ("user_id", "role_id");



CREATE OR REPLACE TRIGGER "handle_updated_at" BEFORE UPDATE ON "public"."announcements" FOR EACH ROW EXECUTE FUNCTION "extensions"."moddatetime"('updated_at');



CREATE OR REPLACE TRIGGER "handle_updated_at" BEFORE UPDATE ON "public"."events" FOR EACH ROW EXECUTE FUNCTION "extensions"."moddatetime"('updated_at');



CREATE OR REPLACE TRIGGER "handle_updated_at" BEFORE UPDATE ON "public"."groups" FOR EACH ROW EXECUTE FUNCTION "extensions"."moddatetime"('updated_at');



CREATE OR REPLACE TRIGGER "handle_updated_at" BEFORE UPDATE ON "public"."meta_data" FOR EACH ROW EXECUTE FUNCTION "extensions"."moddatetime"('updated_at');



CREATE OR REPLACE TRIGGER "handle_updated_at" BEFORE UPDATE ON "public"."notes" FOR EACH ROW EXECUTE FUNCTION "extensions"."moddatetime"('updated_at');



CREATE OR REPLACE TRIGGER "handle_updated_at" BEFORE UPDATE ON "public"."roleplayers" FOR EACH ROW EXECUTE FUNCTION "extensions"."moddatetime"('updated_at');



CREATE OR REPLACE TRIGGER "handle_updated_at" BEFORE UPDATE ON "public"."sermons" FOR EACH ROW EXECUTE FUNCTION "extensions"."moddatetime"('updated_at');



CREATE OR REPLACE TRIGGER "handle_updated_at" BEFORE UPDATE ON "public"."social_media" FOR EACH ROW EXECUTE FUNCTION "extensions"."moddatetime"('updated_at');



CREATE OR REPLACE TRIGGER "handle_updated_at" BEFORE UPDATE ON "public"."user_announcements" FOR EACH ROW EXECUTE FUNCTION "extensions"."moddatetime"('updated_at');



CREATE OR REPLACE TRIGGER "handle_updated_at" BEFORE UPDATE ON "public"."user_profile" FOR EACH ROW EXECUTE FUNCTION "extensions"."moddatetime"('updated_at');



CREATE OR REPLACE TRIGGER "send_announcement_trigger" AFTER UPDATE OF "state" ON "public"."announcements" FOR EACH ROW WHEN ((("new"."state" = 'sent'::"text") AND ("old"."state" = 'pending'::"text"))) EXECUTE FUNCTION "public"."trigger_send_announcement"();



ALTER TABLE ONLY "public"."notes"
    ADD CONSTRAINT "notes_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."user_announcements"
    ADD CONSTRAINT "user_announcements_announcement_id_fkey" FOREIGN KEY ("announcement_id") REFERENCES "public"."announcements"("id") ON UPDATE CASCADE ON DELETE CASCADE;



ALTER TABLE ONLY "public"."user_announcements"
    ADD CONSTRAINT "user_announcements_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON UPDATE CASCADE ON DELETE CASCADE;



ALTER TABLE ONLY "public"."user_profile"
    ADD CONSTRAINT "user_profile_id_fkey" FOREIGN KEY ("id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."user_roles"
    ADD CONSTRAINT "user_roles_role_id_fkey" FOREIGN KEY ("role_id") REFERENCES "public"."roles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."user_roles"
    ADD CONSTRAINT "user_roles_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



CREATE POLICY "allow all access for super_admin on user_profile" ON "public"."user_profile" TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."user_roles",
    "public"."roles"
  WHERE (("user_roles"."user_id" = "auth"."uid"()) AND ("roles"."id" = "user_roles"."role_id") AND ("roles"."role" = 'super_admin'::"text"))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."user_roles",
    "public"."roles"
  WHERE (("user_roles"."user_id" = "auth"."uid"()) AND ("roles"."id" = "user_roles"."role_id") AND ("roles"."role" = 'super_admin'::"text")))));



CREATE POLICY "allow all access to owner" ON "public"."user_announcements" TO "authenticated" USING (("auth"."uid"() = "user_id")) WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "allow all access to owner of note" ON "public"."notes" TO "authenticated" USING (("auth"."uid"() = "user_id")) WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "allow all access to super admin" ON "public"."announcements" TO "authenticated" USING ("public"."is_super_admin"("auth"."uid"(), 'super_admin'::"text")) WITH CHECK ("public"."is_super_admin"("auth"."uid"(), 'super_admin'::"text"));



CREATE POLICY "allow all access to super admin" ON "public"."events" TO "authenticated" USING ("public"."is_super_admin"("auth"."uid"(), 'super_admin'::"text")) WITH CHECK ("public"."is_super_admin"("auth"."uid"(), 'super_admin'::"text"));



CREATE POLICY "allow all access to super admin" ON "public"."groups" TO "authenticated" USING ("public"."is_super_admin"("auth"."uid"(), 'super_admin'::"text")) WITH CHECK ("public"."is_super_admin"("auth"."uid"(), 'super_admin'::"text"));



CREATE POLICY "allow all access to super admin" ON "public"."meta_data" TO "authenticated" USING ("public"."is_super_admin"("auth"."uid"(), 'super_admin'::"text")) WITH CHECK ("public"."is_super_admin"("auth"."uid"(), 'super_admin'::"text"));



CREATE POLICY "allow all access to super admin" ON "public"."notes" TO "authenticated" USING ("public"."is_super_admin"("auth"."uid"(), 'super_admin'::"text")) WITH CHECK ("public"."is_super_admin"("auth"."uid"(), 'super_admin'::"text"));



CREATE POLICY "allow all access to super admin" ON "public"."roleplayers" TO "authenticated" USING ("public"."is_super_admin"("auth"."uid"(), 'super_admin'::"text")) WITH CHECK ("public"."is_super_admin"("auth"."uid"(), 'super_admin'::"text"));



CREATE POLICY "allow all access to super admin" ON "public"."sermons" TO "authenticated" USING ("public"."is_super_admin"("auth"."uid"(), 'super_admin'::"text")) WITH CHECK ("public"."is_super_admin"("auth"."uid"(), 'super_admin'::"text"));



CREATE POLICY "allow all access to super admin" ON "public"."social_media" TO "authenticated" USING ("public"."is_super_admin"("auth"."uid"(), 'super_admin'::"text")) WITH CHECK ("public"."is_super_admin"("auth"."uid"(), 'super_admin'::"text"));



CREATE POLICY "allow all access to super admin" ON "public"."user_announcements" TO "authenticated" USING ("public"."is_super_admin"("auth"."uid"(), 'super_admin'::"text")) WITH CHECK ("public"."is_super_admin"("auth"."uid"(), 'super_admin'::"text"));



CREATE POLICY "allow all access to super_admin" ON "public"."roles" TO "authenticated" USING ("public"."is_super_admin"("auth"."uid"(), 'super_admin'::"text")) WITH CHECK ("public"."is_super_admin"("auth"."uid"(), 'super_admin'::"text"));



CREATE POLICY "allow all access to super_admin" ON "public"."user_roles" TO "authenticated" USING ("public"."is_super_admin"("auth"."uid"(), 'super_admin'::"text")) WITH CHECK ("public"."is_super_admin"("auth"."uid"(), 'super_admin'::"text"));



CREATE POLICY "allow all actions for owner of user_profile" ON "public"."user_profile" TO "authenticated" USING (("auth"."uid"() = "id")) WITH CHECK (("auth"."uid"() = "id"));



CREATE POLICY "allow read access to authed users" ON "public"."announcements" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "allow read access to authed users" ON "public"."events" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "allow read access to authed users" ON "public"."groups" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "allow read access to authed users" ON "public"."roleplayers" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "allow read access to authed users" ON "public"."sermons" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "allow read access to authed users" ON "public"."social_media" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "allow view for all authed users" ON "public"."meta_data" FOR SELECT TO "authenticated" USING (true);



ALTER TABLE "public"."announcements" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."events" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."groups" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."meta_data" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."notes" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."roleplayers" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."roles" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."sermons" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."social_media" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."user_announcements" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."user_profile" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."user_roles" ENABLE ROW LEVEL SECURITY;




ALTER PUBLICATION "supabase_realtime" OWNER TO "postgres";


REVOKE USAGE ON SCHEMA "public" FROM PUBLIC;
GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";




















































































































































































GRANT ALL ON FUNCTION "public"."add_user_default_role"() TO "anon";
GRANT ALL ON FUNCTION "public"."add_user_default_role"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."add_user_default_role"() TO "service_role";



GRANT ALL ON FUNCTION "public"."create_user_announcements"("announcement_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."create_user_announcements"("announcement_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_user_announcements"("announcement_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."is_super_admin"("_user_id" "uuid", "_role" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."is_super_admin"("_user_id" "uuid", "_role" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_super_admin"("_user_id" "uuid", "_role" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."trigger_send_announcement"() TO "anon";
GRANT ALL ON FUNCTION "public"."trigger_send_announcement"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."trigger_send_announcement"() TO "service_role";



























GRANT ALL ON TABLE "public"."announcements" TO "anon";
GRANT ALL ON TABLE "public"."announcements" TO "authenticated";
GRANT ALL ON TABLE "public"."announcements" TO "service_role";



GRANT ALL ON TABLE "public"."events" TO "anon";
GRANT ALL ON TABLE "public"."events" TO "authenticated";
GRANT ALL ON TABLE "public"."events" TO "service_role";



GRANT ALL ON TABLE "public"."groups" TO "anon";
GRANT ALL ON TABLE "public"."groups" TO "authenticated";
GRANT ALL ON TABLE "public"."groups" TO "service_role";



GRANT ALL ON TABLE "public"."meta_data" TO "anon";
GRANT ALL ON TABLE "public"."meta_data" TO "authenticated";
GRANT ALL ON TABLE "public"."meta_data" TO "service_role";



GRANT ALL ON TABLE "public"."notes" TO "anon";
GRANT ALL ON TABLE "public"."notes" TO "authenticated";
GRANT ALL ON TABLE "public"."notes" TO "service_role";



GRANT ALL ON TABLE "public"."roleplayers" TO "anon";
GRANT ALL ON TABLE "public"."roleplayers" TO "authenticated";
GRANT ALL ON TABLE "public"."roleplayers" TO "service_role";



GRANT ALL ON TABLE "public"."roles" TO "anon";
GRANT ALL ON TABLE "public"."roles" TO "authenticated";
GRANT ALL ON TABLE "public"."roles" TO "service_role";



GRANT ALL ON TABLE "public"."sermons" TO "anon";
GRANT ALL ON TABLE "public"."sermons" TO "authenticated";
GRANT ALL ON TABLE "public"."sermons" TO "service_role";



GRANT ALL ON TABLE "public"."social_media" TO "anon";
GRANT ALL ON TABLE "public"."social_media" TO "authenticated";
GRANT ALL ON TABLE "public"."social_media" TO "service_role";



GRANT ALL ON TABLE "public"."user_announcements" TO "anon";
GRANT ALL ON TABLE "public"."user_announcements" TO "authenticated";
GRANT ALL ON TABLE "public"."user_announcements" TO "service_role";



GRANT ALL ON TABLE "public"."user_profile" TO "anon";
GRANT ALL ON TABLE "public"."user_profile" TO "authenticated";
GRANT ALL ON TABLE "public"."user_profile" TO "service_role";



GRANT ALL ON TABLE "public"."user_roles" TO "anon";
GRANT ALL ON TABLE "public"."user_roles" TO "authenticated";
GRANT ALL ON TABLE "public"."user_roles" TO "service_role";



GRANT ALL ON TABLE "public"."user_profile_view" TO "anon";
GRANT ALL ON TABLE "public"."user_profile_view" TO "authenticated";
GRANT ALL ON TABLE "public"."user_profile_view" TO "service_role";









ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES  TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES  TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES  TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES  TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS  TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS  TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS  TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS  TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES  TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES  TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES  TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES  TO "service_role";






























drop extension if exists "pg_net";

CREATE TRIGGER add_user_role AFTER INSERT ON auth.users FOR EACH ROW EXECUTE FUNCTION public.add_user_default_role();


