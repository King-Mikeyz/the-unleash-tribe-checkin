import { supabase } from "../supabase.js";

import {
    requireActiveUser
} from "../auth/guards.js";


const requestsContainer =
    document.querySelector("#requests-container");

const logoutButton =
    document.querySelector("#logout-button");

const adminMessage =
    document.querySelector("#admin-message");

const pendingCount =
    document.querySelector("#pending-count");

const activeCount =
    document.querySelector("#active-count");

const adminCount =
    document.querySelector("#admin-count");

const disabledCount =
    document.querySelector("#disabled-count");


function escapeHtml(value = "") {

    return String(value)
        .replaceAll("&", "&amp;")
        .replaceAll("<", "&lt;")
        .replaceAll(">", "&gt;")
        .replaceAll('"', "&quot;")
        .replaceAll("'", "&#039;");

}


function showMessage(text) {

    adminMessage.textContent =
        text;

    adminMessage.hidden =
        false;

}


function formatDate(value) {

    return new Intl.DateTimeFormat(
        undefined,
        {
            dateStyle: "medium",
            timeStyle: "short"
        }
    ).format(
        new Date(value)
    );

}


function displayAnswer(value) {

    if (Array.isArray(value)) {

        return value.length
            ? value.join(", ")
            : "—";

    }


    if (
        value === null
        ||
        value === undefined
        ||
        value === ""
    ) {
        return "—";
    }


    return String(value);

}


function renderApplicationAnswers(data) {

    const answers =
        Array.isArray(data.answers)
            ? data.answers
            : [];


    if (!answers.length) {

        return `
            <div class="application-answer-empty">
                This is a legacy application submitted
                before the onboarding questionnaire was introduced.
            </div>
        `;

    }


    const sections =
        new Map();


    answers.forEach(
        (item) => {

            if (!sections.has(item.section_title)) {

                sections.set(
                    item.section_title,
                    []
                );

            }


            sections.get(
                item.section_title
            ).push(item);

        }
    );


    return `
        <div class="application-version">
            Questionnaire Version
            ${escapeHtml(data.version_number ?? "—")}
        </div>

        ${
            Array.from(
                sections.entries()
            )
            .map(
                ([section, items]) => `
                    <section class="application-answer-section">

                        <h4>
                            ${escapeHtml(section)}
                        </h4>

                        ${
                            items.map(
                                (item) => `
                                    <div class="application-answer-row">

                                        <strong>
                                            ${escapeHtml(item.label)}
                                        </strong>

                                        <p>
                                            ${escapeHtml(
                                                displayAnswer(
                                                    item.answer
                                                )
                                            )}
                                        </p>

                                    </div>
                                `
                            )
                            .join("")
                        }

                    </section>
                `
            )
            .join("")
        }
    `;

}


async function loadStatistics() {

    const [
        requestResponse,
        profileResponse
    ] = await Promise.all([

        supabase
            .from("access_requests")
            .select(
                "id",
                {
                    count: "exact",
                    head: true
                }
            )
            .eq(
                "status",
                "pending"
            ),

        supabase
            .from("profiles")
            .select(
                "id, role, status"
            )

    ]);


    if (requestResponse.error) {
        throw requestResponse.error;
    }


    if (profileResponse.error) {
        throw profileResponse.error;
    }


    const profiles =
        profileResponse.data || [];


    pendingCount.textContent =
        String(
            requestResponse.count || 0
        );


    activeCount.textContent =
        String(
            profiles.filter(
                (profile) =>
                    profile.status === "active"
            ).length
        );


    adminCount.textContent =
        String(
            profiles.filter(
                (profile) =>
                    profile.role === "admin"
                    &&
                    profile.status === "active"
            ).length
        );


    disabledCount.textContent =
        String(
            profiles.filter(
                (profile) =>
                    profile.status === "disabled"
            ).length
        );

}


async function loadRequests() {

    const {
        data,
        error
    } = await supabase
        .from("access_requests")
        .select(
            "id, full_name, email, message, status, questionnaire_version_id, created_at"
        )
        .eq(
            "status",
            "pending"
        )
        .order(
            "created_at",
            {
                ascending: true
            }
        );


    if (error) {
        throw error;
    }


    renderRequests(
        data || []
    );

}


