import { createClient } from "npm:@supabase/supabase-js@2";


const LOCAL_ORIGINS = new Set([
    "http://127.0.0.1:5500",
    "http://localhost:5500"
]);


function getAllowedOrigins() {

    const origins =
        new Set(LOCAL_ORIGINS);

    const appSiteUrl =
        Deno.env.get(
            "APP_SITE_URL"
        );

    if (appSiteUrl) {

        try {

            origins.add(
                new URL(
                    appSiteUrl
                ).origin
            );

        }
        catch {
            // Ignore an invalid optional APP_SITE_URL here.
            // Required environment configuration is checked
            // separately when necessary.
        }

    }

    return origins;

}


function getCorsHeaders(
    request: Request
) {

    const origin =
        request.headers.get(
            "Origin"
        );

    const allowedOrigins =
        getAllowedOrigins();

    const allowedOrigin =
        origin &&
        allowedOrigins.has(origin)
            ? origin
            : "";

    return {
        "Access-Control-Allow-Origin":
            allowedOrigin,

        "Access-Control-Allow-Headers":
            "authorization, x-client-info, apikey, content-type",

        "Access-Control-Allow-Methods":
            "POST, OPTIONS",

        "Vary":
            "Origin"
    };

}


function jsonResponse(
    request: Request,
    body: Record<string, unknown>,
    status = 200
) {

    return new Response(
        JSON.stringify(body),
        {
            status,

            headers: {
                ...getCorsHeaders(
                    request
                ),

                "Content-Type":
                    "application/json",

                "Cache-Control":
                    "no-store"
            }
        }
    );

}


function normalizeUsername(
    value: string
) {

    return value
        .trim()
        .replace(
            /\s+/g,
            " "
        )
        .toLowerCase();

}


function usernameLooksValid(
    value: string
) {

    const clean =
        value
            .trim()
            .replace(
                /\s+/g,
                " "
            );

    return (
        clean.length >= 3
        &&
        clean.length <= 30
        &&
        /^[A-Za-z0-9][A-Za-z0-9 _-]*[A-Za-z0-9]$/.test(
            clean
        )
    );

}


Deno.serve(
    async (request) => {

        const origin =
            request.headers.get(
                "Origin"
            );

        const allowedOrigins =
            getAllowedOrigins();


        if (
            origin
            &&
            !allowedOrigins.has(
                origin
            )
        ) {

            return new Response(
                JSON.stringify({
                    error:
                        "Origin not allowed."
                }),
                {
                    status: 403,

                    headers: {
                        "Content-Type":
                            "application/json",

                        "Cache-Control":
                            "no-store"
                    }
                }
            );

        }


        if (
            request.method ===
            "OPTIONS"
        ) {

            return new Response(
                null,
                {
                    status: 204,

                    headers:
                        getCorsHeaders(
                            request
                        )
                }
            );

        }


        if (
            request.method !==
            "POST"
        ) {

            return jsonResponse(
                request,
                {
                    error:
                        "Method not allowed."
                },
                405
            );

        }


        try {

            const supabaseUrl =
                Deno.env.get(
                    "SUPABASE_URL"
                );

            const anonKey =
                Deno.env.get(
                    "SUPABASE_ANON_KEY"
                );

            const serviceRoleKey =
                Deno.env.get(
                    "SUPABASE_SERVICE_ROLE_KEY"
                );


            if (
                !supabaseUrl
                ||
                !anonKey
                ||
                !serviceRoleKey
            ) {

                console.error(
                    "Username login environment is incomplete."
                );

                return jsonResponse(
                    request,
                    {
                        error:
                            "Unable to sign in right now."
                    },
                    500
                );

            }


            let body:
                {
                    username?: unknown;
                    password?: unknown;
                };


            try {

                body =
                    await request.json();

            }
            catch {

                return jsonResponse(
                    request,
                    {
                        error:
                            "Invalid request."
                    },
                    400
                );

            }


            if (
                typeof body.username !==
                    "string"
                ||
                typeof body.password !==
                    "string"
            ) {

                return jsonResponse(
                    request,
                    {
                        error:
                            "Enter your username and password."
                    },
                    400
                );

            }


            const submittedUsername =
                body.username;

            const password =
                body.password;


            if (
                !usernameLooksValid(
                    submittedUsername
                )
                ||
                password.length < 1
                ||
                password.length > 256
            ) {

                return jsonResponse(
                    request,
                    {
                        error:
                            "Invalid username or password."
                    },
                    401
                );

            }


            const normalizedUsername =
                normalizeUsername(
                    submittedUsername
                );


            const adminClient =
                createClient(
                    supabaseUrl,
                    serviceRoleKey,
                    {
                        auth: {
                            persistSession:
                                false,

                            autoRefreshToken:
                                false
                        }
                    }
                );


            const authClient =
                createClient(
                    supabaseUrl,
                    anonKey,
                    {
                        auth: {
                            persistSession:
                                false,

                            autoRefreshToken:
                                false
                        }
                    }
                );


            const {
                data: profile,
                error: profileError
            } =
                await adminClient
                    .from(
                        "profiles"
                    )
                    .select(
                        "id, status"
                    )
                    .eq(
                        "username_normalized",
                        normalizedUsername
                    )
                    .maybeSingle();


            if (
                profileError
                ||
                !profile
            ) {

                /*
                 * Still perform an Auth password attempt using
                 * a deliberately nonexistent account.
                 *
                 * This keeps failed-username handling closer
                 * to failed-password handling and ensures the
                 * normal Supabase Auth sign-in rate limiting
                 * participates in failed attempts.
                 */

                await authClient
                    .auth
                    .signInWithPassword({
                        email:
                            "invalid-login@invalid.local",

                        password
                    });


                return jsonResponse(
                    request,
                    {
                        error:
                            "Invalid username or password."
                    },
                    401
                );

            }


            const {
                data: authUserData,
                error: authUserError
            } =
                await adminClient
                    .auth
                    .admin
                    .getUserById(
                        profile.id
                    );


            const email =
                authUserData
                    ?.user
                    ?.email;


            if (
                authUserError
                ||
                !email
            ) {

                console.error(
                    "Username resolved to a profile without a usable Auth user."
                );

                return jsonResponse(
                    request,
                    {
                        error:
                            "Invalid username or password."
                    },
                    401
                );

            }


            const {
                data: signInData,
                error: signInError
            } =
                await authClient
                    .auth
                    .signInWithPassword({
                        email,
                        password
                    });


            if (
                signInError
                ||
                !signInData.session
            ) {

                return jsonResponse(
                    request,
                    {
                        error:
                            "Invalid username or password."
                    },
                    401
                );

            }


            if (
                profile.status !==
                "active"
            ) {

                await authClient
                    .auth
                    .signOut();


                return jsonResponse(
                    request,
                    {
                        error:
                            "Your account is not currently active."
                    },
                    403
                );

            }


            return jsonResponse(
                request,
                {
                    access_token:
                        signInData
                            .session
                            .access_token,

                    refresh_token:
                        signInData
                            .session
                            .refresh_token
                },
                200
            );

        }
        catch (error) {

            console.error(
                "Username login failed:",
                error instanceof Error
                    ? error.message
                    : "Unknown error"
            );


            return jsonResponse(
                request,
                {
                    error:
                        "Unable to sign in right now."
                },
                500
            );

        }

    }
);