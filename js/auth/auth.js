import { supabase } from "../supabase.js";


const form =
    document.querySelector("#login-form");

const usernameInput =
    document.querySelector("#username");

const passwordInput =
    document.querySelector("#password");

const loginButton =
    document.querySelector("#login-button");

const message =
    document.querySelector("#auth-message");


function showMessage(
    text,
    type = ""
) {

    message.textContent =
        text;

    message.className =
        "auth-message";

    if (type) {
        message.classList.add(type);
    }

    message.hidden = false;

}


function hideMessage() {

    message.hidden = true;

    message.textContent = "";

    message.className =
        "auth-message";

}


function normalizeUsername(value = "") {

    return value
        .trim()
        .replace(/\s+/g, " ");

}


async function getCurrentProfile(
    userId
) {

    const {
        data,
        error
    } =
        await supabase
            .from("profiles")
            .select(
                "id, email, full_name, username, role, status"
            )
            .eq(
                "id",
                userId
            )
            .single();


    if (error) {
        throw error;
    }


    return data;

}


async function getFunctionErrorMessage(
    error
) {

    if (!error) {
        return "Unable to sign in.";
    }


    const response =
        error.context;


    if (
        response &&
        typeof response.clone ===
            "function"
    ) {

        try {

            const payload =
                await response
                    .clone()
                    .json();


            if (
                typeof payload?.error ===
                "string"
            ) {

                return payload.error;

            }

        }
        catch {
            // Fall back to the SDK error below.
        }

    }


    return (
        error.message ||
        "Unable to sign in."
    );

}


async function redirectExistingSession() {

    const {
        data: {
            session
        }
    } =
        await supabase.auth.getSession();


    if (!session?.user) {
        return;
    }


    try {

        const profile =
            await getCurrentProfile(
                session.user.id
            );


        if (
            profile.status ===
            "active"
        ) {

            window.location.replace(
                "dashboard.html"
            );

            return;

        }


        await supabase
            .auth
            .signOut({
                scope: "local"
            });

    }
    catch (error) {

        console.error(
            "Existing session check failed:",
            error
        );

    }

}


const query =
    new URLSearchParams(
        window.location.search
    );

const reason =
    query.get("reason");


if (reason === "session") {

    showMessage(
        "Please sign in to continue."
    );

}
else if (
    reason === "inactive"
) {

    showMessage(
        "Your account is not currently active.",
        "error"
    );

}
else if (
    reason === "logout"
) {

    showMessage(
        "You have been signed out.",
        "success"
    );

}
else if (
    reason === "setup"
) {

    showMessage(
        "Account setup complete. Sign in with your username.",
        "success"
    );

}


form.addEventListener(
    "submit",
    async (event) => {

        event.preventDefault();

        hideMessage();


        const username =
            normalizeUsername(
                usernameInput.value
            );

        const password =
            passwordInput.value;


        if (
            !username ||
            !password
        ) {

            showMessage(
                "Enter your username and password.",
                "error"
            );

            return;

        }


        loginButton.disabled = true;

        loginButton.textContent =
            "Signing in...";


        try {

            /*
             * Username resolution occurs inside the trusted
             * Edge Function.
             *
             * The browser never receives or queries the email
             * address that corresponds to another username.
             */
            const {
                data,
                error
            } =
                await supabase
                    .functions
                    .invoke(
                        "username-login",
                        {
                            body: {
                                username,
                                password
                            }
                        }
                    );


            if (error) {

                const errorMessage =
                    await getFunctionErrorMessage(
                        error
                    );

                throw new Error(
                    errorMessage
                );

            }


            if (
                !data?.access_token ||
                !data?.refresh_token
            ) {

                throw new Error(
                    "Unable to establish your session."
                );

            }


            /*
             * Persist the authenticated session returned by
             * the trusted login function into this browser's
             * normal Supabase client.
             */
            const {
                data: sessionData,
                error: sessionError
            } =
                await supabase
                    .auth
                    .setSession({
                        access_token:
                            data.access_token,

                        refresh_token:
                            data.refresh_token
                    });


            if (sessionError) {
                throw sessionError;
            }


            if (
                !sessionData?.user
            ) {

                throw new Error(
                    "Unable to establish your session."
                );

            }


            const profile =
                await getCurrentProfile(
                    sessionData.user.id
                );


            if (
                profile.status !==
                "active"
            ) {

                await supabase
                    .auth
                    .signOut({
                        scope: "local"
                    });


                throw new Error(
                    "Your account is not currently active."
                );

            }


            if (!profile.username) {

                await supabase
                    .auth
                    .signOut({
                        scope: "local"
                    });


                throw new Error(
                    "Your account setup is incomplete. Contact an administrator."
                );

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
                "Invalid username or password.",
                "error"
            );

        }
        finally {

            loginButton.disabled = false;

            loginButton.textContent =
                "Sign In";

        }

    }
);


redirectExistingSession();