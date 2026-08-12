import { supabase } from "../supabase.js";

import {
    requireActiveUser
} from "../auth/guards.js";


const reportDate =
    document.querySelector("#report-date");

const reportList =
    document.querySelector("#report-list");

const reportMessage =
    document.querySelector("#report-message");

const doneCount =
    document.querySelector("#done-count");

const incompleteCount =
    document.querySelector("#incomplete-count");

const notStartedCount =
    document.querySelector("#not-started-count");

const expectedCount =
    document.querySelector("#expected-count");

const backfillForm =
    document.querySelector("#backfill-form");

const backfillMember =
    document.querySelector("#backfill-member");

const backfillDate =
    document.querySelector("#backfill-date");

const backfillTasks =
    document.querySelector("#backfill-task-list");

const backfillReason =
    document.querySelector("#backfill-reason");

const logoutButton =
    document.querySelector("#logout-button");


let reportData = [];
let categories = [];
let tasks = [];


function escapeHtml(value = "") {

    return String(value)
        .replaceAll("&", "&amp;")
        .replaceAll("<", "&lt;")
        .replaceAll(">", "&gt;")
        .replaceAll('"', "&quot;")
        .replaceAll("'", "&#039;");

}


function showMessage(text) {

    reportMessage.textContent =
        text;

    reportMessage.hidden =
        false;

}


function activeOnDate(record, date) {

    if (!record.is_active) {
        return false;
    }


    if (
        record.starts_on &&
        record.starts_on > date
    ) {
        return false;
    }


    if (
        record.ends_on &&
        record.ends_on < date
    ) {
        return false;
    }


    return true;

}


function statusText(status) {

    if (status === "done") {
        return "Done";
    }

    if (status === "incomplete") {
        return "Incomplete";
    }

    return "Not Started";

}


function renderReport() {

    doneCount.textContent =
        String(
            reportData.filter(
                (row) =>
                    row.checkin_status === "done"
            ).length
        );


    incompleteCount.textContent =
        String(
            reportData.filter(
                (row) =>
                    row.checkin_status === "incomplete"
            ).length
        );


    notStartedCount.textContent =
        String(
            reportData.filter(
                (row) =>
                    row.checkin_status === "not_started"
            ).length
        );


    expectedCount.textContent =
        String(reportData.length);


    backfillMember.innerHTML =
        reportData
            .map(
                (row) => `
                    <option value="${row.user_id}">
                        ${escapeHtml(row.full_name)}
                    </option>
                `
            )
            .join("");


    if (!reportData.length) {

        reportList.innerHTML = `
            <div class="dashboard-loading">
                No active members were expected
                for this accountability date.
            </div>
        `;

        return;

    }


    reportList.innerHTML =
        reportData.map(
            (row) => `
                <article class="report-row">

                    <div class="report-member">

                        <strong>
                            ${escapeHtml(row.full_name)}
                        </strong>

                        <small>
                            ${
                                row.username
                                    ? `@${escapeHtml(row.username)}`
                                    : escapeHtml(row.email)
                            }
                        </small>

                    </div>


                    <span
                        class="report-status ${row.checkin_status}"
                    >
                        ${statusText(row.checkin_status)}
                    </span>


                    <div class="report-score">
                        ${row.completed_categories}
                        /
                        ${row.total_categories}
                    </div>


                    <div>

                        <div class="report-bar">

                            <span
                                style="width:${row.percentage}%"
                            ></span>

                        </div>

                        <small>
                            ${row.percentage}%
                        </small>

                    </div>

                </article>
            `
        ).join("");

}


async function loadReport() {

    const {
        data,
        error
    } = await supabase.rpc(
        "admin_accountability_report",
        {
            p_date:
                reportDate.value
        }
    );


    if (error) {
        throw error;
    }


    reportData =
        data || [];


    renderReport();

}


