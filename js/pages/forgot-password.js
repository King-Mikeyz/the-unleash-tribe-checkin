import {
    supabase
} from "../supabase.js";


import {
    AUTH_REDIRECTS
} from "../config.js";



const form =
    document.querySelector(
        "#forgot-password-form"
    );


const emailInput =
    document.querySelector(
        "#email"
    );


const button =
    document.querySelector(
        "#forgot-password-button"
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
        message.classList.add(type);
    }


    message.hidden =
        false;

}



form.addEventListener(
    "submit",
    async (event) => {

        event.preventDefault();


        const email =
            emailInput.value
                .trim();



        if (!email) {

            showMessage(
                "Please enter your email address.",
                "error"
            );

            return;

        }



        button.disabled =
            true;


        button.textContent =
            "Sending...";



        try {


            const {
                error
            } =
                await supabase.auth
                    .resetPasswordForEmail(
                        email,
                        {
                            redirectTo:
                                AUTH_REDIRECTS.passwordReset
                        }
                    );



            if (error) {
                throw error;
            }



            showMessage(
                "If an account exists with that email, a reset link has been sent.",
                "success"
            );


        }
        catch(error) {


            console.error(
                error
            );


            showMessage(
                "Unable to send reset link. Please try again.",
                "error"
            );


        }
        finally {


            button.disabled =
                false;


            button.textContent =
                "Send Reset Link";


        }

    }
);