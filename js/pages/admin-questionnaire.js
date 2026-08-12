import { supabase } from "../supabase.js";

import {
    requireActiveUser
} from "../auth/guards.js";


const publishedVersion =
    document.querySelector("#published-version");

const draftVersion =
    document.querySelector("#draft-version");

const createDraftButton =
    document.querySelector("#create-draft-button");

const publishButton =
    document.querySelector("#publish-button");

const editorSection =
    document.querySelector("#editor-section");

const questionList =
    document.querySelector("#draft-question-list");

const message =
    document.querySelector("#questionnaire-message");

const form =
    document.querySelector("#question-form");

const questionId =
    document.querySelector("#question-id");

const sectionKey =
    document.querySelector("#section-key");

const sectionTitle =
    document.querySelector("#section-title");

const questionKey =
    document.querySelector("#question-key");

const questionLabel =
    document.querySelector("#question-label");

const questionHelp =
    document.querySelector("#question-help");

const questionType =
    document.querySelector("#question-type");

const questionOptions =
    document.querySelector("#question-options");

const questionRequired =
    document.querySelector("#question-required");

const questionOrder =
    document.querySelector("#question-order");

const formTitle =
    document.querySelector("#question-form-title");

const cancelEditButton =
    document.querySelector("#cancel-edit-button");

const logoutButton =
    document.querySelector("#logout-button");


let versions = [];
let draftQuestions = [];
let draft = null;


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


function clearForm() {

    form.reset();

    questionId.value = "";

    questionOrder.value =
        draftQuestions.length
            ? Math.max(
                ...draftQuestions.map(
                    (question) =>
                        question.sort_order
                )
            ) + 10
            : 10;

    formTitle.textContent =
        "Add Question";

}


function renderVersions() {

    const published =
        versions.find(
            (version) =>
                version.status === "published"
        );


    draft =
        versions.find(
            (version) =>
                version.status === "draft"
        );


    publishedVersion.textContent =
        published
            ? `Version ${published.version_number}`
            : "None";


    draftVersion.textContent =
        draft
            ? `Version ${draft.version_number}`
            : "None";


    createDraftButton.hidden =
        Boolean(draft);


    publishButton.hidden =
        !draft;


    editorSection.hidden =
        !draft;

}


function renderQuestions() {

    if (!draftQuestions.length) {

        questionList.innerHTML = `
            <div class="admin-empty">
                This draft has no questions.
            </div>
        `;

        return;

    }


    questionList.innerHTML =
        draftQuestions
            .map(
                (question) => `
                    <article
                        class="draft-question"
                        data-question-id="${question.id}"
                    >

                        <div class="draft-question-heading">

                            <div>

                                <strong>
                                    ${escapeHtml(question.label)}
                                </strong>

                                <small>
                                    ${escapeHtml(question.section_title)}
                                </small>

                            </div>

                            ${
                                question.is_required
                                    ? "<strong>Required</strong>"
                                    : ""
                            }

                        </div>


                        <div class="draft-question-meta">
                            ${escapeHtml(question.question_key)}
                            ·
                            ${escapeHtml(question.field_type)}
                            ·
                            order ${question.sort_order}
                        </div>


                        <div class="draft-question-actions">

                            <button
                                type="button"
                                class="edit-question"
                                data-edit-question="${question.id}"
                            >
                                Edit
                            </button>

                            <button
                                type="button"
                                class="delete-question"
                                data-delete-question="${question.id}"
                            >
                                Delete
                            </button>

                        </div>

                    </article>
                `
            )
            .join("");

}


async function loadVersions() {

    const {
        data,
        error
    } = await supabase
        .from("onboarding_questionnaire_versions")
        .select(
            "id, version_number, status, title, intro, created_at, published_at"
        )
        .order(
            "version_number",
            {
                ascending: false
            }
        );


    if (error) {
        throw error;
    }


    versions =
        data || [];


    renderVersions();

}


