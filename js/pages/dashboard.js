import { supabase } from "../supabase.js";

import {
    requireActiveUser
} from "../auth/guards.js";


const memberName =
    document.querySelector("#member-name");

const memberAvatar =
    document.querySelector("#member-avatar");

const accountabilityDate =
    document.querySelector("#accountability-date");

const streakCount =
    document.querySelector("#streak-count");

const windowStatus =
    document.querySelector("#window-status");

const progressSection =
    document.querySelector("#progress-section");

const progressRing =
    document.querySelector("#progress-ring");

const progressPercentage =
    document.querySelector("#progress-percentage");

const progressCount =
    document.querySelector("#progress-count");

const taskList =
    document.querySelector("#task-list");

const logoutButton =
    document.querySelector("#logout-button");

const adminRequestsLink =
    document.querySelector("#admin-requests-link");

const adminTasksLink =
    document.querySelector("#admin-tasks-link");


function escapeHtml(value = "") {

    return String(value)
        .replaceAll("&", "&amp;")
        .replaceAll("<", "&lt;")
        .replaceAll(">", "&gt;")
        .replaceAll('"', "&quot;")
        .replaceAll("'", "&#039;");

}


function getDisplayIdentity(profile = {}) {

    const username =
        String(
            profile.username || ""
        ).trim();

    if (username) {
        return username;
    }


    const fullName =
        String(
            profile.full_name || ""
        ).trim();

    if (fullName) {
        return fullName;
    }


    return "Member";

}


function getInitials(value = "") {

    const parts =
        String(value)
            .trim()
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
        parts[parts.length - 1][0]
    ).toUpperCase();

}


function formatAccountabilityDate(value) {

    if (!value) {
        return "";
    }


    const date =
        new Date(
            `${value}T12:00:00`
        );


    return new Intl.DateTimeFormat(
        undefined,
        {
            weekday: "long",
            day: "numeric",
            month: "long",
            year: "numeric"
        }
    ).format(date);

}


function renderClosedState(data) {

    progressSection.hidden = true;

    windowStatus.hidden = false;


    windowStatus.innerHTML = `
        <strong>
            Daily Check In is currently closed.
        </strong>

        <div>
            The accountability window runs from
            ${escapeHtml(data.open_time)}
            until
            ${escapeHtml(data.close_time)}
            (${escapeHtml(data.timezone)}).
        </div>
    `;


    taskList.innerHTML = `
        <div class="dashboard-loading">
            Today's check-in will become available
            when the next accountability window opens.
        </div>
    `;

}


function renderTaskMarkup(task) {

    return `
        <button
            type="button"
            class="child-task-button ${
                task.completed
                    ? "is-complete"
                    : ""
            }"
            data-task-id="${escapeHtml(task.id)}"
            data-completed="${
                task.completed
                    ? "true"
                    : "false"
            }"
        >

            <span
                class="child-check"
                aria-hidden="true"
            >
                ✓
            </span>

            <span class="child-task-label">
                ${escapeHtml(task.label)}
            </span>

            ${
                task.required
                    ? `
                        <span class="required-mark">
                            REQUIRED
                        </span>
                    `
                    : ""
            }

        </button>
    `;

}


function renderCategory(
    category,
    index
) {

    const tasks =
        Array.isArray(
            category.tasks
        )
            ? category.tasks
            : [];


    const taskMarkup =
        tasks
            .map(
                renderTaskMarkup
            )
            .join("");


    return `
        <article
            class="parent-task ${
                category.completed
                    ? "is-complete"
                    : ""
            }"
        >

            <div class="parent-task-header">

                <div>

                    <div class="parent-task-number">
                        ${String(index + 1).padStart(2, "0")}
                    </div>

                    <h2>
                        ${escapeHtml(category.name)}
                    </h2>

                    <div class="parent-progress">
                        ${
                            category.completed_required_tasks ?? 0
                        }
                        /
                        ${
                            category.required_tasks ?? 0
                        }
                        required tasks complete
                    </div>

                </div>


                <span class="parent-status">

                    ${
                        category.completed
                            ? "✓ Done"
                            : "Not Done"
                    }

                </span>

            </div>


            <div class="child-task-list">
                ${taskMarkup}
            </div>

        </article>
    `;

}


function renderDashboard(data) {

    streakCount.textContent =
        String(
            data?.streak ?? 0
        );


    if (!data?.is_open) {

        accountabilityDate.textContent =
            "The Daily Check In is currently closed.";

        renderClosedState(
            data || {}
        );

        return;

    }


    windowStatus.hidden = true;


    accountabilityDate.textContent =
        `${formatAccountabilityDate(
            data.accountability_date
        )} · closes ${data.close_time} ${data.timezone}`;


    const percentage =
        Number(
            data.percentage ?? 0
        );


    progressSection.hidden = false;


    progressRing.style.setProperty(
        "--progress",
        String(percentage)
    );


    progressPercentage.textContent =
        `${percentage}%`;


    progressCount.textContent =
        `${
            data.completed_categories ?? 0
        } / ${
            data.total_categories ?? 0
        } completed`;


    const categories =
        Array.isArray(
            data.categories
        )
            ? data.categories
            : [];


    if (!categories.length) {

        taskList.innerHTML = `
            <div class="dashboard-loading">
                No tasks have been scheduled
                for this accountability day.
            </div>
        `;

        return;

    }


    taskList.innerHTML =
        categories
            .map(
                renderCategory
            )
            .join("");

}


async function loadDashboard() {

    const {
        data,
        error
    } =
        await supabase.rpc(
            "get_today_checkin_dashboard"
        );


    if (error) {

        console.error(
            "Dashboard load failed:",
            error
        );


        taskList.innerHTML = `
            <div class="dashboard-loading">
                Unable to load today's tasks.
                ${escapeHtml(error.message)}
            </div>
        `;

        return;

    }


    renderDashboard(data);

}


taskList.addEventListener(
    "click",
    async (event) => {

        const button =
            event.target.closest(
                "[data-task-id]"
            );


        if (!button) {
            return;
        }


        const taskId =
            button.dataset.taskId;

        const currentState =
            button.dataset.completed ===
            "true";


        button.disabled = true;


        try {

            const {
                data,
                error
            } =
                await supabase.rpc(
                    "set_checkin_task_state",
                    {
                        p_checklist_item_id:
                            taskId,

                        p_completed:
                            !currentState
                    }
                );


            if (error) {
                throw error;
            }


            renderDashboard(data);

        }
        catch (error) {

            console.error(
                "Task update failed:",
                error
            );


            button.disabled = false;


            window.alert(
                error?.message ||
                "Unable to update this task."
            );

        }

    }
);


logoutButton.addEventListener(
    "click",
    async () => {

        logoutButton.disabled = true;


        await supabase
            .auth
            .signOut({
                scope: "local"
            });


        window.location.replace(
            "login.html?reason=logout"
        );

    }
);


async function initializeDashboard() {

    const context =
        await requireActiveUser();


    if (!context) {
        return;
    }


    const {
        profile
    } =
        context;


    const displayIdentity =
        getDisplayIdentity(
            profile
        );


    /*
     * The member's chosen username is now the primary
     * dashboard identity.
     *
     * full_name is only a fallback for legacy accounts that
     * have not yet completed username setup.
     */
    memberName.textContent =
        displayIdentity;


    memberAvatar.textContent =
        getInitials(
            displayIdentity
        );


    if (
        profile.role ===
        "admin"
    ) {

        adminRequestsLink.hidden =
            false;

        adminTasksLink.hidden =
            false;

    }


    await loadDashboard();

}


initializeDashboard();