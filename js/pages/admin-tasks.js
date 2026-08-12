import { supabase } from "../supabase.js";

import {
    requireActiveUser
} from "../auth/guards.js";


const settingsForm =
    document.querySelector("#settings-form");

const timezoneInput =
    document.querySelector("#timezone-input");

const openTimeInput =
    document.querySelector("#open-time-input");

const closeTimeInput =
    document.querySelector("#close-time-input");

const parentForm =
    document.querySelector("#parent-form");

const parentName =
    document.querySelector("#parent-name");

const parentDescription =
    document.querySelector("#parent-description");

const parentStart =
    document.querySelector("#parent-start");

const parentEnd =
    document.querySelector("#parent-end");

const parentRequired =
    document.querySelector("#parent-required");

const childForm =
    document.querySelector("#child-form");

const childParent =
    document.querySelector("#child-parent");

const childLabel =
    document.querySelector("#child-label");

const childStart =
    document.querySelector("#child-start");

const childEnd =
    document.querySelector("#child-end");

const childRequired =
    document.querySelector("#child-required");

const taskList =
    document.querySelector("#admin-task-list");

const refreshButton =
    document.querySelector("#refresh-tasks");

const message =
    document.querySelector("#admin-task-message");

const logoutButton =
    document.querySelector("#logout-button");


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

    message.textContent =
        text;

    message.hidden =
        false;

}


function normalizeTime(value) {

    if (!value) {
        return "";
    }

    return value.slice(0, 5);

}


function scheduleText(record) {

    const parts = [];


    if (record.starts_on) {

        parts.push(
            `Starts ${record.starts_on}`
        );

    }


    if (record.ends_on) {

        parts.push(
            `Ends ${record.ends_on}`
        );

    }


    if (!record.is_active) {

        parts.push("Cancelled");

    }


    if (parts.length === 0) {

        return "Always active";

    }


    return parts.join(" · ");

}


async function loadSettings() {

    const {
        data,
        error
    } = await supabase
        .from("app_settings")
        .select(
            "community_timezone, accountability_open_time, accountability_close_time"
        )
        .eq("id", true)
        .single();


    if (error) {
        throw error;
    }


    timezoneInput.value =
        data.community_timezone || "UTC";

    openTimeInput.value =
        normalizeTime(
            data.accountability_open_time
        );

    closeTimeInput.value =
        normalizeTime(
            data.accountability_close_time
        );

}


