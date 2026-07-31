"""
Natural-language triggers for the business-analysis workflow.

Shared by the supervisor (routing: analysis phrases → insights domain) and the
insights agent (mapping the phrase to run_business_analysis's analysis_type).
Order matters — more specific intents are checked before generic ones, so
"how did the price change affect bookings" resolves to pricing_impact even
though it also mentions bookings.
"""
from __future__ import annotations

ANALYSIS_TRIGGERS: list[tuple[str, tuple[str, ...]]] = [
    ("pricing_impact", (
        "pricing impact", "price impact", "price change", "pricing change",
        "price update", "effect of price", "affect bookings", "price increase",
        "impact of pricing", "did the price",
    )),
    ("seasonal", (
        "seasonal", "peak season", "best months", "slow months",
        "busiest months", "season analysis", "seasonality",
    )),
    ("vehicles", (
        "vehicle performance", "which car makes", "which vehicle makes",
        "most profitable vehicle", "best performing vehicle", "top vehicle",
        "car performance", "which car earns", "most money",
    )),
    ("full_review", (
        "full review", "business review", "full analysis", "give me a report",
        "full report", "how are we doing", "business health", "full business",
        "complete analysis", "overall performance",
    )),
    ("revenue", (
        "revenue analysis", "analyze our revenue", "analyse our revenue",
        "revenue this month", "revenue this year", "show me the numbers",
        "revenue breakdown", "revenue trend", "monthly revenue",
    )),
]


def detect_analysis_type(text: str) -> str | None:
    """Return the analysis_type for a message, or None if it isn't an
    analytics request."""
    lower = text.lower()
    for analysis_type, phrases in ANALYSIS_TRIGGERS:
        if any(p in lower for p in phrases):
            return analysis_type
    return None
