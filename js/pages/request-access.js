import { supabase } from "../supabase.js";


const form =
    document.querySelector("#request-form");

const emailInput =
    document.querySelector("#application-email");

const questionContainer =
    document.querySelector("#dynamic-questions");

const title =
    document.querySelector("#questionnaire-title");

const intro =
    document.querySelector("#questionnaire-intro");

const message =
    document.querySelector("#request-message");

const button =
    document.querySelector("#request-button");

const privacyConsent =
    document.querySelector("#privacy-consent");


let questionnaire = null;


function escapeHtml(value = "") {

    return String(value)
        .replaceAll("&", "&amp;")
        .replaceAll("<", "&lt;")
        .replaceAll(">", "&gt;")
        .replaceAll('"', "&quot;")
        .replaceAll("'", "&#039;");

}


function showMessage(text, type = "") {

    message.textContent = text;

    message.className =
        "auth-message";

    if (type) {
        message.classList.add(type);
    }

    message.hidden = false;

}


function fieldName(question) {

    return `question_${question.id}`;

}


function renderQuestion(question) {

    const name =
        fieldName(question);

    const required =
        question.required
            ? "required"
            : "";

    const requiredMark =
        question.required
            ? "<strong>*</strong>"
            : "";


    let control = "";


    if (question.field_type === "long_text") {

        control = `
            <textarea
                id="${name}"
                name="${name}"
                rows="4"
                ${required}
            ></textarea>
        `;

    }
    else if (question.field_type === "single_choice") {

        control = `
            <select
                id="${name}"
                name="${name}"
                ${required}
            >

                <option value="">
                    Select an option
                </option>

                ${
                    (question.options || [])
                        .map(
                            (option) => `
                                <option value="${escapeHtml(option)}">
                                    ${escapeHtml(option)}
                                </option>
                            `
                        )
                        .join("")
                }

            </select>
        `;

    }
    else if (question.field_type === "yes_no") {

        control = `
            <div class="choice-row">

                ${
                    (question.options || ["Yes", "No"])
                        .map(
                            (option) => `
                                <label class="choice-chip">

                                    <input
                                        type="radio"
                                        name="${name}"
                                        value="${escapeHtml(option)}"
                                        ${required}
                                    >

                                    <span>
                                        ${escapeHtml(option)}
                                    </span>

                                </label>
                            `
                        )
                        .join("")
                }

            </div>
        `;

    }
    else if (question.field_type === "multiple_choice") {

        control = `
            <div class="choice-grid">

                ${
                    (question.options || [])
                        .map(
                            (option) => `
                                <label class="choice-checkbox">

                                    <input
                                        type="checkbox"
                                        name="${name}"
                                        value="${escapeHtml(option)}"
                                    >

                                    <span>
                                        ${escapeHtml(option)}
                                    </span>

                                </label>
                            `
                        )
                        .join("")
                }

            </div>
        `;

    }
    else if (question.field_type === "number") {

        control = `
            <input
                id="${name}"
                name="${name}"
                type="number"
                ${required}
            >
        `;

    }
    else if (question.field_type === "date") {

        control = `
            <input
                id="${name}"
                name="${name}"
                type="date"
                ${required}
            >
        `;

    }
    else if (question.field_type === "scale") {

        control = `
            <div class="scale-row">

                ${
                    Array.from(
                        {
                            length: 10
                        },
                        (_, index) =>
                            index + 1
                    )
                    .map(
                        (number) => `
                            <label class="scale-choice">

                                <input
                                    type="radio"
                                    name="${name}"
                                    value="${number}"
                                    ${required}
                                >

                                <span>
                                    ${number}
                                </span>

                            </label>
                        `
                    )
                    .join("")
                }

            </div>
        `;

    }
    else {

        control = `
            <input
                id="${name}"
                name="${name}"
                type="text"
                ${required}
            >
        `;

    }


    return `
        <div class="question-field">

            <label
                class="question-label"
                for="${name}"
            >
                ${escapeHtml(question.label)}
                ${requiredMark}
            </label>

            ${control}

            ${
                question.help_text
                    ? `
                        <small>
                            ${escapeHtml(question.help_text)}
                        </small>
                    `
                    : ""
            }

        </div>
    `;

}


