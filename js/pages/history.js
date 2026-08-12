import { supabase } from "../supabase.js";

import {
    requireActiveUser
} from "../auth/guards.js";


const historyList =
    document.querySelector("#history-list");

const adminLink =
    document.querySelector("#admin-link");

const logoutButton =
    document.querySelector("#logout-button");


function formatDate(value) {

    return new Intl.DateTimeFormat(
        undefined,
        {
            weekday: "short",
            day: "numeric",
            month: "short",
            year: "numeric"
        }
    ).format(
        new Date(
            `${value}T12:00:00`
        )
    );

}


function statusLabel(status) {

    if (status === "done") {
        return "Done";
    }

    if (status === "incomplete") {
        return "Incomplete";
    }

    return "Not Started";

}


async function loadHistory() {

    const {
        data,
        error
    } = await supabase.rpc(
        "get_my_checkin_history",
        {
            p_limit: 30
        }
    );


    if (error) {
        throw error;
    }


    if (!data?.length) {

        historyList.innerHTML = `
            <div class="dashboard-loading">
                No accountability history yet.
            </div>
        `;

        return;

    }


    historyList.innerHTML =
        data.map(
            (item) => `
                <article class="history-row">

                    <div class="history-date">

                        <strong>
                            ${formatDate(item.accountability_date)}
                        </strong>

                        <small>
                            ${
                                item.source === "admin_backfill"
                                    ? "Entered by administrator"
                                    : item.started
                                        ? "Member check-in"
                                        : "No submission"
                            }
                        </small>

                    </div>


                    <span
                        class="history-status ${item.status_label}"
                    >
                        ${statusLabel(item.status_label)}
                    </span>


                    <div>

                        <div class="history-progress-track">

                            <div
                                class="history-progress-fill"
                                style="width:${item.percentage}%"
                            ></div>

                        </div>

                        <div class="history-progress-text">
                            ${item.completed_categories}
                            /
                            ${item.total_categories}
                            parent tasks completed
                        </div>

                    </div>


                    <div class="history-percentage">
                        ${item.percentage}%
                    </div>

                </article>
            `
        ).join("");

}


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


    if (context.profile.role === "admin") {
        adminLink.hidden = false;
    }


    try {

        await loadHistory();

    }
    catch (error) {

        console.error(error);

        historyList.innerHTML = `
            <div class="dashboard-loading">
                ${error.message}
            </div>
        `;

    }

}


initialize();