async function loadTaskDefinitions() {

    const [
        categoryResponse,
        taskResponse
    ] = await Promise.all([

        supabase
            .from("growth_areas")
            .select(
                "id, name, sort_order, starts_on, ends_on, is_active"
            )
            .order(
                "sort_order",
                {
                    ascending: true
                }
            ),

        supabase
            .from("checklist_items")
            .select(
                "id, growth_area_id, label, sort_order, starts_on, ends_on, is_active, is_required"
            )
            .order(
                "sort_order",
                {
                    ascending: true
                }
            )

    ]);


    if (categoryResponse.error) {
        throw categoryResponse.error;
    }


    if (taskResponse.error) {
        throw taskResponse.error;
    }


    categories =
        categoryResponse.data || [];

    tasks =
        taskResponse.data || [];

}


function renderBackfillTasks() {

    const date =
        backfillDate.value;


    if (!date) {

        backfillTasks.textContent =
            "Choose a historical date.";

        return;

    }


    const visibleCategories =
        categories.filter(
            (category) =>
                activeOnDate(
                    category,
                    date
                )
        );


    const markup =
        visibleCategories
            .map(
                (category) => {

                    const children =
                        tasks.filter(
                            (task) =>
                                Number(task.growth_area_id) ===
                                    Number(category.id)
                                &&
                                activeOnDate(
                                    task,
                                    date
                                )
                        );


                    if (!children.length) {
                        return "";
                    }


                    return `
                        <section class="backfill-category">

                            <h3>
                                ${escapeHtml(category.name)}
                            </h3>

                            <div class="backfill-checkboxes">

                                ${
                                    children.map(
                                        (task) => `
                                            <label>

                                                <input
                                                    type="checkbox"
                                                    name="backfill-task"
                                                    value="${task.id}"
                                                >

                                                <span>
                                                    ${escapeHtml(task.label)}
                                                </span>

                                            </label>
                                        `
                                    ).join("")
                                }

                            </div>

                        </section>
                    `;

                }
            )
            .join("");


    backfillTasks.innerHTML =
        markup ||
        `
            <div class="dashboard-loading">
                No tasks existed for this date.
            </div>
        `;

}


async function chooseInitialDate() {

    const {
        data,
        error
    } = await supabase.rpc(
        "get_my_checkin_history",
        {
            p_limit: 1
        }
    );


    if (
        !error &&
        data?.length
    ) {

        reportDate.value =
            data[0].accountability_date;

        backfillDate.value =
            data[0].accountability_date;

        return;

    }


    const today =
        new Date()
            .toISOString()
            .slice(0, 10);


    reportDate.value =
        today;

    backfillDate.value =
        today;

}


reportDate.addEventListener(
    "change",
    async () => {

        try {

            await loadReport();

        }
        catch (error) {

            showMessage(error.message);

        }

    }
);


backfillDate.addEventListener(
    "change",
    renderBackfillTasks
);


backfillForm.addEventListener(
    "submit",
    async (event) => {

        event.preventDefault();


        const selectedIds =
            Array.from(
                document.querySelectorAll(
                    'input[name="backfill-task"]:checked'
                )
            )
            .map(
                (checkbox) =>
                    checkbox.value
            );


        const confirmed =
            window.confirm(
                "Create this historical accountability record?"
            );


        if (!confirmed) {
            return;
        }


        const {
            error
        } = await supabase.rpc(
            "admin_backfill_checkin",
            {
                p_user_id:
                    backfillMember.value,

                p_date:
                    backfillDate.value,

                p_completed_task_ids:
                    selectedIds,

                p_reason:
                    backfillReason.value.trim()
            }
        );


        if (error) {

            showMessage(error.message);

            return;

        }


        showMessage(
            "Historical check-in saved and added to the audit log."
        );


        backfillReason.value = "";


        if (
            reportDate.value ===
            backfillDate.value
        ) {

            await loadReport();

        }

    }
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


    try {

        await loadTaskDefinitions();

        await chooseInitialDate();

        renderBackfillTasks();

        await loadReport();

    }
    catch (error) {

        console.error(error);

        showMessage(
            error.message
        );

    }

}


initialize();