function renderQuestionnaire() {

    const groups =
        new Map();


    questionnaire.questions.forEach(
        (question) => {

            if (!groups.has(question.section_key)) {

                groups.set(
                    question.section_key,
                    {
                        title:
                            question.section_title,

                        questions: []
                    }
                );

            }


            groups.get(
                question.section_key
            ).questions.push(question);

        }
    );


    questionContainer.innerHTML =
        Array.from(
            groups.entries()
        )
        .map(
            ([key, section], index) => `
                <section
                    class="question-section"
                    data-section="${escapeHtml(key)}"
                >

                    <div class="question-section-heading">

                        <span>
                            ${String(index + 1).padStart(2, "0")}
                        </span>

                        <h2>
                            ${escapeHtml(section.title)}
                        </h2>

                    </div>


                    <div class="question-grid">

                        ${
                            section.questions
                                .map(renderQuestion)
                                .join("")
                        }

                    </div>

                </section>
            `
        )
        .join("");

}


function readAnswer(question) {

    const name =
        fieldName(question);


    if (question.field_type === "multiple_choice") {

        return Array.from(
            document.querySelectorAll(
                `[name="${name}"]:checked`
            )
        )
        .map(
            (input) =>
                input.value
        );

    }


    if (
        question.field_type === "yes_no"
        ||
        question.field_type === "scale"
    ) {

        const checked =
            document.querySelector(
                `[name="${name}"]:checked`
            );


        if (!checked) {
            return null;
        }


        if (question.field_type === "scale") {
            return Number(checked.value);
        }


        return checked.value;

    }


    const input =
        document.querySelector(
            `[name="${name}"]`
        );


    if (!input) {
        return null;
    }


    const value =
        input.value.trim();


    if (question.field_type === "number") {

        return value === ""
            ? null
            : Number(value);

    }


    return value === ""
        ? null
        : value;

}


function collectAnswers() {

    const answers = {};


    questionnaire.questions.forEach(
        (question) => {

            const value =
                readAnswer(question);


            if (
                value !== null
                &&
                !(
                    Array.isArray(value)
                    &&
                    value.length === 0
                )
            ) {

                answers[question.id] =
                    value;

            }

        }
    );


    return answers;

}


async function loadQuestionnaire() {

    const {
        data,
        error
    } = await supabase.rpc(
        "get_published_onboarding_questionnaire"
    );


    if (error) {
        throw error;
    }


    questionnaire = data;


    title.textContent =
        questionnaire.title;

    intro.textContent =
        questionnaire.intro;


    renderQuestionnaire();

}


form.addEventListener(
    "submit",
    async (event) => {

        event.preventDefault();

        message.hidden = true;


        if (!questionnaire) {

            showMessage(
                "The onboarding form has not finished loading.",
                "error"
            );

            return;

        }


        if (!form.reportValidity()) {
            return;
        }


        if (!privacyConsent.checked) {

            showMessage(
                "Please confirm the application privacy notice.",
                "error"
            );

            return;

        }


        button.disabled = true;

        button.textContent =
            "Submitting Application...";


        try {

            const {
                error
            } = await supabase.rpc(
                "submit_access_application",
                {
                    p_email:
                        emailInput.value
                            .trim()
                            .toLowerCase(),

                    p_answers:
                        collectAnswers()
                }
            );


            if (error) {
                throw error;
            }


            form.reset();


            showMessage(
                "Application submitted successfully. The Unleash Tribe administrators will review your responses. If approved, you will receive an email invitation to complete your account.",
                "success"
            );


            window.scrollTo({
                top: 0,
                behavior: "smooth"
            });

        }
        catch (error) {

            console.error(
                "Application submission failed:",
                error
            );


            showMessage(
                error?.message ||
                "Unable to submit your application.",
                "error"
            );

        }
        finally {

            button.disabled = false;

            button.textContent =
                "Submit Application";

        }

    }
);


loadQuestionnaire()
    .catch(
        (error) => {

            console.error(error);

            questionContainer.innerHTML = `
                <div class="question-loading">
                    Unable to load the onboarding form.
                    ${escapeHtml(error.message)}
                </div>
            `;

        }
    );