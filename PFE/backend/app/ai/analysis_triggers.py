"""
Natural-language triggers for the business-analysis workflow.

Shared by the supervisor (routing: analysis phrases → insights domain) and the
insights agent (mapping the phrase to run_business_analysis's analysis mode).

Order matters — more specific intents are checked before generic ones, so
"how did the price change affect bookings" resolves to `pricing` even though it
also mentions bookings, and "revenue by vehicle category" resolves to
`vehicles` rather than `revenue`.

Deliberately NOT triggers: bare "bookings" / "all bookings" / "pending
bookings". Those are list queries the operations agent answers with
list_all_bookings — routing them here would replace a simple list with a chart
report.
"""
from __future__ import annotations

ANALYSIS_TRIGGERS: list[tuple[str, tuple[str, ...]]] = [
    ("pricing", (
        "pricing impact", "price impact", "price change", "pricing change",
        "price update", "effect of price", "affect bookings", "price increase",
        "impact of pricing", "did the price", "pricing analysis",
        "how did prices", "how did pricing", "price adjustment",
        "since we raised", "since we lowered",
    )),
    ("vehicles", (
        "vehicle performance", "which car makes", "which vehicle makes",
        "most profitable vehicle", "best performing vehicle", "top vehicle",
        "car performance", "which car earns", "most money", "fleet analytics",
        "fleet performance", "best vehicle", "which car", "which vehicle",
        "revenue by vehicle", "revenue by category", "per vehicle",
        "vehicle breakdown", "compare vehicles",
    )),
    ("seasonal", (
        "seasonal", "peak season", "best months", "slow months",
        "busiest months", "season analysis", "seasonality", "peak period",
        "peak periods", "monthly pattern", "monthly patterns",
        "trends over time", "when is busy", "when are we busy",
        "when are we busiest", "quiet months", "time of year",
    )),
    ("full_review", (
        "full review", "business review", "full analysis", "give me a report",
        "full report", "how are we doing", "business health", "full business",
        "complete analysis", "overall performance", "overall analysis",
        "how is the business", "how's the business", "everything you know",
    )),
    ("revenue", (
        "revenue", "income", "earnings", "how much money", "turnover",
        "show me the numbers", "financial health", "how much did we make",
        "how much have we made", "top line",
    )),
    ("bookings", (
        "booking trend", "booking trends", "booking volume", "booking stats",
        "booking statistics", "booking analysis", "bookings analysis",
        "reservation trend", "reservation trends", "how many trips",
        "how many bookings", "how many rides", "completion rate",
        "cancellation rate", "conversion rate", "trip volume",
        "analyse bookings", "analyze bookings", "booking performance",
    )),
]


def detect_analysis_mode(text: str) -> str | None:
    """Return the analysis mode for a message, or None if it isn't an
    analytics request.

    Modes: full_review | revenue | bookings | pricing | seasonal | vehicles
    """
    lower = text.lower()
    for mode, phrases in ANALYSIS_TRIGGERS:
        if any(p in lower for p in phrases):
            return mode
    return None


# Legacy name — the insights agent and older call sites import this.
detect_analysis_type = detect_analysis_mode