async function loadDraftQuestions() {

    if (!draft) {

        draftQuestions = [];

        renderQuestions();

        return;

    }


    const {
        data,
        error
    } = await supabase
        .from("onboarding_questions")
        .select(
            "id, section_key, section_title, question_key, label, help_text, field_type, options, is_required, sort_order"
        )
        .eq(
            "version_id",
            draft.id
        )
        .order(
            "sort_order",
            {
                ascending: true
            }
        );


    if (error) {
        throw error;
    }


    draftQuestions =
        data || [];


    renderQuestions();

    clearForm();

}


function editQuestion(id) {

    const question =
        draftQuestions.find(
            (item) =>
                item.id === id
        );


    if (!question) {
        return;
    }


    questionId.value =
        question.id;

    sectionKey.value =
        question.section_key;

    sectionTitle.value =
        question.section_title;

    questionKey.value =
        question.question_key;

    questionLabel.value =
        question.label;

    questionHelp.value =
        question.help_text || "";

    questionType.value =
        question.field_type;

    questionOptions.value =
        (question.options || [])
            .join("\n");

    questionRequired.checked =
        question.is_required;

    questionOrder.value =
        question.sort_order;

    formTitle.textContent =
        "Edit Question";


    window.scrollTo({
        top: form.offsetTop - 100,
        behavior: "smooth"
    });

}


function parseOptions() {

    return questionOptions.value
        .split("\n")
        .map(
            (option) =>
                option.trim()
        )
        .filter(Boolean);

}


createDraftButton.addEventListener(
    "click",
    async () => {

        createDraftButton.disabled =
            true;


        const {
            error
        } = await supabase.rpc(
            "admin_create_questionnaire_draft"
        );


        createDraftButton.disabled =
            false;


        if (error) {

            showMessage(
                error.message
            );

            return;

        }


        showMessage(
            "Draft questionnaire created."
        );


        await loadVersions();

        await loadDraftQuestions();

    }
);


form.addEventListener(
    "submit",
    async (event) => {

        event.preventDefault();


        const {
            error
        } = await supabase.rpc(
            "admin_save_onboarding_question",
            {
                p_question_id:
                    questionId.value || null,

                p_section_key:
                    sectionKey.value.trim(),

                p_section_title:
                    sectionTitle.value.trim(),

                p_question_key:
                    questionKey.value
                        .trim()
                        .toLowerCase(),

                p_label:
                    questionLabel.value.trim(),

                p_help_text:
                    questionHelp.value.trim()
                    || null,

                p_field_type:
                    questionType.value,

                p_options:
                    parseOptions(),

                p_required:
                    questionRequired.checked,

                p_sort_order:
                    Number(
                        questionOrder.value
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
            "Draft question saved."
        );


        await loadDraftQuestions();

    }
);


questionList.addEventListener(
    "click",
    async (event) => {

        const editButton =
            event.target.closest(
                "[data-edit-question]"
            );

        const deleteButton =
            event.target.closest(
                "[data-delete-question]"
            );


        if (editButton) {

            editQuestion(
                editButton.dataset.editQuestion
            );

            return;

        }


        if (deleteButton) {

            const confirmed =
                window.confirm(
                    "Delete this question from the draft?"
                );


            if (!confirmed) {
                return;
            }


            const {
                error
            } = await supabase.rpc(
                "admin_delete_onboarding_question",
                {
                    p_question_id:
                        deleteButton.dataset.deleteQuestion
                }
            );


            if (error) {

                showMessage(
                    error.message
                );

                return;

            }


            showMessage(
                "Draft question deleted."
            );


            await loadDraftQuestions();

        }

    }
);


publishButton.addEventListener(
    "click",
    async () => {

        const confirmed =
            window.confirm(
                "Publish this questionnaire version? New applicants will immediately receive it."
            );


        if (!confirmed) {
            return;
        }


        const {
            data,
            error
        } = await supabase.rpc(
            "admin_publish_questionnaire"
        );


        if (error) {

            showMessage(
                error.message
            );

            return;

        }


        showMessage(
            `Questionnaire version ${data} published.`
        );


        await loadVersions();

        await loadDraftQuestions();

    }
);


cancelEditButton.addEventListener(
    "click",
    clearForm
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

        await loadVersions();

        await loadDraftQuestions();

    }
    catch (error) {

        console.error(error);

        showMessage(
            error.message
        );

    }

}


initialize();