function renderRequests(requests) {

    if (requests.length === 0) {

        requestsContainer.innerHTML = `
            <div class="admin-empty">

                <strong>
                    No pending membership applications.
                </strong>

                <div>
                    New applications will appear here automatically.
                </div>

            </div>
        `;

        return;

    }


    requestsContainer.innerHTML =
        requests
            .map(
                (request) => `
                    <article
                        class="request-card"
                        data-request-id="${request.id}"
                    >

                        <div class="request-card-header">

                            <div>

                                <h3>
                                    ${escapeHtml(request.full_name)}
                                </h3>

                                <div class="request-email">
                                    ${escapeHtml(request.email)}
                                </div>

                            </div>


                            <span class="request-status">
                                PENDING
                            </span>

                        </div>


                        <div class="request-meta">
                            Submitted
                            ${formatDate(request.created_at)}
                        </div>


                        <div class="request-actions">

                            <button
                                type="button"
                                class="request-action request-review"
                                data-action="review"
                            >
                                Review Answers
                            </button>

                            <button
                                type="button"
                                class="request-action request-approve"
                                data-action="approved"
                            >
                                Approve & Invite
                            </button>

                            <button
                                type="button"
                                class="request-action request-reject"
                                data-action="rejected"
                            >
                                Reject
                            </button>

                        </div>


                        <div
                            class="application-answer-container"
                            hidden
                        ></div>

                    </article>
                `
            )
            .join("");

}


async function reviewAnswers(card) {

    const container =
        card.querySelector(
            ".application-answer-container"
        );


    if (
        container.dataset.loaded ===
        "true"
    ) {

        container.hidden =
            !container.hidden;

        return;

    }


    container.hidden =
        false;

    container.innerHTML =
        "Loading application answers...";


    const {
        data,
        error
    } = await supabase.rpc(
        "admin_get_application_answers",
        {
            p_request_id:
                card.dataset.requestId
        }
    );


    if (error) {

        container.innerHTML =
            escapeHtml(
                error.message
            );

        return;

    }


    container.dataset.loaded =
        "true";

    container.innerHTML =
        renderApplicationAnswers(data);

}


async function approveAndInvite(card) {

    const requestId =
        card.dataset.requestId;


    const {
        error: approvalError
    } = await supabase.rpc(
        "admin_review_access_request",
        {
            p_request_id:
                requestId,

            p_decision:
                "approved",

            p_rejection_reason:
                null
        }
    );


    if (approvalError) {
        throw approvalError;
    }


    const {
        data,
        error: invitationError
    } = await supabase.functions.invoke(
        "invite-approved-member",
        {
            body: {
                requestId
            }
        }
    );


    if (invitationError) {

        throw new Error(
            `Application approved, but the invitation email failed: ${invitationError.message}`
        );

    }


    if (data?.error) {

        throw new Error(
            `Application approved, but the invitation email failed: ${data.error}`
        );

    }


    showMessage(
        `Application approved. Invitation sent to ${data.email}.`
    );

}


requestsContainer.addEventListener(
    "click",
    async (event) => {

        const button =
            event.target.closest(
                "[data-action]"
            );


        if (!button) {
            return;
        }


        const card =
            button.closest(
                "[data-request-id]"
            );


        if (!card) {
            return;
        }


        const action =
            button.dataset.action;


        if (action === "review") {

            await reviewAnswers(card);

            return;

        }


        const confirmed =
            window.confirm(
                action === "approved"
                    ? "Approve this application and send the member an account invitation?"
                    : "Reject this membership application?"
            );


        if (!confirmed) {
            return;
        }


        const buttons =
            card.querySelectorAll(
                "button"
            );


        buttons.forEach(
            (item) => {
                item.disabled = true;
            }
        );


        try {

            if (action === "approved") {

                await approveAndInvite(card);

            }
            else {

                const {
                    error
                } = await supabase.rpc(
                    "admin_review_access_request",
                    {
                        p_request_id:
                            card.dataset.requestId,

                        p_decision:
                            "rejected",

                        p_rejection_reason:
                            null
                    }
                );


                if (error) {
                    throw error;
                }


                showMessage(
                    "Membership application rejected."
                );

            }


            await refreshAdminConsole();

        }
        catch (error) {

            console.error(
                "Application review failed:",
                error
            );


            showMessage(
                error.message
            );


            buttons.forEach(
                (item) => {
                    item.disabled = false;
                }
            );

        }

    }
);


async function refreshAdminConsole() {

    try {

        await Promise.all([
            loadStatistics(),
            loadRequests()
        ]);

    }
    catch (error) {

        console.error(
            "Admin console failed:",
            error
        );


        showMessage(
            error.message
        );

    }

}


logoutButton.addEventListener(
    "click",
    async () => {

        logoutButton.disabled =
            true;

        logoutButton.textContent =
            "Signing out...";


        await supabase.auth.signOut();


        window.location.replace(
            "login.html?reason=logout"
        );

    }
);


async function initializeAdminConsole() {

    const context =
        await requireActiveUser();


    if (!context) {
        return;
    }


    if (
        context.profile.role !==
        "admin"
    ) {

        window.location.replace(
            "dashboard.html"
        );

        return;

    }


    await refreshAdminConsole();

}


initializeAdminConsole();