async function loadTaskLibrary() {

    const [
        categoryResponse,
        taskResponse
    ] = await Promise.all([

        supabase
            .from("growth_areas")
            .select(
                "id, name, description, sort_order, is_required, starts_on, ends_on, is_active"
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
                "id, growth_area_id, label, sort_order, is_required, starts_on, ends_on, is_active"
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


    renderParentOptions();
    renderTasks();

}


function renderParentOptions() {

    const usableParents =
        categories.filter(
            (category) =>
                category.is_active
        );


    childParent.innerHTML =
        usableParents
            .map(
                (category) => `
                    <option value="${category.id}">
                        ${escapeHtml(category.name)}
                    </option>
                `
            )
            .join("");

}


function renderTasks() {

    if (categories.length === 0) {

        taskList.innerHTML =
            "No parent tasks exist.";

        return;
    }


    taskList.innerHTML =
        categories
            .map(
                (category) => {

                    const childTasks =
                        tasks.filter(
                            (task) =>
                                Number(
                                    task.growth_area_id
                                ) ===
                                Number(
                                    category.id
                                )
                        );


                    const childMarkup =
                        childTasks.length

                            ? childTasks
                                .map(
                                    (task) => `
                                        <div class="admin-child">

                                            <div>

                                                <div class="admin-child-name">
                                                    ${escapeHtml(task.label)}

                                                    ${
                                                        task.is_required
                                                            ? `
                                                                <span class="status-badge">
                                                                    REQUIRED
                                                                </span>
                                                            `
                                                            : `
                                                                <span class="status-badge">
                                                                    OPTIONAL
                                                                </span>
                                                            `
                                                    }
                                                </div>

                                                <small>
                                                    ${escapeHtml(scheduleText(task))}
                                                </small>

                                            </div>


                                            ${
                                                task.is_active
                                                    ? `
                                                        <button
                                                            type="button"
                                                            class="archive-button"
                                                            data-archive-child="${task.id}"
                                                        >
                                                            Archive
                                                        </button>
                                                    `
                                                    : ""
                                            }

                                        </div>
                                    `
                                )
                                .join("")

                            : `
                                <div class="admin-child">
                                    No child tasks yet.
                                </div>
                            `;


                    return `
                        <article class="admin-parent-card">

                            <div class="admin-parent-header">

                                <div>

                                    <h3>
                                        ${escapeHtml(category.name)}

                                        ${
                                            category.is_required
                                                ? `
                                                    <span class="status-badge">
                                                        REQUIRED PARENT
                                                    </span>
                                                `
                                                : ""
                                        }

                                    </h3>

                                    <div class="admin-parent-meta">
                                        ${escapeHtml(scheduleText(category))}
                                    </div>

                                </div>


                                ${
                                    category.is_active
                                        ? `
                                            <button
                                                type="button"
                                                class="archive-button"
                                                data-archive-parent="${category.id}"
                                            >
                                                Archive Parent
                                            </button>
                                        `
                                        : ""
                                }

                            </div>


                            <div class="admin-child-list">
                                ${childMarkup}
                            </div>

                        </article>
                    `;

                }
            )
            .join("");

}


settingsForm.addEventListener(
    "submit",
    async (event) => {

        event.preventDefault();


        const {
            error
        } = await supabase
            .from("app_settings")
            .update({

                community_timezone:
                    timezoneInput.value.trim(),

                accountability_open_time:
                    openTimeInput.value,

                accountability_close_time:
                    closeTimeInput.value

            })
            .eq("id", true);


        if (error) {

            showMessage(
                error.message
            );

            return;
        }


        showMessage(
            "Accountability schedule saved."
        );

    }
);


parentForm.addEventListener(
    "submit",
    async (event) => {

        event.preventDefault();


        const {
            error
        } = await supabase.rpc(
            "admin_create_growth_area",
            {

                p_name:
                    parentName.value.trim(),

                p_description:
                    parentDescription.value.trim()
                    || null,

                p_starts_on:
                    parentStart.value
                    || null,

                p_ends_on:
                    parentEnd.value
                    || null,

                p_required:
                    parentRequired.checked

            }
        );


        if (error) {

            showMessage(
                error.message
            );

            return;
        }


        parentForm.reset();
        parentRequired.checked = true;

        showMessage(
            "Parent task created."
        );

        await loadTaskLibrary();

    }
);


childForm.addEventListener(
    "submit",
    async (event) => {

        event.preventDefault();


        const {
            error
        } = await supabase.rpc(
            "admin_create_checklist_item",
            {

                p_growth_area_id:
                    Number(
                        childParent.value
                    ),

                p_label:
                    childLabel.value.trim(),

                p_required:
                    childRequired.checked,

                p_starts_on:
                    childStart.value
                    || null,

                p_ends_on:
                    childEnd.value
                    || null

            }
        );


        if (error) {

            showMessage(
                error.message
            );

            return;
        }


        childForm.reset();
        childRequired.checked = true;

        showMessage(
            "Child task created."
        );

        await loadTaskLibrary();

    }
);


taskList.addEventListener(
    "click",
    async (event) => {

        const parentButton =
            event.target.closest(
                "[data-archive-parent]"
            );

        const childButton =
            event.target.closest(
                "[data-archive-child]"
            );


        if (parentButton) {

            const approved =
                window.confirm(
                    "Archive this parent task? Existing history will remain."
                );


            if (!approved) {
                return;
            }


            const {
                error
            } = await supabase.rpc(
                "admin_archive_growth_area",
                {
                    p_growth_area_id:
                        Number(
                            parentButton.dataset.archiveParent
                        )
                }
            );


            if (error) {

                showMessage(
                    error.message
                );

                return;
            }


            showMessage(
                "Parent task archived."
            );

            await loadTaskLibrary();

            return;

        }


        if (childButton) {

            const approved =
                window.confirm(
                    "Archive this child task? Existing history will remain."
                );


            if (!approved) {
                return;
            }


            const {
                error
            } = await supabase.rpc(
                "admin_archive_checklist_item",
                {
                    p_checklist_item_id:
                        childButton.dataset.archiveChild
                }
            );


            if (error) {

                showMessage(
                    error.message
                );

                return;
            }


            showMessage(
                "Child task archived."
            );

            await loadTaskLibrary();

        }

    }
);


refreshButton.addEventListener(
    "click",
    loadTaskLibrary
);


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


async function initializeAdminTasks() {

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


    try {

        await Promise.all([
            loadSettings(),
            loadTaskLibrary()
        ]);

    }
    catch (error) {

        console.error(
            "Task manager initialization failed:",
            error
        );

        showMessage(
            error.message
        );

    }

}


initializeAdminTasks();

