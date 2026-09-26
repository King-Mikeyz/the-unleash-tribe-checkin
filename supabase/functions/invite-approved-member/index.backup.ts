import { createClient } from "npm:@supabase/supabase-js@2";


const corsHeaders = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers":
        "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods":
        "POST, OPTIONS"
};


Deno.serve(
    async (request) => {

        if (request.method === "OPTIONS") {

            return new Response(
                "ok",
                {
                    headers:
                        corsHeaders
                }
            );

        }


        if (request.method !== "POST") {

            return Response.json(
                {
                    error:
                        "Method not allowed."
                },
                {
                    status: 405,
                    headers:
                        corsHeaders
                }
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

                throw new Error(
                    "Required Supabase environment variables are unavailable."
                );

            }


            const authorization =
                request.headers.get(
                    "Authorization"
                );


            if (!authorization) {

                return Response.json(
                    {
                        error:
                            "Authentication required."
                    },
                    {
                        status: 401,
                        headers:
                            corsHeaders
                    }
                );

            }


            const userClient =
                createClient(
                    supabaseUrl,
                    anonKey,
                    {
                        global: {
                            headers: {
                                Authorization:
                                    authorization
                            }
                        },
                        auth: {
                            persistSession:
                                false,
                            autoRefreshToken:
                                false
                        }
                    }
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


            const {
                data: {
                    user
                },
                error: userError
            } =
                await userClient.auth.getUser();


            if (
                userError
                ||
                !user
            ) {

                return Response.json(
                    {
                        error:
                            "Invalid administrator session."
                    },
                    {
                        status: 401,
                        headers:
                            corsHeaders
                    }
                );

            }


            const {
                data: actorProfile,
                error: profileError
            } =
                await adminClient
                    .from("profiles")
                    .select(
                        "role, status"
                    )
                    .eq(
                        "id",
                        user.id
                    )
                    .single();


            if (
                profileError
                ||
                !actorProfile
                ||
                actorProfile.role !==
                    "admin"
                ||
                actorProfile.status !==
                    "active"
            ) {

                return Response.json(
                    {
                        error:
                            "Administrator access required."
                    },
                    {
                        status: 403,
                        headers:
                            corsHeaders
                    }
                );

            }


            const body =
                await request.json();


            const requestId =
                body?.requestId;


            if (!requestId) {

                return Response.json(
                    {
                        error:
                            "Application request ID is required."
                    },
                    {
                        status: 400,
                        headers:
                            corsHeaders
                    }
                );

            }


            const {
                data: application,
                error: applicationError
            } =
                await adminClient
                    .from(
                        "access_requests"
                    )
                    .select(
                        "id, email, full_name, status"
                    )
                    .eq(
                        "id",
                        requestId
                    )
                    .single();


            if (
                applicationError
                ||
                !application
            ) {

                return Response.json(
                    {
                        error:
                            "Approved application was not found."
                    },
                    {
                        status: 404,
                        headers:
                            corsHeaders
                    }
                );

            }


            if (
                application.status !==
                "approved"
            ) {

                return Response.json(
                    {
                        error:
                            "The application must be approved before an invitation can be sent."
                    },
                    {
                        status: 400,
                        headers:
                            corsHeaders
                    }
                );

            }


            const appSiteUrl =
                Deno.env.get(
                    "APP_SITE_URL"
                )
                ??
                "http://127.0.0.1:5500";


            const redirectTo =
                `${appSiteUrl.replace(/\/$/, "")}/setup-account.html`;


            const {
                data,
                error: inviteError
            } =
                await adminClient
                    .auth
                    .admin
                    .inviteUserByEmail(
                        application.email,
                        {
                            data: {
                                full_name:
                                    application.full_name
                            },
                            redirectTo
                        }
                    );


            if (inviteError) {

                return Response.json(
                    {
                        error:
                            inviteError.message
                    },
                    {
                        status: 400,
                        headers:
                            corsHeaders
                    }
                );

            }


            await adminClient
                .from(
                    "admin_audit_log"
                )
                .insert({
                    actor_user_id:
                        user.id,

                    target_user_id:
                        data.user?.id
                        ?? null,

                    action:
                        "membership_invitation_sent",

                    details: {
                        request_id:
                            application.id,

                        email:
                            application.email,

                        redirect_to:
                            redirectTo
                    }
                });


            return Response.json(
                {
                    success:
                        true,

                    email:
                        application.email
                },
                {
                    status: 200,
                    headers:
                        corsHeaders
                }
            );

        }
        catch (error) {

            console.error(error);


            return Response.json(
                {
                    error:
                        error instanceof Error
                            ? error.message
                            : "Unexpected invitation error."
                },
                {
                    status: 500,
                    headers:
                        corsHeaders
                }
            );

        }

    }
);