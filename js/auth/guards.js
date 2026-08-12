import { supabase } from "../supabase.js";


export async function requireActiveUser() {

    const {
        data: { user },
        error: userError
    } = await supabase.auth.getUser();


    if (userError || !user) {

        window.location.replace(
            "login.html?reason=session"
        );

        return null;
    }


    const {
        data: profile,
        error: profileError
    } = await supabase
        .from("profiles")
        .select(
            "id, email, full_name, username, role, status, created_at"
        )
        .eq("id", user.id)
        .single();


    if (
        profileError ||
        !profile ||
        profile.status !== "active"
    ) {

        await supabase.auth.signOut();

        window.location.replace(
            "login.html?reason=inactive"
        );

        return null;
    }


    return {
        user,
        profile
    };

}
