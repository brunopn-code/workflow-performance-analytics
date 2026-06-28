import streamlit as st
import pandas as pd
import plotly.express as px
from pathlib import Path


# ------------------------------------------------------------
# Page configuration
# ------------------------------------------------------------

st.set_page_config(
    page_title="Workflow Performance Analytics",
    page_icon="📊",
    layout="wide"
)


# ------------------------------------------------------------
# Load KPI data
# ------------------------------------------------------------

BASE_DIR = Path(__file__).resolve().parent.parent
KPI_DIR = BASE_DIR / "data" / "kpis"


@st.cache_data
def load_csv(filename):
    return pd.read_csv(KPI_DIR / filename)


case_duration = load_csv("case_duration_categories.csv")
activity_frequency = load_csv("activity_frequency.csv")
rework_by_duration = load_csv("rework_by_duration.csv")
key_transitions = load_csv("key_transition_comparison.csv")
waiting_time = load_csv("waiting_time_summary.csv")
resource_workload = load_csv("resource_workload.csv")


# ------------------------------------------------------------
# Dashboard title
# ------------------------------------------------------------

st.title("Workflow Performance Analytics")
st.markdown(
    """
    This dashboard summarizes process KPIs from the **BPI Challenge 2012**
    loan application event log.

    The goal is to monitor case duration, repeated activities, waiting-time
    bottlenecks, and workload distribution.
    """
)


# ------------------------------------------------------------
# Overview KPIs
# ------------------------------------------------------------

st.header("Process Overview")

total_cases = int(case_duration["total_cases"].sum())
largest_category = case_duration.sort_values("total_cases", ascending=False).iloc[0]

col1, col2, col3 = st.columns(3)

col1.metric("Total Cases", f"{total_cases:,}")
col2.metric("Largest Duration Category", largest_category["duration_category"])
col3.metric("Largest Category Share", f"{largest_category['case_percentage']}%")


# ------------------------------------------------------------
# Case duration categories
# ------------------------------------------------------------

st.header("Case Duration Categories")

fig_case_duration = px.bar(
    case_duration,
    x="duration_category",
    y="total_cases",
    text="case_percentage",
    title="Cases by Duration Category",
    labels={
        "duration_category": "Duration Category",
        "total_cases": "Total Cases",
        "case_percentage": "Case Percentage"
    }
)

fig_case_duration.update_traces(texttemplate="%{text}%", textposition="outside")
st.plotly_chart(fig_case_duration, use_container_width=True)


# ------------------------------------------------------------
# Activity frequency
# ------------------------------------------------------------

st.header("Most Frequent Activities")

top_activities = activity_frequency.head(10)

fig_activity = px.bar(
    top_activities.sort_values("total_events"),
    x="total_events",
    y="activity",
    orientation="h",
    title="Top 10 Most Frequent Activities",
    labels={
        "total_events": "Total Events",
        "activity": "Activity"
    }
)

st.plotly_chart(fig_activity, use_container_width=True)


# ------------------------------------------------------------
# Rework analysis
# ------------------------------------------------------------

st.header("Rework by Duration Category")

selected_category = st.selectbox(
    "Select duration category",
    sorted(rework_by_duration["duration_category"].unique())
)

filtered_rework = rework_by_duration[
    rework_by_duration["duration_category"] == selected_category
].sort_values("rework_case_rate", ascending=True)

fig_rework = px.bar(
    filtered_rework,
    x="rework_case_rate",
    y="activity",
    orientation="h",
    title=f"Rework Case Rate - {selected_category}",
    labels={
        "rework_case_rate": "Rework Case Rate (%)",
        "activity": "Activity"
    }
)

st.plotly_chart(fig_rework, use_container_width=True)

st.markdown(
    """
    Rework is defined as a completed workflow activity appearing more than once
    in the same case.
    """
)


# ------------------------------------------------------------
# Key transition analysis
# ------------------------------------------------------------

st.header("Key Transition Comparison")

fig_transition_frequency = px.bar(
    key_transitions,
    x="transitions_per_case",
    y="transition",
    color="duration_category",
    orientation="h",
    barmode="group",
    title="Transition Frequency per Case by Duration Category",
    labels={
        "transitions_per_case": "Transitions per Case",
        "transition": "Transition",
        "duration_category": "Duration Category"
    }
)

st.plotly_chart(fig_transition_frequency, use_container_width=True)


fig_transition_wait = px.bar(
    key_transitions,
    x="median_wait_days",
    y="transition",
    color="duration_category",
    orientation="h",
    barmode="group",
    title="Median Waiting Time by Transition",
    labels={
        "median_wait_days": "Median Waiting Time (Days)",
        "transition": "Transition",
        "duration_category": "Duration Category"
    }
)

st.plotly_chart(fig_transition_wait, use_container_width=True)


# ------------------------------------------------------------
# Waiting time table
# ------------------------------------------------------------

st.header("Longest Median Waiting Times")

waiting_time_display = waiting_time.sort_values(
    "median_wait_days",
    ascending=False
).head(15)

st.dataframe(
    waiting_time_display[
        [
            "transition",
            "transition_count",
            "mean_wait_days",
            "median_wait_days",
            "p95_wait_days"
        ]
    ],
    use_container_width=True
)


# ------------------------------------------------------------
# Resource workload
# ------------------------------------------------------------

st.header("Resource Workload")

top_resources = resource_workload.head(15)

fig_resources = px.bar(
    top_resources.sort_values("completed_workflow_events"),
    x="completed_workflow_events",
    y="resource",
    orientation="h",
    title="Top 15 Resources by Completed Workflow Events",
    labels={
        "completed_workflow_events": "Completed Workflow Events",
        "resource": "Resource"
    }
)

st.plotly_chart(fig_resources, use_container_width=True)


# ------------------------------------------------------------
# Main conclusion
# ------------------------------------------------------------

st.header("Main Insight")

st.markdown(
    """
    The analysis suggests that long case durations are not mainly caused by
    individual workflow tasks taking a long time to execute.

    Instead, delayed cases appear to be associated with repeated follow-up
    cycles and waiting time between activities, especially around:

    - `W_Nabellen offertes → W_Nabellen offertes`
    - `W_Nabellen offertes → O_SENT_BACK`
    - `W_Nabellen offertes → W_Valideren aanvraag`

    The strongest candidate for further bottleneck investigation is
    `W_Nabellen offertes`, which becomes much more frequent in very delayed cases.
    """
)
