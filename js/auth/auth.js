import { supabase } from "../supabase.js";

const form = document.querySelector("#login-form");
const emailInput = document.querySelector("#email");
const passwordInput = document.querySelector("#password");
const loginButton = document.querySelector("#login-button");
const message = document.querySelector("#auth-message");


function showMessage(text, type = "") {

    message.textContent = text;
    message.className = "auth-message";

    if (type) {
        message.classList.add(type);
    }

    message.hidden = false;
}


function hideMessage() {

    message.hidden = true;
    message.textContent = "";
    message.className = "auth-message";
}


async function getCurrentProfile(userId) {

    const { data, error } = await supabase
        .from("profiles")
        .select("id, email, full_name, role, status")
        .eq("id", userId)
        .single();

    if (error) {
        throw error;
    }

    return data;
}


async function redirectExistingSession() {

    const {
        data: { session }
    } = await supabase.auth.getSession();

    if (!session?.user) {
        return;
    }

    try {

        const profile = await getCurrentProfile(
            session.user.id
        );

        if (profile.status === "active") {
            window.location.replace("dashboard.html");
        }

    }
    catch (error) {

        console.error(
            "Existing session profile check failed:",
            error
        );

    }

}


const query = new URLSearchParams(
    window.location.search
);

const reason = query.get("reason");


if (reason === "session") {

    showMessage(
        "Please sign in to continue."
    );

}
else if (reason === "inactive") {

    showMessage(
        "Your account is not currently active.",
        "error"
    );

}
else if (reason === "logout") {

    showMessage(
        "You have been signed out.",
        "success"
    );

}


form.addEventListener(
    "submit",
    async (event) => {

        event.preventDefault();
        hideMessage();

        const email = emailInput.value
            .trim()
            .toLowerCase();

        const password = passwordInput.value;


        if (!email || !password) {

            showMessage(
                "Enter both your email address and password.",
                "error"
            );

            return;
        }


        loginButton.disabled = true;
        loginButton.textContent = "Signing in...";


        try {

            const {
                data,
                error
            } = await supabase.auth.signInWithPassword({
                email,
                password
            });


            if (error) {
                throw error;
            }


            const profile = await getCurrentProfile(
                data.user.id
            );


            if (profile.status !== "active") {

                await supabase.auth.signOut();

                showMessage(
                    profile.status === "disabled"
                        ? "Your account has been disabled. Contact an administrator."
                        : "Your membership has not been approved yet.",
                    "error"
                );

                return;
            }


            window.location.replace(
                "dashboard.html"
            );

        }
        catch (error) {

            console.error(
                "Login failed:",
                error
            );

            showMessage(
                error?.message ||
                "Unable to sign in. Please try again.",
                "error"
            );

        }
        finally {

            loginButton.disabled = false;
            loginButton.textContent = "Sign In";

        }

    }
);


redirectExistingSession();
