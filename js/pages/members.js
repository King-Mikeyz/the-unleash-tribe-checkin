import { supabase } from "../supabase.js";

import {
    requireActiveUser
} from "../auth/guards.js";


const list =
    document.querySelector("#members-list");

const search =
    document.querySelector("#member-search");

const message =
    document.querySelector("#members-message");

const logoutButton =
    document.querySelector("#logout-button");

const activeCount =
    document.querySelector("#active-members");

const adminCount =
    document.querySelector("#admin-members");

const disabledCount =
    document.querySelector("#disabled-members");

const totalCount =
    document.querySelector("#total-members");


let profiles = [];
let currentUserId = null;


function escapeHtml(value = "") {

    return String(value)
        .replaceAll("&", "&amp;")
        .replaceAll("<", "&lt;")
        .replaceAll(">", "&gt;")
        .replaceAll('"', "&quot;")
        .replaceAll("'", "&#039;");

}


function initials(name = "") {

    const parts =
        name.trim()
            .split(/\s+/)
            .filter(Boolean);


    if (!parts.length) {
        return "UT";
    }


    if (parts.length === 1) {
        return parts[0]
            .slice(0, 2)
            .toUpperCase();
    }


    return (
        parts[0][0] +
        parts.at(-1)[0]
    ).toUpperCase();

}


function showMessage(text) {

    message.textContent = text;
    message.hidden = false;

}


function updateStats() {

    totalCount.textContent =
        String(profiles.length);


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


function renderProfiles() {

    const term =
        search.value
            .trim()
            .toLowerCase();


    const filtered =
        profiles.filter(
            (profile) => {

                const haystack = [
                    profile.full_name,
                    profile.username,
                    profile.email
                ]
                    .filter(Boolean)
                    .join(" ")
                    .toLowerCase();


                return haystack.includes(term);

            }
        );


    if (!filtered.length) {

        list.innerHTML = `
            <div class="admin-empty">
                No members match your search.
            </div>
        `;

        return;
    }


    list.innerHTML =
        filtered.map(
            (profile) => {

                const self =
                    profile.id ===
                    currentUserId;


                return `
                    <article class="member-row">

                        <div class="member-identity">

                            <div class="member-mini-avatar">
                                ${escapeHtml(initials(profile.full_name))}
                            </div>

                            <div>

                                <strong>
                                    ${escapeHtml(profile.full_name)}
                                </strong>

                                <small>
                                    ${
                                        profile.username
                                            ? `@${escapeHtml(profile.username)} · `
                                            : ""
                                    }
                                    ${escapeHtml(profile.email)}
                                </small>

                            </div>

                        </div>


                        <span class="member-badge">
                            ${escapeHtml(profile.role)}
                        </span>


                        <span class="member-badge">
                            ${escapeHtml(profile.status)}
                        </span>


                        <div class="member-actions">

                            ${
                                self
                                    ? `
                                        <span class="current-user-note">
                                            Your account
                                        </span>
                                    `
                                    : `
                                        ${
                                            profile.status === "active"
                                                ? `
                                                    <button
                                                        type="button"
                                                        class="role-button"
                                                        data-role-user="${profile.id}"
                                                        data-next-role="${
                                                            profile.role === "admin"
                                                                ? "member"
                                                                : "admin"
                                                        }"
                                                    >
                                                        ${
                                                            profile.role === "admin"
                                                                ? "Demote"
                                                                : "Promote to Admin"
                                                        }
                                                    </button>

                                                    <button
                                                        type="button"
                                                        class="disable-button"
                                                        data-status-user="${profile.id}"
                                                        data-next-status="disabled"
                                                    >
                                                        Disable
                                                    </button>
                                                `
                                                : ""
                                        }

                                        ${
                                            profile.status === "disabled"
                                                ? `
                                                    <button
                                                        type="button"
                                                        class="restore-button"
                                                        data-status-user="${profile.id}"
                                                        data-next-status="active"
                                                    >
                                                        Restore
                                                    </button>
                                                `
                                                : ""
                                        }

                                        ${
                                            profile.status === "pending"
                                                ? `
                                                    <button
                                                        type="button"
                                                        class="restore-button"
                                                        data-status-user="${profile.id}"
                                                        data-next-status="active"
                                                    >
                                                        Activate
                                                    </button>
                                                `
                                                : ""
                                        }
                                    `
                            }

                        </div>

                    </article>
                `;

            }
        ).join("");

}


async function loadProfiles() {

    const {
        data,
        error
    } = await supabase
        .from("profiles")
        .select(
            "id, full_name, username, email, role, status, created_at, approved_at"
        )
        .order(
            "full_name",
            {
                ascending: true
            }
        );


    if (error) {
        throw error;
    }


    profiles =
        data || [];


    updateStats();
    renderProfiles();

}


list.addEventListener(
    "click",
    async (event) => {

        const roleButton =
            event.target.closest(
                "[data-role-user]"
            );

        const statusButton =
            event.target.closest(
                "[data-status-user]"
            );


        if (roleButton) {

            const nextRole =
                roleButton.dataset.nextRole;


            const confirmed =
                window.confirm(
                    nextRole === "admin"
                        ? "Promote this member to administrator?"
                        : "Demote this administrator to member?"
                );


            if (!confirmed) {
                return;
            }


            roleButton.disabled = true;


            const {
                error
            } = await supabase.rpc(
                "admin_set_user_role",
                {
                    p_user_id:
                        roleButton.dataset.roleUser,

                    p_role:
                        nextRole
                }
            );


            if (error) {

                showMessage(error.message);
                roleButton.disabled = false;

                return;

            }


            showMessage(
                nextRole === "admin"
                    ? "Member promoted to administrator."
                    : "Administrator demoted to member."
            );


            await loadProfiles();

            return;

        }


        if (statusButton) {

            const nextStatus =
                statusButton.dataset.nextStatus;


            const confirmed =
                window.confirm(
                    nextStatus === "disabled"
                        ? "Disable this member account?"
                        : "Restore this member account?"
                );


            if (!confirmed) {
                return;
            }


            statusButton.disabled = true;


            const {
                error
            } = await supabase.rpc(
                "admin_set_user_status",
                {
                    p_user_id:
                        statusButton.dataset.statusUser,

                    p_status:
                        nextStatus
                }
            );


            if (error) {

                showMessage(error.message);
                statusButton.disabled = false;

                return;

            }


            showMessage(
                nextStatus === "disabled"
                    ? "Member disabled."
                    : "Member restored."
            );


            await loadProfiles();

        }

    }
);


search.addEventListener(
    "input",
    renderProfiles
);


logoutButton.addEventListener(
    "click",
    async () => {

        await supabase.auth.signOut();

        window.location.replace(
            "login.html?reason=logout"
        );

    }
);


async function initialize() {

    const context =
        await requireActiveUser();


    if (!context) {
        return;
    }


    if (context.profile.role !== "admin") {

        window.location.replace(
            "dashboard.html"
        );

        return;

    }


    currentUserId =
        context.user.id;


    try {

        await loadProfiles();

    }
    catch (error) {

        console.error(error);

        showMessage(
            error.message
        );

    }

}


initialize();