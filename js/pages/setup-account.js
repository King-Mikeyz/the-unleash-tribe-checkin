import { supabase } from "../supabase.js";


const form =
    document.querySelector("#setup-form");

const emailInput =
    document.querySelector("#setup-email");

const usernameInput =
    document.querySelector("#setup-username");

const passwordInput =
    document.querySelector("#setup-password");

const confirmPasswordInput =
    document.querySelector("#setup-confirm-password");

const button =
    document.querySelector("#setup-button");

const message =
    document.querySelector("#setup-message");


let currentUser = null;


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


function normalizeUsername(value = "") {

    return value
        .trim()
        .replace(/\s+/g, " ");

}


function usernameIsValid(value) {

    const username =
        normalizeUsername(value);

    if (
        username.length < 3 ||
        username.length > 30
    ) {
        return false;
    }

    return /^[A-Za-z0-9][A-Za-z0-9 _-]*[A-Za-z0-9]$/.test(
        username
    );

}


function showSetupForm(user) {

    currentUser = user;

    emailInput.value =
        user.email || "";

    form.hidden = false;

    showMessage(
        "Invitation verified. Complete your account to continue.",
        "success"
    );

    usernameInput.focus();

}


async function detectInviteSession() {

    const hashParams =
        new URLSearchParams(
            window.location.hash.replace(
                /^#/,
                ""
            )
        );


    const invitationError =
        hashParams.get(
            "error_description"
        );


    if (invitationError) {

        showMessage(
            invitationError,
            "error"
        );

        return;

    }


    try {

        const {
            data: {
                session
            },
            error
        } =
            await supabase.auth.getSession();


        if (error) {
            throw error;
        }


        if (session?.user) {

            showSetupForm(
                session.user
            );

            return;

        }


        showMessage(
            "This invitation is no longer valid. Ask an administrator to send a new invitation.",
            "error"
        );

    }
    catch (error) {

        console.error(
            "Invitation verification failed:",
            error
        );

        showMessage(
            "Unable to verify this invitation.",
            "error"
        );

    }

}


form.addEventListener(
    "submit",
    async (event) => {

        event.preventDefault();


        if (!currentUser) {

            showMessage(
                "Your invitation session is no longer available.",
                "error"
            );

            return;

        }


        const username =
            normalizeUsername(
                usernameInput.value
            );

        const password =
            passwordInput.value;

        const confirmPassword =
            confirmPasswordInput.value;


        if (!usernameIsValid(username)) {

            showMessage(
                "Choose a username between 3 and 30 characters using letters, numbers, spaces, hyphens or underscores.",
                "error"
            );

            usernameInput.focus();

            return;

        }


        if (password.length < 8) {

            showMessage(
                "Your password must contain at least 8 characters.",
                "error"
            );

            passwordInput.focus();

            return;

        }


        if (password.length > 128) {

            showMessage(
                "Your password is too long.",
                "error"
            );

            passwordInput.focus();

            return;

        }


        if (
            password !==
            confirmPassword
        ) {

            showMessage(
                "The passwords do not match.",
                "error"
            );

            confirmPasswordInput.focus();

            return;

        }


        button.disabled = true;

        button.textContent =
            "Completing Setup...";


        try {

            /*
             * Save the member's chosen username.
             *
             * RLS limits this profile update to the currently
             * authenticated invited user.
             */
            const {
                error: profileError
            } =
                await supabase
                    .from("profiles")
                    .update({
                        username
                    })
                    .eq(
                        "id",
                        currentUser.id
                    );


            if (profileError) {

                if (
                    profileError.code ===
                    "23505"
                ) {

                    throw new Error(
                        "That username is already taken. Choose another one."
                    );

                }


                if (
                    profileError.code ===
                    "23514"
                ) {

                    throw new Error(
                        "That username cannot be used. Choose another one."
                    );

                }


                throw profileError;

            }


            /*
             * Set the permanent Auth password and keep the
             * username in Auth metadata as a convenience copy.
             *
             * public.profiles remains the application identity
             * source of truth.
             */
            const {
                error: passwordError
            } =
                await supabase
                    .auth
                    .updateUser({
                        password,

                        data: {
                            username
                        }
                    });


            if (passwordError) {
                throw passwordError;
            }


            /*
             * The invitation session has served its purpose.
             * Remove only this browser's session.
             */
            await supabase
                .auth
                .signOut({
                    scope: "local"
                });


            window.location.replace(
                "login.html?reason=setup"
            );

        }
        catch (error) {

            console.error(
                "Account setup failed:",
                error
            );


            showMessage(
                error?.message ||
                "Unable to complete account setup.",
                "error"
            );

        }
        finally {

            button.disabled = false;

            button.textContent =
                "Complete Account Setup";

        }

    }
);


detectInviteSession();