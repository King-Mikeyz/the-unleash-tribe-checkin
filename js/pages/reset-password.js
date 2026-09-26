import {
    supabase
} from "../supabase.js";


const form =
    document.querySelector(
        "#reset-password-form"
    );


const passwordInput =
    document.querySelector(
        "#password"
    );


const confirmPasswordInput =
    document.querySelector(
        "#confirm-password"
    );


const button =
    document.querySelector(
        "#reset-password-button"
    );


const message =
    document.querySelector(
        "#auth-message"
    );



function showMessage(
    text,
    type = ""
) {

    message.textContent =
        text;


    message.className =
        "auth-message";


    if (type) {

        message.classList.add(
            type
        );

    }


    message.hidden =
        false;

}



async function checkRecoverySession() {

    const {
        data,
        error
    } =
        await supabase.auth.getSession();



    if (
        error ||
        !data.session
    ) {

        showMessage(
            "This password reset link has expired. Please request a new one.",
            "error"
        );


        form.style.display =
            "none";


        return false;

    }


    return true;

}



function validatePassword(
    password
) {

    if (
        password.length < 8
    ) {

        return "Password must contain at least 8 characters.";

    }


    return null;

}



form.addEventListener(
    "submit",
    async (event) => {

        event.preventDefault();



        const password =
            passwordInput.value.trim();



        const confirmPassword =
            confirmPasswordInput.value.trim();



        const validationError =
            validatePassword(
                password
            );



        if (validationError) {

            showMessage(
                validationError,
                "error"
            );

            return;

        }



        if (
            password !== confirmPassword
        ) {

            showMessage(
                "Passwords do not match.",
                "error"
            );

            return;

        }



        button.disabled =
            true;


        button.textContent =
            "Updating...";



        try {


            const {
                error
            } =
                await supabase.auth.updateUser(
                    {
                        password
                    }
                );



            if (error) {

                throw error;

            }



            /*
             Important:
             Supabase creates a temporary recovery session
             during password reset.

             We remove that session so the user must
             authenticate normally after resetting.
            */

            await supabase.auth.signOut(
                {
                    scope: "local"
                }
            );



            showMessage(
                "Password updated successfully. Please sign in with your new password.",
                "success"
            );



            setTimeout(
                () => {

                    window.location.replace(
                        "login.html"
                    );

                },
                2500
            );


        }
        catch(error) {


            console.error(
                "Password reset failed:",
                error
            );


            showMessage(
                error.message ||
                "Unable to update password. Please try again.",
                "error"
            );


        }
        finally {


            button.disabled =
                false;


            button.textContent =
                "Update Password";

        }

    }
);



checkRecoverySession();