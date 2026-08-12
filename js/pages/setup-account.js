import { supabase } from "../supabase.js";


const form =
    document.querySelector("#setup-form");

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


function showMessage(text, type = "") {

    message.textContent =
        text;

    message.className =
        "auth-message";

    if (type) {
        message.classList.add(type);
    }

    message.hidden = false;

}


function showSetupForm(user) {

    currentUser = user;

    form.hidden = false;


    showMessage(
        `Invitation verified for ${user.email}. Choose your username and password.`,
        "success"
    );

}


async function detectInviteSession() {

    const hashParams =
        new URLSearchParams(
            window.location.hash
                .replace(/^#/, "")
        );


    if (hashParams.get("error_description")) {

        showMessage(
            hashParams.get("error_description"),
            "error"
        );

        return;

    }


    const {
        data: { session },
        error
    } = await supabase.auth.getSession();


    if (error) {

        showMessage(
            error.message,
            "error"
        );

        return;

    }


    if (session?.user) {

        showSetupForm(
            session.user
        );

        return;

    }


    showMessage(
        "No valid invitation session was found. The invitation may have expired or already been used. Ask an administrator to send another invitation.",
        "error"
    );

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
            usernameInput.value.trim();


        const password =
            passwordInput.value;

        const confirmPassword =
            confirmPasswordInput.value;


        if (
            !/^[A-Za-z0-9_]{3,30}$/.test(
                username
            )
        ) {

            showMessage(
                "Username must contain only letters, numbers or underscores and be 3–30 characters long.",
                "error"
            );

            return;

        }


        if (password.length < 8) {

            showMessage(
                "Password must contain at least 8 characters.",
                "error"
            );

            return;

        }


        if (password !== confirmPassword) {

            showMessage(
                "The passwords do not match.",
                "error"
            );

            return;

        }


        button.disabled = true;

        button.textContent =
            "Completing Setup...";


        try {

            const {
                error: profileError
            } = await supabase
                .from("profiles")
                .update({
                    username
                })
                .eq(
                    "id",
                    currentUser.id
                );


            if (profileError) {

                if (profileError.code === "23505") {

                    throw new Error(
                        "That username is already taken. Choose another username."
                    );

                }

                throw profileError;

            }


            const {
                error: passwordError
            } = await supabase.auth.updateUser({
                password,
                data: {
                    username
                }
            });


            if (passwordError) {
                throw passwordError;
            }


            await supabase.auth.signOut();


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
                error.message ||
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