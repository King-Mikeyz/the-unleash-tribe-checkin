import { supabase } from "../supabase.js";


let authSubscription = null;

let focusHandler = null;

let expectedUserId = null;


/* =========================================================
   REDIRECT HELPERS
   ========================================================= */

function redirectToLogin(reason = "session") {

    window.location.replace(
        `login.html?reason=${encodeURIComponent(reason)}`
    );

}


/* =========================================================
   CROSS-TAB / CROSS-WINDOW SESSION PROTECTION
   ========================================================= */

function installSessionIdentityGuard(userId) {

    expectedUserId =
        userId;


    /*
     * Remove an older listener if this guard is initialized
     * more than once on the same page.
     */
    if (authSubscription) {

        authSubscription.unsubscribe();

        authSubscription = null;

    }


    if (focusHandler) {

        window.removeEventListener(
            "focus",
            focusHandler
        );

        focusHandler = null;

    }


    /*
     * Supabase broadcasts authentication changes.
     *
     * If another tab signs into a DIFFERENT account,
     * this page must no longer trust its existing UI.
     *
     * Reloading causes requireActiveUser() to perform a
     * fresh server-confirmed identity + profile check.
     */
    const {
        data: {
            subscription
        }
    } =
        supabase.auth.onAuthStateChange(
            (event, session) => {

                if (
                    event === "INITIAL_SESSION"
                    ||
                    event === "TOKEN_REFRESHED"
                ) {

                    return;

                }


                const sessionUserId =
                    session?.user?.id || null;


                if (!sessionUserId) {

                    redirectToLogin(
                        "session"
                    );

                    return;

                }


                if (
                    expectedUserId
                    &&
                    sessionUserId !==
                        expectedUserId
                ) {

                    window.location.reload();

                }

            }
        );


    authSubscription =
        subscription;


    /*
     * Also re-check whenever the user returns to this
     * browser window.
     *
     * This handles the exact scenario where one Chrome
     * window signs into another account while this window
     * is sitting in the background.
     *
     * getSession() is used only to detect a stored-session
     * identity change. Authorization itself is still
     * performed by requireActiveUser() using getUser().
     */
    focusHandler =
        async () => {

            try {

                const {
                    data: {
                        session
                    }
                } =
                    await supabase
                        .auth
                        .getSession();


                const storedUserId =
                    session?.user?.id || null;


                if (!storedUserId) {

                    redirectToLogin(
                        "session"
                    );

                    return;

                }


                if (
                    expectedUserId
                    &&
                    storedUserId !==
                        expectedUserId
                ) {

                    window.location.reload();

                }

            }
            catch (error) {

                console.error(
                    "Session identity check failed:",
                    error
                );


                window.location.reload();

            }

        };


    window.addEventListener(
        "focus",
        focusHandler
    );

}


/* =========================================================
   ACTIVE USER GUARD
   ========================================================= */

export async function requireActiveUser() {

    /*
     * getUser() performs a server-confirmed Auth lookup.
     *
     * Do not rely on the locally stored session alone for
     * authorization decisions.
     */
    const {
        data: {
            user
        },
        error: userError
    } =
        await supabase
            .auth
            .getUser();


    if (
        userError
        ||
        !user
    ) {

        redirectToLogin(
            "session"
        );

        return null;

    }


    const {
        data: profile,
        error: profileError
    } =
        await supabase
            .from(
                "profiles"
            )
            .select(
                "id, email, full_name, username, role, status, created_at"
            )
            .eq(
                "id",
                user.id
            )
            .single();


    if (
        profileError
        ||
        !profile
    ) {

        console.error(
            "Unable to load authenticated profile:",
            profileError
        );


        await supabase
            .auth
            .signOut({
                scope: "local"
            });


        redirectToLogin(
            "session"
        );

        return null;

    }


    if (
        profile.status !==
        "active"
    ) {

        /*
         * We only clear this browser session.
         *
         * The database account status is the actual access
         * control and remains authoritative.
         */
        await supabase
            .auth
            .signOut({
                scope: "local"
            });


        redirectToLogin(
            "inactive"
        );

        return null;

    }


    /*
     * Once the initial identity has been verified, protect
     * this page against another tab changing the account
     * underneath it.
     */
    installSessionIdentityGuard(
        user.id
    );


    return {
        user,
        profile
    };

}